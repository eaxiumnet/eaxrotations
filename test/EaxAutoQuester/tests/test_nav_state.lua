-- What: Unit tests for EaxAutoQuester/quest_state/nav_state.lua
-- When: Run via `lua EaxAutoQuester/tests/run_quester_tests.lua`
-- Why: Verify NAV state transitions: IDLE (combat/arrived/failed/stuck), NAV

local mock = require("EaxAutoQuester/tests/mock_core")
mock.install()
mock.reset()

local nav_state = require("EaxAutoQuester/quest_state/nav_state")

-- Test run with combat
local combat_player = mock.create_player({ pos = {x=0, y=0, z=0}, combat = true })
local mock_nav = { get_state = function() return "NAVIGATING" end, stop = function() end, update = function() end }
local shared = { _nav_retry_timer = 0 }
local ctx = { me = combat_player, nav = mock_nav, now = 0, debug_log = function() end, safe = function(v, fallback) return v or fallback end, log = function() end }
assert(nav_state.run(shared, ctx) == "IDLE", "nav combat → IDLE")

-- Test run arrived
local player = mock.create_player({ pos = {x=0, y=0, z=0} })
mock_nav = { get_state = function() return "ARRIVED" end, stop = function() end, update = function() end }
shared = { _nav_retry_timer = 0, _nav_destination = {x=1,y=1,z=1} }
ctx = { me = player, nav = mock_nav, now = 0, debug_log = function() end, safe = function(v, fallback) return v or fallback end, log = function() end }
assert(nav_state.run(shared, ctx) == "IDLE", "nav arrived → IDLE")
assert(shared._nav_destination == nil, "nav arrived clears destination")

-- Test run failed
mock_nav = { get_state = function() return "FAILED" end, stop = function() end, update = function() end }
shared = { _nav_retry_timer = 0, _nav_retries = 0, _nav_destination = {x=1,y=1,z=1} }
ctx = { me = player, nav = mock_nav, now = 0, debug_log = function() end, safe = function(v, fallback) return v or fallback end, log = function() end }
assert(nav_state.run(shared, ctx) == "NAV", "nav failed retry → NAV")

-- Test run stuck
mock_nav = { get_state = function() return "STUCK" end, stop = function() end, update = function() end }
shared = { _nav_retry_timer = 0, _nav_retries = 0, _nav_destination = {x=1,y=1,z=1} }
ctx = { me = player, nav = mock_nav, now = 0, debug_log = function() end, safe = function(v, fallback) return v or fallback end, log = function() end }
assert(nav_state.run(shared, ctx) == "NAV", "nav stuck retry → NAV")

-- Test run max retries
mock_nav = { get_state = function() return "FAILED" end, stop = function() end, update = function() end }
shared = { _nav_retry_timer = 0, _nav_retries = 3, _nav_destination = {x=1,y=1,z=1} }
ctx = { me = player, nav = mock_nav, now = 0, debug_log = function() end, safe = function(v, fallback) return v or fallback end, log = function() end }
assert(nav_state.run(shared, ctx) == "IDLE", "nav max retries → IDLE")

print("PASS test_nav_state")
os.exit(0)
