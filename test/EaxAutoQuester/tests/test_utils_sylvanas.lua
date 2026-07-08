-- What: Unit tests for EaxAutoQuester/utils_sylvanas.lua
-- When: Run via `lua EaxAutoQuester/tests/run_quester_tests.lua`
-- Why: Verify distance, throttle, and logging utilities

local mock = require("EaxAutoQuester/tests/mock_core")
mock.install()
mock.reset()

local utils = require("EaxAutoQuester/utils_sylvanas")

-- Test squared_distance
assert(utils.squared_distance({x=0,y=0,z=0}, {x=3,y=4,z=0}) == 25, "squared_distance 3-4-5 triangle")
assert(utils.squared_distance({x=1,y=1,z=1}, {x=1,y=1,z=1}) == 0, "squared_distance same point")
assert(utils.squared_distance(nil, {x=1,y=1,z=1}) == 0, "squared_distance nil a")
assert(utils.squared_distance({x=1,y=1,z=1}, nil) == 0, "squared_distance nil b")

-- Test vec3_to_string
assert(utils.vec3_to_string({x=1,y=2,z=3}) == "(1, 2, 3)", "vec3_to_string")
assert(utils.vec3_to_string(nil) == "(0, 0, 0)", "vec3_to_string nil")

-- Test throttle
assert(utils.throttle("test_a", 1.0) == true, "throttle first call")
assert(utils.throttle("test_a", 1.0) == false, "throttle second call immediate")
assert(utils.throttle("test_b", 0.0) == true, "throttle zero interval")

-- Test log (no crash)
utils.log("test message")

-- Test debug_log (no crash when debug=false)
utils.debug_log("debug message", false)

-- Test debug_log (no crash when debug=true)
utils.debug_log("debug message", true)

print("PASS test_utils_sylvanas")
os.exit(0)
