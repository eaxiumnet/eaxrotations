-- What: Unit tests for EaxAutoQuester/quest_state/waiting_state.lua
-- When: Run via `lua EaxAutoQuester/tests/run_quester_tests.lua`
-- Why: Verify WAITING state transitions: IDLE (step appears), WAITING

local mock = require("EaxAutoQuester/tests/mock_core")
mock.install()
mock.reset()

local waiting_state = require("EaxAutoQuester/quest_state/waiting_state")

-- Test run with no Zygor
local shared = {}
local ctx = { debug_log = function() end, zygor = nil }
assert(waiting_state.run(shared, ctx) == "WAITING", "waiting no zygor → WAITING")

-- Test run with no step
local mock_zygor = { has_current_step = function() return false end }
ctx = { debug_log = function() end, zygor = mock_zygor }
assert(waiting_state.run(shared, ctx) == "WAITING", "waiting no step → WAITING")

-- Test run with step appearing (throttle is per-utils instance, so first call is allowed)
local mock_zygor_step = { has_current_step = function() return true end }
local mock_utils = { throttle = function(name, interval) return true end }
ctx = { debug_log = function() end, zygor = mock_zygor_step, utils = mock_utils }
assert(waiting_state.run(shared, ctx) == "IDLE", "waiting step appears → IDLE")

print("PASS test_waiting_state")
os.exit(0)
