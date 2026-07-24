-- test_mage_leveling_wotlk_dsl_priority.lua — WotLK Mage leveling DSL priority tests.
-- WHAT:  Validates that the 24 mage leveling_wotlk strategies are compiled by the DSL
--        and that their match gates (incl. AoE and pet gates) fire in the expected order.
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
package.loaded["shared/pet_manager_sylvanas"] = {
    get_pet = function(me) return nil end,
    pet_alive = function(pet) return false end,
}

_G.EaxRotations = {
    MageSpells = {
        ArcaneMissiles = make_action(5143, "ArcaneMissiles"),
        ArcaneBarrage = make_action(44425, "ArcaneBarrage"),
        Fireball = make_action(133, "Fireball"),
        Pyroblast = make_action(11366, "Pyroblast"),
        FireBlast = make_action(2136, "FireBlast"),
        LivingBomb = make_action(44457, "LivingBomb"),
        Scorch = make_action(2948, "Scorch"),
        Frostbolt = make_action(116, "Frostbolt"),
        IceLance = make_action(30455, "IceLance"),
        FrostfireBolt = make_action(44614, "FrostfireBolt"),
        DeepFreeze = make_action(44572, "DeepFreeze"),
        ConeOfCold = make_action(120, "ConeOfCold"),
        Blink = make_action(1953, "Blink"),
        IceBarrier = make_action(11426, "IceBarrier"),
        ManaShield = make_action(1463, "ManaShield"),
        Evocation = make_action(12051, "Evocation"),
        ConjureManaGem = make_action(759, "ConjureManaGem"),
        Counterspell = make_action(2139, "Counterspell"),
        ArcaneIntellect = make_action(1459, "ArcaneIntellect"),
        MageArmor = make_action(6117, "MageArmor"),
        ArcaneExplosion = make_action(1449, "ArcaneExplosion"),
        SummonWaterElemental = make_action(31687, "SummonWaterElemental"),
        Blizzard = make_action(10, "Blizzard"),
        Shoot = make_action(5019, "Shoot"),
    },
    GetPlayer = function() return {
        get_health_percentage = function() return 100 end,
        get_mana_percentage = function() return 100 end,
    } end,
    me = {
        get_health_percentage = function() return 100 end,
        get_mana_percentage = function() return 100 end,
    },
    AOE_RADIUS = { SELF_10 = 10, GROUND_8 = 8 },
    aoe_self_meets = function(count, radius, context, state) return true end,
    aoe_target_meets = function(count, radius, target, context, state) return true end,
    aoe_cone_meets = function(count, radius, facing, context, state) return true end,
    should_use_long_cd = function(context, cd) return true end,
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

print("=== test_mage_leveling_wotlk_dsl_priority ===")

local lv = dofile("EaxRotations/classes/mage/leveling_wotlk.lua")
assert_true(type(lv) == "table", "leveling_wotlk should return a table")
assert_true(type(lv.strategies) == "table", "leveling_wotlk should expose strategies")
assert_true(#lv.strategies == 24, "leveling_wotlk should have 24 strategies")

local registered = _G.EaxRotations._registered_leveling
assert_true(registered ~= nil and registered.name == "leveling", "leveling_wotlk should register under 'leveling'")

-- ============================================================================
-- Priority order test
-- ============================================================================
local expected_order = {
    "Counterspell",
    "ArcaneIntellect",
    "MageArmor",
    "IceBarrier",
    "ManaShield",
    "Evocation",
    "Blink",
    "ConjureManaGem",
    "ConeOfCold",
    "ArcaneExplosion",
    "Blizzard",
    "SummonWaterElemental",
    "LivingBomb",
    "Pyroblast",
    "Fireball",
    "Frostbolt",
    "FrostfireBolt",
    "ArcaneBarrage",
    "ArcaneMissiles",
    "FireBlast",
    "Scorch",
    "IceLance",
    "DeepFreeze",
    "Shoot",
}

test("priority order: 24 strategies match expected order", function()
    for i = 1, #expected_order do
        assert_true(lv.strategies[i].name == expected_order[i],
            string.format("Strategy %d should be %s, got %s", i, expected_order[i], lv.strategies[i].name))
    end
end)

-- ============================================================================
-- Match gate tests
-- ============================================================================
local ctx = { in_combat = true, target = {}, settings = {} }

-- Counterspell (1): in_combat and target_casting == true
test("Counterspell: matches when target casting", function()
    local state = lv.build_state(ctx)
    state.in_combat = true
    state.target_casting = true
    assert_true(lv.strategies[1].matches(ctx, state), "Counterspell should match when target casting")
end)

test("Counterspell: does not match when target not casting", function()
    local state = lv.build_state(ctx)
    state.in_combat = true
    state.target_casting = false
    assert_false(lv.strategies[1].matches(ctx, state), "Counterspell should not match when not casting")
end)

-- ArcaneIntellect (2): not arcane_intellect_up and mana >= 20
test("ArcaneIntellect: matches without buff", function()
    local state = lv.build_state(ctx)
    state.arcane_intellect_up = false
    state.mana_pct = 20
    assert_true(lv.strategies[2].matches(ctx, state), "AI should match without buff")
end)

-- IceBarrier (4): in_combat and hp < 50 and not ice_barrier_up
test("IceBarrier: matches on low hp without shield", function()
    local state = lv.build_state(ctx)
    state.in_combat = true
    state.hp = 40
    state.ice_barrier_up = false
    assert_true(lv.strategies[4].matches(ctx, state), "IceBarrier should match on low hp")
end)

test("IceBarrier: does not match at full hp", function()
    local state = lv.build_state(ctx)
    state.in_combat = true
    state.hp = 100
    state.ice_barrier_up = false
    assert_false(lv.strategies[4].matches(ctx, state), "IceBarrier should not match at full hp")
end)

-- Evocation (6): in_combat and mana < 20
test("Evocation: matches when low mana", function()
    local state = lv.build_state(ctx)
    state.in_combat = true
    state.mana_pct = 10
    assert_true(lv.strategies[6].matches(ctx, state), "Evocation should match when low mana")
end)

-- ConjureManaGem (8): not in_combat and mana < 80
test("ConjureManaGem: matches OOC below 80 mana", function()
    local state = lv.build_state(ctx)
    state.in_combat = false
    state.mana_pct = 50
    assert_true(lv.strategies[8].matches(ctx, state), "ConjureManaGem should match OOC below 80 mana")
end)

-- ConeOfCold (9): in_combat and cone gate
test("ConeOfCold: matches when cone meets", function()
    local state = lv.build_state(ctx)
    state.in_combat = true
    assert_true(lv.strategies[9].matches(ctx, state), "ConeOfCold should match when cone meets")
end)

-- ArcaneExplosion (10): in_combat and mana >= 15 and aoe gate
test("ArcaneExplosion: matches when AoE meets", function()
    local state = lv.build_state(ctx)
    state.in_combat = true
    state.mana_pct = 15
    assert_true(lv.strategies[10].matches(ctx, state), "ArcaneExplosion should match when AoE meets")
end)

test("ArcaneExplosion: does not match below mana", function()
    local state = lv.build_state(ctx)
    state.in_combat = true
    state.mana_pct = 10
    assert_false(lv.strategies[10].matches(ctx, state), "ArcaneExplosion should not match below 15 mana")
end)

-- Blizzard (11): in_combat and mana >= 25 and aoe gate
test("Blizzard: matches when AoE meets", function()
    local state = lv.build_state(ctx)
    state.in_combat = true
    state.mana_pct = 25
    assert_true(lv.strategies[11].matches(ctx, state), "Blizzard should match when AoE meets")
end)

-- SummonWaterElemental (12): in_combat, not pet_alive, mana >= 16, long cd ok
test("SummonWaterElemental: matches without pet", function()
    local state = lv.build_state(ctx)
    state.in_combat = true
    state.pet_alive = false
    state.mana_pct = 16
    assert_true(lv.strategies[12].matches(ctx, state), "SWE should match without pet")
end)

test("SummonWaterElemental: does not match with pet alive", function()
    local state = lv.build_state(ctx)
    state.in_combat = true
    state.pet_alive = true
    state.mana_pct = 100
    assert_false(lv.strategies[12].matches(ctx, state), "SWE should not match with pet alive")
end)

-- LivingBomb (13): in_combat and living_bomb_remains < 3 and mana >= 15
test("LivingBomb: matches when dot missing", function()
    local state = lv.build_state(ctx)
    state.in_combat = true
    state.living_bomb_remains = 0
    state.mana_pct = 15
    assert_true(lv.strategies[13].matches(ctx, state), "LivingBomb should match when dot missing")
end)

-- Fireball (15): in_combat and mana >= 15
test("Fireball: matches as filler", function()
    local state = lv.build_state(ctx)
    state.in_combat = true
    state.mana_pct = 15
    assert_true(lv.strategies[15].matches(ctx, state), "Fireball should match with mana >= 15")
end)

-- Shoot (24): in_combat and mana < 10
test("Shoot: matches when OOM", function()
    local state = lv.build_state(ctx)
    state.in_combat = true
    state.mana_pct = 5
    assert_true(lv.strategies[24].matches(ctx, state), "Shoot should match when OOM")
end)

test("Shoot: does not match with mana", function()
    local state = lv.build_state(ctx)
    state.in_combat = true
    state.mana_pct = 50
    assert_false(lv.strategies[24].matches(ctx, state), "Shoot should not match with mana")
end)

print(string.format("Tests: %d/%d passed", total_passed, total_tests))
if #failures > 0 then
    print("FAILURES:")
    for _, f in ipairs(failures) do
        print("  " .. f.label .. ": " .. tostring(f.error))
    end
    os.exit(1)
end
