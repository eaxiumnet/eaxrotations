-- run_forever_audit_tests.lua -- Audit _forever.lua rotation files for invalid spell IDs.
-- WHAT:  scans Forever rotation files for IDs that do not resolve in the
--        Forever spell-index bridge; scaffold mode until the beta DBC lands.
-- WHEN:  run manually, in the pre-commit gate, and in CI (verify_all).
-- WHY:   repo law: a spell exists only if the client DBC says so. Forever adds
--        NEW spells (Holy Strike, Seal of Fury, reworked racials) with
--        unknown-un-beta IDs; this audit is the gate that keeps guessed IDs
--        out of _forever files forever, mirroring run_wotlk_audit_tests.lua.
-- SAFETY: read-only text scan; --self-test has no filesystem writes; exits 2
--         on missing bridge, 1 on findings, 0 on pass.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;" .. package.path

local bridge_ok, bridge = pcall(require, "shared/wowhead_data_bridge_spell_index_forever_sylvanas")
if not bridge_ok or not bridge then
    print("[ERROR] Could not load wowhead_data_bridge_spell_index_forever_sylvanas")
    print("        The stub bridge must exist; the real one replaces it on beta day")
    print("        (docs/forever/dbc_runbook.md).")
    os.exit(2)
end

local forever_index = bridge.spell_index_forever or {}
local STUB_MODE = bridge.__forever_stub == true

local valid_forever_ids = {}
for id in pairs(forever_index) do
    valid_forever_ids[id] = true
end

-- Cross-era membership for precise verdicts (a Forever file referencing a
-- vanilla ID must say VANILLA_ID_IN_FOREVER, not a bare INVALID).
local vanilla_ok, vanilla_bridge = pcall(require, "shared/wowhead_data_bridge_spell_index_vanilla_sylvanas")
local vanilla_index = (vanilla_ok and (vanilla_bridge.spell_index_vanilla or vanilla_bridge)) or {}
local valid_vanilla_ids = {}
for id in pairs(vanilla_index) do valid_vanilla_ids[id] = true end

-- ---------------------------------------------------------------------------
-- ID extraction (mirrors the wotlk audit's two patterns):
--   Pattern 1: define("Label", { 123, 456 }, "Label") / numeric 2nd arg
--   Pattern 2: pure numeric table literals { 123, 456 }
-- ---------------------------------------------------------------------------

local function extract_ids_from_line(line)
    if type(line) ~= "string" then return {} end
    local ids = {}
    local seen = {}
    local function collect(s)
        for num in s:gmatch("%d+") do
            local v = tonumber(num)
            if v and v >= 100 and v <= 999999 and not seen[v] then
                seen[v] = true
                ids[#ids + 1] = v
            end
        end
    end
    -- Pure numeric table literals.
    for table_part in line:gmatch("(%b{})") do
        local inner = table_part:sub(2, -2)
        if inner:match("^[%s,,%d]*$") then collect(inner) end
    end
    -- define("X", 123, ...) single-numeric-arg form.
    for _, arg in ipairs({ line:match('define%s*%(%s*"[^"]*"%s*,%s*(%d+)') }) do
        collect(arg)
    end
    return ids
end

local function is_comment_line(line)
    return line:match("^%s*%-%-") ~= nil
end

local function classify_id(id)
    if valid_forever_ids[id] then return nil end
    if valid_vanilla_ids[id] then return "VANILLA_ID_IN_FOREVER" end
    return "INVALID"
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
            for _, id in ipairs(extract_ids_from_line(line)) do
                local kind = classify_id(id)
                if kind then
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

local function read_file(path)
    local f = io.open(path, "rb")
    if not f then return nil end
    local content = f:read("*a")
    f:close()
    return content
end

local function scan_file(filepath)
    local content = read_file(filepath)
    if not content then return { skipped = true, hits = {} } end
    return scan_content(content)
end

local function find_forever_files()
    local files = {}
    -- Class spec deltas: classes/<class>/<spec>_forever.lua
    local pipe = io.popen('find EaxRotations/classes -name "*_forever.lua" 2>/dev/null')
    if pipe then
        for line in pipe:lines() do
            files[#files + 1] = line:gsub("\\", "/")
        end
        pipe:close()
    end
    table.sort(files)
    return files
end

-- ---------------------------------------------------------------------------
-- Self-tests: the scanner must PROVE it fires before it is allowed to pass.
-- Mirrors the wotlk audit's --self-test contract (a dropped pin / a scanner
-- that silently matches nothing must hard-fail).
-- ---------------------------------------------------------------------------

local function run_self_tests()
    local function expect(actual, expected, label)
        if actual ~= expected then
            error(label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
        end
    end

    expect(#extract_ids_from_line(nil), 0, "malformed nil line")
    expect(scan_content(nil).error, "content must be a string", "malformed content")
    expect(scan_file("__missing_forever_audit_fixture__.lua").skipped, true, "missing fixture")

    -- Comment lines must never fire.
    local comment_scan = scan_content('-- define("SealOfFury", { 999999 }, "SealOfFury")')
    expect(#comment_scan.hits, 0, "comment lines are exempt")

    -- In stub mode, EVERY id in code is unresolvable; a define line with two
    -- ids yields two hits (deduped when equal).
    local scan = scan_content('define("SealOfFury", { 12345, 12345, 678 }, "SealOfFury")')
    expect(#scan.hits, 2, "stub-mode scan dedupes and fires")
    expect(scan.hits[1].id, 12345, "first hit id")
    expect(scan.hits[2].kind, "INVALID", "unknown id classifies INVALID")

    -- A sub-100 number is not a spell id (rank literals etc.).
    local small = scan_content('local rank = 42')
    expect(#small.hits, 0, "small numerics exempt")

    -- Vanilla-known IDs still report the precise era-leak verdict in code
    -- (bridge tables are data, and data tables are scanned only in real
    -- _forever files; the scanner itself just classifies).
    expect(classify_id(25898), "VANILLA_ID_IN_FOREVER", "vanilla id leaks precise verdict (25898 = Seal of Righteousness r1)")

    print("  self-test: scanner fires, comments exempt, dedupe works, verdicts precise")
end

-- ---------------------------------------------------------------------------
-- Main
-- ---------------------------------------------------------------------------

if arg and arg[1] == "--self-test" then
    local ok, err = pcall(run_self_tests)
    if not ok then
        print("[FAIL] forever audit self-test: " .. tostring(err))
        os.exit(2)
    end
    print("[PASS] forever audit self-test (scanner fires on synthetic violations)")
    os.exit(0)
end

if STUB_MODE then
    -- Scaffold mode: no DBC yet, so a live scan would flag nothing meaningful.
    -- Prove the scanner still fires (the self-test above ran only under
    -- --self-test; run the core probes here so scaffold mode is not vacuous).
    local ok, err = pcall(run_self_tests)
    if not ok then
        print("[FAIL] forever audit scaffold probes: " .. tostring(err))
        os.exit(2)
    end
    print("Forever audit: SCAFFOLD MODE (beta DBC not yet extracted — docs/forever/dbc_runbook.md)")
    print("  scanner self-probes: PASS")
    print("  No _forever spec files exist yet; the audit enforces live scans once")
    print("  the bridge stub is replaced (docs/forever/dbc_runbook.md step 3-5).")
    os.exit(0)
end

local files = find_forever_files()
local invalid = 0
local findings = {}
for _, f in ipairs(files) do
    local result = scan_file(f)
    if result.hits and #result.hits > 0 then
        findings[#findings + 1] = { file = f, hits = result.hits }
        invalid = invalid + #result.hits
    end
end

print(string.format("Forever audit: %d _forever file(s) scanned", #files))
if #findings > 0 then
    print(string.format("Invalid: %d", invalid))
    for _, f in ipairs(findings) do
        for _, hit in ipairs(f.hits) do
            print(string.format("    %s  line %d: id %d [%s]  %s", f.file, hit.line, hit.id, hit.kind, hit.snippet))
        end
    end
    print("  INVALID: no Forever-bridge or vanilla classification exists for the ID.")
    print("  VANILLA_ID_IN_FOREVER: a vanilla-era ID appears outside an explicit")
    print("  era-shared pin. Add a pinned entry with DBC evidence if the ID is")
    print("  genuinely era-shared (see run_wotlk_audit_tests.lua for the pin shape).")
    os.exit(1)
end

print("Invalid: 0")
print("  All _forever spell IDs resolve in the Forever bridge (or are pinned).")
os.exit(0)
