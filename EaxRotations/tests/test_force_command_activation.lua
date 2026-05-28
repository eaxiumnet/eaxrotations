-- =========================================================================
-- EaxRotations File Version: 1.1.1
-- Last Modified: 2026-05-27
-- Change: File version stamp for runtime load verification
-- =========================================================================
local __eax_file = "tests/test_force_command_activation.lua"
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
-- Force command regression test.
-- Validates force command activation, expiry, and context integration.

local function assert_true(v, label) if not v then error(label or "assert_true failed", 2) end end
local function assert_eq(a, b, label) if a ~= b then error((label or "assert_eq") .. ": " .. tostring(a) .. " ~= " .. tostring(b), 2) end end

-- Mock NS minimal for force_command loading
local NS = { time_now = function() return _G._test_now or 0 end, log = function() end }
_G.EaxRotations = NS
_G.os = { time = function() return (_G._test_now or 0) end }

local force = dofile("EaxRotations/shared/force_command_sylvanas.lua")
assert_true(type(NS.force_burst_active) == "function", "namespace burst accessor should be registered")
assert_true(type(NS.force_defensive_active) == "function", "namespace defensive accessor should be registered")
assert_true(type(NS.force_gap_active) == "function", "namespace gap accessor should be registered")

-- Test 1: Activate burst command
_G._test_now = 100
assert_true(force.activate("burst"), "activate burst should return true")
assert_true(force.is_active("burst"), "burst should be active immediately")
assert_true(NS.force_burst_active(), "namespace burst accessor should reflect active command")

-- Test 2: Invalid command fails
_G._test_now = 100
assert_eq(force.activate("invalid"), false, "invalid command should return false")

-- Test 3: Command expires after its window
_G._test_now = 100
force.activate("burst")
_G._test_now = 104  -- 4 seconds later, beyond 3s window
assert_eq(force.is_active("burst"), false, "burst should expire after 3 seconds")

-- Test 4: get_remaining returns correct value
_G._test_now = 100
force.activate("gap")
_G._test_now = 101
local remaining = force.get_remaining("gap")
assert_true(remaining and remaining > 1.5 and remaining < 2.1, "remaining should be ~2s")

-- Test 5: clear_all removes all commands
_G._test_now = 100
force.activate("burst")
force.activate("defensive")
force.clear_all()
assert_eq(force.is_active("burst"), false, "burst should be cleared")
assert_eq(force.is_active("defensive"), false, "defensive should be cleared")

-- Test 6: get_active_commands returns active commands only
_G._test_now = 100
force.activate("burst")
force.activate("gap")
local active = force.get_active_commands()
assert_eq(#active, 2, "should have 2 active commands")

-- Test 7: defensive window is 5 seconds (not 3)
_G._test_now = 100
force.activate("defensive")
_G._test_now = 106
assert_eq(force.is_active("defensive"), false, "defensive should expire after 5 seconds")

print("PASS force_command_activation")
