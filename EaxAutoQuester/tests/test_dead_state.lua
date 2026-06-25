-- What: Unit tests for EaxAutoQuester/quest_state/dead_state.lua
-- When: Run via `lua EaxAutoQuester/tests/run_quester_tests.lua`
-- Why: Verify DEAD state transitions: IDLE (resurrected), DEAD

local mock = require("EaxAutoQuester/tests/mock_core")
mock.install()
mock.reset()

local dead_state = require("EaxAutoQuester/quest_state/dead_state")

-- Test run with resurrected player
local alive_player = mock.create_player({ pos = {x=0, y=0, z=0}, dead = false })
local shared = { _nav_destination = nil, _nav_retries = 0, _nav_retry_timer = 0 }
local ctx = { now = 100, debug_log = function() end, me = alive_player, nav = nil }
assert(dead_state.run(shared, ctx) == "IDLE", "dead alive → IDLE")

-- Test run with dead player
local dead_player = mock.create_player({ pos = {x=0, y=0, z=0}, dead = true })
shared = { _nav_destination = nil, _nav_retries = 0, _nav_retry_timer = 0 }
ctx = { now = 100, debug_log = function() end, me = dead_player, nav = nil }
assert(dead_state.run(shared, ctx) == "DEAD", "dead dead → DEAD")

-- Test: Wrath client ghost form — is_dead()=false, HP>0, but has Ghost buff (8326)
-- This is the live bug: without buff check, dead_state exits early thinking player is alive
local ghost_player = mock.create_player({ pos = {x=0, y=0, z=0}, dead = false, hp = 5000, buffs = { [8326] = true } })
shared = { _nav_destination = nil, _nav_retries = 0, _nav_retry_timer = 0 }
ctx = { now = 100, debug_log = function() end, me = ghost_player, nav = nil }
assert(dead_state.run(shared, ctx) == "DEAD", "Wrath ghost buff via get_buffs → DEAD")

-- Test reset
dead_state.reset()

print("PASS test_dead_state")
os.exit(0)
