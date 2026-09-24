-- What: Unit tests for EaxAutoQuester/quest_blacklist_sylvanas.lua
-- When: Run via `lua EaxAutoQuester/tests/run_quester_tests.lua`
-- Why: Verify failure recording, 60s sliding window, 5-failure threshold, explicit abandon, isolation
-- Safety: Uses module.set_clock() for mock time — no real timers or I/O

-- Path setup
package.path = package.path .. ";./EaxAutoQuester/?.lua;./EaxAutoQuester/?/init.lua"

-- Bootstrap _G.EaxAutoQuester (normally done by main.lua)
_G.EaxAutoQuester = _G.EaxAutoQuester or {}

local quest_blacklist = require("quest_blacklist_sylvanas")

-- =============================================================================
-- S1: 4 failures within 30 seconds → should_abandon = false (< 5)
-- =============================================================================
do
    quest_blacklist.reset()
    local mock_t = 0
    quest_blacklist.set_clock(function() return mock_t end)

    quest_blacklist.record_failure(101, "area_fail")
    mock_t = 10
    quest_blacklist.record_failure(101, "dead_npc")
    mock_t = 20
    quest_blacklist.record_failure(101, "unsolvable_gossip")
    mock_t = 30
    quest_blacklist.record_failure(101, "area_fail")

    local result = quest_blacklist.should_abandon(101)
    assert(result == false, "S1 FAIL: 4 failures should NOT trigger abandon, got " .. tostring(result))
    print("  S1 PASS: 4 failures within 30s → should_abandon = false")
end

-- =============================================================================
-- S2: 5 failures within 50 seconds → should_abandon = true (≥ 5)
-- =============================================================================
do
    quest_blacklist.reset()
    local mock_t = 0
    quest_blacklist.set_clock(function() return mock_t end)

    for i = 1, 5 do
        quest_blacklist.record_failure(102, "area_fail")
        mock_t = mock_t + 10
    end

    local result = quest_blacklist.should_abandon(102)
    assert(result == true, "S2 FAIL: 5 failures should trigger abandon, got " .. tostring(result))
    print("  S2 PASS: 5 failures within 50s → should_abandon = true")
end

-- =============================================================================
-- S3: 5 failures spread over 70 seconds → should_abandon = false
--     (oldest failure > 60s expired from window)
-- =============================================================================
do
    quest_blacklist.reset()
    local mock_t = 0
    quest_blacklist.set_clock(function() return mock_t end)

    -- 5 failures: t=0, 15, 30, 45, 70
    quest_blacklist.record_failure(103, "area_fail")    -- t=0
    mock_t = 15
    quest_blacklist.record_failure(103, "dead_npc")     -- t=15
    mock_t = 30
    quest_blacklist.record_failure(103, "area_fail")    -- t=30
    mock_t = 45
    quest_blacklist.record_failure(103, "unsolvable_gossip") -- t=45
    mock_t = 70
    quest_blacklist.record_failure(103, "area_fail")    -- t=70

    -- At t=70: failures at t=0 is >60s ago (expired), so only 4 remain (t=15,30,45,70)
    local result = quest_blacklist.should_abandon(103)
    assert(result == false, "S3 FAIL: oldest failure expired (>60s), should be <5 in window, got " .. tostring(result))
    print("  S3 PASS: oldest expired out of 60s window → should_abandon = false")
end

-- =============================================================================
-- S4: mark_abandoned(123) → is_blacklisted(123)=true, should_abandon(123)=true
--     regardless of failure count
-- =============================================================================
do
    quest_blacklist.reset()
    local mock_t = 0
    quest_blacklist.set_clock(function() return mock_t end)

    -- No failures recorded for quest 123
    quest_blacklist.mark_abandoned(123)

    local blacklisted = quest_blacklist.is_blacklisted(123)
    assert(blacklisted == true, "S4 FAIL: mark_abandoned(123) should make is_blacklisted true, got " .. tostring(blacklisted))

    local abandon = quest_blacklist.should_abandon(123)
    assert(abandon == true, "S4 FAIL: mark_abandoned(123) should make should_abandon true, got " .. tostring(abandon))

    print("  S4 PASS: mark_abandoned → is_blacklisted=true, should_abandon=true")
end

-- =============================================================================
-- S5: Failures for quest_id=100 isolated from quest_id=200
-- =============================================================================
do
    quest_blacklist.reset()
    local mock_t = 0
    quest_blacklist.set_clock(function() return mock_t end)

    -- 5 failures for quest 100, 0 for quest 200
    for i = 1, 5 do
        quest_blacklist.record_failure(100, "area_fail")
        mock_t = mock_t + 10
    end

    local result_100 = quest_blacklist.should_abandon(100)
    local result_200 = quest_blacklist.should_abandon(200)

    assert(result_100 == true, "S5 FAIL: quest 100 with 5 failures should abandon, got " .. tostring(result_100))
    assert(result_200 == false, "S5 FAIL: quest 200 with 0 failures should NOT abandon, got " .. tostring(result_200))

    -- Also verify is_blacklisted reflects the session state
    local bl_100 = quest_blacklist.is_blacklisted(100)
    local bl_200 = quest_blacklist.is_blacklisted(200)
    assert(bl_100 == true, "S5 FAIL: quest 100 should be blacklisted after should_abandon returned true")
    assert(bl_200 == false, "S5 FAIL: quest 200 should NOT be blacklisted with no failures")

    print("  S5 PASS: quest 100 and 200 tracked independently")
end

-- =============================================================================
-- S5b: one recorded failure is a session-persistent skip, while the legacy
--       five-in-window abandonment query remains a separate decision.
-- =============================================================================
do
    quest_blacklist.reset()
    local mock_t = 0
    quest_blacklist.set_clock(function() return mock_t end)

    quest_blacklist.record_failure(700, "area_fail")
    assert(quest_blacklist.is_persistent_failure(700) == true,
        "S5b FAIL: a recorded failure must be persistent")
    assert(quest_blacklist.is_blacklisted(700) == true,
        "S5b FAIL: the existing blacklist surface must expose the persistent skip")
    assert(quest_blacklist.should_abandon(700) == false,
        "S5b FAIL: persistent skip must not wire or trigger should_abandon")

    -- The mark is session-scoped, not tied to the sliding failure window.
    mock_t = 1000
    assert(quest_blacklist.is_persistent_failure(700) == true,
        "S5b FAIL: a persistent failure must survive the 60s observation window")
    assert(quest_blacklist.is_persistent_failure(701) == false,
        "S5b FAIL: an unrelated quest must remain eligible")

    quest_blacklist.reset(700)
    assert(quest_blacklist.is_persistent_failure(700) == false,
        "S5b FAIL: reset must clear the persistent mark")
    quest_blacklist.reset()
    print("  S5b PASS: recorded failure becomes a quiet session-persistent skip")
end

-- =============================================================================
-- S6-S9: the three clock fallbacks (production prefers core.time(); os.* is not
-- assumed to exist because .api/core.lua documents os.date()/os.time() as
-- unavailable in the sandboxed Lua — see docs/runtime_sandbox_audit.md).
-- Each case re-requires the module with a stubbed _G.core, because the default
-- clock is chosen inside the module; the runner restores _G after the suite.
-- =============================================================================

-- S6: core.time() present → the window is measured in SECONDS
do
    package.loaded["quest_blacklist_sylvanas"] = nil
    local t = 0
    _G.core = { time = function() return t end }
    local mod = require("quest_blacklist_sylvanas")

    for i = 1, 5 do
        mod.record_failure(601, "area_fail")
        t = t + 10
    end
    assert(mod.should_abandon(601) == true,
        "S6 FAIL: 5 failures 10s apart via core.time must abandon inside 60s")

    mod.reset()
    t = 0
    for i = 1, 5 do
        mod.record_failure(602, "area_fail")
        t = t + 70
    end
    assert(mod.should_abandon(602) == false,
        "S6 FAIL: failures 70s apart must fall out of the 60s window " ..
        "(proves a seconds clock, not a call counter)")

    print("  S6 PASS: core.time() drives the 60s window in seconds")
end

-- S7: core.time() absent, core.cpu_time() present → NANOseconds scaled to seconds
do
    package.loaded["quest_blacklist_sylvanas"] = nil
    local ns = 0
    _G.core = { cpu_time = function() return ns end }
    local mod = require("quest_blacklist_sylvanas")

    for i = 1, 5 do
        mod.record_failure(603, "area_fail")
        ns = ns + 10 * 1e9   -- 10 seconds expressed in nanoseconds
    end
    assert(mod.should_abandon(603) == true,
        "S7 FAIL: 5 failures 10s apart via core.cpu_time must abandon — raw " ..
        "nanoseconds left unscaled would put every entry outside the 60s window")

    print("  S7 PASS: core.cpu_time() nanoseconds scaled to the same second unit")
end

-- S8: no clock API exposed → monotonic tick counter still works
-- S9: `core` absent entirely → no error (the sandbox-unknown case)
do
    package.loaded["quest_blacklist_sylvanas"] = nil
    _G.core = {}
    local mod = require("quest_blacklist_sylvanas")
    for i = 1, 5 do mod.record_failure(604, "area_fail") end
    assert(mod.should_abandon(604) == true,
        "S8 FAIL: with no clock API the tick counter must still count 5 failures")

    package.loaded["quest_blacklist_sylvanas"] = nil
    _G.core = nil
    local mod2 = require("quest_blacklist_sylvanas")
    local ok, result = pcall(function()
        for i = 1, 5 do mod2.record_failure(605, "area_fail") end
        return mod2.should_abandon(605)
    end)
    assert(ok, "S9 FAIL: module must degrade without error when core is absent: " .. tostring(result))
    assert(result == true,
        "S9 FAIL: tick fallback must still abandon after 5 failures, got " .. tostring(result))

    print("  S8 PASS: no clock API -> tick counter; core absent -> no error")
end

print("PASS test_quest_blacklist")
os.exit(0)
