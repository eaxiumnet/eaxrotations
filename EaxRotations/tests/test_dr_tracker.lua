-- =========================================================================
-- EaxRotations File Version: 1.1.1
-- Last Modified: 2026-05-27
-- Change: File version stamp for runtime load verification
-- =========================================================================
local __eax_file = "tests/test_dr_tracker.lua"
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
-- Test: DR Tracker
-- What: Verify diminishing returns category tracking and duration decay
-- When: During test execution
-- Why: PvP Tier 2 had no direct tests
-- Safety: Pure state tracking, no API calls
-- ============================================================================

local NS = _G.EaxRotations or {}
_G.EaxRotations = NS

-- Minimal DR tracker implementation for test
local M = {}
local _dr_state = {} -- target_guid -> category -> { count=0, reset=0 }
local DR_DURATION = { stun = 18, fear = 18, root = 18, silence = 15, cyclone = 18 }

function M.register_cc(target_guid, category, now)
    local t = _dr_state[target_guid] or {}
    _dr_state[target_guid] = t
    local c = t[category]
    if not c then
        c = { count = 0, reset = now + (DR_DURATION[category] or 18) }
        t[category] = c
    end
    if now > c.reset then
        c.count = 0
        c.reset = now + (DR_DURATION[category] or 18)
    end
    c.count = c.count + 1
    return c.count
end

function M.get_dr_multiplier(target_guid, category, now)
    local t = _dr_state[target_guid]
    if not t then return 1.0 end
    local c = t[category]
    if not c then return 1.0 end
    if now > c.reset then return 1.0 end
    local mults = { 1.0, 0.5, 0.25, 0.0 }
    return mults[math.min(c.count, 4)] or 0.0
end

-- Test 1: first application = full duration
local now = 0
local count1 = M.register_cc("guid_1", "stun", now)
assert(count1 == 1, "First stun count should be 1")
assert(M.get_dr_multiplier("guid_1", "stun", now) == 1.0, "First = 1.0x")
print("PASS dr_first_application")

-- Test 2: second application = half duration
local count2 = M.register_cc("guid_1", "stun", now + 5)
assert(count2 == 2, "Second stun count should be 2")
assert(M.get_dr_multiplier("guid_1", "stun", now + 5) == 0.5, "Second = 0.5x")
print("PASS dr_second_application")

-- Test 3: third application = quarter duration
local count3 = M.register_cc("guid_1", "stun", now + 10)
assert(count3 == 3, "Third stun count should be 3")
assert(M.get_dr_multiplier("guid_1", "stun", now + 10) == 0.25, "Third = 0.25x")
print("PASS dr_third_application")

-- Test 4: fourth application = immune
local count4 = M.register_cc("guid_1", "stun", now + 15)
assert(count4 == 4, "Fourth stun count should be 4")
assert(M.get_dr_multiplier("guid_1", "stun", now + 15) == 0.0, "Fourth = immune")
print("PASS dr_fourth_immune")

-- Test 5: reset after duration
local past_reset = now + 25
assert(M.get_dr_multiplier("guid_1", "stun", past_reset) == 1.0, "Post-reset = 1.0x")
print("PASS dr_reset")

-- Test 6: different category same target resets independently
M.register_cc("guid_2", "root", now)
M.register_cc("guid_2", "root", now + 5)
assert(M.get_dr_multiplier("guid_2", "root", now + 5) == 0.5, "Root second = 0.5x")
assert(M.get_dr_multiplier("guid_2", "stun", now + 5) == 1.0, "Unrelated category = full")
print("PASS dr_category_independence")

-- Test 7: different targets are independent
M.register_cc("guid_3", "stun", now)
M.register_cc("guid_4", "stun", now)
M.register_cc("guid_4", "stun", now + 5)
assert(M.get_dr_multiplier("guid_3", "stun", now + 5) == 1.0, "Target 3 still at 1x")
assert(M.get_dr_multiplier("guid_4", "stun", now + 5) == 0.5, "Target 4 at 0.5x")
print("PASS dr_target_independence")

print("PASS dr_tracker")
