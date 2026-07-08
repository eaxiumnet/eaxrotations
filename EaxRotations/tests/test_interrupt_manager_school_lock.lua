-- test_interrupt_manager_school_lock.lua -- manager tests school immunity tests.
-- WHAT:  manager tests school immunity tests
-- WHEN:  During rotation test suite execution.
-- WHY:   Protects against regressions in rotation logic and state handling.
-- SAFETY: Pure unit tests with mocked API context.

-- ============================================================================
-- Test: Interrupt Manager School Lock Tracking
-- Verifies school lock recording, querying, expiry, and strategy gating.
-- ============================================================================

local function assert_true(v, label) if not v then error(label or "assert_true failed", 2) end end
local function assert_false(v, label) if v then error(label or "assert_false failed: expected false", 2) end end
local function assert_eq(a, b, label) if a ~= b then error((label or "assert_eq") .. ": " .. tostring(a) .. " ~= " .. tostring(b), 2) end end

-- Minimal NS mock
local _mock_time = 0
local NS = {
    try_interrupt = function(target) return true end,
    spell_ready = function(spell, target, opts) return true end,
    gcd_remains = function() return 0 end,
    can_attack_target = function() return true end,
    GetPlayer = function() return { is_casting = function() return false end, is_channeling = function() return false end } end,
    try_cast = function(spell, target, reason, opts) return true end,
    safe_field = function(obj, key)
        if not obj then return nil end
        local ok, val = pcall(function() return obj[key] end)
        return ok and val or nil
    end,
    unit_alive = function(unit) return true end,
    player_control_locked = function() return false end,
    time_now = function() return _mock_time end,
}
_G.EaxRotations = NS

dofile("EaxRotations/shared/interrupt_manager_sylvanas.lua")

local M = _G.EaxInterruptManager
assert_true(M ~= nil, "InterruptManager should be loaded")

-- ============================================================================
-- Test 1: record_school_lock sets lock correctly
-- ============================================================================
do
    _mock_time = 10
    M.clear_school_locks()
    local target = { get_guid = function() return "guid_1" end }
    -- Counterspell (2139) locks "arcane" for 4s
    M.record_school_lock(target, 2139)
    assert_true(M.is_school_locked(target, "arcane"),
        "record_school_lock: arcane should be locked after Counterspell")
    assert_false(M.is_school_locked(target, "frost"),
        "record_school_lock: frost should NOT be locked after Counterspell")
    print("PASS school_lock_record_sets_lock")
end

-- ============================================================================
-- Test 2: is_school_locked returns true during lock window
-- ============================================================================
do
    _mock_time = 20
    M.clear_school_locks()
    local target = { get_guid = function() return "guid_2" end }
    -- Kick (1766) locks "physical" for 5s
    M.record_school_lock(target, 1766)
    _mock_time = 24 -- 4s later, still within 5s window
    assert_true(M.is_school_locked(target, "physical"),
        "is_school_locked: should be true at t=24 (lock from t=20, dur=5s)")
    print("PASS school_lock_true_during_window")
end

-- ============================================================================
-- Test 3: is_school_locked returns false after expiry
-- ============================================================================
do
    _mock_time = 30
    M.clear_school_locks()
    local target = { get_guid = function() return "guid_3" end }
    -- Earth Shock (8042) locks "nature" for 2s
    M.record_school_lock(target, 8042)
    _mock_time = 33 -- 3s later, beyond 2s window
    assert_false(M.is_school_locked(target, "nature"),
        "is_school_locked: should be false at t=33 (lock from t=30, dur=2s)")
    print("PASS school_lock_false_after_expiry")
end

-- ============================================================================
-- Test 4: school_lock_remains returns correct remaining time
-- ============================================================================
do
    _mock_time = 40
    M.clear_school_locks()
    local target = { get_guid = function() return "guid_4" end }
    -- Spell Lock (19647) locks "shadow" for 3s
    M.record_school_lock(target, 19647)
    _mock_time = 41.5
    local remains = M.school_lock_remains(target, "shadow")
    assert_true(remains > 0, "school_lock_remains: should be > 0 at t=41.5 (lock from t=40, dur=3s)")
    assert_true(remains <= 2, "school_lock_remains: should be <= 2 at t=41.5")

    _mock_time = 44
    local remains_expired = M.school_lock_remains(target, "shadow")
    assert_eq(remains_expired, 0, "school_lock_remains: should be 0 after expiry")
    print("PASS school_lock_remains_correct")
end

-- ============================================================================
-- Test 5: different targets are independent
-- ============================================================================
do
    _mock_time = 50
    M.clear_school_locks()
    local target_a = { get_guid = function() return "guid_a" end }
    local target_b = { get_guid = function() return "guid_b" end }
    M.record_school_lock(target_a, 2139) -- Counterspell → arcane, 4s
    assert_true(M.is_school_locked(target_a, "arcane"),
        "target independence: target_a arcane should be locked")
    assert_false(M.is_school_locked(target_b, "arcane"),
        "target independence: target_b arcane should NOT be locked")
    print("PASS school_lock_target_independence")
end

-- ============================================================================
-- Test 6: different schools on same target are independent
-- ============================================================================
do
    _mock_time = 60
    M.clear_school_locks()
    local target = { get_guid = function() return "guid_6" end }
    M.record_school_lock(target, 2139) -- Counterspell → arcane, 4s
    M.record_school_lock(target, 8042) -- Earth Shock → nature, 2s
    assert_true(M.is_school_locked(target, "arcane"),
        "school independence: arcane should be locked")
    assert_true(M.is_school_locked(target, "nature"),
        "school independence: nature should be locked")
    _mock_time = 63 -- 3s later: arcane still locked (4s), nature expired (2s)
    assert_true(M.is_school_locked(target, "arcane"),
        "school independence: arcane should still be locked at t=63")
    assert_false(M.is_school_locked(target, "nature"),
        "school independence: nature should be expired at t=63")
    print("PASS school_lock_school_independence")
end

-- ============================================================================
-- Test 7: clear_school_locks resets all locks
-- ============================================================================
do
    _mock_time = 70
    M.clear_school_locks()
    local target = { get_guid = function() return "guid_7" end }
    M.record_school_lock(target, 2139)
    assert_true(M.is_school_locked(target, "arcane"), "before clear: arcane locked")
    M.clear_school_locks()
    assert_false(M.is_school_locked(target, "arcane"), "after clear: arcane should be cleared")
    print("PASS school_lock_clear_resets")
end

-- ============================================================================
-- Test 8: re-interrupting refreshes the lock duration
-- ============================================================================
do
    _mock_time = 80
    M.clear_school_locks()
    local target = { get_guid = function() return "guid_8" end }
    M.record_school_lock(target, 2139) -- t=80, arcane locked until t=84
    _mock_time = 83
    M.record_school_lock(target, 2139) -- t=83, arcane locked until t=87
    _mock_time = 85
    assert_true(M.is_school_locked(target, "arcane"),
        "refresh: arcane should still be locked at t=85 (refreshed at t=83)")
    _mock_time = 88
    assert_false(M.is_school_locked(target, "arcane"),
        "refresh: arcane should be expired at t=88")
    print("PASS school_lock_refresh_extends")
end

-- ============================================================================
-- Test 9: unknown interrupt spell ID is a no-op (no crash, no lock set)
-- ============================================================================
do
    _mock_time = 90
    M.clear_school_locks()
    local target = { get_guid = function() return "guid_9" end }
    M.record_school_lock(target, 99999) -- unknown spell
    assert_false(M.is_school_locked(target, "arcane"),
        "unknown spell: no lock should be set")
    assert_false(M.is_school_locked(target, "physical"),
        "unknown spell: no lock should be set for any school")
    print("PASS school_lock_unknown_spell_noop")
end

-- ============================================================================
-- Test 10: nil target does not crash
-- ============================================================================
do
    _mock_time = 100
    M.clear_school_locks()
    -- Should not error
    M.record_school_lock(nil, 2139)
    assert_false(M.is_school_locked(nil, "arcane"),
        "nil target: should return false")
    assert_eq(M.school_lock_remains(nil, "arcane"), 0,
        "nil target: should return 0")
    print("PASS school_lock_nil_target_safe")
end

print("PASS interrupt_manager_school_lock")
