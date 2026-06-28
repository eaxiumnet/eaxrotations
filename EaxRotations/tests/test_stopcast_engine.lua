-- test_stopcast_engine.lua — Unit tests for StopCast module.
-- WHAT:  Validates smart in-flight cast cancellation logic.
-- WHEN:  Run via run_rotation_tests.lua or standalone.
-- WHY:   Ensures the module correctly gates cancellation behind settings and thresholds.

local _G = _G
local NS = _G.EaxRotations or {}
_G.EaxRotations = NS

NS.log = function(msg) end
NS.settings = {}

-- Mock cancel_spells tracking
local _cancel_called = false
NS.cancel_spells = function() _cancel_called = true; return true end
NS.time_now = function() return 10.0 end

-- Load module
local mod_ok, mod_err = pcall(dofile, "EaxRotations/shared/stopcast_sylvanas.lua")
if not mod_ok then
    print("FAIL: could not load shared/stopcast_sylvanas.lua: " .. tostring(mod_err))
    return
end

local function assert_true(v, msg)
    if not v then
        print("FAIL " .. tostring(msg))
        return false
    end
    print("PASS " .. tostring(msg))
    return true
end

local function assert_false(v, msg)
    return assert_true(not v, msg)
end

local all_ok = true

-- Test 1: Module loaded
all_ok = assert_true(NS.StopCast ~= nil, "NS.StopCast is non-nil after load") and all_ok
all_ok = assert_true(type(NS.StopCast.update) == "function", "NS.StopCast.update is a function") and all_ok

-- Test 2: Disabled when stopcast_enabled = false
_cancel_called = false
NS.StopCast.reset()
local mock_me = {
    is_casting = function() return true end,
    get_cast_info = function()
        return { spell_id = 2060, target = { get_health_percentage = function() return 100 end, get_max_health = function() return 10000 end }, cast_time = 2.5, expected_heal = 3000 }
    end,
}
local cancelled = NS.StopCast.update(mock_me, { stopcast_enabled = false })
all_ok = assert_false(cancelled, "StopCast disabled: should not cancel") and all_ok
all_ok = assert_false(_cancel_called, "StopCast disabled: cancel_spells not called") and all_ok

-- Test 3: Cancel when target HP above threshold
_cancel_called = false
NS.StopCast.reset()
local mock_me2 = {
    is_casting = function() return true end,
    get_cast_info = function()
        return { spell_id = 2060, target = { get_health_percentage = function() return 98 end, get_max_health = function() return 10000 end, get_guid = function() return "target1" end }, cast_time = 2.5, expected_heal = 3000 }
    end,
}
-- Simulate 50% cast progress by faking elapsed time via time_now
local _t = 10.0
NS.time_now = function() return _t end
NS.StopCast.update(mock_me2, { stopcast_enabled = true, stopcast_threshold = 95 })
_t = 11.3  -- 1.3s elapsed out of 2.5s = ~52% progress
_cancel_called = false
cancelled = NS.StopCast.update(mock_me2, { stopcast_enabled = true, stopcast_threshold = 95 })
all_ok = assert_true(cancelled, "StopCast should cancel when target HP > threshold at 50% checkpoint") and all_ok
all_ok = assert_true(_cancel_called, "StopCast should call cancel_spells") and all_ok

-- Test 4: is_enabled helper
all_ok = assert_true(NS.StopCast.is_enabled({ stopcast_enabled = true }), "is_enabled returns true when enabled") and all_ok
all_ok = assert_false(NS.StopCast.is_enabled({ stopcast_enabled = false }), "is_enabled returns false when disabled") and all_ok
all_ok = assert_true(NS.StopCast.is_enabled({}), "is_enabled defaults to true") and all_ok

if all_ok then
    print("OK stopcast_engine")
else
    print("FAIL stopcast_engine")
end
