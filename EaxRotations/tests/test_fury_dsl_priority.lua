-- test_fury_dsl_priority.lua — Regression test for fury DSL strategy priority order.
-- WHAT:  Verifies that declarative DSL strategies replace imperative entries
--        at the same list positions, preserving rotation priority, and that
--        DSL conditions behave equivalently for representative state inputs.
-- WHEN:  Run via EaxRotations/tests/run_rotation_tests.lua.
-- WHY:   Fury is the second DSL adopter (after arms); this guards the
--        name-based in-place substitution and the condition equivalences.
-- SAFETY: Self-contained; only inspects the returned strategy table.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local pass_count, test_count = 0, 0

local function assert_true(v, label)
    test_count = test_count + 1
    if not v then error("FAIL: " .. (label or "assert_true"), 2) end
    pass_count = pass_count + 1
end

local function assert_false(v, label)
    test_count = test_count + 1
    if v then error("FAIL: " .. (label or "assert_false"), 2) end
    pass_count = pass_count + 1
end

local function assert_eq(a, b, label)
    test_count = test_count + 1
    if a ~= b then error("FAIL: " .. (label or "assert_eq") .. ": " .. tostring(a) .. " ~= " .. tostring(b), 2) end
    pass_count = pass_count + 1
end

-- Minimal NS namespace so fury_sylvanas.lua loads without the engine.
local mock_rampage_remains = 0
_G.EaxRotations = {
    WarriorConstants = {
        STANCE = { BATTLE = 1, DEFENSIVE = 2, BERSERKER = 3 },
    },
    log = function() end,
    log_warning = function() end,
    GetPlayer = function() return {} end,
    get_setting = function(_, default) return default end,
    buff_remains = function() return mock_rampage_remains end,
    rotation_registry = { register = function() end },
}

local fury = require("classes/warrior/fury_sylvanas")

local expected_order = {
    "HealthPotion", "DamagePotion", "Healthstone", "Intercept",
    "Hamstring", "Pummel", "BerserkerStance", "BattleStance",
    "BattleShout", "BerserkerRage", "Bloodrage", "EngineeringBomb",
    "VictoryRush", "Charge", "Recklessness", "DeathWish",
    "SweepingStrikes", "Rampage", "Execute", "Bloodthirst",
    "Whirlwind", "Overpower", "Slam", "SwingDesync",
    "SunderArmor", "DemoralizingShout", "Cleave", "HeroicStrike",
    "HitCapPriority",
}

local actual_order = {}
for i = 1, #fury.strategies do
    actual_order[#actual_order + 1] = fury.strategies[i].name
end

assert_eq(#actual_order, #expected_order, "strategy count matches expected")

for i = 1, #expected_order do
    assert_eq(actual_order[i], expected_order[i], "strategy at index " .. i .. " is " .. expected_order[i])
end

-- Explicitly verify the 7 DSL-converted names sit at their original indices.
local dsl_positions = {
    BattleShout = 9,
    VictoryRush = 13,
    Rampage = 18,
    Execute = 19,
    Bloodthirst = 20,
    Whirlwind = 21,
    DemoralizingShout = 26,
}

for name, expected_index in pairs(dsl_positions) do
    assert_eq(actual_order[expected_index], name, name .. " is at expected index " .. expected_index)
end

local function find_strategy(name)
    for i = 1, #fury.strategies do
        if fury.strategies[i].name == name then return fury.strategies[i] end
    end
    error("strategy not found: " .. name)
end

-- ============================================================================
-- DSL condition equivalence checks (explicit state → no build_state needed)
-- ============================================================================

-- BattleShout: missing both shouts + rage >= 10
local battle_shout = find_strategy("BattleShout")
assert_true(battle_shout.matches({}, { has_battle_shout = false, has_commanding_shout = false, rage = 50 }),
    "BattleShout matches when no shout buff and rage >= 10")
assert_false(battle_shout.matches({}, { has_battle_shout = true, has_commanding_shout = false, rage = 50 }),
    "BattleShout does not match when Battle Shout already up")
assert_false(battle_shout.matches({}, { has_battle_shout = false, has_commanding_shout = true, rage = 50 }),
    "BattleShout does not match when Commanding Shout already up")
assert_false(battle_shout.matches({}, { has_battle_shout = false, has_commanding_shout = false, rage = 5 }),
    "BattleShout does not match below 10 rage")

-- VictoryRush: proc buff required
local victory_rush = find_strategy("VictoryRush")
assert_true(victory_rush.matches({ me = {} }, { victory_rush_ready = true }),
    "VictoryRush matches when proc buff is up")
assert_false(victory_rush.matches({ me = {} }, { victory_rush_ready = false }),
    "VictoryRush does not match without proc buff")

-- Rampage: in-combat only; apply when missing, refresh at <= 3s, else hold
local rampage = find_strategy("Rampage")
assert_false(rampage.matches({}, { in_combat = false, has_rampage = false, rage = 50 }),
    "Rampage does not match out of combat")
mock_rampage_remains = 0
assert_true(rampage.matches({ me = {} }, { in_combat = true, has_rampage = false, rage = 50 }),
    "Rampage matches to apply missing buff")
mock_rampage_remains = 2
assert_true(rampage.matches({ me = {} }, { in_combat = true, has_rampage = true, rage = 50 }),
    "Rampage matches to refresh at <= 3s remaining")
mock_rampage_remains = 10
assert_false(rampage.matches({ me = {} }, { in_combat = true, has_rampage = true, rage = 50 }),
    "Rampage does not match when buff fresh")
assert_false(rampage.matches({ me = {} }, { in_combat = true, has_rampage = false, rage = 20 }),
    "Rampage does not match below 30 rage")
mock_rampage_remains = 0

-- Execute: execute phase + rage setting gate (default 25)
local execute = find_strategy("Execute")
assert_false(execute.matches({}, { execute_phase = false, rage = 50 }),
    "Execute does not match outside execute phase")
assert_true(execute.matches({}, { execute_phase = true, rage = 50 }),
    "Execute matches in execute phase with sufficient rage")
assert_false(execute.matches({}, { execute_phase = true, rage = 10 }),
    "Execute does not match below the rage gate")

-- Bloodthirst: readiness + rage gate; yields to Whirlwind window
local bloodthirst = find_strategy("Bloodthirst")
assert_true(bloodthirst.matches({}, { bt_ready = true, ww_ready = false, rage = 50 }),
    "Bloodthirst matches when ready with rage")
assert_false(bloodthirst.matches({}, { bt_ready = false, ww_ready = false, rage = 50 }),
    "Bloodthirst does not match while on cooldown")
assert_false(bloodthirst.matches({}, { bt_ready = true, ww_ready = false, rage = 20 }),
    "Bloodthirst does not match below 30 rage")

-- Whirlwind: readiness + CC gate + rage/AoE gate
local whirlwind = find_strategy("Whirlwind")
assert_false(whirlwind.matches({}, { ww_ready = false, aoe_cc_nearby = false, rage = 50 }),
    "Whirlwind does not match while on cooldown")
assert_true(whirlwind.matches({}, { ww_ready = true, aoe_cc_nearby = false, rage = 50 }),
    "Whirlwind matches when ready with rage")
assert_false(whirlwind.matches({}, { ww_ready = true, aoe_cc_nearby = true, rage = 50 }),
    "Whirlwind does not match with CC nearby")
assert_false(whirlwind.matches({}, { ww_ready = true, aoe_cc_nearby = false, rage = 10 }),
    "Whirlwind does not match below 25 rage without AoE")

-- DemoralizingShout: refresh window + PvP/multi-enemy/low-HP gate + rage
local demo_shout = find_strategy("DemoralizingShout")
assert_true(demo_shout.matches({}, { demo_remains = 0, is_pvp = false, enemy_count = 3, hp = 50, rage = 50 }),
    "DemoralizingShout matches at low HP with enemies")
assert_true(demo_shout.matches({}, { demo_remains = 5, is_pvp = true, enemy_count = 1, hp = 100, rage = 50 }),
    "DemoralizingShout matches in PvP at refresh window edge")
assert_false(demo_shout.matches({}, { demo_remains = 6, is_pvp = true, enemy_count = 1, hp = 50, rage = 50 }),
    "DemoralizingShout does not match when debuff fresh")
assert_false(demo_shout.matches({}, { demo_remains = 0, is_pvp = false, enemy_count = 1, hp = 80, rage = 50 }),
    "DemoralizingShout does not match single enemy at high HP outside PvP")
assert_false(demo_shout.matches({}, { demo_remains = 0, is_pvp = false, enemy_count = 3, hp = 50, rage = 5 }),
    "DemoralizingShout does not match below 10 rage")

print(string.format("PASS test_fury_dsl_priority (%d/%d assertions passed)", pass_count, test_count))
