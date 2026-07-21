-- test_strategy_dsl_sylvanas.lua — Unit tests for the declarative strategy DSL.
-- WHAT:  Verifies condition evaluators, logic gates, and compilation.
-- WHEN:  Run via EaxRotations/tests/run_rotation_tests.lua.
-- WHY:   Lock in DSL behavior independently of any spec file.
-- SAFETY: Self-contained mocks; no engine required.

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

local function assert_false(v, label)
    test_count = test_count + 1
    if v then error("FAIL: " .. (label or "assert_false"), 2) end
    pass_count = pass_count + 1
end

-- Mock NS namespace minimally for DSL condition evaluators.
_G.EaxRotations = {
    buff_up = function(unit, ids) return unit and unit._buff_up or false end,
    debuff_up = function(unit, ids) return unit and unit._debuff_up or false end,
    debuff_remains = function(unit, ids) return (unit and unit._debuff_remains) or 0 end,
    spell_ready = function(spell, target, opts) return target and target._spell_ready or false end,
    log_warning = function() end,
    GetPlayer = function() return { _is_player = true } end,
}

local dsl = require("shared/strategy_dsl_sylvanas")

-- ============================================================================
-- Logic gates
-- ============================================================================
local and_strategy = dsl.compile_strategy({
    name = "AndTest",
    conditions = {
        { type = "state", field = "hp", op = "<=", value = 50 },
        { type = "state", field = "rage", op = ">=", value = 30 },
    },
    action = { type = "custom", fn = function() return true end },
})

assert_true(and_strategy.matches({}, { hp = 40, rage = 40 }), "AND matches when both conditions true")
assert_false(and_strategy.matches({}, { hp = 60, rage = 40 }), "AND fails when first condition false")
assert_false(and_strategy.matches({}, { hp = 40, rage = 20 }), "AND fails when second condition false")

local or_strategy = dsl.compile_strategy({
    name = "OrTest",
    conditions = {
        { type = "OR", conditions = {
            { type = "state", field = "hp", op = "<=", value = 30 },
            { type = "state", field = "rage", op = ">=", value = 80 },
        }},
    },
    action = { type = "custom", fn = function() return true end },
})

assert_true(or_strategy.matches({}, { hp = 20, rage = 10 }), "OR matches on first true")
assert_true(or_strategy.matches({}, { hp = 100, rage = 90 }), "OR matches on second true")
assert_false(or_strategy.matches({}, { hp = 100, rage = 10 }), "OR fails when both false")

local not_strategy = dsl.compile_strategy({
    name = "NotTest",
    conditions = {
        { type = "NOT", condition = { type = "state", field = "stunned", op = "truthy" } },
    },
    action = { type = "custom", fn = function() return true end },
})

assert_true(not_strategy.matches({}, { stunned = false }), "NOT matches when condition false")
assert_false(not_strategy.matches({}, { stunned = true }), "NOT fails when condition true")

-- ============================================================================
-- Condition evaluators
-- ============================================================================
local buff_strategy = dsl.compile_strategy({
    name = "BuffTest",
    conditions = {
        { type = "buff", unit = "self", ids = { 1, 2 }, invert = true },
    },
    action = { type = "custom", fn = function() return true end },
})

assert_true(buff_strategy.matches({ me = { _buff_up = false } }, {}), "missing buff matches with invert")
assert_false(buff_strategy.matches({ me = { _buff_up = true } }, {}), "present buff fails with invert")

local debuff_strategy = dsl.compile_strategy({
    name = "DebuffTest",
    conditions = {
        { type = "debuff", ids = { 1 }, invert = true },
    },
    action = { type = "custom", fn = function() return true end },
})

assert_true(debuff_strategy.matches({ target = { _debuff_up = false } }, {}), "missing debuff matches with invert")
assert_false(debuff_strategy.matches({ target = { _debuff_up = true } }, {}), "present debuff fails with invert")

local spell_ready_strategy = dsl.compile_strategy({
    name = "SpellReadyTest",
    conditions = {
        { type = "spell_ready", spell = 12345, target = "target" },
    },
    action = { type = "custom", fn = function() return true end },
})

assert_true(spell_ready_strategy.matches({ target = { _spell_ready = true } }, {}), "spell_ready matches when ready")
assert_false(spell_ready_strategy.matches({ target = { _spell_ready = false } }, {}), "spell_ready fails when not ready")

local enemy_count_strategy = dsl.compile_strategy({
    name = "EnemyCountTest",
    conditions = {
        { type = "enemy_count", op = ">=", value = 3 },
    },
    action = { type = "custom", fn = function() return true end },
})

assert_true(enemy_count_strategy.matches({}, { enemy_count = 4 }), "enemy_count >= 3 matches at 4")
assert_false(enemy_count_strategy.matches({}, { enemy_count = 2 }), "enemy_count >= 3 fails at 2")

local hp_strategy = dsl.compile_strategy({
    name = "HpThresholdTest",
    conditions = {
        { type = "hp_threshold", unit = "self", op = "<=", value = 40 },
    },
    action = { type = "custom", fn = function() return true end },
})

assert_true(hp_strategy.matches({ hp = 30 }, {}), "self hp <= 40 matches at 30")
assert_false(hp_strategy.matches({ hp = 50 }, {}), "self hp <= 40 fails at 50")

-- ============================================================================
-- get_state wrapper
-- ============================================================================
local get_state_strategy = dsl.compile_strategy({
    name = "GetStateTest",
    conditions = {
        { type = "state", field = "rage", op = ">=", value = 25 },
    },
    action = { type = "custom", fn = function() return true end },
}, { get_state = function(context) return { rage = context.rage or 0 } end })

assert_true(get_state_strategy.matches({ rage = 30 }), "get_state wrapper builds state from context")
assert_false(get_state_strategy.matches({ rage = 10 }), "get_state wrapper builds state and fails condition")

-- ============================================================================
-- Action execution
-- ============================================================================
local custom_action_strategy = dsl.compile_strategy({
    name = "CustomActionTest",
    conditions = {},
    action = { type = "custom", fn = function(context, state) return true end },
})

assert_true(custom_action_strategy.execute({}, {}), "custom action executes and returns true")

-- 1. cast action handler mocks NS.try_cast and receives correct args.
local cast_calls = {}
_G.EaxRotations.try_cast = function(spell, target, label, opts)
    cast_calls[#cast_calls + 1] = { spell = spell, target = target, label = label, opts = opts }
    return true
end
local cast_strategy = dsl.compile_strategy({
    name = "CastTest",
    conditions = {},
    action = { type = "cast", spell = 12345, target = "target", label = "TestCast", opts = { fast = true } },
})
local cast_target = { _target = true }
assert_true(cast_strategy.execute({ target = cast_target }, {}), "cast action returns true")
assert_eq(#cast_calls, 1, "try_cast called once")
assert_eq(cast_calls[1].spell, 12345, "try_cast received spell")
assert_eq(cast_calls[1].target, cast_target, "try_cast received target")
assert_eq(cast_calls[1].label, "TestCast", "try_cast received label")
assert_eq(cast_calls[1].opts.fast, true, "try_cast received opts")

-- 2. item action handler mocks NS.use_item_by_id.
local item_calls = {}
_G.EaxRotations.use_item_by_id = function(item_id, target)
    item_calls[#item_calls + 1] = { item_id = item_id, target = target }
    return true
end
local item_strategy = dsl.compile_strategy({
    name = "ItemTest",
    conditions = {},
    action = { type = "item", item_id = 67890, target = "target" },
})
local item_target = { _item_target = true }
assert_true(item_strategy.execute({ target = item_target }, {}), "item action returns true")
assert_eq(#item_calls, 1, "use_item_by_id called once")
assert_eq(item_calls[1].item_id, 67890, "use_item_by_id received item_id")
assert_eq(item_calls[1].target, item_target, "use_item_by_id received target")

-- 3. Custom action error handling: throwing fn returns false, no crash.
local error_strategy = dsl.compile_strategy({
    name = "ErrorActionTest",
    conditions = {},
    action = { type = "custom", fn = function() error("boom") end },
})
assert_false(error_strategy.execute({}, {}), "throwing custom action returns false")

-- 4. Invalid condition type: evaluate_node returns false, no crash.
assert_false(dsl.evaluate_node({}, {}, { type = "nonexistent" }), "invalid condition type returns false")

-- 5. Missing state with no get_state wrapper: matches works when state is provided.
local no_state_wrapper_strategy = dsl.compile_strategy({
    name = "NoStateWrapperTest",
    conditions = {
        { type = "state", field = "rage", op = ">=", value = 25 },
    },
    action = { type = "custom", fn = function() return true end },
})
assert_true(no_state_wrapper_strategy.matches({}, { rage = 30 }), "matches works with explicit state")
assert_false(no_state_wrapper_strategy.matches({}, { rage = 10 }), "matches fails with explicit state")

-- 6. Setting conditions with all comparison ops.
local setting_conditions = {
    { op = "==", value = 5, context = { settings = { threshold = 5 } }, expect = true },
    { op = "!=", value = 5, context = { settings = { threshold = 3 } }, expect = true },
    { op = ">", value = 5, context = { settings = { threshold = 10 } }, expect = true },
    { op = ">=", value = 5, context = { settings = { threshold = 5 } }, expect = true },
    { op = "<", value = 5, context = { settings = { threshold = 2 } }, expect = true },
    { op = "<=", value = 5, context = { settings = { threshold = 5 } }, expect = true },
}
for _, case in ipairs(setting_conditions) do
    local setting_strategy = dsl.compile_strategy({
        name = "SettingOpTest_" .. case.op,
        conditions = {
            { type = "setting", key = "threshold", op = case.op, value = case.value },
        },
        action = { type = "custom", fn = function() return true end },
    })
    local result = setting_strategy.matches(case.context, {})
    if case.expect then
        assert_true(result, "setting condition op " .. case.op .. " matches")
    else
        assert_false(result, "setting condition op " .. case.op .. " does not match")
    end
end

-- 6b. Setting conditions with truthy/falsy ops (default-sensitive checks).
local setting_truthy_cases = {
    { context = { settings = { enabled = true } }, op = "truthy", expect = true },
    { context = { settings = { enabled = false } }, op = "truthy", expect = false },
    { context = { settings = {} }, op = "truthy", expect = false },
    { context = { settings = { enabled = true } }, op = "falsy", expect = false },
    { context = { settings = { enabled = false } }, op = "falsy", expect = true },
    { context = { settings = {} }, op = "falsy", expect = true },
}
for i, case in ipairs(setting_truthy_cases) do
    local setting_strategy = dsl.compile_strategy({
        name = "SettingTruthyTest_" .. i,
        conditions = {
            { type = "setting", key = "enabled", op = case.op },
        },
        action = { type = "custom", fn = function() return true end },
    })
    local result = setting_strategy.matches(case.context, {})
    if case.expect then
        assert_true(result, "setting condition op " .. case.op .. " matches (case " .. i .. ")")
    else
        assert_false(result, "setting condition op " .. case.op .. " does not match (case " .. i .. ")")
    end
end

-- 7. NOT condition evaluator edge cases.
local not_truthy_strategy = dsl.compile_strategy({
    name = "NotTruthyTest",
    conditions = {
        { type = "NOT", condition = { type = "state", field = "stunned", op = "truthy" } },
    },
    action = { type = "custom", fn = function() return true end },
})
assert_true(not_truthy_strategy.matches({}, { stunned = false }), "NOT truthy matches when false")
assert_false(not_truthy_strategy.matches({}, { stunned = true }), "NOT truthy fails when true")
assert_true(not_truthy_strategy.matches({}, {}), "NOT truthy matches when field missing")
local not_missing_strategy = dsl.compile_strategy({
    name = "NotMissingTest",
    conditions = {
        { type = "NOT", condition = nil },
    },
    action = { type = "custom", fn = function() return true end },
})
assert_false(not_missing_strategy.matches({}, {}), "NOT nil condition returns false")

-- 8. buff condition with invert=false and missing unit returns false.
local buff_missing_unit_strategy = dsl.compile_strategy({
    name = "BuffMissingUnitTest",
    conditions = {
        { type = "buff", unit = "self", ids = { 1 }, invert = false },
    },
    action = { type = "custom", fn = function() return true end },
})
assert_false(buff_missing_unit_strategy.matches({ me = nil }, {}), "buff invert=false with missing unit returns false")

-- 9. debuff_remains condition.
local debuff_remains_strategy = dsl.compile_strategy({
    name = "DebuffRemainsTest",
    conditions = {
        { type = "debuff_remains", ids = { 1 }, op = "<=", value = 5 },
    },
    action = { type = "custom", fn = function() return true end },
})
assert_true(debuff_remains_strategy.matches({ target = { _debuff_remains = 3 } }, {}), "debuff_remains <= 5 matches at 3")
assert_false(debuff_remains_strategy.matches({ target = { _debuff_remains = 10 } }, {}), "debuff_remains <= 5 fails at 10")

-- 10. in_combat condition with invert.
local in_combat_invert_strategy = dsl.compile_strategy({
    name = "InCombatInvertTest",
    conditions = {
        { type = "in_combat", invert = true },
    },
    action = { type = "custom", fn = function() return true end },
})
assert_true(in_combat_invert_strategy.matches({}, { in_combat = false }), "in_combat invert matches when false")
assert_false(in_combat_invert_strategy.matches({}, { in_combat = true }), "in_combat invert fails when true")

print(string.format("PASS test_strategy_dsl_sylvanas (%d/%d assertions passed)", pass_count, test_count))
