-- test_warrior_leveling_wotlk_dsl_priority.lua — WotLK Warrior leveling DSL priority tests.
-- WHAT:  Validates that the 12 warrior leveling_wotlk strategies are compiled by the DSL
--        and that their match gates (incl. AoE and interrupt gates) fire in order.
-- WHEN:  run_wotlk_tests.lua, run_rotation_tests.lua, run_leveling_tests.lua.
-- WHY:   Regression guard for DSL-based leveling strategy definitions.
-- SAFETY: Standalone; mocks all NS dependencies and shared modules.

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

package.loaded["shared/aoe_hit_volume_sylvanas"] = { install = function(NS) end }
package.loaded["shared/leveling_helpers_sylvanas"] = { should_interrupt = function(target) return false end }

_G.EaxRotations = {
    WarriorSpells = {
        BattleShout = make_action(6673, "BattleShout"),
        Charge = make_action(100, "Charge"),
        Rend = make_action(772, "Rend"),
        HeroicStrike = make_action(78, "HeroicStrike"),
        Overpower = make_action(7384, "Overpower"),
        Execute = make_action(5308, "Execute"),
        ThunderClap = make_action(6343, "ThunderClap"),
        VictoryRush = make_action(34428, "VictoryRush"),
        Pummel = make_action(6552, "Pummel"),
        BattleStance = make_action(2457, "BattleStance"),
        Whirlwind = make_action(1680, "Whirlwind"),
        Cleave = make_action(845, "Cleave"),
    },
    GetPlayer = function() return {
        get_health_percentage = function() return 100 end,
        get_rage = function() return 0 end,
    } end,
    me = {
        get_health_percentage = function() return 100 end,
        get_rage = function() return 0 end,
    },
    AOE_RADIUS = { SELF_8 = 8, TARGET_8 = 8 },
    aoe_self_meets = function(count, radius, context, state) return true end,
    aoe_target_meets = function(count, radius, target, context, state) return true end,
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
            _G.EaxRotations._registered_leveling = { name = name, strategies = strategies, options = options }
        end,
    },
}

package.loaded["shared/strategy_dsl_sylvanas"] = package.loaded["shared/strategy_dsl_sylvanas"]
    or require("shared/strategy_dsl_sylvanas")

print("=== test_warrior_leveling_wotlk_dsl_priority ===")

local lv = dofile("EaxRotations/classes/warrior/leveling_wotlk.lua")
assert_true(type(lv) == "table", "leveling_wotlk should return a table")
assert_true(type(lv.strategies) == "table", "leveling_wotlk should expose strategies")
assert_true(#lv.strategies == 12, "leveling_wotlk should have 12 strategies")

local registered = _G.EaxRotations._registered_leveling
assert_true(registered ~= nil and registered.name == "leveling", "leveling_wotlk should register under 'leveling'")

-- ============================================================================
-- Priority order test
-- ============================================================================
local expected_order = {
    "Pummel",
    "BattleStance",
    "BattleShout",
    "Charge",
    "VictoryRush",
    "Execute",
    "Overpower",
    "ThunderClap",
    "Whirlwind",
    "Cleave",
    "Rend",
    "HeroicStrike",
}

test("priority order: 12 strategies match expected order", function()
    for i = 1, #expected_order do
        assert_true(lv.strategies[i].name == expected_order[i],
            string.format("Strategy %d should be %s, got %s", i, expected_order[i], lv.strategies[i].name))
    end
end)

-- ============================================================================
-- Match gate tests
-- ============================================================================
local ctx = { in_combat = true, target = {}, settings = {} }

-- Pummel (1): in_combat and target_casting == true and rage >= 10
test("Pummel: matches when target casting with rage", function()
    local state = lv.build_state(ctx)
    state.in_combat = true
    state.target_casting = true
    state.rage = 10
    assert_true(lv.strategies[1].matches(ctx, state), "Pummel should match when target casting")
end)

test("Pummel: does not match when not casting", function()
    local state = lv.build_state(ctx)
    state.in_combat = true
    state.target_casting = false
    state.rage = 100
    assert_false(lv.strategies[1].matches(ctx, state), "Pummel should not match when not casting")
end)

-- BattleStance (2): not in_combat and not battle_stance_up
test("BattleStance: matches OOC without stance", function()
    local state = lv.build_state(ctx)
    state.in_combat = false
    state.battle_stance_up = false
    assert_true(lv.strategies[2].matches(ctx, state), "BattleStance should match OOC without stance")
end)

-- BattleShout (3): not in_combat and not battle_shout_up
test("BattleShout: matches OOC without shout", function()
    local state = lv.build_state(ctx)
    state.in_combat = false
    state.battle_shout_up = false
    assert_true(lv.strategies[3].matches(ctx, state), "BattleShout should match OOC without shout")
end)

-- Charge (4): not in_combat
test("Charge: matches OOC", function()
    local state = lv.build_state(ctx)
    state.in_combat = false
    assert_true(lv.strategies[4].matches(ctx, state), "Charge should match OOC")
end)

-- Execute (6): in_combat and target_hp < 20 and rage >= 10
test("Execute: matches on low target with rage", function()
    local state = lv.build_state(ctx)
    state.in_combat = true
    state.target_hp = 15
    state.rage = 10
    assert_true(lv.strategies[6].matches(ctx, state), "Execute should match on low target")
end)

test("Execute: does not match on healthy target", function()
    local state = lv.build_state(ctx)
    state.in_combat = true
    state.target_hp = 80
    state.rage = 100
    assert_false(lv.strategies[6].matches(ctx, state), "Execute should not match on healthy target")
end)

-- ThunderClap (8): in_combat and rage >= 20 and aoe gate
test("ThunderClap: matches when AoE meets", function()
    local state = lv.build_state(ctx)
    state.in_combat = true
    state.rage = 20
    assert_true(lv.strategies[8].matches(ctx, state), "ThunderClap should match when AoE meets")
end)

test("ThunderClap: does not match below rage", function()
    local state = lv.build_state(ctx)
    state.in_combat = true
    state.rage = 10
    assert_false(lv.strategies[8].matches(ctx, state), "ThunderClap should not match below 20 rage")
end)

-- Whirlwind (9): in_combat and rage >= 25 and aoe gate
test("Whirlwind: matches when AoE meets", function()
    local state = lv.build_state(ctx)
    state.in_combat = true
    state.rage = 25
    assert_true(lv.strategies[9].matches(ctx, state), "Whirlwind should match when AoE meets")
end)

-- Cleave (10): in_combat and rage >= 20 and aoe gate
test("Cleave: matches when AoE meets", function()
    local state = lv.build_state(ctx)
    state.in_combat = true
    state.rage = 20
    assert_true(lv.strategies[10].matches(ctx, state), "Cleave should match when AoE meets")
end)

-- Rend (11): in_combat and rend_remains < 3
test("Rend: matches when dot missing", function()
    local state = lv.build_state(ctx)
    state.in_combat = true
    state.rend_remains = 0
    assert_true(lv.strategies[11].matches(ctx, state), "Rend should match when dot missing")
end)

-- HeroicStrike (12): in_combat and rage >= 30
test("HeroicStrike: matches with high rage", function()
    local state = lv.build_state(ctx)
    state.in_combat = true
    state.rage = 30
    assert_true(lv.strategies[12].matches(ctx, state), "HeroicStrike should match with rage >= 30")
end)

test("HeroicStrike: does not match out of combat", function()
    local state = lv.build_state(ctx)
    state.in_combat = false
    state.rage = 100
    assert_false(lv.strategies[12].matches(ctx, state), "HeroicStrike should not match OOC")
end)

print(string.format("Tests: %d/%d passed", total_passed, total_tests))
if #failures > 0 then
    print("FAILURES:")
    for _, f in ipairs(failures) do
        print("  " .. f.label .. ": " .. tostring(f.error))
    end
    os.exit(1)
end
