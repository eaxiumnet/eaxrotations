-- ============================================================================
-- Test: DoT Refresh Integration
-- ============================================================================
local NS = _G.EaxRotations or {}
_G.EaxRotations = NS

pcall(dofile, "EaxRotations/shared/dot_refresh.lua")
local DR = _G.DotRefresh or {}
-- Wire NS registration (mirrors dot_refresh_sylvanas.lua)
NS.should_refresh_dot = DR.should_refresh_dot
NS.is_dot_active = DR.is_dot_active

-- Test 1: dot remaining below refresh window, target lives long enough
local r1 = DR.should_refresh_dot(0.5, 1.5, 60, 18)
assert(r1 == true, "Should refresh when dot_remaining < refresh_window and ttd > base_duration + refresh_window")
print("PASS dot_refresh_low_remaining")

-- Test 2: dot remaining above refresh window
local r2 = DR.should_refresh_dot(2.0, 1.5, 60, 18)
assert(r2 == false, "Should NOT refresh when dot_remaining >= refresh_window")
print("PASS dot_refresh_high_remaining")

-- Test 3: target dies too soon
local r3 = DR.should_refresh_dot(0.5, 1.5, 10, 18)
assert(r3 == false, "Should NOT refresh when target dies before DoT pays off")
print("PASS dot_refresh_short_ttd")

-- Test 4: is_dot_active
assert(DR.is_dot_active(5, 0) == true, "5s remaining is active")
assert(DR.is_dot_active(0, 0) == false, "0s remaining is not active")
assert(DR.is_dot_active(nil, 0) == false, "nil remaining is not active")
print("PASS dot_refresh_is_dot_active")

-- Test 5: nil-safe defaults
local r5 = DR.should_refresh_dot(nil, nil, nil, nil)
assert(r5 == true, "Nil inputs should default to needing refresh")
print("PASS dot_refresh_nil_defaults")

-- Test 6: NS registration
assert(type(NS.should_refresh_dot) == "function", "NS.should_refresh_dot should be registered")
assert(type(NS.is_dot_active) == "function", "NS.is_dot_active should be registered")
print("PASS dot_refresh_ns_registration")

print("PASS dot_refresh_integration")
