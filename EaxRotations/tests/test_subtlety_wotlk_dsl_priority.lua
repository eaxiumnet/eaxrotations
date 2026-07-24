-- test_subtlety_wotlk_dsl_priority.lua — WotLK Subtlety rogue DSL priority tests.
-- WHAT:  Validates that the 5 subtlety_wotlk strategies are compiled correctly by
--        the DSL and that their match gates fire in the expected priority order.
-- WHEN:  run_wotlk_tests.lua and run_rotation_tests.lua.
-- WHY:   Regression guard for DSL-based strategy definitions.
-- SAFETY: Standalone; mocks all NS dependencies.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local assert_true = function(v, label) if not v then error(label or "assert_true failed", 2) end end
local assert_false = function(v, label) if v then error(label or "assert_false failed", 2) end end
local failures, total_tests, total_passed = {}, 0, 0

local function test(label, fn)
    total_tests = total_tests + 1
    local ok, err = pcall(fn)
    if ok then total_passed = total_passed + 1
    else failures[#failures + 1] = { label = label, error = err } end
end

local function make_action(ids, label)
    local id = type(ids) == "table" and ids[1] or ids
    return {
        id = id,
        name = label or tostring(id),
        cast_safe = function(self, target) return true end,
        cooldown_remaining = function(self) return 0 end,
        can_cast = function(self, target) return true end,
        is_learned = function(self) return true end,
    }
end

_G.EaxRotations = {
    RogueSpells = {
        Premeditation = make_action(14183, "Premeditation"),
        ShadowDance = make_action(51713, "ShadowDance"),
        Ambush = make_action(27441, "Ambush"),
        Backstab = make_action(26863, "Backstab"),
        Eviscerate = make_action(26865, "Eviscerate"),
    },
    GetPlayer = function() return {
        get_health_percentage = function() return 80 end,
        get_energy = function() return 100 end,
        get_combo_points = function() return 0 end,
    } end,
    me = {
        get_health_percentage = function() return 80 end,
        get_energy = function() return 100 end,
        get_combo_points = function() return 0 end,
    },
    spell_action = make_action,
    spell_ready = function() return true end,
    spell_exists = function() return true end,
    try_cast = function() return true end,
    buff_up = function(unit, ids) return false end,
    buff_remains = function() return 0 end,
    debuff_up = function(unit, ids) return false end,
    debuff_remains = function(unit, ids) return 0 end,
    get_debuff_stacks = function() return 0 end,
    cooldown_remains = function() return 0 end,
    is_item_ready = function() return false end,
    use_item_by_id = function() return true end,
    broken_api_throttled = function() return false end,
    time_now = function() return 0 end,
    log = function() end,
    log_warning = function() end,
    rotation_registry = {
        register = function(self, name, strategies, options)
            _G.EaxRotations._registered_subtlety = { strategies = strategies, options = options }
        end,
    },
}

package.loaded["shared/potion_helper_sylvanas"] =
    { try_use_potion = function() return false end, HEALTH_POTION_IDS = {}, DAMAGE_POTION_IDS = {} }
package.loaded["shared/strategy_dsl_sylvanas"] = package.loaded["shared/strategy_dsl_sylvanas"]
    or require("shared/strategy_dsl_sylvanas")

print("=== test_subtlety_wotlk_dsl_priority ===")

local sub = dofile("EaxRotations/classes/rogue/subtlety_wotlk.lua")
assert_true(type(sub) == "table", "subtlety_wotlk should return a table")
assert_true(type(sub.strategies) == "table", "subtlety_wotlk should expose strategies")
assert_true(#sub.strategies == 5, "subtlety_wotlk should have 5 strategies")

local registered = _G.EaxRotations._registered_subtlety
assert_true(registered ~= nil, "subtlety_wotlk should register under 'subtlety'")

-- ============================================================================
-- Priority order test
-- ============================================================================
local expected_order = {
    "Premeditation",
    "ShadowDance",
    "Ambush",
    "Eviscerate",
    "Backstab",
}

test("priority order: 5 strategies match expected order", function()
    for i = 1, #expected_order do
        assert_true(sub.strategies[i].name == expected_order[i],
            string.format("Strategy %d should be %s, got %s", i, expected_order[i], sub.strategies[i].name))
    end
end)

-- ============================================================================
-- Match gate tests
-- ============================================================================
local ctx = { in_combat = true, target = {}, settings = {} }

-- Premeditation (1): always matches (no conditions)
test("Premeditation: always matches", function()
    local state = sub.build_state(ctx)
    assert_true(sub.strategies[1].matches(ctx, state), "Premeditation should always match")
end)

-- ShadowDance (2): matches when shadow_dance_up is falsy
test("ShadowDance: matches when buff down", function()
    local state = sub.build_state(ctx)
    state.shadow_dance_up = false
    assert_true(sub.strategies[2].matches(ctx, state), "ShadowDance should match when buff down")
end)

test("ShadowDance: does not match when buff up", function()
    local state = sub.build_state(ctx)
    state.shadow_dance_up = true
    assert_false(sub.strategies[2].matches(ctx, state), "ShadowDance should not match when buff up")
end)

-- Ambush (3): shadow_dance_up truthy AND energy >= 60
test("Ambush: matches when dance up and energy >= 60", function()
    local state = sub.build_state(ctx)
    state.shadow_dance_up = true
    state.energy = 60
    assert_true(sub.strategies[3].matches(ctx, state), "Ambush should match with dance up and energy >= 60")
end)

test("Ambush: does not match when dance down", function()
    local state = sub.build_state(ctx)
    state.shadow_dance_up = false
    state.energy = 100
    assert_false(sub.strategies[3].matches(ctx, state), "Ambush should not match when dance down")
end)

test("Ambush: does not match when energy < 60", function()
    local state = sub.build_state(ctx)
    state.shadow_dance_up = true
    state.energy = 45
    assert_false(sub.strategies[3].matches(ctx, state), "Ambush should not match when energy < 60")
end)

-- Eviscerate (4): combo_points >= 4
test("Eviscerate: matches when combo >= 4", function()
    local state = sub.build_state(ctx)
    state.combo_points = 4
    assert_true(sub.strategies[4].matches(ctx, state), "Eviscerate should match with combo >= 4")
end)

test("Eviscerate: does not match with combo < 4", function()
    local state = sub.build_state(ctx)
    state.combo_points = 3
    assert_false(sub.strategies[4].matches(ctx, state), "Eviscerate should not match with combo < 4")
end)

-- Backstab (5): energy >= 60
test("Backstab: matches when energy >= 60", function()
    local state = sub.build_state(ctx)
    state.energy = 60
    assert_true(sub.strategies[5].matches(ctx, state), "Backstab should match when energy >= 60")
end)

test("Backstab: does not match when energy < 60", function()
    local state = sub.build_state(ctx)
    state.energy = 45
    assert_false(sub.strategies[5].matches(ctx, state), "Backstab should not match when energy < 60")
end)

print(string.format("Tests: %d/%d passed", total_passed, total_tests))
if #failures > 0 then
    print("FAILURES:")
    for _, f in ipairs(failures) do
        print("  " .. f.label .. ": " .. tostring(f.error))
    end
    os.exit(1)
end
