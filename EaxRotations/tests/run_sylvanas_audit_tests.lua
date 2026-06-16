-- ============================================================================
-- What: Audit sylvanas.lua rotation files for spell IDs that do NOT exist
--       in the WoW client 2.5.5.68101 DBC database (via wowhead_data_bridge).
-- When: lua EaxRotations/tests/run_sylvanas_audit_tests.lua
-- Why:  Catches invalid spell IDs (e.g., 61336, 25285) that pass vanilla
--       audit but are bogus for TBC Anniversary. This is the positive check;
--       run_vanilla_audit_tests is the negative (TBC-contamination) check.
-- Exit: 0 = clean; 1 = invalid IDs found.
-- Safety: Read-only text scan + bridge lookup. No dofile(), no io writes.
-- ============================================================================

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;" .. package.path

local bridge_ok, bridge = pcall(require, "shared/wowhead_data_bridge_sylvanas")
if not bridge_ok or not bridge then
    print("[ERROR] Could not load wowhead_data_bridge_sylvanas")
    print("        Run: python build_tools/json_to_lua_data.py")
    os.exit(2)
end

local spell_index = bridge.spell_index_tbc or {}
local item_index  = bridge.item_index or {}

-- Count entries (hash tables, not arrays)
local spell_count, item_count = 0, 0
for _ in pairs(spell_index) do spell_count = spell_count + 1 end
for _ in pairs(item_index)  do item_count  = item_count  + 1 end

-- Build quick lookup tables
local valid_spell_ids = {}
for id in pairs(spell_index) do
    valid_spell_ids[id] = true
end

local valid_item_ids = {}
for id in pairs(item_index) do
    valid_item_ids[id] = true
end

local HAS_ITEM_INDEX = (item_count > 0)

-- ---------------------------------------------------------------------------
-- File list: every spec/leveling/class file for TBC Anniversary
--             + shared/ modules that contain spell IDs
-- ---------------------------------------------------------------------------
local SYLVANAS_FILES = {}
for _, class in ipairs({
    "druid", "hunter", "mage", "paladin", "priest",
    "rogue", "shaman", "warlock", "warrior",
}) do
    SYLVANAS_FILES[#SYLVANAS_FILES + 1] = "classes/" .. class .. "/class_sylvanas.lua"
    SYLVANAS_FILES[#SYLVANAS_FILES + 1] = "classes/" .. class .. "/leveling_sylvanas.lua"
    for _, suffix in ipairs({
        "balance", "bear", "cat", "caster", "resto",
        "beast_mastery", "marksmanship", "survival",
        "arcane", "fire", "frost",
        "holy", "protection", "retribution",
        "discipline", "shadow", "smite", "healing",
        "assassination", "combat", "subtlety",
        "elemental", "enhancement", "restoration",
        "affliction", "demonology", "destruction",
        "arms", "fury", "kebab",
    }) do
        SYLVANAS_FILES[#SYLVANAS_FILES + 1] = "classes/" .. class .. "/" .. suffix .. "_sylvanas.lua"
    end
end

-- Shared modules known to contain spell IDs (buffs, debuffs, talents, consumables)
local SHARED_FILES_WITH_IDS = {
    "shared/buff_upgrade_sylvanas.lua",
    "shared/cast_bar_overlay_sylvanas.lua",
    "shared/consumable_manager_sylvanas.lua",
    "shared/hot_tick_tracker_sylvanas.lua",
    "shared/ooc_manager_sylvanas.lua",
    "shared/talent_inference_sylvanas.lua",
    "shared/tbc_data_sylvanas.lua",
    "shared/weapon_imbue_sylvanas.lua",
}
for _, f in ipairs(SHARED_FILES_WITH_IDS) do
    SYLVANAS_FILES[#SYLVANAS_FILES + 1] = f
end

local root = "EaxRotations"

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------
local function read_file(path)
    local f = io.open(path, "rb")
    if not f then return nil end
    local content = f:read("*a") or ""
    f:close()
    return content
end

local function file_exists(path)
    local f = io.open(path, "rb")
    if f then f:close(); return true end
    return false
end

-- Patterns we scan for spell IDs:
--  - `ids = { N, N, ... }` inside spell_action calls
--  - `spell_ids = { N, N, ... }` in hot tick trackers
--  - `{ ids = { N, N, ... } }` in talent/buff tables (nested)
--  - Standalone BUFF/DEBUFF/SPELL arrays like `local X_BUFF = { N, N }`
-- Skip plain counters like `local _work_ids = { n = 0 }` — only match arrays
-- whose *contents* are dense numeric literals (not field assignments).
local function extract_ids_from_line(line)
    local ids = {}
    local function collect(block)
        if block:find("=") then return end
        for n in block:gmatch("(%d+)") do
            local v = tonumber(n)
            if v >= 1000 and v <= 99999 then
                ids[#ids + 1] = v
            end
        end
    end
    -- `%b{}` captures the braces only; strip them so `=` check is content-only.
    local inner = line:match("[%w_]*ids%s*=%s*(%b{})")
    if inner then
        local body = inner:sub(2, -2)
        collect(body)
        if #ids > 0 then return ids end
    end
    local arr_inner = line:match("^%s*[%w_]+%s*=%s*(%b{})")
    if arr_inner then collect(arr_inner:sub(2, -2)) end
    return ids
end

local function is_comment_line(line)
    return line:match("^%s*%-%-") ~= nil
end

local function scan_file(filepath)
    if not file_exists(filepath) then
        return { skipped = true, hits = {} }
    end
    local content = read_file(filepath)
    if not content then
        return { error = "could not read", hits = {} }
    end

    local hits = {}
    local line_no = 0
    for line in content:gmatch("[^\r\n]+") do
        line_no = line_no + 1
        if not is_comment_line(line) then
            local ids = extract_ids_from_line(line)
            for _, id in ipairs(ids) do
                if not valid_spell_ids[id] then
                    local kind = "INVALID"
                    if valid_item_ids[id] then
                        kind = "ITEM_AS_SPELL"
                    end
                    hits[#hits + 1] = {
                        line = line_no,
                        id = id,
                        kind = kind,
                        snippet = (line:match("^%s*(.-)%s*$") or line):sub(1, 100),
                    }
                end
            end
        end
    end

    return { found = #hits > 0, hits = hits }
end

-- ---------------------------------------------------------------------------
-- Main
-- ---------------------------------------------------------------------------
print("=============================================================================")
print("  SYLVANAS SPELL ID AUDIT (positive DBC existence check)")
print("  Source: wowheadScrape/dbc_extract/wowsims.db (client 2.5.5.68101)")
print(string.format("  Bridge: %d TBC spells, %d items loaded", spell_count, item_count))
print("=============================================================================")
print("")

local total, skipped, passed, failed = 0, 0, 0, 0
local failures = {}

for _, file in ipairs(SYLVANAS_FILES) do
    local path = root .. "/" .. file
    total = total + 1

    local result = scan_file(path)
    if result.skipped then
        skipped = skipped + 1
    elseif result.error then
        failed = failed + 1
        failures[#failures + 1] = { file = file, error = result.error }
        print(string.format("  [ ERROR ] %-50s %s", file, result.error))
    elseif result.found then
        failed = failed + 1
        failures[#failures + 1] = { file = file, hits = result.hits }
        print(string.format("  [ FAIL ]  %-50s %d invalid ID(s)", file, #result.hits))
        for _, hit in ipairs(result.hits) do
            print(string.format("            line %4d: id %d [%s]  %s",
                hit.line, hit.id, hit.kind, hit.snippet))
        end
    else
        passed = passed + 1
        print(string.format("  [ PASS ]  %-50s clean", file))
    end
end

print("")
print("=============================================================================")
print("  SYLVANAS SPELL AUDIT RESULTS")
print("=============================================================================")
print(string.format("  Total:     %3d sylvanas files", total))
print(string.format("  Skipped:   %3d (file not present)", skipped))
print(string.format("  Clean:     %3d", passed))
print(string.format("  Invalid:   %3d", failed))
print("")

if failed > 0 then
    print("  Invalid spell IDs found in sylvanas files:")
    for _, f in ipairs(failures) do
        if f.error then
            print("    " .. f.file .. "  ERROR: " .. f.error)
        else
            for _, hit in ipairs(f.hits) do
                print(string.format("    %s  line %d: id %d [%s]",
                    f.file, hit.line, hit.id, hit.kind))
            end
        end
    end
    print("")
    print("  ID 'ITEM_AS_SPELL' means the ID exists in item_index but not spell_index.")
    print("  ID 'INVALID' means the ID exists in neither — definitely a bug.")
    os.exit(1)
end

print("  All sylvanas files clean — every spell ID exists in DBC.")
os.exit(0)
