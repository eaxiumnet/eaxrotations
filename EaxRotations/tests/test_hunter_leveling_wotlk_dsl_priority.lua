-- test_hunter_leveling_wotlk_dsl_priority.lua — WotLK Hunter leveling DSL priority tests.
-- WHAT:  Validates that the 14 hunter leveling_wotlk strategies are compiled by the DSL
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

local aoe_ok = true  -- toggled by tests

_G.EaxRotations = {
    HunterSpells = {
        HuntersMark = make_action(1130, "HuntersMark"),
        SerpentSting = make_action(1978, "SerpentSting"),
        SteadyShot = make_action(34120, "SteadyShot"),
        ArcaneShot = make_action(3044, "ArcaneShot"),
        KillCommand = make_action(34026, "KillCommand"),
        BestialWrath = make_action(19574, "BestialWrath"),
        SilencingShot = make_action(34490, "SilencingShot"),
        AspectOfTheDragonhawk = make_action(61847, "AspectOfTheDragonhawk"),
        AspectOfTheHawk = make_action(13165, "AspectOfTheHawk"),
        AspectOfTheViper = make_action(34074, "AspectOfTheViper"),
        CallPet = make_action(883, "CallPet"),
        RevivePet = make_action(982, "RevivePet"),
        MendPet = make_action(3111, "MendPet"),
        MultiShot = make_action(2643, "MultiShot"),
        Volley = make_action(1543, "Volley"),
    },
    GetPlayer = function() return {
        get_health_percentage = function() return 100 end,
        get_mana_percentage = function() return 100 end,
    } end,
    me = {
        get_health_percentage = function() return 100 end,
        get_mana_percentage = function() return 100 end,
    },
    AOE_RADIUS = { TARGET_8 = 8, GROUND_8 = 8 },
    aoe_target_meets = function(n, radius, target, context, state) return aoe_ok end,
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
package.loaded["shared/pet_manager_sylvanas"] = {
    get_pet = function(me) return nil end,
    pet_alive = function(pet) return false end,
    pet_hp_pct = function(pet) return 100 end,
}
package.loaded["shared/strategy_dsl_sylvanas"] = package.loaded["shared/strategy_dsl_sylvanas"]
    or require("shared/strategy_dsl_sylvanas")

print("=== test_hunter_leveling_wotlk_dsl_priority ===")

local lv = dofile("EaxRotations/classes/hunter/leveling_wotlk.lua")
assert_true(type(lv) == "table", "leveling_wotlk should return a table")
assert_true(type(lv.strategies) == "table", "leveling_wotlk should expose strategies")
assert_true(#lv.strategies == 14, "leveling_wotlk should have 14 strategies")

local registered = _G.EaxRotations._registered_leveling
assert_true(registered ~= nil and registered.name == "leveling", "leveling_wotlk should register under 'leveling'")

-- ============================================================================
-- Priority order test
-- ============================================================================
local expected_order = {
    "SilencingShot",
    "AspectOfTheViper",
    "DpsAspect",
    "CallPet",
    "RevivePet",
    "MendPet",
    "HuntersMark",
    "Volley",
    "MultiShot",
    "BestialWrath",
    "KillCommand",
    "SerpentSting",
    "ArcaneShot",
    "SteadyShot",
}

test("priority order: 14 strategies match expected order", function()
    for i = 1, #expected_order do
        assert_true(lv.strategies[i].name == expected_order[i],
            string.format("Strategy %d should be %s, got %s", i, expected_order[i], lv.strategies[i].name))
    end
end)

-- ============================================================================
-- Match gate tests
-- ============================================================================
local ctx = { in_combat = true, target = {}, settings = {} }

-- SilencingShot (1): in_combat and target_casting and mana >= 6
test("SilencingShot: matches when target casting with mana", function()
    local state = lv.build_state(ctx)
    state.in_combat = true
    state.target_casting = true
    state.mana_pct = 6
    assert_true(lv.strategies[1].matches(ctx, state), "SilencingShot should match when target casting")
end)

test("SilencingShot: does not match when target not casting", function()
    local state = lv.build_state(ctx)
    state.in_combat = true
    state.target_casting = false
    state.mana_pct = 100
    assert_false(lv.strategies[1].matches(ctx, state), "SilencingShot should not match when target not casting")
end)

-- AspectOfTheViper (2): not viper_up and mana < 20
test("AspectOfTheViper: matches when low mana and not in viper", function()
    local state = lv.build_state(ctx)
    state.viper_up = false
    state.mana_pct = 10
    assert_true(lv.strategies[2].matches(ctx, state), "Viper should match when low mana")
end)

test("AspectOfTheViper: does not match when already in viper", function()
    local state = lv.build_state(ctx)
    state.viper_up = true
    state.mana_pct = 5
    assert_false(lv.strategies[2].matches(ctx, state), "Viper should not match when already active")
end)

-- DpsAspect (3): not dps_aspect_up and mana >= 40
test("DpsAspect: matches when mana recovered and no dps aspect", function()
    local state = lv.build_state(ctx)
    state.dps_aspect_up = false
    state.mana_pct = 40
    assert_true(lv.strategies[3].matches(ctx, state), "DpsAspect should match when mana >= 40")
end)

test("DpsAspect: does not match below hysteresis mana", function()
    local state = lv.build_state(ctx)
    state.dps_aspect_up = false
    state.mana_pct = 39
    assert_false(lv.strategies[3].matches(ctx, state), "DpsAspect should not match below 40 mana")
end)

-- CallPet (4): not in_combat and not has_pet
test("CallPet: matches OOC without pet", function()
    local state = lv.build_state(ctx)
    state.in_combat = false
    state.has_pet = false
    assert_true(lv.strategies[4].matches(ctx, state), "CallPet should match OOC with no pet")
end)

test("CallPet: does not match with pet present", function()
    local state = lv.build_state(ctx)
    state.in_combat = false
    state.has_pet = true
    assert_false(lv.strategies[4].matches(ctx, state), "CallPet should not match with pet")
end)

-- RevivePet (5): not in_combat and has_pet and not pet_alive
test("RevivePet: matches OOC with dead pet", function()
    local state = lv.build_state(ctx)
    state.in_combat = false
    state.has_pet = true
    state.pet_alive = false
    assert_true(lv.strategies[5].matches(ctx, state), "RevivePet should match with dead pet OOC")
end)

test("RevivePet: does not match when pet alive", function()
    local state = lv.build_state(ctx)
    state.in_combat = false
    state.has_pet = true
    state.pet_alive = true
    assert_false(lv.strategies[5].matches(ctx, state), "RevivePet should not match when pet alive")
end)

-- MendPet (6): pet_alive and pet_hp < 80 and mana >= 10
test("MendPet: matches when pet hurt", function()
    local state = lv.build_state(ctx)
    state.pet_alive = true
    state.pet_hp = 50
    state.mana_pct = 10
    assert_true(lv.strategies[6].matches(ctx, state), "MendPet should match when pet hurt")
end)

test("MendPet: does not match when pet healthy", function()
    local state = lv.build_state(ctx)
    state.pet_alive = true
    state.pet_hp = 90
    state.mana_pct = 100
    assert_false(lv.strategies[6].matches(ctx, state), "MendPet should not match when pet healthy")
end)

-- HuntersMark (7): in_combat and mark_remains < 3 and mana >= 10
test("HuntersMark: matches when mark expiring", function()
    local state = lv.build_state(ctx)
    state.in_combat = true
    state.mark_remains = 0
    state.mana_pct = 10
    assert_true(lv.strategies[7].matches(ctx, state), "HuntersMark should match when expiring")
end)

-- Volley (8): in_combat and mana >= 17 and aoe gate
test("Volley: matches when AoE gate met", function()
    aoe_ok = true
    local state = lv.build_state(ctx)
    state.in_combat = true
    state.mana_pct = 17
    assert_true(lv.strategies[8].matches(ctx, state), "Volley should match when AoE gate met")
end)

test("Volley: does not match when AoE gate fails", function()
    aoe_ok = false
    local state = lv.build_state(ctx)
    state.in_combat = true
    state.mana_pct = 100
    assert_false(lv.strategies[8].matches(ctx, state), "Volley should not match when AoE gate fails")
    aoe_ok = true
end)

-- MultiShot (9): in_combat and mana >= 9 and aoe gate
test("MultiShot: matches when AoE gate met", function()
    aoe_ok = true
    local state = lv.build_state(ctx)
    state.in_combat = true
    state.mana_pct = 9
    assert_true(lv.strategies[9].matches(ctx, state), "MultiShot should match when AoE gate met")
end)

test("MultiShot: does not match when AoE gate fails", function()
    aoe_ok = false
    local state = lv.build_state(ctx)
    state.in_combat = true
    state.mana_pct = 100
    assert_false(lv.strategies[9].matches(ctx, state), "MultiShot should not match when AoE gate fails")
    aoe_ok = true
end)

-- BestialWrath (10): in_combat and bestial_wrath_ready
test("BestialWrath: matches when ready", function()
    local state = lv.build_state(ctx)
    state.in_combat = true
    state.bestial_wrath_ready = true
    assert_true(lv.strategies[10].matches(ctx, state), "BestialWrath should match when ready")
end)

test("BestialWrath: does not match on cooldown", function()
    local state = lv.build_state(ctx)
    state.in_combat = true
    state.bestial_wrath_ready = false
    assert_false(lv.strategies[10].matches(ctx, state), "BestialWrath should not match on cooldown")
end)

-- KillCommand (11): in_combat and mana >= 15
test("KillCommand: matches with mana", function()
    local state = lv.build_state(ctx)
    state.in_combat = true
    state.mana_pct = 15
    assert_true(lv.strategies[11].matches(ctx, state), "KillCommand should match with mana >= 15")
end)

-- SerpentSting (12): in_combat and serpent_remains < 3 and mana >= 15
test("SerpentSting: matches when sting expiring", function()
    local state = lv.build_state(ctx)
    state.in_combat = true
    state.serpent_remains = 0
    state.mana_pct = 15
    assert_true(lv.strategies[12].matches(ctx, state), "SerpentSting should match when expiring")
end)

test("SerpentSting: does not match with low mana", function()
    local state = lv.build_state(ctx)
    state.in_combat = true
    state.serpent_remains = 0
    state.mana_pct = 14
    assert_false(lv.strategies[12].matches(ctx, state), "SerpentSting should not match below 15 mana")
end)

-- ArcaneShot (13): in_combat and mana >= 20
test("ArcaneShot: matches with mana", function()
    local state = lv.build_state(ctx)
    state.in_combat = true
    state.mana_pct = 20
    assert_true(lv.strategies[13].matches(ctx, state), "ArcaneShot should match with mana >= 20")
end)

-- SteadyShot (14): in_combat and mana >= 10
test("SteadyShot: matches with mana", function()
    local state = lv.build_state(ctx)
    state.in_combat = true
    state.mana_pct = 10
    assert_true(lv.strategies[14].matches(ctx, state), "SteadyShot should match with mana >= 10")
end)

test("SteadyShot: does not match with low mana", function()
    local state = lv.build_state(ctx)
    state.in_combat = true
    state.mana_pct = 9
    assert_false(lv.strategies[14].matches(ctx, state), "SteadyShot should not match below 10 mana")
end)

print(string.format("Tests: %d/%d passed", total_passed, total_tests))
if #failures > 0 then
    print("FAILURES:")
    for _, f in ipairs(failures) do
        print("  " .. f.label .. ": " .. tostring(f.error))
    end
    os.exit(1)
end
