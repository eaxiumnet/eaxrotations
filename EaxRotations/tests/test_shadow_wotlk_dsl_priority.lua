-- test_shadow_wotlk_dsl_priority.lua — WotLK Shadow priest DSL priority order tests.
-- WHAT:  Validates that the 5 shadow_wotlk strategies are compiled correctly by the DSL
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
    PriestSpells = {
        VampiricTouch = make_action(34914, "VampiricTouch"),
        ShadowWordPain = make_action(25368, "ShadowWordPain"),
        DevouringPlague = make_action(25467, "DevouringPlague"),
        MindBlast = make_action(25375, "MindBlast"),
        MindFlay = make_action(25387, "MindFlay"),
    },
    GetPlayer = function() return {
        get_health_percentage = function() return 80 end,
        get_mana_percentage = function() return 80 end,
    } end,
    me = {
        get_health_percentage = function() return 80 end,
        get_mana_percentage = function() return 80 end,
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
    is_wotlk = function() return true end,
    rotation_registry = {
        register = function(self, name, strategies, options)
            _G.EaxRotations._registered_shadow = { strategies = strategies, options = options }
        end,
    },
}

package.loaded["shared/potion_helper_sylvanas"] =
    { try_use_potion = function() return false end, HEALTH_POTION_IDS = {}, DAMAGE_POTION_IDS = {} }
package.loaded["shared/strategy_dsl_sylvanas"] = package.loaded["shared/strategy_dsl_sylvanas"]
    or require("shared/strategy_dsl_sylvanas")

print("=== test_shadow_wotlk_dsl_priority ===")

local shadow = dofile("EaxRotations/classes/priest/shadow_wotlk.lua")
assert_true(type(shadow) == "table", "shadow_wotlk should return a table")
assert_true(type(shadow.strategies) == "table", "shadow_wotlk should expose strategies")
assert_true(#shadow.strategies == 5, "shadow_wotlk should have 5 strategies")

local registered = _G.EaxRotations._registered_shadow
assert_true(registered ~= nil, "shadow_wotlk should register under 'shadow'")

-- ============================================================================
-- Priority order test
-- ============================================================================
local expected_order = {
    "VampiricTouch",
    "ShadowWordPain",
    "DevouringPlague",
    "MindBlast",
    "MindFlay",
}

test("priority order: 5 strategies match expected order", function()
    for i = 1, #expected_order do
        assert_true(shadow.strategies[i].name == expected_order[i],
            string.format("Strategy %d should be %s, got %s", i, expected_order[i], shadow.strategies[i].name))
    end
end)

-- ============================================================================
-- Match gate tests
-- ============================================================================

local ctx = { in_combat = true, target = {}, settings = {} }

-- VampiricTouch: matches when remains < 3
test("VampiricTouch: matches when remains < 3", function()
    local state = shadow.build_state(ctx)  -- defaults: debuff_remains returns 0
    assert_true(shadow.strategies[1].matches(ctx, state), "VampiricTouch should match when remains < 3")
end)

test("VampiricTouch: does not match when remains >= 3", function()
    local orig_debuff = _G.EaxRotations.debuff_remains
    _G.EaxRotations.debuff_remains = function(unit, ids) return 5 end
    local state = shadow.build_state(ctx)
    local ok = shadow.strategies[1].matches(ctx, state)
    _G.EaxRotations.debuff_remains = orig_debuff
    assert_false(ok, "VampiricTouch should not match when remains >= 3")
end)

-- ShadowWordPain: matches when remains < 3
test("ShadowWordPain: matches when remains < 3", function()
    local state = shadow.build_state(ctx)
    assert_true(shadow.strategies[2].matches(ctx, state), "ShadowWordPain should match when remains < 3")
end)

test("ShadowWordPain: does not match when remains >= 3", function()
    local orig_debuff = _G.EaxRotations.debuff_remains
    _G.EaxRotations.debuff_remains = function(unit, ids) return 5 end
    local state = shadow.build_state(ctx)
    local ok = shadow.strategies[2].matches(ctx, state)
    _G.EaxRotations.debuff_remains = orig_debuff
    assert_false(ok, "ShadowWordPain should not match when remains >= 3")
end)

-- DevouringPlague: matches when remains < 3
test("DevouringPlague: matches when remains < 3", function()
    local state = shadow.build_state(ctx)
    assert_true(shadow.strategies[3].matches(ctx, state), "DevouringPlague should match when remains < 3")
end)

test("DevouringPlague: does not match when remains >= 3", function()
    local orig_debuff = _G.EaxRotations.debuff_remains
    _G.EaxRotations.debuff_remains = function(unit, ids) return 5 end
    local state = shadow.build_state(ctx)
    local ok = shadow.strategies[3].matches(ctx, state)
    _G.EaxRotations.debuff_remains = orig_debuff
    assert_false(ok, "DevouringPlague should not match when remains >= 3")
end)

-- MindBlast: matches when mana >= 20
test("MindBlast: matches when mana >= 20", function()
    local state = shadow.build_state(ctx)  -- default mana 80
    assert_true(shadow.strategies[4].matches(ctx, state), "MindBlast should match when mana >= 20")
end)

test("MindBlast: does not match when mana < 20", function()
    local orig_mana = _G.EaxRotations.me.get_mana_percentage
    _G.EaxRotations.me.get_mana_percentage = function() return 10 end
    local state = shadow.build_state(ctx)
    local ok = shadow.strategies[4].matches(ctx, state)
    _G.EaxRotations.me.get_mana_percentage = orig_mana
    assert_false(ok, "MindBlast should not match when mana < 20")
end)

-- MindFlay: matches when mana >= 20
test("MindFlay: matches when mana >= 20", function()
    local state = shadow.build_state(ctx)  -- default mana 80
    assert_true(shadow.strategies[5].matches(ctx, state), "MindFlay should match when mana >= 20")
end)

test("MindFlay: does not match when mana < 20", function()
    local orig_mana = _G.EaxRotations.me.get_mana_percentage
    _G.EaxRotations.me.get_mana_percentage = function() return 10 end
    local state = shadow.build_state(ctx)
    local ok = shadow.strategies[5].matches(ctx, state)
    _G.EaxRotations.me.get_mana_percentage = orig_mana
    assert_false(ok, "MindFlay should not match when mana < 20")
end)

print(string.format("Tests: %d/%d passed", total_passed, total_tests))
if #failures > 0 then
    print("FAILURES:")
    for _, f in ipairs(failures) do
        print("  " .. f.label .. ": " .. tostring(f.error))
    end
    os.exit(1)
end
