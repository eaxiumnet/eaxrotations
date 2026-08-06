-- test_holy_wotlk_dsl_priority.lua — WotLK Holy paladin DSL priority tests.
-- WHAT:  Validates that the 5 holy_wotlk strategies are compiled correctly by
--        the DSL and that their match gates fire in the expected priority order.
-- WHEN:  run_wotlk_tests.lua and run_rotation_tests.lua.
-- WHY:   Regression guard for DSL-based strategy definitions.
-- SAFETY: Standalone; mocks all NS dependencies.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local assert_true = function(v, label) if not v then error(label or "assert_true failed", 2) end end
local assert_false = function(v, label) if v then error(label or "assert_false failed", 2) end end
local failures, total_tests, total_passed = {}, 0, 0
local last_execute_target = nil

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
    PaladinSpells = {
        BeaconOfLight = make_action(53563, "BeaconOfLight"),
        HolyShock = make_action(33074, "HolyShock"),
        FlashOfLight = make_action(48785, "FlashOfLight"),
        HolyLight = make_action(48782, "HolyLight"),
        SacredShield = make_action(53601, "SacredShield"),
    },
    GetPlayer = function() return {
        get_health_percentage = function() return 80 end,
        get_mana_percentage = function() return 100 end,
    } end,
    me = {
        get_health_percentage = function() return 80 end,
        get_mana_percentage = function() return 100 end,
    },
    spell_action = make_action,
    spell_ready = function() return true end,
    spell_exists = function() return true end,
    try_cast = function(spell, target) last_execute_target = target; return true end,
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
            _G.EaxRotations._registered_holy = { strategies = strategies, options = options }
        end,
    },
}

package.loaded["shared/potion_helper_sylvanas"] =
    { try_use_potion = function() return false end, HEALTH_POTION_IDS = {}, DAMAGE_POTION_IDS = {} }
package.loaded["shared/strategy_dsl_sylvanas"] = package.loaded["shared/strategy_dsl_sylvanas"]
    or require("shared/strategy_dsl_sylvanas")

print("=== test_holy_wotlk_dsl_priority ===")

local holy = dofile("EaxRotations/classes/paladin/holy_wotlk.lua")
assert_true(type(holy) == "table", "holy_wotlk should return a table")
assert_true(type(holy.strategies) == "table", "holy_wotlk should expose strategies")
assert_true(#holy.strategies == 5, "holy_wotlk should have 5 strategies")

local registered = _G.EaxRotations._registered_holy
assert_true(registered ~= nil, "holy_wotlk should register under 'holy'")

-- ============================================================================
-- Priority order test
-- ============================================================================
local expected_order = {
    "BeaconOfLight",
    "SacredShield",
    "HolyShock",
    "HolyLight",
    "FlashOfLight",
}

test("priority order: 5 strategies match expected order", function()
    for i = 1, #expected_order do
        assert_true(holy.strategies[i].name == expected_order[i],
            string.format("Strategy %d should be %s, got %s", i, expected_order[i], holy.strategies[i].name))
    end
end)

-- ============================================================================
-- Match gate tests
-- ============================================================================
local ctx = { in_combat = true, target = {}, settings = {} }

test("healing strategies use the lowest friendly target", function()
    local ally = { get_health_percentage = function() return 35 end }
    local ctx_friendly = {
        in_combat = true,
        target = { get_health_percentage = function() return 90 end },
        lowest = { unit = ally, hp = 35 },
        settings = {},
    }
    local state = holy.build_state(ctx_friendly)
    assert_true(state.target_hp == 35, "Holy paladin should score the lowest friendly unit")
    last_execute_target = nil
    assert_true(holy.strategies[4].execute(ctx_friendly, state), "Holy Light should execute")
    assert_true(last_execute_target == ally, "Holy Light should target the lowest friendly unit")
end)

-- BeaconOfLight (1): matches when beacon_up falsy
test("BeaconOfLight: matches when buff down", function()
    local state = holy.build_state(ctx)
    state.beacon_up = false
    assert_true(holy.strategies[1].matches(ctx, state), "BeaconOfLight should match when buff down")
end)

test("BeaconOfLight: does not match when buff up", function()
    local state = holy.build_state(ctx)
    state.beacon_up = true
    assert_false(holy.strategies[1].matches(ctx, state), "BeaconOfLight should not match when buff up")
end)

-- SacredShield (2): matches when sacred_shield_up falsy
test("SacredShield: matches when buff down", function()
    local state = holy.build_state(ctx)
    state.sacred_shield_up = false
    assert_true(holy.strategies[2].matches(ctx, state), "SacredShield should match when buff down")
end)

test("SacredShield: does not match when buff up", function()
    local state = holy.build_state(ctx)
    state.sacred_shield_up = true
    assert_false(holy.strategies[2].matches(ctx, state), "SacredShield should not match when buff up")
end)

-- HolyShock (3): target_hp < 80
test("HolyShock: matches when target below 80", function()
    local state = holy.build_state(ctx)
    state.target_hp = 79
    assert_true(holy.strategies[3].matches(ctx, state), "HolyShock should match when target < 80")
end)

test("HolyShock: does not match when target healthy", function()
    local state = holy.build_state(ctx)
    state.target_hp = 90
    assert_false(holy.strategies[3].matches(ctx, state), "HolyShock should not match when target >= 80")
end)

-- HolyLight (4): target_hp < 50 and mana_pct >= 30
test("HolyLight: matches when target < 50 and mana >= 30", function()
    local state = holy.build_state(ctx)
    state.target_hp = 40
    state.mana_pct = 30
    assert_true(holy.strategies[4].matches(ctx, state), "HolyLight should match with target < 50 and mana >= 30")
end)

test("HolyLight: does not match when target >= 50", function()
    local state = holy.build_state(ctx)
    state.target_hp = 60
    state.mana_pct = 100
    assert_false(holy.strategies[4].matches(ctx, state), "HolyLight should not match when target >= 50")
end)

test("HolyLight: does not match when mana < 30", function()
    local state = holy.build_state(ctx)
    state.target_hp = 40
    state.mana_pct = 20
    assert_false(holy.strategies[4].matches(ctx, state), "HolyLight should not match when mana < 30")
end)

-- FlashOfLight (5): target_hp < 70 and mana_pct >= 20
test("FlashOfLight: matches when target < 70 and mana >= 20", function()
    local state = holy.build_state(ctx)
    state.target_hp = 60
    state.mana_pct = 20
    assert_true(holy.strategies[5].matches(ctx, state), "FlashOfLight should match with target < 70 and mana >= 20")
end)

test("FlashOfLight: does not match when target >= 70", function()
    local state = holy.build_state(ctx)
    state.target_hp = 75
    state.mana_pct = 100
    assert_false(holy.strategies[5].matches(ctx, state), "FlashOfLight should not match when target >= 70")
end)

test("FlashOfLight: does not match when mana < 20", function()
    local state = holy.build_state(ctx)
    state.target_hp = 60
    state.mana_pct = 10
    assert_false(holy.strategies[5].matches(ctx, state), "FlashOfLight should not match when mana < 20")
end)

print(string.format("Tests: %d/%d passed", total_passed, total_tests))
if #failures > 0 then
    print("FAILURES:")
    for _, f in ipairs(failures) do
        print("  " .. f.label .. ": " .. tostring(f.error))
    end
    os.exit(1)
end
