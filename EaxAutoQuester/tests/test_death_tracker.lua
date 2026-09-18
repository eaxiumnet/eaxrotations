-- What: Unit tests for EaxAutoQuester/death_tracker_sylvanas.lua
-- When: Run via `lua EaxAutoQuester/tests/run_quester_tests.lua`
-- Why: Verify death recording, blacklist threshold, reset, and nil guards

local mock = require("EaxAutoQuester/tests/mock_core")
mock.install()
mock.reset()

-- Bootstrap _G.EaxAutoQuester (normally done by main.lua)
_G.EaxAutoQuester = _G.EaxAutoQuester or {}

local death_tracker = require("EaxAutoQuester/death_tracker_sylvanas")

-- =============================================================================
-- S1: Fresh zone returns 0
-- =============================================================================
do
    local count = death_tracker.get_death_count(1000)
    assert(count == 0, "S1 FAIL: fresh zone should have count 0, got " .. tostring(count))
    print("  S1 PASS: fresh zone count = 0")
end

-- =============================================================================
-- S2: Record death increments count and returns new count
-- =============================================================================
do
    local new_count = death_tracker.record_death(1000)
    assert(new_count == 1, "S2 FAIL: first death should return 1, got " .. tostring(new_count))
    assert(death_tracker.get_death_count(1000) == 1, "S2 FAIL: get after record should be 1")
    print("  S2 PASS: record_death returns 1, get_death_count = 1")
end

-- =============================================================================
-- S3: Multiple deaths in same zone accumulate
-- =============================================================================
do
    death_tracker.record_death(1000)
    death_tracker.record_death(1000)
    assert(death_tracker.get_death_count(1000) == 3, "S3 FAIL: 3 deaths should have count 3, got " .. tostring(death_tracker.get_death_count(1000)))
    print("  S3 PASS: 3 deaths accumulated in same zone")
end

-- =============================================================================
-- S4: should_blacklist true at threshold (3)
-- =============================================================================
do
    assert(death_tracker.should_blacklist(1000) == true, "S4 FAIL: 3 deaths should trigger blacklist")
    print("  S4 PASS: should_blacklist = true at threshold 3")
end

-- =============================================================================
-- S5: should_blacklist false below threshold (1 death)
-- =============================================================================
do
    death_tracker.record_death(1001)  -- 1 death
    assert(death_tracker.should_blacklist(1001) == false, "S5 FAIL: 1 death should not trigger blacklist")
    print("  S5 PASS: should_blacklist = false with 1 death")
end

-- =============================================================================
-- S6: Different zones tracked independently
-- =============================================================================
do
    death_tracker.reset_all()
    death_tracker.record_death(2000)
    death_tracker.record_death(2000)
    death_tracker.record_death(3000)  -- different zone
    assert(death_tracker.get_death_count(2000) == 2, "S6 FAIL: zone 2000 should have 2 deaths")
    assert(death_tracker.get_death_count(3000) == 1, "S6 FAIL: zone 3000 should have 1 death")
    assert(death_tracker.get_death_count(4000) == 0, "S6 FAIL: zone 4000 should have 0 deaths")
    print("  S6 PASS: zones tracked independently")
end

-- =============================================================================
-- S7: reset_zone clears one zone
-- =============================================================================
do
    death_tracker.reset_all()
    death_tracker.record_death(5000)
    death_tracker.record_death(5000)
    death_tracker.record_death(5000)
    death_tracker.record_death(6000)
    assert(death_tracker.get_death_count(5000) == 3, "S7 FAIL: zone 5000 should have 3 deaths before reset")
    death_tracker.reset_zone(5000)
    assert(death_tracker.get_death_count(5000) == 0, "S7 FAIL: zone 5000 should be 0 after reset_zone")
    assert(death_tracker.get_death_count(6000) == 1, "S7 FAIL: zone 6000 should still have 1 death")
    print("  S7 PASS: reset_zone clears only the specified zone")
end

-- =============================================================================
-- S8: reset_all clears all zones
-- =============================================================================
do
    death_tracker.reset_all()
    death_tracker.record_death(7000)
    death_tracker.record_death(7000)
    death_tracker.record_death(8000)
    death_tracker.reset_all()
    assert(death_tracker.get_death_count(7000) == 0, "S8 FAIL: zone 7000 should be 0 after reset_all")
    assert(death_tracker.get_death_count(8000) == 0, "S8 FAIL: zone 8000 should be 0 after reset_all")
    print("  S8 PASS: reset_all clears all zones")
end

-- =============================================================================
-- S9: get_blacklisted_zones returns only zones at threshold
-- =============================================================================
do
    death_tracker.reset_all()
    death_tracker.record_death(100)
    death_tracker.record_death(100)
    death_tracker.record_death(100)  -- blacklisted
    death_tracker.record_death(200)
    death_tracker.record_death(200)  -- not blacklisted (2 only)
    death_tracker.record_death(300)
    death_tracker.record_death(300)
    death_tracker.record_death(300)  -- blacklisted
    local blacklisted = death_tracker.get_blacklisted_zones()
    assert(#blacklisted == 2, "S9 FAIL: expected 2 blacklisted zones, got " .. tostring(#blacklisted))
    local found_100 = false
    local found_300 = false
    for _, id in ipairs(blacklisted) do
        if id == 100 then found_100 = true end
        if id == 300 then found_300 = true end
    end
    assert(found_100, "S9 FAIL: zone 100 should be blacklisted")
    assert(found_300, "S9 FAIL: zone 300 should be blacklisted")
    print("  S9 PASS: get_blacklisted_zones returns only zones >= 3 deaths")
end

-- =============================================================================
-- S10: Nil map_id guards (pcall-safe)
-- =============================================================================
do
    local count = death_tracker.record_death(nil)
    assert(count == 0, "S10 FAIL: record_death(nil) should return 0, got " .. tostring(count))
    assert(death_tracker.get_death_count(nil) == 0, "S10 FAIL: get_death_count(nil) should return 0")
    assert(death_tracker.should_blacklist(nil) == false, "S10 FAIL: should_blacklist(nil) should be false")
    death_tracker.reset_zone(nil)  -- should not error
    print("  S10 PASS: nil map_id guards safe")
end

-- =============================================================================
-- S11: Global export exists on _G.EaxAutoQuester
-- =============================================================================
do
    assert(_G.EaxAutoQuester.death_tracker == death_tracker, "S11 FAIL: _G.EaxAutoQuester.death_tracker should be our module")
    print("  S11 PASS: global export _G.EaxAutoQuester.death_tracker")
end

print("PASS test_death_tracker")
os.exit(0)
