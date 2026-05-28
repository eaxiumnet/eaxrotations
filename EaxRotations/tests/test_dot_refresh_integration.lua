-- =========================================================================
-- EaxRotations File Version: 1.1.1
-- Last Modified: 2026-05-27
-- Change: File version stamp for runtime load verification
-- =========================================================================
local __eax_file = "tests/test_dot_refresh_integration.lua"
local __eax_version = "1.1.1"
local __eax_modified = "2026-05-27"
local __eax_change = "File version stamp for runtime load verification"
local __eax_versions = rawget(_G, "EaxRotationsFileVersions") or {}
_G.EaxRotationsFileVersions = __eax_versions
__eax_versions[__eax_file] = { version = __eax_version, modified = __eax_modified, change = __eax_change }
local __eax_core = rawget(_G, "core")
if type(__eax_core) == "table" and type(__eax_core.log) == "function" then
    pcall(__eax_core.log, "[EaxRotations] Loaded " .. __eax_file .. " v" .. __eax_version)
end
local __eax_ns = rawget(_G, "EaxRotations")
if type(__eax_ns) == "table" then __eax_ns.file_versions = __eax_versions end
-- ============================================================================
-- Test: DoT Refresh Integration
-- ============================================================================
local NS = _G.EaxRotations or {}
_G.EaxRotations = NS

pcall(dofile, "EaxRotations/shared/dot_refresh_sylvanas.lua")
local DR = _G.DotRefresh or {}
-- NS registration is handled by dot_refresh_sylvanas.lua itself.

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
