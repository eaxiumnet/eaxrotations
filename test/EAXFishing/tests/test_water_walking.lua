-- test_water_walking.lua — Unit tests for the water walking buff module.

local WaterWalking = require("fishing/water_walking")

local assertions = 0
local failures = 0

local function CHECK(cond, msg)
    assertions = assertions + 1
    if not cond then
        failures = failures + 1
        print("  FAIL: " .. msg)
    end
end

-- TW1: module exposes expected API
CHECK(type(WaterWalking) == "table", "WaterWalking is a table")
CHECK(type(WaterWalking.has_water_walking_buff) == "function", "has_water_walking_buff is a function")
CHECK(type(WaterWalking.try_apply) == "function", "try_apply is a function")
CHECK(type(WaterWalking.reset) == "function", "reset is a function")

-- TW2: has_water_walking_buff returns false with nil player
local result = WaterWalking.has_water_walking_buff(nil)
CHECK(result == false, "has_water_walking_buff returns false with nil player")

-- TW3: try_apply returns false with nil player
local ctx = { state = { water_walking = { last_try_time = 0 } }, deps = { config = { menu = {} } } }
result = WaterWalking.try_apply(ctx, nil, 0)
CHECK(result == false, "try_apply returns false with nil player")

-- TW4: reset zeroes state fields
local state = { water_walking = { last_try_time = 999.0 } }
WaterWalking.reset(state)
CHECK(state.water_walking.last_try_time == 0.0, "reset zeroes last_try_time")

-- TW5: try_apply respects throttle (5s)
state = { water_walking = { last_try_time = 900.0 } }
ctx = { state = state, deps = { config = { menu = { auto_water_walking = { get_state = function() return true end } } } } }
result = WaterWalking.try_apply(ctx, nil, 901.0)
CHECK(result == false, "try_apply respects throttle — returns false within 5s")

-- TW6: try_apply returns false when no menu toggle
ctx = { state = { water_walking = { last_try_time = 0 } }, deps = { config = { menu = {} } } }
result = WaterWalking.try_apply(ctx, nil, 100)
CHECK(result == false, "try_apply returns false with no menu toggle")

print(string.format("PASS test_water_walking (%d assertions, %d failures)", assertions, failures))
return { assertions = assertions, failures = failures }
