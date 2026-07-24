-- test_rogue_leveling_wotlk_dsl_priority.lua — WotLK Rogue leveling DSL priority tests.
-- WHAT:  Validates that the 9 rogue leveling_wotlk strategies are compiled by the DSL
--        and that their match gates fire in the expected priority order.
-- WHEN:  run_wotlk_tests.lua and run_rotation_tests.lua.
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

local aoe_ok = true  -- toggled by tests

_G.EaxRotations = {
    RogueSpells = {
        SliceAndDice = make_action({ 6774, 5171 }, "SliceAndDice"),
        SinisterStrike = make_action(1752, "SinisterStrike"),
        Eviscerate = make_action(2098, "Eviscerate"),
        Rupture = make_action(48672, "Rupture"),
        FanOfKnives = make_action(51723, "FanOfKnives"),
        Gouge = make_action(1776, "Gouge"),
        Kick = make_action(1766, "Kick"),
        Stealth = make_action(1784, "Stealth"),
        Ambush = make_action(8676, "Ambush"),
    },
    GetPlayer = function() return {
        get_health_percentage = function() return 100 end,
        get_energy = function() return 100 end,
        get_combo_points = function() return 0 end,
    } end,
    me = {
        get_health_percentage = function() return 100 end,
        get_energy = function() return 100 end,
        get_combo_points = function() return 0 end,
    },
    AOE_RADIUS = { SELF_8 = 8 },
    aoe_self_meets = function(n, radius, context, state) return aoe_ok end,
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

package.loaded["shared/leveling_helpers_sylvanas"] = { should_interrupt = function(target) return false end }
package.loaded["shared/aoe_hit_volume_sylvanas"] = { install = function(ns) end }
package.loaded["shared/potion_helper_sylvanas"] =
    { try_use_potion = function() return false end, HEALTH_POTION_IDS = {}, DAMAGE_POTION_IDS = {} }
package.loaded["shared/strategy_dsl_sylvanas"] = package.loaded["shared/strategy_dsl_sylvanas"]
    or require("shared/strategy_dsl_sylvanas")

print("=== test_rogue_leveling_wotlk_dsl_priority ===")

local lv = dofile("EaxRotations/classes/rogue/leveling_wotlk.lua")
assert_true(type(lv) == "table", "leveling_wotlk should return a table")
assert_true(type(lv.strategies) == "table", "leveling_wotlk should expose strategies")
assert_true(#lv.strategies == 9, "leveling_wotlk should have 9 strategies")

local registered = _G.EaxRotations._registered_leveling
assert_true(registered ~= nil and registered.name == "leveling", "leveling_wotlk should register under 'leveling'")

-- ============================================================================
-- Priority order test
-- ============================================================================
local expected_order = {
    "Stealth",
    "Ambush",
    "Kick",
    "SliceAndDice",
    "FanOfKnives",
    "Rupture",
    "Gouge",
    "Eviscerate",
    "SinisterStrike",
}

test("priority order: 9 strategies match expected order", function()
    for i = 1, #expected_order do
        assert_true(lv.strategies[i].name == expected_order[i],
            string.format("Strategy %d should be %s, got %s", i, expected_order[i], lv.strategies[i].name))
    end
end)

-- ============================================================================
-- Match gate tests
-- ============================================================================
local ctx = { in_combat = true, target = {}, settings = {} }

-- Stealth (1): not in_combat and not stealth_active
test("Stealth: matches when OOC and not stealthed", function()
    local state = lv.build_state(ctx)
    state.in_combat = false
    state.stealth_active = false
    assert_true(lv.strategies[1].matches(ctx, state), "Stealth should match OOC")
end)

test("Stealth: does not match in combat", function()
    local state = lv.build_state(ctx)
    state.in_combat = true
    state.stealth_active = false
    assert_false(lv.strategies[1].matches(ctx, state), "Stealth should not match in combat")
end)

test("Stealth: does not match if already stealthed", function()
    local state = lv.build_state(ctx)
    state.in_combat = false
    state.stealth_active = true
    assert_false(lv.strategies[1].matches(ctx, state), "Stealth should not match when already stealthed")
end)

-- Ambush (2): stealth_active and energy >= 60
test("Ambush: matches when stealthed with energy", function()
    local state = lv.build_state(ctx)
    state.stealth_active = true
    state.energy = 60
    assert_true(lv.strategies[2].matches(ctx, state), "Ambush should match when stealthed with energy >= 60")
end)

test("Ambush: does not match when not stealthed", function()
    local state = lv.build_state(ctx)
    state.stealth_active = false
    state.energy = 100
    assert_false(lv.strategies[2].matches(ctx, state), "Ambush should not match when not stealthed")
end)

-- Kick (3): in_combat and target_casting == true and energy >= 25
test("Kick: matches when target casting with energy", function()
    local state = lv.build_state(ctx)
    state.in_combat = true
    state.target_casting = true
    state.energy = 25
    assert_true(lv.strategies[3].matches(ctx, state), "Kick should match when target casting")
end)

test("Kick: does not match when target not casting", function()
    local state = lv.build_state(ctx)
    state.in_combat = true
    state.target_casting = false
    state.energy = 100
    assert_false(lv.strategies[3].matches(ctx, state), "Kick should not match when target not casting")
end)

-- SliceAndDice (4): in_combat and snd_remains < 3 and combo_points >= 1
test("SliceAndDice: matches when buff expiring with combo", function()
    local state = lv.build_state(ctx)
    state.in_combat = true
    state.snd_remains = 1
    state.combo_points = 1
    assert_true(lv.strategies[4].matches(ctx, state), "SliceAndDice should match with combo and expiring buff")
end)

test("SliceAndDice: does not match with 0 combo", function()
    local state = lv.build_state(ctx)
    state.in_combat = true
    state.snd_remains = 1
    state.combo_points = 0
    assert_false(lv.strategies[4].matches(ctx, state), "SliceAndDice should not match with 0 combo")
end)

-- FanOfKnives (5): in_combat and energy >= 50 and aoe_self_meets
test("FanOfKnives: matches when AoE gate met", function()
    aoe_ok = true
    local state = lv.build_state(ctx)
    state.in_combat = true
    state.energy = 50
    assert_true(lv.strategies[5].matches(ctx, state), "FanOfKnives should match when AoE gate met")
end)

test("FanOfKnives: does not match when AoE gate not met", function()
    aoe_ok = false
    local state = lv.build_state(ctx)
    state.in_combat = true
    state.energy = 100
    assert_false(lv.strategies[5].matches(ctx, state), "FanOfKnives should not match when AoE gate fails")
    aoe_ok = true
end)

test("FanOfKnives: does not match with low energy", function()
    aoe_ok = true
    local state = lv.build_state(ctx)
    state.in_combat = true
    state.energy = 40
    assert_false(lv.strategies[5].matches(ctx, state), "FanOfKnives should not match with energy < 50")
end)

-- Rupture (6): in_combat and combo >= 4 and rupture_remains < 3 and target_hp > 25
test("Rupture: matches with combo, expiring bleed, healthy target", function()
    local state = lv.build_state(ctx)
    state.in_combat = true
    state.combo_points = 4
    state.rupture_remains = 0
    state.target_hp = 80
    assert_true(lv.strategies[6].matches(ctx, state), "Rupture should match")
end)

test("Rupture: does not match on low-HP target", function()
    local state = lv.build_state(ctx)
    state.in_combat = true
    state.combo_points = 5
    state.rupture_remains = 0
    state.target_hp = 20
    assert_false(lv.strategies[6].matches(ctx, state), "Rupture should not match on execute-range target")
end)

-- Gouge (7): in_combat and energy >= 45
test("Gouge: matches with energy", function()
    local state = lv.build_state(ctx)
    state.in_combat = true
    state.energy = 45
    assert_true(lv.strategies[7].matches(ctx, state), "Gouge should match with energy >= 45")
end)

-- Eviscerate (8): in_combat and combo >= 4
test("Eviscerate: matches with combo >= 4", function()
    local state = lv.build_state(ctx)
    state.in_combat = true
    state.combo_points = 4
    assert_true(lv.strategies[8].matches(ctx, state), "Eviscerate should match with combo >= 4")
end)

test("Eviscerate: does not match with combo < 4", function()
    local state = lv.build_state(ctx)
    state.in_combat = true
    state.combo_points = 3
    assert_false(lv.strategies[8].matches(ctx, state), "Eviscerate should not match with combo < 4")
end)

-- SinisterStrike (9): in_combat and energy >= 45
test("SinisterStrike: matches with energy", function()
    local state = lv.build_state(ctx)
    state.in_combat = true
    state.energy = 45
    assert_true(lv.strategies[9].matches(ctx, state), "SinisterStrike should match with energy >= 45")
end)

test("SinisterStrike: does not match with low energy", function()
    local state = lv.build_state(ctx)
    state.in_combat = true
    state.energy = 30
    assert_false(lv.strategies[9].matches(ctx, state), "SinisterStrike should not match with energy < 45")
end)

print(string.format("Tests: %d/%d passed", total_passed, total_tests))
if #failures > 0 then
    print("FAILURES:")
    for _, f in ipairs(failures) do
        print("  " .. f.label .. ": " .. tostring(f.error))
    end
    os.exit(1)
end
