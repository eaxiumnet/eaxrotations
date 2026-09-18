-- What: Integration test for EaxAutoQuester death flow
-- When: Run via `lua EaxAutoQuester/tests/run_quester_tests.lua`
-- Why: Verify death handling: IDLE → DEAD → IDLE

local mock = require("EaxAutoQuester/tests/mock_core")
mock.install()
mock.reset()

local dead_state = require("EaxAutoQuester/quest_state/dead_state")
local idle_state = require("EaxAutoQuester/quest_state/idle_state")

-- Test death detection in idle
local dead_player = mock.create_player({ pos = {x=0, y=0, z=0}, dead = true, hp = 0 })
local shared = { _interact_cooldown = 0, _last_cooldown_log = 0 }
local ctx = { zygor = nil, now = 0, debug_log = function() end, me = dead_player }
local result = idle_state.run(shared, ctx)
assert(result == "DEAD" or result == "WAITING", "death flow idle detects death (got " .. tostring(result) .. ")")

-- Test resurrection in dead_state
local alive_player = mock.create_player({ pos = {x=0, y=0, z=0}, dead = false })
shared = { _nav_destination = nil, _nav_retries = 0, _nav_retry_timer = 0 }
ctx = { now = 100, debug_log = function() end, me = alive_player, nav = nil }
assert(dead_state.run(shared, ctx) == "IDLE", "death flow dead detects resurrection")

print("PASS test_integration_death_flow")
os.exit(0)
