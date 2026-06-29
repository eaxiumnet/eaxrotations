-- Test: Shot Timer shared module.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local assert_true, assert_false
local function setup_asserts()
    assert_true = function(v, label) if not v then error(label or "assert_true failed", 2) end end
    assert_false = function(v, label) if v then error(label or "assert_false failed", 2) end end
end
setup_asserts()

-- Mock HunterCore
local mock_hunter_core = {
    ms_until_auto = function() return 0 end,
    get_steady_cast_ms = function() return 1500 end,
    can_cast_steady = function() return true end,
    can_cast_instant = function() return true end,
}
_G.EaxRotations = {
    log = function() end,
    HunterCore = mock_hunter_core,
}
package.loaded["shared/hunter_core_sylvanas"] = mock_hunter_core

local ShotTimer = dofile("EaxRotations/shared/shot_timer_sylvanas.lua")
assert_true(ShotTimer ~= nil, "module should load")

-- ms_until_auto returns 0 -> never delay
assert_false(ShotTimer.should_delay_cast({}, 150), "no auto pending -> don't delay")

-- Mock: auto-shot is far away -> don't delay
_G.EaxRotations.HunterCore.ms_until_auto = function() return 3000 end
assert_false(ShotTimer.should_delay_cast({}, 150), "auto far away -> don't delay")

-- Mock: auto-shot is imminent -> delay
_G.EaxRotations.HunterCore.ms_until_auto = function() return 500 end
assert_true(ShotTimer.should_delay_cast({}, 150), "auto imminent -> delay")

-- instant shot delay
_G.EaxRotations.HunterCore.ms_until_auto = function() return 400 end
assert_true(ShotTimer.should_delay_instant({}, 150), "instant with imminent auto -> delay")

_G.EaxRotations.HunterCore.ms_until_auto = function() return 800 end
assert_false(ShotTimer.should_delay_instant({}, 150), "instant with safe window -> don't delay")

-- passthrough to HunterCore
assert_true(ShotTimer.can_cast_steady(), "passthrough steady should work")
assert_true(ShotTimer.can_cast_instant(), "passthrough instant should work")

print("PASS test_shot_timer")
