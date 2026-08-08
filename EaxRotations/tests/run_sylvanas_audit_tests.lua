-- run_sylvanas_audit_tests.lua -- Audit sylvanas.lua rotation files for invalid spell IDs.
-- WHAT:  Scans rotation files for spell IDs absent from WoW 2.5.5.68101 DBC.
-- WHEN:  Run manually or in CI before releases.
-- WHY:   Catches invalid spell IDs that pass vanilla audit but are bogus for TBC Anniversary.
-- SAFETY: Read-only text scan + bridge lookup. No dofile(), no io writes.

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

-- WotLK-era spell IDs that exist in the full-dataset bridge but are NOT valid
-- on the TBC Anniversary (2.5.5) client. The bridge contains all eras, so
-- bridge-membership alone cannot discriminate; these are the confirmed leaks
-- (wowhead TBC 404 / absent from the 2.5.x DBC). Kept as an explicit blocklist so
-- a WotLK rank can never silently return to a *_sylvanas.lua file.
local WOTLK_ONLY_IDS = {
    [50334] = "Berserk (WotLK druid; not in TBC)",
    [61305] = "Polymorph (Black Cat) (WotLK; not in TBC)",
    [61721] = "Polymorph (Rabbit) (WotLK; not in TBC)",
    [61780] = "Polymorph (Turkey) (WotLK; not in TBC)",
}

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
-- Tracked-file set from git: a "skipped" inventory entry whose file IS
-- git-tracked means the repo expects the file but the working tree lacks it
-- (deleted locally, case mismatch on a case-sensitive CI, etc.) — the audit
-- would silently skip a real repo file, a masking gap. Mirror the WotLK
-- audit's zero-skip strictness: only genuinely-absent files may be skipped.
-- io.popen is exempt from test_spec_layout_compliance's banned-API scan for
-- run_*.lua runners (same exemption run_verify_all relies on).
local TRACKED = {}
-- Fail-closed like run_clean_checkout_probe.lua: if the tracked set cannot be
-- populated (git missing, popen failure, empty output) the masking check must
-- NOT silently pass — a nil pipe or empty set would otherwise make is_tracked
-- return false for every entry and hide all masking gaps. This audit only runs
-- inside a git checkout (verify_all already requires git), so exit 1 loudly.
local TRACKED_LOADED = false
local function load_tracked()
    -- NOTE: no `2>/dev/null` — on Windows cmd.exe that redirect targets a
    -- literal file and popen fails, silently emptying the tracked set.
    local pipe = io.popen("git ls-files")
    if not pipe then return false end
    local count = 0
    for line in pipe:lines() do
        -- Strip trailing \r: some Windows Lua 5.1/CRT builds leave CRLF on
        -- popen text lines, which would make every lookup miss and silently
        -- disable the check on the dev OS.
        local p = line:gsub("\r$", ""):gsub("\\", "/"):gsub("^%./", "")
        if p ~= "" then
            TRACKED[p] = true
            count = count + 1
        end
    end
    pipe:close()
    TRACKED_LOADED = count > 0
    return TRACKED_LOADED
end

-- Inventory entries are EaxRotations-relative ("classes/..."); git lists
-- repo-root-relative ("EaxRotations/classes/..."). Canonicalize and check.
local EAX_PREFIX = "EaxRotations/"
local function is_tracked(file)
    -- Guard against a future repo-root-relative inventory entry:
    -- "EaxRotations/classes/..." must not become "EaxRotations/EaxRotations/...".
    local rel = file
    if rel:sub(1, #EAX_PREFIX) == EAX_PREFIX then
        rel = rel:sub(#EAX_PREFIX + 1)
    end
    return TRACKED[EAX_PREFIX .. rel] or false
end

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
--  - `ids = { N, N, ... }` inside spell_action/define calls
--  - `spell_ids = { N, N, ... }` in hot tick trackers
--  - Standalone BUFF/DEBUFF/SPELL arrays `local X_BUFF = { N, N }`
--  - `define("Name", { N, N }, ...)` second-arg tables
-- Skip plain counters like `local _work_ids = { n = 0 }` — only collect tables
-- whose *contents* are dense numeric literals (no field assignments). Every
-- balanced-brace group is walked so `local X = {...}` and `define(... {...} ...)`
-- (the exact shapes the Berserk/polymorph leaks used) cannot slip through.
--
-- Item-family tables (healthstones, mana gems, potions, dark runes, conjured
-- food/water) legitimately hold ITEM ids and are used via item-click, never
-- cast as spells — so their IDs must not be audited as spell IDs. They are
-- excluded by the ASSIGNMENT NAME: a name that ends in _IDS / _ID / _ITEM /
-- _ITEMS AND contains an item-family keyword (ITEM, POTION, GEM, SHARD, FOOD,
-- WATER, RUNE, HEALTHSTONE, SOUL). Spell tables that merely contain a keyword
-- but do NOT end in the ID suffix (e.g. MANA_GEM_CONJURE, CONJURE_MANA_GEM_SPELLS)
-- are still audited, as are debuff lists like SERPENT_STING_IDS (no keyword).
--
-- KNOWN LIMITATION (line-based scanner): only IDs inside a single-line brace
-- group are collected. A MULTI-LINE flat array (`local FOO = {` then `50334,`
-- on its own line) or a brace-less bare number (`local x = 50334`) is
-- invisible — the same limitation as the vanilla/WotLK audits. The historical
-- Berserk/polymorph leaks were single-line define-form, so the guard covers
-- the real attack surface; do not assume full multi-line coverage.
local function is_item_table_name(name)
    if not name or name == "" then return false end
    if not (name:match("_IDS$") or name:match("_ID$")
            or name:match("_ITEM$") or name:match("_ITEMS$")) then
        return false
    end
    return name:match("ITEM") ~= nil
        or name:match("POTION") ~= nil
        or name:match("GEM") ~= nil
        or name:match("SHARD") ~= nil
        or name:match("FOOD") ~= nil
        or name:match("WATER") ~= nil
        or name:match("RUNE") ~= nil
        or name:match("HEALTHSTONE") ~= nil
        or name:match("SOUL") ~= nil
end
local function extract_ids_from_line(line)
    local ids = {}
    local function collect(block)
        if block:find("=") then return end
        for n in block:gmatch("(%d+)") do
            local v = tonumber(n)
            -- Range covers all spell IDs across eras; 6-digit IDs (e.g. 348700)
            -- reach the WOTLK_ONLY / validity checks instead of being masked.
            if v >= 1000 and v <= 999999 then
                ids[#ids + 1] = v
            end
        end
    end
    -- Walk a block and RECURSE into any nested balanced-brace groups so
    -- single-line nested tables like
    --   magic = { spell = "DispelMagic", ids = { 988, 527 } }
    -- are fully covered (the outer group contains `=` so it is skipped by
    -- collect, but the inner ids group is visited recursively).
    local function walk(str)
        local pos = 1
        while true do
            local s, e = str:find("%b{}", pos)
            if not s then break end
            local body = str:sub(s + 1, e - 1)
            collect(body)
            walk(body)
            pos = e + 1
        end
    end
    local pos = 1
    while true do
        local s, e = line:find("%b{}", pos)
        if not s then break end
        -- Capture the assignment target directly before the brace group
        -- (`local NAME = {`, `NAME = {`, `foo.NAME = {`, or `or {` fallbacks).
        local prefix = line:sub(1, s - 1)
        local name = prefix:match("([%w_]+)%s*=%s*$")
            or prefix:match("local%s+([%w_]+)")
        -- Item-family tables are excluded at the assignment level; a nested
        -- keyed table inside a scanned group (e.g. `ids = {...}`) is walked.
        if not is_item_table_name(name) then
            local body = line:sub(s + 1, e - 1)
            -- collect() the OUTER body too: `ids = {5938},` ladder lines,
            -- `spell_ids = { 988, 527 }` hot-tick-tracker lines, and
            -- `define("Name", { 50334 }, ...)` second-arg tables are all FLAT
            -- (no nested braces) — walk() alone would skip every one of them.
            -- collect() skips bodies containing `=` (field-assignment tables),
            -- so nested `{ ids = {...}, levels = {...} }` spell_action blocks
            -- are still reached only via walk().
            collect(body)
            walk(body)
        end
        pos = e + 1
    end
    return ids
end

local function is_comment_line(line)
    return line:match("^%s*%-%-") ~= nil
end

local function scan_content(content)
    if type(content) ~= "string" then
        return { error = "content must be a string", hits = {} }
    end

    local hits = {}
    local line_no = 0
    for line in content:gmatch("[^\r\n]+") do
        line_no = line_no + 1
        if not is_comment_line(line) then
            local ids = extract_ids_from_line(line)
            for _, id in ipairs(ids) do
                if WOTLK_ONLY_IDS[id] then
                    hits[#hits + 1] = {
                        line = line_no,
                        id = id,
                        kind = "WOTLK_ONLY",
                        desc = WOTLK_ONLY_IDS[id],
                        snippet = line:match("^%s*(.-)%s*$") or line,
                    }
                elseif not valid_spell_ids[id] then
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

local function scan_file(filepath)
    if not file_exists(filepath) then
        return { skipped = true, hits = {} }
    end
    local content = read_file(filepath)
    if not content then
        return { error = "could not read", hits = {} }
    end
    return scan_content(content)
end

-- ---------------------------------------------------------------------------
-- Self-tests (mirror the vanilla/WotLK audits' --self-test modes)
-- ---------------------------------------------------------------------------
local function run_self_tests()
    local function expect(actual, expected, label)
        if actual ~= expected then
            error(label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
        end
    end

    -- Malformed / missing input is controlled, not fatal.
    expect(scan_content(nil).error, "content must be a string", "malformed content")
    expect(scan_file("__missing_sylvanas_audit_fixture__.lua").skipped, true, "missing fixture")

    local function map_count(map)
        local n = 0
        for _ in pairs(map) do n = n + 1 end
        return n
    end

    -- Table integrity: every pinned WotLK-only ID must fire as a WOTLK_ONLY hit.
    local pinned = {}
    for id, desc in pairs(WOTLK_ONLY_IDS) do
        pinned[#pinned + 1] = { id = id, desc = desc }
    end
    expect(#pinned, 4, "WOTLK_ONLY_IDS size")
    local seen = {}
    for _, e in ipairs(pinned) do
        expect(seen[e.id], nil, "duplicate WOTLK_ONLY_IDS entry: " .. tostring(e.id))
        seen[e.id] = true
    end

    -- Every pinned WotLK-only rank must be flagged as WOTLK_ONLY, never silent.
    -- Probed in BOTH shapes the real leaks used: the nested spell_action form
    -- (`{ ids = { N } }`, class ladders) AND the flat define form
    -- (`Name = define("Name", { N }, "Name")`, spec ACTION tables) — the
    -- historical Berserk/polymorph leaks were flat define-form, so both must fire.
    local unfired = {}
    for _, e in ipairs(pinned) do
        local shapes = {
            "local PROBE = { ids = { " .. e.id .. " } }",
            "Berserk = define(\"Berserk\", { " .. e.id .. " }, \"Berserk\")",
        }
        for _, probe in ipairs(shapes) do
            local result = scan_content(probe)
            local fired = false
            for _, hit in ipairs(result.hits or {}) do
                if hit.id == e.id and hit.kind == "WOTLK_ONLY" then fired = true end
            end
            if not fired then
                unfired[#unfired + 1] = string.format("%d (%s) in shape %q", e.id, e.desc, probe)
            end
        end
    end
    expect(#unfired, 0, "all WOTLK_ONLY_IDS pins fire in both shapes (missed: " .. table.concat(unfired, "; ") .. ")")

    -- A known-valid TBC spell ID must NOT fire (30330 = Mortal Strike) in
    -- either shape.
    local valid = scan_content("local PROBE = { ids = { 30330 } }")
    expect(valid.found, false, "valid TBC ID must be silent (nested shape)")
    local valid2 = scan_content("Berserk = define(\"Berserk\", { 30330 }, \"Berserk\")")
    expect(valid2.found, false, "valid TBC ID must be silent (flat define shape)")

    -- Inventory: no duplicate file entries.
    local seen_files = {}
    for _, f in ipairs(SYLVANAS_FILES) do
        expect(seen_files[f], nil, "duplicate inventory entry: " .. tostring(f))
        seen_files[f] = true
    end

    -- Masking-gap helper: is_tracked() must resolve the EaxRotations-relative
    -- inventory form against the repo-root git ls-files form. Feed a synthetic
    -- tracked set and assert both the hit and the miss.
    local saved_tracked = TRACKED
    TRACKED = {
        ["EaxRotations/classes/warrior/arms_sylvanas.lua"] = true,
    }
    expect(is_tracked("classes/warrior/arms_sylvanas.lua"), true, "tracked inventory entry resolves")
    expect(is_tracked("classes/mage/arcane_sylvanas.lua"), false, "untracked inventory entry stays clear")
    TRACKED = saved_tracked

    print("[PASS] Sylvanas audit self-tests: malformed input, all 4 WOTLK_ONLY_IDS pins fire, valid TBC ID silent, no duplicate inventory entries, masking-gap helper resolves")
end

-- ---------------------------------------------------------------------------
-- Main
-- ---------------------------------------------------------------------------
if arg and arg[1] == "--self-test" then
    run_self_tests()
    os.exit(0)
end

print("=============================================================================")
print("  SYLVANAS SPELL ID AUDIT (positive DBC existence check)")
print("  Source: wowheadScrape/dbc_extract/wowsims.db (client 2.5.5.68101)")
print(string.format("  Bridge: %d TBC spells, %d items loaded", spell_count, item_count))
print("=============================================================================")
print("")

local total, skipped, passed, failed = 0, 0, 0, 0
local failures = {}
local skipped_files = {}

local tracked_ok = load_tracked()
if not tracked_ok then
    print("")
    print("  [ERROR] masking-gap check could not run: git ls-files returned nothing")
    print("          (git missing, popen failure, or empty repo). The audit would")
    print("          silently skip covering real repo files. Run inside a git checkout.")
    os.exit(1)
end

for _, file in ipairs(SYLVANAS_FILES) do
    local path = root .. "/" .. file
    total = total + 1

    local result = scan_file(path)
    if result.skipped then
        skipped = skipped + 1
        skipped_files[#skipped_files + 1] = file
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

-- Masking-gap check: a skipped inventory entry that is git-tracked means a
-- real repo file exists but the audit could not read it at its expected
-- path (deleted from the worktree, case mismatch on case-sensitive CI, or
-- a stale inventory entry pointing at a moved file). The audit would
-- silently stop covering that file — a masking gap, not a legit skip.
local masked = {}
for _, file in ipairs(skipped_files) do
    if is_tracked(file) then
        masked[#masked + 1] = file
    end
end
if #masked > 0 then
    print(string.format("  Masked:    %3d (git-tracked but reported skipped)", #masked))
end
print("")

if failed > 0 or #masked > 0 then
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
    end
    if #masked > 0 then
        print("  Masking gaps (git-tracked files the audit could not scan):")
        for _, f in ipairs(masked) do
            print("    " .. f)
        end
        print("")
        print("  A 'Masked' entry means the file exists in git but was reported skipped —")
        print("  the audit silently stopped covering it. Fix the worktree/inventory so it is")
        print("  scanned (mirror the WotLK audit's zero-skip strictness).")
    end
    os.exit(1)
end

print("  All sylvanas files clean — every spell ID exists in DBC, zero masking gaps.")
os.exit(0)
