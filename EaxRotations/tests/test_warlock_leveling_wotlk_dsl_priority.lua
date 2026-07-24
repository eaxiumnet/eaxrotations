-- test_warlock_leveling_wotlk_dsl_priority.lua — WotLK Warlock leveling DSL priority tests.
-- WHAT:  Validates that the 21 warlock leveling_wotlk strategies are compiled by the DSL
--        and that their match gates fire in the expected priority order.
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

-- Shared module stubs (installed before dofile of the spec).
package.loaded["shared/leveling_helpers_sylvanas"] = {
    should_interrupt = function(target) return false end,
}
package.loaded["shared/pet_manager_sylvanas"] = {
    get_pet = function(me) return nil end,
    pet_alive = function(pet) return false end,
}
package.loaded["shared/aoe_hit_volume_sylvanas"] = {
    install = function(NS) end,
}

_G.EaxRotations = {
    WarlockSpells = {
        Haunt = make_action(48181, "Haunt"),
        UnstableAffliction = make_action(30108, "UnstableAffliction"),
        Corruption = make_action(172, "Corruption"),
        CurseOfAgony = make_action(980, "CurseOfAgony"),
        Immolate = make_action(348, "Immolate"),
        DrainSoul = make_action(1120, "DrainSoul"),
        DrainLife = make_action(689, "DrainLife"),
        ShadowBolt = make_action(686, "ShadowBolt"),
        Incinerate = make_action(29722, "Incinerate"),
        ChaosBolt = make_action(50796, "ChaosBolt"),
        SoulFire = make_action(6353, "SoulFire"),
        Conflagrate = make_action(17962, "Conflagrate"),
        FelArmor = make_action(28176, "FelArmor"),
        DemonArmor = make_action(706, "DemonArmor"),
        LifeTap = make_action(1454, "LifeTap"),
        CreateHealthstone = make_action(5699, "CreateHealthstone"),
        CreateSoulstone = make_action(693, "CreateSoulstone"),
        SummonFelhunter = make_action(691, "SummonFelhunter"),
        SummonVoidwalker = make_action(697, "SummonVoidwalker"),
        SummonImp = make_action(688, "SummonImp"),
        SpellLock = make_action(19647, "SpellLock"),
        SeedOfCorruption = make_action(27243, "SeedOfCorruption"),
        RainOfFire = make_action(5740, "RainOfFire"),
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
    AOE_RADIUS = { TARGET_15 = 15, GROUND_8 = 8 },
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

print("=== test_warlock_leveling_wotlk_dsl_priority ===")

local lv = dofile("EaxRotations/classes/warlock/leveling_wotlk.lua")
assert_true(type(lv) == "table", "leveling_wotlk should return a table")
assert_true(type(lv.strategies) == "table", "leveling_wotlk should expose strategies")
assert_true(#lv.strategies == 21, "leveling_wotlk should have 21 strategies")

local registered = _G.EaxRotations._registered_leveling
assert_true(registered ~= nil and registered.name == "leveling", "leveling_wotlk should register under 'leveling'")

-- ============================================================================
-- Priority order test
-- ============================================================================
local expected_order = {
    "SpellLock",
    "SummonPet",
    "CreateSoulstone",
    "CreateHealthstone",
    "FelArmor",
    "Haunt",
    "SeedOfCorruption",
    "RainOfFire",
    "UnstableAffliction",
    "Corruption",
    "Immolate",
    "CurseOfAgony",
    "Conflagrate",
    "DrainSoul",
    "DrainLife",
    "LifeTap",
    "ChaosBolt",
    "Incinerate",
    "ShadowBolt",
    "SoulFire",
    "Shoot",
}

test("priority order: 21 strategies match expected order", function()
    for i = 1, #expected_order do
        assert_true(lv.strategies[i].name == expected_order[i],
            string.format("Strategy %d should be %s, got %s", i, expected_order[i], lv.strategies[i].name))
    end
end)

-- ============================================================================
-- Match gate tests
-- ============================================================================
local ctx = { in_combat = true, target = {}, settings = {} }

-- SpellLock (1): in_combat and target_casting and mana >= 5
test("SpellLock: matches when target casting", function()
    local state = lv.build_state(ctx)
    state.in_combat = true
    state.target_casting = true
    state.mana_pct = 5
    assert_true(lv.strategies[1].matches(ctx, state), "SpellLock should match when target casting")
end)

test("SpellLock: does not match when target not casting", function()
    local state = lv.build_state(ctx)
    state.in_combat = true
    state.target_casting = false
    state.mana_pct = 100
    assert_false(lv.strategies[1].matches(ctx, state), "SpellLock should not match when not casting")
end)

-- SummonPet (2): OOC and (not has_pet or not pet_alive) and mana >= 60
test("SummonPet: matches OOC without pet", function()
    local state = lv.build_state(ctx)
    state.in_combat = false
    state.has_pet = false
    state.pet_alive = false
    state.mana_pct = 60
    assert_true(lv.strategies[2].matches(ctx, state), "SummonPet should match OOC without pet")
end)

test("SummonPet: matches OOC when pet dead", function()
    local state = lv.build_state(ctx)
    state.in_combat = false
    state.has_pet = true
    state.pet_alive = false
    state.mana_pct = 60
    assert_true(lv.strategies[2].matches(ctx, state), "SummonPet should match when pet dead")
end)

test("SummonPet: does not match with living pet", function()
    local state = lv.build_state(ctx)
    state.in_combat = false
    state.has_pet = true
    state.pet_alive = true
    state.mana_pct = 100
    assert_false(lv.strategies[2].matches(ctx, state), "SummonPet should not match with living pet")
end)

test("SummonPet: does not match in combat", function()
    local state = lv.build_state(ctx)
    state.in_combat = true
    state.has_pet = false
    state.pet_alive = false
    state.mana_pct = 100
    assert_false(lv.strategies[2].matches(ctx, state), "SummonPet should not match in combat")
end)

-- FelArmor (5): OOC and not fel_armor_up and not demon_armor_up
test("FelArmor: matches OOC without armor", function()
    local state = lv.build_state(ctx)
    state.in_combat = false
    state.fel_armor_up = false
    state.demon_armor_up = false
    assert_true(lv.strategies[5].matches(ctx, state), "FelArmor should match OOC without armor")
end)

test("FelArmor: does not match with demon armor up", function()
    local state = lv.build_state(ctx)
    state.in_combat = false
    state.fel_armor_up = false
    state.demon_armor_up = true
    assert_false(lv.strategies[5].matches(ctx, state), "FelArmor should not match with demon armor")
end)

-- Haunt (6): in_combat and haunt_remains < 3 and mana >= 10
test("Haunt: matches when debuff expiring", function()
    local state = lv.build_state(ctx)
    state.in_combat = true
    state.haunt_remains = 0
    state.mana_pct = 10
    assert_true(lv.strategies[6].matches(ctx, state), "Haunt should match when expiring")
end)

-- SeedOfCorruption (7): in_combat and mana >= 34 and aoe gate
test("SeedOfCorruption: matches when AoE meets", function()
    local state = lv.build_state(ctx)
    state.in_combat = true
    state.mana_pct = 34
    assert_true(lv.strategies[7].matches(ctx, state), "Seed should match when AoE meets")
end)

test("SeedOfCorruption: does not match below mana", function()
    local state = lv.build_state(ctx)
    state.in_combat = true
    state.mana_pct = 20
    assert_false(lv.strategies[7].matches(ctx, state), "Seed should not match below 34 mana")
end)

-- Corruption (10): in_combat and corruption_remains < 3 and mana >= 10
test("Corruption: matches when dot expiring", function()
    local state = lv.build_state(ctx)
    state.in_combat = true
    state.corruption_remains = 0
    state.mana_pct = 10
    assert_true(lv.strategies[10].matches(ctx, state), "Corruption should match when expiring")
end)

-- Conflagrate (13): in_combat and immolate_remains > 3 and mana >= 15
test("Conflagrate: matches with immolate up", function()
    local state = lv.build_state(ctx)
    state.in_combat = true
    state.immolate_remains = 5
    state.mana_pct = 15
    assert_true(lv.strategies[13].matches(ctx, state), "Conflagrate should match with immolate up")
end)

test("Conflagrate: does not match without immolate", function()
    local state = lv.build_state(ctx)
    state.in_combat = true
    state.immolate_remains = 0
    state.mana_pct = 100
    assert_false(lv.strategies[13].matches(ctx, state), "Conflagrate should not match without immolate")
end)

-- DrainSoul (14): in_combat and target_hp < 25
test("DrainSoul: matches on low target", function()
    local state = lv.build_state(ctx)
    state.in_combat = true
    state.target_hp = 20
    assert_true(lv.strategies[14].matches(ctx, state), "DrainSoul should match on low target")
end)

test("DrainSoul: does not match on healthy target", function()
    local state = lv.build_state(ctx)
    state.in_combat = true
    state.target_hp = 80
    assert_false(lv.strategies[14].matches(ctx, state), "DrainSoul should not match on healthy target")
end)

-- LifeTap (16): in_combat and mana < 30 and hp > 40
test("LifeTap: matches when low mana and safe hp", function()
    local state = lv.build_state(ctx)
    state.in_combat = true
    state.mana_pct = 20
    state.hp = 80
    assert_true(lv.strategies[16].matches(ctx, state), "LifeTap should match when low mana safe hp")
end)

test("LifeTap: does not match when hp too low", function()
    local state = lv.build_state(ctx)
    state.in_combat = true
    state.mana_pct = 20
    state.hp = 30
    assert_false(lv.strategies[16].matches(ctx, state), "LifeTap should not match when hp too low")
end)

-- ShadowBolt (19): in_combat and mana >= 15
test("ShadowBolt: matches with mana", function()
    local state = lv.build_state(ctx)
    state.in_combat = true
    state.mana_pct = 15
    assert_true(lv.strategies[19].matches(ctx, state), "ShadowBolt should match with mana >= 15")
end)

-- Shoot (21): in_combat and mana < 10
test("Shoot: matches when OOM in combat", function()
    local state = lv.build_state(ctx)
    state.in_combat = true
    state.mana_pct = 5
    assert_true(lv.strategies[21].matches(ctx, state), "Shoot should match when OOM")
end)

test("Shoot: does not match with mana available", function()
    local state = lv.build_state(ctx)
    state.in_combat = true
    state.mana_pct = 50
    assert_false(lv.strategies[21].matches(ctx, state), "Shoot should not match with mana")
end)

print(string.format("Tests: %d/%d passed", total_passed, total_tests))
if #failures > 0 then
    print("FAILURES:")
    for _, f in ipairs(failures) do
        print("  " .. f.label .. ": " .. tostring(f.error))
    end
    os.exit(1)
end
