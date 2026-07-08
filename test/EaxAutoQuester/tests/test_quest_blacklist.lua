-- What: Unit tests for EaxAutoQuester/quest_blacklist_sylvanas.lua
-- When: Run via `lua EaxAutoQuester/tests/run_quester_tests.lua`
-- Why: Verify failure recording, 60s sliding window, 5-failure threshold, explicit abandon, isolation
-- Safety: Uses module.set_clock() for mock time — no real timers or I/O

-- Path setup
package.path = package.path .. ";./EaxAutoQuester/?.lua;./EaxAutoQuester/?/init.lua"

-- Bootstrap _G.EaxAutoQuester (normally done by main.lua)
_G.EaxAutoQuester = _G.EaxAutoQuester or {}

local quest_blacklist = require("EaxAutoQuester/quest_blacklist_sylvanas")

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

print("PASS test_quest_blacklist")
os.exit(0)
