-- What: Unit tests for EaxAutoQuester/quest_state/interact_state.lua
-- When: Run via `lua EaxAutoQuester/tests/run_quester_tests.lua`
-- Why: Verify INTERACT state transitions: IDLE (timeout/handled), INTERACT

-- Path setup for standalone run
package.path = package.path .. ";./EaxAutoQuester/?.lua;./EaxAutoQuester/?/init.lua"

local mock = require("EaxAutoQuester/tests/mock_core")
mock.install()
mock.reset()

local interact_state = require("quest_state/interact_state")

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

-- ============================================================================
-- Loot frame branch of quest_interaction.handle_any_frame (priority 1).
-- Loot slots are 0 BASED (.api/core.lua:1025, :1849, :2123), so a window of 2
-- slots is addressed 0 and 1 — never 1 and 2, and never past the end. Taking a slot
-- also compacts the window, so walking it by ascending index skips whatever shifts
-- down into an index already visited: the second item is then never looted.
-- ============================================================================
mock.reset()
mock._loot_items = {
    { id = 11, name = "First",  is_gold = false },
    { id = 12, name = "Second", is_gold = false },
}
mock._loot_compacts = true
local quest_interaction = require("quest_interaction_sylvanas")
local action = quest_interaction.handle_any_frame(nil)
assert(action == "loot:2items",
    "loot branch should handle a 2 slot window, got " .. tostring(action))
local looted = {}
for _, call in ipairs(mock._input_calls) do
    if call[1] == "loot_item" then looted[call[2]] = true end
end
assert(looted[0] and looted[1], "loot branch must address slots 0 and 1")
assert(not looted[2], "loot branch must not address the out-of-range index 2")
-- Both items must come out exactly once; the order they are taken in is the
-- window's business, not a contract.
local took = {}
for _, name in ipairs(mock._looted_names) do took[name] = (took[name] or 0) + 1 end
assert(took["First"] == 1 and took["Second"] == 1 and #mock._looted_names == 2,
    "both items must actually be looted from a compacting window, got: " ..
    table.concat(mock._looted_names, ","))
print("  loot branch PASS: 0-based slots, compacting window, both items looted")

print("PASS test_interact_state")
os.exit(0)
