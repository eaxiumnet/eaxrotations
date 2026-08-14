-- test_arms_dsl_priority.lua — Regression test for arms DSL strategy priority order.
-- WHAT:  Verifies that declarative DSL strategies replace imperative entries
--        at the same list positions, preserving rotation priority.
-- WHEN:  Run via EaxRotations/tests/run_rotation_tests.lua.
-- WHY:   A previous bug appended DSL strategies at the end of the table,
--        moving BattleShout/Execute/etc. to lowest priority.
-- SAFETY: Self-contained; only inspects the returned strategy table.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local pass_count, test_count = 0, 0

local function assert_true(v, label)
    test_count = test_count + 1
    if not v then error("FAIL: " .. (label or "assert_true"), 2) end
    pass_count = pass_count + 1
end

local function assert_eq(a, b, label)
    test_count = test_count + 1
    if a ~= b then error("FAIL: " .. (label or "assert_eq") .. ": " .. tostring(a) .. " ~= " .. tostring(b), 2) end
    pass_count = pass_count + 1
end

-- Minimal NS namespace so arms_sylvanas.lua loads without the engine.
_G.EaxRotations = {
    log = function() end,
    log_warning = function() end,
    GetPlayer = function() return {} end,
    get_setting = function(_, default) return default end,
    rotation_registry = { register = function() end },
}

local arms = require("classes/warrior/arms_sylvanas")

local expected_order = {
    "HealthPotion", "DamagePotion", "SpellReflection", "ShieldWall",
    "IntimidatingShout", "Pummel", "Intercept", "Disarm", "Charge",
    "DefensiveStance", "BattleStance", "BerserkerStance", "CommandingShout",
    "BattleShout", "SunderArmor", "Bloodrage", "VictoryRush", "Retaliation",
    "Recklessness", "DeathWish", "BerserkerRage", "Execute", "MortalStrike",
    "Whirlwind", "Overpower", "Slam", "SweepingStrikes", "Rend",
    "PiercingHowl", "Hamstring", "DemoralizingShout", "ThunderClap",
    "Cleave", "HeroicStrike", "Healthstone", "EngineeringBomb",
}

local actual_order = {}
for i = 1, #arms.strategies do
    actual_order[#actual_order + 1] = arms.strategies[i].name
end

assert_eq(#actual_order, #expected_order, "strategy count matches expected")

for i = 1, #expected_order do
    assert_eq(actual_order[i], expected_order[i], "strategy at index " .. i .. " is " .. expected_order[i])
end

-- Explicitly verify the 8 DSL-converted names sit at their original indices.
local dsl_positions = {
    BattleShout = 14,
    VictoryRush = 17,
    Execute = 22,
    Overpower = 25,
    Rend = 28,
    Hamstring = 30,
    DemoralizingShout = 31,
    ThunderClap = 32,
}

for name, expected_index in pairs(dsl_positions) do
    assert_eq(actual_order[expected_index], name, name .. " is at expected index " .. expected_index)
end

print(string.format("PASS test_arms_dsl_priority (%d/%d assertions passed)", pass_count, test_count))
