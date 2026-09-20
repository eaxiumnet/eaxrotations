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

-- ============================================================================
-- Trainer frame: the offer list carries no id (.api/core.lua:4379-4383 — only
-- spell_name/rank/category), and the docs never say whether buying removes the
-- service from the list (quests.md:881-941). So the walk must be correct under
-- BOTH: re-read the offers per step and act on the index that read returned.
-- Names are deliberately not in list order, so a walk that buys by position
-- instead of by identity cannot produce the expected set.
-- ============================================================================

-- S-T1: list does NOT compact — behaviour must match the single-pass walk exactly
mock.reset()
mock._player = mock.create_player({ pos = {x=0, y=0, z=0} })
mock._gold = 500
mock._trainer_services = {
    { spell_name = "Ice Lance",        cost = 100 },   -- index 1, affordable
    { spell_name = "Blink",            cost = 0   },   -- index 2, free -> skipped
    { spell_name = "Frostbolt",        cost = 250 },   -- index 3, affordable
    { spell_name = "Arcane Brilliance", cost = 9000 },  -- index 4, unaffordable
}
mock._trainer_compacts = false
mock._input_calls = {}

local trainer_action = quest_interaction.handle_trainer()
assert(trainer_action == "trainer:2spells(1:Ice Lance,3:Frostbolt)",
    "S-T1a FAIL: stable list should buy the two affordable services in index order, got " ..
    tostring(trainer_action))
assert(#mock._trainer_bought_names == 2
    and mock._trainer_bought_names[1] == "Ice Lance"
    and mock._trainer_bought_names[2] == "Frostbolt",
    "S-T1b FAIL: bought " .. table.concat(mock._trainer_bought_names, ","))
local buy_indexes = {}
for _, call in ipairs(mock._input_calls) do
    if call[1] == "buy_trainer_service" then buy_indexes[#buy_indexes + 1] = call[2] end
end
assert(#buy_indexes == 2 and buy_indexes[1] == 1 and buy_indexes[2] == 3,
    "S-T1c FAIL: expected buys at indexes 1,3 got " .. table.concat(buy_indexes, ","))
print("  trainer stable PASS: same buys, same order, same report")

-- S-T2: list DOES compact — every service must still be bought exactly once
mock.reset()
mock._player = mock.create_player({ pos = {x=0, y=0, z=0} })
mock._gold = 1000
mock._trainer_services = {
    { spell_name = "Frostbolt", cost = 100 },
    { spell_name = "Blink",     cost = 100 },
    { spell_name = "Ice Lance", cost = 100 },
}
mock._trainer_compacts = true
mock._input_calls = {}

trainer_action = quest_interaction.handle_trainer()
local bought = {}
for _, name in ipairs(mock._trainer_bought_names) do bought[name] = (bought[name] or 0) + 1 end
assert(bought["Frostbolt"] == 1 and bought["Blink"] == 1 and bought["Ice Lance"] == 1
    and #mock._trainer_bought_names == 3,
    "S-T2a FAIL: a compacting list must still buy all 3 services, bought: " ..
    table.concat(mock._trainer_bought_names, ","))
assert(#mock._trainer_services == 0,
    "S-T2b FAIL: the offer list should be empty, " .. tostring(#mock._trainer_services) .. " left")
local prefix = "trainer:3spells("
assert(type(trainer_action) == "string" and trainer_action:sub(1, #prefix) == prefix,
    "S-T2c FAIL: expected a 3spells report, got " .. tostring(trainer_action))
print("  trainer compacting PASS: every service bought once, none skipped")

-- S-T3: compacting list, tight gold — the step must re-check affordability against
-- the list as it now stands, so it can never buy a service it did not select
mock.reset()
mock._player = mock.create_player({ pos = {x=0, y=0, z=0} })
mock._gold = 200
mock._trainer_services = {
    { spell_name = "Frostbolt",         cost = 100 },   -- affordable
    { spell_name = "Arcane Brilliance", cost = 9000 },  -- never affordable
    { spell_name = "Blink",             cost = 100 },   -- affordable, shifts to index 2
    { spell_name = "Ice Lance",         cost = 100 },   -- unaffordable once gold is spent
}
mock._trainer_compacts = true
mock._input_calls = {}

trainer_action = quest_interaction.handle_trainer()
bought = {}
for _, name in ipairs(mock._trainer_bought_names) do bought[name] = (bought[name] or 0) + 1 end
assert(bought["Frostbolt"] == 1 and bought["Blink"] == 1 and #mock._trainer_bought_names == 2,
    "S-T3a FAIL: expected Frostbolt+Blink only, bought: " ..
    table.concat(mock._trainer_bought_names, ","))
assert(not bought["Arcane Brilliance"] and not bought["Ice Lance"],
    "S-T3b FAIL: bought a service that was not affordable: " ..
    table.concat(mock._trainer_bought_names, ","))
print("  trainer affordability PASS: only affordable, freshly selected services bought")

print("PASS test_interact_state")
os.exit(0)
