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
-- File list: every spec/levelning/class file for TBC Anniversary
-- ---------------------------------------------------------------------------
local SYLVANAS_FILES = {}
for _, class in ipairs({
    "druid", "hunter", "mage", "paladin", "priest",
    "rogue", "shaman", "warlock", "warrior",
}) do
    -- class file + leveling file
    SYLVANAS_FILES[#SYLVANAS_FILES + 1] = "classes/" .. class .. "/class_sylvanas.lua"
    SYLVANAS_FILES[#SYLVANAS_FILES + 1] = "classes/" .. class .. "/leveling_sylvanas.lua"
    -- TBC spec files (bear_sylvanas, balance_sylvanas, etc.)
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
        local f = "classes/" .. class .. "/" .. suffix .. "_sylvanas.lua"
        SYLVANAS_FILES[#SYLVANAS_FILES + 1] = f
    end
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

-- Patterns we scan for spell IDs (skip 1-999 = not spell IDs, skip 100000+ = test/huge)
--  - `ids = { N, N, ... }` inside spell_action calls
--  - Standalone BUFF/DEBUFF/SPELL arrays like `local X_BUFF = { N, N }`
local function extract_ids_from_line(line)
    local ids = {}
    -- Pattern 1: `ids = { N, N, N }` — spell definitions
    local ids_block = line:match("ids%s*=%s*%b{}")
    if ids_block then
        for n in ids_block:gmatch("(%d+)") do
            ids[#ids + 1] = tonumber(n)
        end
        return ids
    end
    -- Pattern 2: Array literal of multi-digit numbers (likely buff/debuff arrays)
    local arr_block = line:match("^%s*[%w_]+%s*=%s*%b{}")
    if arr_block then
        local has_only_ints = true
        local found_any = false
        for tok in arr_block:gmatch("[^,%s{}]+") do
            if not tok:match("^%d+$") then
                if tok:match("^%d") or tok:match("^%-") then
                    has_only_ints = false
                end
                -- skip non-numeric tokens (variable refs, nil, etc.)
            else
                local n = tonumber(tok)
                if n >= 1000 and n <= 99999 then  -- plausible spell ID range
                    ids[#ids + 1] = n
                    found_any = true
                end
            end
        end
        if found_any and has_only_ints then
            return ids
        end
    end
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
