-- What: Tripwire — nothing in this plugin may abandon a quest, ever, for any reason.
-- When: Run via `lua EaxAutoQuester/tests/run_quester_tests.lua`
-- Why: The plugin used to delete quests on its own. Two paths did it: an idle "quest log
--      maintenance" pass that auto-abandoned grey quests once the log held 20+ entries
--      (deleted while the player was still going to turn them in — a hearthstone and a walk
--      back, live), and a failure-path that abandoned a quest after repeated interaction
--      failures. Both are gone; this suite is what keeps them gone. Player-owned state is
--      owned by the player: the plugin may give up on a target and say so, not delete work.
--      The scan is a read-only source walk with a positive control, so it cannot pass by
--      looking at nothing: a synthetic offender must be caught, and the same line inside a
--      comment must not be.
-- Safety: read-only source scans (io.open + lfs); no writes, no execution of scanned code.

-- Path setup for standalone run
package.path = package.path .. ";./EaxAutoQuester/?.lua;./EaxAutoQuester/?/init.lua"

local mock = require("EaxAutoQuester/tests/mock_core")
mock.install()
mock.reset()

-- =============================================================================
-- Helpers — plugin root, production file discovery, comment-stripping scan
-- =============================================================================

--- Locate the plugin root so this suite runs from the repo root or the plugin root.
local function plugin_root()
    for _, prefix in ipairs({ "EaxAutoQuester/", "" }) do
        local f = io.open(prefix .. "main.lua", "r")
        if f then
            f:close()
            return prefix
        end
    end
    return nil
end

local ROOT = plugin_root()
assert(ROOT, "EaxAutoQuester root not found (expected main.lua in ./ or ./EaxAutoQuester/)")

local function read_source(rel)
    local f = io.open(ROOT .. rel, "r")
    if not f then return nil end
    local data = f:read("*a")
    f:close()
    return data
end

local function exists(rel)
    local f = io.open(ROOT .. rel, "r")
    if not f then return false end
    f:close()
    return true
end

--- Every production Lua file: everything under the plugin root except the suites, the docs and
--- the throwaway `_`-prefixed probes.
local function list_production_files()
    local ok, lfs = pcall(require, "lfs")
    assert(ok and lfs and lfs.dir,
        "FAIL: lfs is required — a partial scan of production code must not be able to pass")

    local out = {}
    local function walk(dir)
        for entry in lfs.dir(dir) do
            if entry ~= "." and entry ~= ".." then
                local path = dir .. "/" .. entry
                local mode = lfs.attributes(path, "mode")
                if mode == "directory" then
                    if entry ~= "tests" and entry ~= "docs" then walk(path) end
                elseif entry:match("%.lua$") and not entry:match("^_") then
                    out[#out + 1] = path:sub(#ROOT + 1)
                end
            end
        end
    end
    walk(ROOT:sub(1, #ROOT - 1))
    table.sort(out)
    return out
end

--- Blank out comments while preserving newlines, so a line number in the stripped source is
--- still a line number in the file. Prose about the banned call must not trip the scan.
--- @param src string
--- @return string
local function strip_comments(src)
    local out = {}
    local i, n = 1, #src
    while i <= n do
        if src:sub(i, i + 1) == "--" then
            local eq = src:match("^%-%-%[(=*)%[", i)
            if eq then
                local close = "]" .. eq .. "]"
                local start = i + 4 + #eq
                local e = src:find(close, start, true)
                e = e and (e + #close) or (n + 1)
                for nl in src:sub(i, e - 1):gmatch("[\r\n]") do out[#out + 1] = nl end
                i = e
            else
                local e = src:find("[\r\n]", i) or (n + 1)
                i = e
            end
        else
            out[#out + 1] = src:sub(i, i)
            i = i + 1
        end
    end
    return table.concat(out)
end

--- Line number of the first occurrence of `needle` in `stripped`.
local function line_of(stripped, needle)
    local at = stripped:find(needle, 1, true)
    if not at then return nil end
    local _, count = stripped:sub(1, at):gsub("\n", "\n")
    return count + 1
end

--- Calls that delete a quest. `set_abandon_quest` is included by `abandon_quest`.
local BANNED = "abandon_" .. "quest"

--- @return number count, number|nil line
local function find_banned(src)
    local stripped = strip_comments(src)
    local line = line_of(stripped, BANNED)
    if not line then return 0, nil end
    return 1, line
end

-- =============================================================================
-- S1 — the scanner itself: it must catch a real call and ignore prose about one
-- =============================================================================

do
    local offender = "local function f()\n    core.quests." .. BANNED .. "(5)\nend\n"
    local count, line = find_banned(offender)
    assert(count == 1, "S1 FAIL: a real abandon call must be caught")
    assert(line == 2, "S1 FAIL: the offender must be reported at its own line (got " .. tostring(line) .. ")")

    local prose = "local function f()\n    -- core.quests." .. BANNED .. "(5) is gone\n    return 1\nend\n"
    assert(find_banned(prose) == 0, "S1 FAIL: a comment about the call must not trip the scan")

    local block_prose = "--[[ block: core.quests." .. BANNED .. "(5) ]]\nreturn 1\n"
    assert(find_banned(block_prose) == 0, "S1 FAIL: a long comment must not trip the scan")

    print("  S1 PASS: scanner catches the call and ignores prose about it")
end

-- =============================================================================
-- S2 — no production file can delete a quest
-- =============================================================================

do
    local files = list_production_files()
    assert(#files >= 40,
        "S2 FAIL: the walk found only " .. tostring(#files) ..
        " production files — a scan this thin proves nothing")

    local offenders = {}
    for _, rel in ipairs(files) do
        local src = read_source(rel)
        assert(src, "S2 FAIL: production file listed but unreadable: " .. rel)
        local count, line = find_banned(src)
        if count > 0 then
            offenders[#offenders + 1] = rel .. ":" .. tostring(line)
        end
    end

    assert(#offenders == 0,
        "S2 FAIL: production code may never abandon a quest — found: " ..
        table.concat(offenders, ", "))
    print("  S2 PASS: " .. tostring(#files) .. " production files, zero quest deletion calls")
end

-- =============================================================================
-- S3 — the grey-quest maintenance pass and its module are gone, not merely unused
-- =============================================================================

do
    assert(not exists("quest_log_manager_sylvanas.lua"),
        "S3 FAIL: the grey-quest auto-abandon module must stay deleted")

    local loaded = pcall(require, "quest_log_manager_sylvanas")
    assert(not loaded, "S3 FAIL: the deleted module must not be loadable")

    local remnants = {}
    for _, rel in ipairs(list_production_files()) do
        local src = read_source(rel) or ""
        if src:find("maintenance_check", 1, true) or src:find("find_grey_quests", 1, true) then
            remnants[#remnants + 1] = rel
        end
    end
    assert(#remnants == 0,
        "S3 FAIL: the maintenance pass must not survive anywhere — found: " ..
        table.concat(remnants, ", "))
    print("  S3 PASS: grey-quest maintenance module and call sites are gone")
end

print("PASS test_no_quest_abandon")
os.exit(0)
