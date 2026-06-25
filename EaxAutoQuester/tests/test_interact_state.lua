-- What: Unit tests for EaxAutoQuester/quest_state/interact_state.lua
-- When: Run via `lua EaxAutoQuester/tests/run_quester_tests.lua`
-- Why: Verify INTERACT state transitions: IDLE (timeout/handled), INTERACT

local mock = require("EaxAutoQuester/tests/mock_core")
mock.install()
mock.reset()

local interact_state = require("EaxAutoQuester/quest_state/interact_state")

-- Test run with no interaction module
local shared = { _interact_start_time = 0, _interact_cooldown = 0 }
local ctx = { now = 100, debug_log = function() end, quest_interaction = nil, detect_open_frame = function() return false end }
assert(interact_state.run(shared, ctx) == "IDLE", "interact no module → IDLE")

-- Test run timeout
local mock_interaction = { handle_any_frame = function() return nil end }
shared = { _interact_start_time = 80, _interact_cooldown = 0 }
ctx = { now = 100, debug_log = function() end, quest_interaction = mock_interaction, detect_open_frame = function() return false end }
assert(interact_state.run(shared, ctx) == "IDLE", "interact timeout → IDLE")

-- Test run handled
mock_interaction = { handle_any_frame = function() return "quest_accepted" end }
shared = { _interact_start_time = 0, _interact_cooldown = 0 }
ctx = { now = 100, debug_log = function() end, quest_interaction = mock_interaction, detect_open_frame = function() return false end }
assert(interact_state.run(shared, ctx) == "IDLE", "interact handled → IDLE")

-- Test run throttled
mock_interaction = { handle_any_frame = function() return "quest_throttled" end }
shared = { _interact_start_time = 0, _interact_cooldown = 0 }
ctx = { now = 100, debug_log = function() end, quest_interaction = mock_interaction, detect_open_frame = function() return true end }
assert(interact_state.run(shared, ctx) == "INTERACT", "interact throttled → INTERACT")

print("PASS test_interact_state")
os.exit(0)
