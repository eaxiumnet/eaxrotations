-- test_bear_wotlk_dsl_priority.lua — WotLK Bear druid DSL priority order tests.
-- WHAT:  Validates that the 5 bear_wotlk strategies are compiled correctly by the DSL
--        and that their match gates fire in the expected priority order.
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
    DruidSpells = {
        MangleBear = make_action(33987, "MangleBear"),
        Lacerate = make_action(33745, "Lacerate"),
        SwipeBear = make_action(26997, "SwipeBear"),
        Maul = make_action(26996, "Maul"),
        FaerieFireFeral = make_action(27011, "FeralFaerieFire"),
    },
    GetPlayer = function() return {
        get_health_percentage = function() return 80 end,
        get_rage = function() return 50 end,
    } end,
    me = {
        get_health_percentage = function() return 80 end,
        get_rage = function() return 50 end,
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
    should_use_long_cd = function(ctx, cd) return true end,
    rotation_registry = {
        register = function(self, name, strategies, options)
            _G.EaxRotations._registered_bear = { strategies = strategies, options = options }
        end,
    },
}

package.loaded["shared/potion_helper_sylvanas"] =
    { try_use_potion = function() return false end, HEALTH_POTION_IDS = {}, DAMAGE_POTION_IDS = {} }
package.loaded["shared/strategy_dsl_sylvanas"] = package.loaded["shared/strategy_dsl_sylvanas"]
    or require("shared/strategy_dsl_sylvanas")

print("=== test_bear_wotlk_dsl_priority ===")

local bear = dofile("EaxRotations/classes/druid/bear_wotlk.lua")
assert_true(type(bear) == "table", "bear_wotlk should return a table")
assert_true(type(bear.strategies) == "table", "bear_wotlk should expose strategies")
assert_true(#bear.strategies == 5, "bear_wotlk should have 5 strategies")

local registered = _G.EaxRotations._registered_bear
assert_true(registered ~= nil, "bear_wotlk should register under 'bear'")

-- ============================================================================
-- Priority order test
-- ============================================================================
local expected_order = {
    "Lacerate",
    "SwipeBear",
    "MangleBear",
    "FeralFaerieFire",
    "Maul",
}

test("priority order: 5 strategies match expected order", function()
    for i = 1, #expected_order do
        assert_true(bear.strategies[i].name == expected_order[i],
            string.format("Strategy %d should be %s, got %s", i, expected_order[i], bear.strategies[i].name))
    end
end)

-- ============================================================================
-- Match gate tests
-- ============================================================================

local ctx = { in_combat = true, target = {}, settings = {} }

-- FeralFaerieFire: matches when debuff remains < 3
test("FeralFaerieFire: matches when debuff remains < 3", function()
    local state = bear.build_state(ctx)
    state.faerie_fire_remains = 1
    assert_true(bear.strategies[4].matches(ctx, state), "FeralFaerieFire should match when debuff < 3")
end)

test("FeralFaerieFire: does not match when debuff remains >= 3", function()
    local state = bear.build_state(ctx)
    state.faerie_fire_remains = 5
    assert_false(bear.strategies[4].matches(ctx, state), "FeralFaerieFire should not match when debuff >= 3")
end)

-- Lacerate: matches when debuff < 3 and rage >= 15
test("Lacerate: matches when debuff < 3 and rage >= 15", function()
    local state = bear.build_state(ctx)
    state.lacerate_remains = 1
    assert_true(bear.strategies[1].matches(ctx, state), "Lacerate should match when debuff < 3 and rage >= 15")
end)

test("Lacerate: does not match when not in combat", function()
    local state = bear.build_state({ in_combat = false, target = {}, settings = {} })
    state.lacerate_remains = 1
    assert_false(bear.strategies[1].matches({ in_combat = false, target = {}, settings = {} }, state),
        "Lacerate should not match when out of combat")
end)

test("Lacerate: does not match when rage < 15", function()
    local orig_rage = _G.EaxRotations.me.get_rage
    _G.EaxRotations.me.get_rage = function() return 10 end
    local state = bear.build_state(ctx)
    state.lacerate_remains = 1
    local ok = bear.strategies[1].matches(ctx, state)
    _G.EaxRotations.me.get_rage = orig_rage
    assert_false(ok, "Lacerate should not match when rage < 15")
end)

-- SwipeBear: matches when in combat, enemy_count >= 2, rage >= 15
test("SwipeBear: matches in AoE combat with rage >= 15", function()
    local state = bear.build_state({ in_combat = true, target = {}, settings = {}, enemy_count = 2 })
    assert_true(bear.strategies[2].matches({ in_combat = true, target = {}, settings = {}, enemy_count = 2 }, state),
        "SwipeBear should match in AoE combat")
end)

test("SwipeBear: does not match with fewer than 2 enemies", function()
    local state = bear.build_state({ in_combat = true, target = {}, settings = {}, enemy_count = 1 })
    assert_false(bear.strategies[2].matches({ in_combat = true, target = {}, settings = {}, enemy_count = 1 }, state),
        "SwipeBear should not match with < 2 enemies")
end)

test("SwipeBear: does not match when rage < 15", function()
    local orig_rage = _G.EaxRotations.me.get_rage
    _G.EaxRotations.me.get_rage = function() return 10 end
    local state = bear.build_state({ in_combat = true, target = {}, settings = {}, enemy_count = 2 })
    local ok = bear.strategies[2].matches({ in_combat = true, target = {}, settings = {}, enemy_count = 2 }, state)
    _G.EaxRotations.me.get_rage = orig_rage
    assert_false(ok, "SwipeBear should not match when rage < 15")
end)

-- MangleBear: matches when in combat and rage >= 15
test("MangleBear: matches when in combat and rage >= 15", function()
    local state = bear.build_state(ctx)
    assert_true(bear.strategies[3].matches(ctx, state), "MangleBear should match when in combat and rage >= 15")
end)

test("MangleBear: does not match when not in combat", function()
    local state = bear.build_state({ in_combat = false, target = {}, settings = {} })
    assert_false(bear.strategies[3].matches({ in_combat = false, target = {}, settings = {} }, state),
        "MangleBear should not match when out of combat")
end)

test("MangleBear: does not match when rage < 15", function()
    local orig_rage = _G.EaxRotations.me.get_rage
    _G.EaxRotations.me.get_rage = function() return 10 end
    local state = bear.build_state(ctx)
    local ok = bear.strategies[3].matches(ctx, state)
    _G.EaxRotations.me.get_rage = orig_rage
    assert_false(ok, "MangleBear should not match when rage < 15")
end)

-- Maul: matches when in combat and rage >= 30
test("Maul: matches when in combat and rage >= 30", function()
    local orig_rage = _G.EaxRotations.me.get_rage
    _G.EaxRotations.me.get_rage = function() return 65 end
    local state = bear.build_state(ctx)
    local ok = bear.strategies[5].matches(ctx, state)
    _G.EaxRotations.me.get_rage = orig_rage
    assert_true(ok, "Maul should match when rage >= 30")
end)

test("Maul: does not match when rage < 30", function()
    local orig_rage = _G.EaxRotations.me.get_rage
    _G.EaxRotations.me.get_rage = function() return 20 end
    local state = bear.build_state(ctx)
    local ok = bear.strategies[5].matches(ctx, state)
    _G.EaxRotations.me.get_rage = orig_rage
    assert_false(ok, "Maul should not match when rage < 30")
end)

print(string.format("Tests: %d/%d passed", total_passed, total_tests))
if #failures > 0 then
    print("FAILURES:")
    for _, f in ipairs(failures) do
        print("  " .. f.label .. ": " .. tostring(f.error))
    end
    os.exit(1)
end
