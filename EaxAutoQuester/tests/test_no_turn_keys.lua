-- What: Tripwire — no production file may hold a turn key, and facing has one owner.
--       (1) turn_left_start / turn_right_start begin HOLDING an arrow key.
--       (2) movement_handler:look_at_target(lock_duration, delay, target) HOLDS a facing for that
--           duration rather than snapping, so a per-tick re-issue is the same spin by another
--           route — shared/facing.lua is the only file allowed to issue it.
-- When: Run via `lua EaxAutoQuester/tests/run_quester_tests.lua`
-- Why: `turn_left_start()` / `turn_right_start()` do not turn by an amount — they begin HOLDING the
--      arrow key until the matching `*_stop()` (scraped_docs_md/dev/api/input.md: "Starts turning
--      the player to the left" / "Stops turning to the left"). Two live defects came out of that:
--        * combat_helper_sylvanas.auto_face_enemy rolled a random turn start as cosmetic "jitter"
--          and never called a stop anywhere in the plugin — the player rotated continuously from
--          the first enemy contact (live: "I'm spinning around in circles").
--        * nav_state's stuck-retry 2 called start and stop in the SAME tick, which turns for zero
--          frames: it could not have helped a wedged character, while still being one forgotten
--          stop away from holding the key down.
--      The quester navigates through SentinelNavClient and faces with look_at/look_at_3d, which are
--      point-at-an-instant calls with no key to release. Turn keys are therefore never needed, and
--      this scan is what keeps them out. The `*_stop` calls stay allowed: a defensive stop with no
--      start is harmless, and forbidding it would forbid the cleanup.
--      The scan is a read-only source walk with a positive control, so it cannot pass by looking at
--      nothing: a synthetic offender must be caught, and the same line inside a comment must not be.
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

--- The two calls that begin a held turn. Split so this file's own prose cannot match itself.
local BANNED = { "turn_left_" .. "start", "turn_right_" .. "start" }

--- look_at_target is not a snap either: it HOLDS a facing for `lock_duration` (scraped_docs_md/
--- dev/api/movement-handler.md). Re-issued per tick with 0.5 it is a continuous servo — the same
--- spin by another route. shared/facing.lua owns that call now (one lock per interval, only when
--- the target is outside a 60-degree cone, never at a corpse), so nothing else may make it.
local FACING_OWNER = "shared/facing.lua"
local FACING_CALL = "look_at_" .. "target"

--- @return string|nil needle, number|nil line
local function find_banned(src)
    local stripped = strip_comments(src)
    for _, needle in ipairs(BANNED) do
        local line = line_of(stripped, needle)
        if line then return needle, line end
    end
    return nil, nil
end

--- Raw facing locks outside their one owner.
--- @return number|nil line
local function find_raw_facing(src)
    return line_of(strip_comments(src), FACING_CALL)
end

-- =============================================================================
-- S1 — the scanner itself: it must catch a real start and ignore prose about one
-- =============================================================================

do
    local offender = "local function f()\n    pcall(core.input." .. BANNED[1] .. ")\nend\n"
    local needle, line = find_banned(offender)
    assert(needle == BANNED[1], "S1 FAIL: a real turn start must be caught")
    assert(line == 2, "S1 FAIL: the offender must be reported at its own line (got " .. tostring(line) .. ")")

    local prose = "local function f()\n    -- core.input." .. BANNED[2] .. "() is gone now\n    return 1\nend\n"
    assert(find_banned(prose) == nil, "S1 FAIL: a comment about the call must not trip the scan")

    local block_prose = "--[[ block: core.input." .. BANNED[2] .. "() ]] \nreturn 1\n"
    assert(find_banned(block_prose) == nil, "S1 FAIL: a long comment must not trip the scan")

    print("  S1 PASS: scanner catches a turn start and ignores prose about it")
end

-- =============================================================================
-- S2 — no production file holds a turn key
-- =============================================================================

do
    local files = list_production_files()
    assert(#files >= 40,
        "S2 FAIL: the scan found only " .. #files .. " production files — it is not walking the plugin")
    local offenders = {}
    for _, rel in ipairs(files) do
        local src = read_source(rel)
        assert(src, "S2 FAIL: a listed production file could not be read: " .. rel)
        local needle, line = find_banned(src)
        if needle then
            offenders[#offenders + 1] = rel .. ":" .. tostring(line) .. " (" .. needle .. ")"
        end
    end
    assert(#offenders == 0,
        "S2 FAIL: production code may never start a turn key — found: " .. table.concat(offenders, ", "))
    print("  S2 PASS: " .. #files .. " production files, zero turn-key starts")
end

-- =============================================================================
-- S3 — the two files that used to hold one are clean, and the patterns the quester uses INSTEAD
-- are still present (a scan that passes because the feature was deleted is not a pass)
-- =============================================================================

do
    local combat = read_source("combat_helper_sylvanas.lua")
    assert(combat, "S3 FAIL: combat_helper_sylvanas.lua is missing")
    assert(find_banned(combat) == nil, "S3 FAIL: combat_helper must not start a turn")
    -- The exact shape that spun the player: a random roll over the two start calls.
    assert(not combat:find("math.random(2) == 1 and core.input.turn", 1, true),
        "S3 FAIL: the removed jitter expression is still there")
    assert(combat:find("look_at_3d", 1, true),
        "S3 FAIL: combat_helper should still face the target by point-at, not by key")

    local nav = read_source("quest_state/nav_state.lua")
    assert(nav, "S3 FAIL: quest_state/nav_state.lua is missing")
    assert(find_banned(nav) == nil, "S3 FAIL: nav_state must not start a turn")
    assert(nav:find("core.input.jump", 1, true),
        "S3 FAIL: the stuck ladder should still jump — recovery must not have been deleted with the turn")

    print("  S3 PASS: both former offenders are clean and the point-at / jump paths remain")
end

-- =============================================================================
-- S4 — a per-tick look-at lock is the same spin by another route, so it has one owner
-- =============================================================================

do
    -- Positive control first: the scanner must catch a raw call, and ignore prose about it.
    local offender = "local function f()\n    mh:look_at_" .. "target(0.5, 0, t)\nend\n"
    assert(find_raw_facing(offender) == 2, "S4 FAIL: a raw look_at_target must be caught")
    local prose = "-- mh:look_at_" .. "target(0.5, 0, t) used to run every tick\nreturn 1\n"
    assert(find_raw_facing(prose) == nil, "S4 FAIL: prose about the call must not trip the scan")

    local files = list_production_files()
    local offenders = {}
    for _, rel in ipairs(files) do
        if rel ~= FACING_OWNER then
            local src = read_source(rel)
            assert(src, "S4 FAIL: a listed production file could not be read: " .. rel)
            local line = find_raw_facing(src)
            if line then
                offenders[#offenders + 1] = rel .. ":" .. tostring(line)
            end
        end
    end
    assert(#offenders == 0,
        "S4 FAIL: facing is driven by " .. FACING_OWNER .. " only — raw look_at_target found in: " ..
        table.concat(offenders, ", "))

    local owner = read_source(FACING_OWNER)
    assert(owner and find_raw_facing(owner),
        "S4 FAIL: " .. FACING_OWNER .. " no longer issues the lock — the scan would pass on a " ..
        "plugin that simply never faces anything")
    print("  S4 PASS: " .. #files .. " production files, facing driven only by " .. FACING_OWNER)
end

print("PASS test_no_turn_keys")
os.exit(0)
