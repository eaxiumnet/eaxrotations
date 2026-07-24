-- test_assassination_wotlk_dsl_priority.lua — WotLK Assassination rogue DSL priority tests.
-- WHAT:  Validates that the 6 assassination_wotlk strategies are compiled correctly by
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
        HungerForBlood = make_action(51662, "HungerForBlood"),
        Mutilate = make_action(34413, "Mutilate"),
        Envenom = make_action(32645, "Envenom"),
        Rupture = make_action(26867, "Rupture"),
        TricksOfTheTrade = make_action(57934, "TricksOfTheTrade"),
        SliceAndDice = make_action(6774, "SliceAndDice"),
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
            _G.EaxRotations._registered_assassination = { strategies = strategies, options = options }
        end,
    },
}

package.loaded["shared/potion_helper_sylvanas"] =
    { try_use_potion = function() return false end, HEALTH_POTION_IDS = {}, DAMAGE_POTION_IDS = {} }
package.loaded["shared/strategy_dsl_sylvanas"] = package.loaded["shared/strategy_dsl_sylvanas"]
    or require("shared/strategy_dsl_sylvanas")

print("=== test_assassination_wotlk_dsl_priority ===")

local sin = dofile("EaxRotations/classes/rogue/assassination_wotlk.lua")
assert_true(type(sin) == "table", "assassination_wotlk should return a table")
assert_true(type(sin.strategies) == "table", "assassination_wotlk should expose strategies")
assert_true(#sin.strategies == 6, "assassination_wotlk should have 6 strategies")

local registered = _G.EaxRotations._registered_assassination
assert_true(registered ~= nil, "assassination_wotlk should register under 'assassination'")

-- ============================================================================
-- Priority order test
-- ============================================================================
local expected_order = {
    "TricksOfTheTrade",
    "HungerForBlood",
    "SliceAndDice",
    "Rupture",
    "Envenom",
    "Mutilate",
}

test("priority order: 6 strategies match expected order", function()
    for i = 1, #expected_order do
        assert_true(sin.strategies[i].name == expected_order[i],
            string.format("Strategy %d should be %s, got %s", i, expected_order[i], sin.strategies[i].name))
    end
end)

-- ============================================================================
-- Match gate tests
-- ============================================================================
local ctx = { in_combat = true, target = {}, settings = {} }

-- TricksOfTheTrade (1): always matches (no conditions)
test("TricksOfTheTrade: always matches", function()
    local state = sin.build_state(ctx)
    assert_true(sin.strategies[1].matches(ctx, state), "TricksOfTheTrade should always match")
end)

-- HungerForBlood (2): always matches (no conditions)
test("HungerForBlood: always matches", function()
    local state = sin.build_state(ctx)
    assert_true(sin.strategies[2].matches(ctx, state), "HungerForBlood should always match")
end)

-- SliceAndDice (3): snd_remains < 3 and combo_points >= 1
test("SliceAndDice: matches when buff < 3 and combo >= 1", function()
    local state = sin.build_state(ctx)
    state.snd_remains = 1
    state.combo_points = 1
    assert_true(sin.strategies[3].matches(ctx, state), "SliceAndDice should match with combo >= 1 and buff < 3")
end)

test("SliceAndDice: does not match with 0 combo points", function()
    local state = sin.build_state(ctx)
    state.snd_remains = 1
    state.combo_points = 0
    assert_false(sin.strategies[3].matches(ctx, state), "SliceAndDice should not match with 0 combo")
end)

test("SliceAndDice: does not match when buff fresh (>= 3)", function()
    local state = sin.build_state(ctx)
    state.snd_remains = 10
    state.combo_points = 3
    assert_false(sin.strategies[3].matches(ctx, state), "SliceAndDice should not match when buff fresh")
end)

-- Rupture (4): rupture_remains < 3 and combo_points >= 1
test("Rupture: matches when debuff < 3 and combo >= 1", function()
    local state = sin.build_state(ctx)
    state.rupture_remains = 0
    state.combo_points = 2
    assert_true(sin.strategies[4].matches(ctx, state), "Rupture should match with combo >= 1 and debuff < 3")
end)

test("Rupture: does not match with 0 combo points", function()
    local state = sin.build_state(ctx)
    state.rupture_remains = 0
    state.combo_points = 0
    assert_false(sin.strategies[4].matches(ctx, state), "Rupture should not match with 0 combo")
end)

-- Envenom (5): combo_points >= 4
test("Envenom: matches when combo >= 4", function()
    local state = sin.build_state(ctx)
    state.combo_points = 4
    assert_true(sin.strategies[5].matches(ctx, state), "Envenom should match with combo >= 4")
end)

test("Envenom: does not match with combo < 4", function()
    local state = sin.build_state(ctx)
    state.combo_points = 3
    assert_false(sin.strategies[5].matches(ctx, state), "Envenom should not match with combo < 4")
end)

-- Mutilate (6): energy >= 60
test("Mutilate: matches when energy >= 60", function()
    local state = sin.build_state(ctx)
    state.energy = 60
    assert_true(sin.strategies[6].matches(ctx, state), "Mutilate should match when energy >= 60")
end)

test("Mutilate: does not match when energy < 60", function()
    local state = sin.build_state(ctx)
    state.energy = 45
    assert_false(sin.strategies[6].matches(ctx, state), "Mutilate should not match when energy < 60")
end)

print(string.format("Tests: %d/%d passed", total_passed, total_tests))
if #failures > 0 then
    print("FAILURES:")
    for _, f in ipairs(failures) do
        print("  " .. f.label .. ": " .. tostring(f.error))
    end
    os.exit(1)
end
