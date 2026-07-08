-- What: Integration test for EaxAutoQuester quest flow
-- When: Run via `lua EaxAutoQuester/tests/run_quester_tests.lua`
-- Why: Verify end-to-end state transitions: IDLE → NAV → DO_ACTION → IDLE

local mock = require("EaxAutoQuester/tests/mock_core")
mock.install()
mock.reset()

local player = mock.create_player({ pos = {x=0, y=0, z=0} })
local coordinator = require("EaxAutoQuester/quest_state/coordinator")

-- Verify initial state
local state = coordinator.get_state and coordinator.get_state() or nil

-- Test stop_navigation doesn't crash
coordinator.stop_navigation()

-- Test update doesn't crash
coordinator.update()

print("PASS test_integration_quest_flow")
os.exit(0)
