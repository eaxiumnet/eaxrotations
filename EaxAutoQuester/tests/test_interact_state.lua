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
-- spell_name/rank/category) and the docs never say whether buying removes a service
-- from the list (quests.md:881-941), so the walk must be correct under BOTH semantics
-- AND for offers that nothing distinguishes: two ranks of one spell, or entries with no
-- name at all. Names are deliberately out of list order so a walk that buys by position
-- cannot produce the expected set.

local function trainer_setup(services, gold, compacts)
    mock.reset()
    mock._player = mock.create_player({ pos = {x=0, y=0, z=0} })
    mock._gold = gold
    mock._trainer_services = services
    mock._trainer_compacts = compacts
    mock._input_calls = {}
end

local function trainer_bought()
    return table.concat(mock._trainer_bought_names, ",")
end

local function trainer_count_of(name)
    local n = 0
    for _, got in ipairs(mock._trainer_bought_names) do
        if got == name then n = n + 1 end
    end
    return n
end

--- No walk may buy an index with no offer behind it (the mock marks such a call).
local function trainer_assert_no_overreach(label)
    assert(not trainer_bought():find("<no offer", 1, true),
        label .. " FAIL: bought an index with no offer behind it: " .. trainer_bought())
end

-- S-T1: stable list — behaviour must match the pre-existing single-pass walk
trainer_setup({
    { spell_name = "Ice Lance",         cost = 100 },   -- 1, affordable
    { spell_name = "Blink",             cost = 0   },   -- 2, free -> skipped
    { spell_name = "Frostbolt",         cost = 250 },   -- 3, affordable
    { spell_name = "Arcane Brilliance", cost = 9000 },  -- 4, unaffordable
}, 500, false)
local trainer_action = quest_interaction.handle_trainer()
assert(trainer_action == "trainer:2spells(1:Ice Lance,3:Frostbolt)",
    "S-T1a FAIL: stable list should buy the two affordable services in index order, got " ..
    tostring(trainer_action))
assert(trainer_bought() == "Ice Lance,Frostbolt",
    "S-T1b FAIL: bought " .. trainer_bought())
trainer_assert_no_overreach("S-T1c")
print("  trainer stable PASS: same buys, same order, same report")

-- S-T2: compacting list of distinguishable services — each bought exactly once
trainer_setup({
    { spell_name = "Frostbolt", cost = 100 },
    { spell_name = "Blink",     cost = 100 },
    { spell_name = "Ice Lance", cost = 100 },
}, 1000, true)
trainer_action = quest_interaction.handle_trainer()
assert(trainer_count_of("Frostbolt") == 1 and trainer_count_of("Blink") == 1
    and trainer_count_of("Ice Lance") == 1 and #mock._trainer_bought_names == 3,
    "S-T2a FAIL: a compacting list must still buy all 3 services, bought: " .. trainer_bought())
assert(#mock._trainer_services == 0,
    "S-T2b FAIL: the offer list should be empty, " .. tostring(#mock._trainer_services) .. " left")
local trainer_prefix = "trainer:3spells"
assert(type(trainer_action) == "string" and trainer_action:sub(1, #trainer_prefix) == trainer_prefix,
    "S-T2c FAIL: expected a 3spells report, got " .. tostring(trainer_action))
trainer_assert_no_overreach("S-T2d")
print("  trainer compacting PASS: every service bought once, none skipped")

-- S-T3: compacting list, tight gold — affordability is re-checked against the live list
trainer_setup({
    { spell_name = "Frostbolt",         cost = 100 },   -- affordable
    { spell_name = "Arcane Brilliance", cost = 9000 },  -- never affordable
    { spell_name = "Blink",             cost = 100 },   -- affordable, shifts to index 2
    { spell_name = "Ice Lance",         cost = 100 },   -- unaffordable once gold is spent
}, 200, true)
trainer_action = quest_interaction.handle_trainer()
assert(trainer_count_of("Frostbolt") == 1 and trainer_count_of("Blink") == 1
    and #mock._trainer_bought_names == 2,
    "S-T3a FAIL: expected Frostbolt+Blink only, bought: " .. trainer_bought())
assert(trainer_count_of("Arcane Brilliance") == 0 and trainer_count_of("Ice Lance") == 0,
    "S-T3b FAIL: bought a service that was not affordable: " .. trainer_bought())
trainer_assert_no_overreach("S-T3c")
print("  trainer affordability PASS: only affordable, freshly selected services bought")

-- S-T4: two RANKS of one spell, stable list. spell_name alone does not identify an
-- offer — rank exists to separate these — so keying "already bought" on the name buys
-- one and silently skips the other.
trainer_setup({
    { spell_name = "Frostbolt", rank = "Rank 3", cost = 100 },
    { spell_name = "Frostbolt", rank = "Rank 4", cost = 100 },
}, 1000, false)
trainer_action = quest_interaction.handle_trainer()
assert(trainer_count_of("Frostbolt") == 2,
    "S-T4a FAIL: both ranks must be bought, bought: " .. trainer_bought())
assert(trainer_action == "trainer:2spells(1:Frostbolt,2:Frostbolt)",
    "S-T4b FAIL: got " .. tostring(trainer_action))
trainer_assert_no_overreach("S-T4c")
print("  trainer ranks (stable) PASS: both ranks bought")

-- S-T5: two ranks of one spell, compacting list
trainer_setup({
    { spell_name = "Frostbolt", rank = "Rank 3", cost = 100 },
    { spell_name = "Frostbolt", rank = "Rank 4", cost = 100 },
}, 1000, true)
trainer_action = quest_interaction.handle_trainer()
assert(trainer_count_of("Frostbolt") == 2 and #mock._trainer_bought_names == 2,
    "S-T5a FAIL: both ranks must be bought, bought: " .. trainer_bought())
assert(#mock._trainer_services == 0,
    "S-T5b FAIL: the offer list should be empty, " .. tostring(#mock._trainer_services) .. " left")
print("  trainer ranks (compacting) PASS: both ranks bought, list drained")

-- S-T6: offers with no name at all, compacting — a fallback identity built from the
-- index collides the moment the list renumbers, and a service is skipped
trainer_setup({
    { cost = 100 }, { cost = 100 }, { cost = 100 },
}, 1000, true)
trainer_action = quest_interaction.handle_trainer()
assert(#mock._trainer_bought_names == 3,
    "S-T6a FAIL: all 3 nameless offers must be bought, bought: " .. trainer_bought())
assert(#mock._trainer_services == 0,
    "S-T6b FAIL: the offer list should be empty, " .. tostring(#mock._trainer_services) .. " left")
trainer_assert_no_overreach("S-T6c")
print("  trainer nameless (compacting) PASS: every offer bought once")

-- S-T7: offers with no name, stable list
trainer_setup({ { cost = 100 }, { cost = 100 } }, 1000, false)
trainer_action = quest_interaction.handle_trainer()
assert(#mock._trainer_bought_names == 2,
    "S-T7a FAIL: both nameless offers must be bought, bought: " .. trainer_bought())
trainer_assert_no_overreach("S-T7b")
print("  trainer nameless (stable) PASS: both offers bought")

-- S-T8: a count that is not a number must not raise (the guard compared a string with
-- a number), and no frame is handled
trainer_setup({ { spell_name = "Ice Lance", cost = 100 } }, 1000, false)
core.quests.get_num_trainer_services = function() return "many" end
local ok_call, hostile = pcall(quest_interaction.handle_trainer)
assert(ok_call, "S-T8a FAIL: a non-numeric count must not raise, error: " .. tostring(hostile))
assert(hostile == nil, "S-T8b FAIL: expected no action, got " .. tostring(hostile))
print("  trainer hostile count PASS: no raise, no action")

-- S-T9: an empty offer list is not a frame (restores the mock's own accessor)
trainer_setup({}, 1000, false)
core.quests.get_num_trainer_services = function() return #mock._trainer_services end
assert(quest_interaction.handle_trainer() == nil, "S-T9 FAIL: empty list should return nil")
print("  trainer empty list PASS: no action")

print("PASS test_interact_state")
os.exit(0)
