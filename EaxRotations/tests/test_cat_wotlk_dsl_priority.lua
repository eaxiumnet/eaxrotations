-- test_cat_wotlk_dsl_priority.lua — WotLK Feral Cat druid DSL priority order tests.
-- WHAT:  Validates that the 8 cat_wotlk strategies are compiled correctly by the DSL
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
        FaerieFireFeral = make_action(27011, "FaerieFireFeral"),
        Ravage = make_action(27005, "Ravage"),
        MangleCat = make_action(33983, "MangleCat"),
        Rake = make_action(27003, "Rake"),
        Rip = make_action(27008, "Rip"),
        SavageRoar = make_action(52610, "SavageRoar"),
        FerociousBite = make_action(24248, "FerociousBite"),
        Shred = make_action(27002, "Shred"),
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
    is_behind_target = function() return false end,
    is_item_ready = function() return false end,
    use_item_by_id = function() return true end,
    broken_api_throttled = function() return false end,
    time_now = function() return 0 end,
    log = function() end,
    log_warning = function() end,
    rotation_registry = {
        register = function(self, name, strategies, options)
            _G.EaxRotations._registered_cat = { strategies = strategies, options = options }
        end,
    },
}

package.loaded["shared/potion_helper_sylvanas"] =
    { try_use_potion = function() return false end, HEALTH_POTION_IDS = {}, DAMAGE_POTION_IDS = {} }
package.loaded["shared/strategy_dsl_sylvanas"] = package.loaded["shared/strategy_dsl_sylvanas"]
    or require("shared/strategy_dsl_sylvanas")

print("=== test_cat_wotlk_dsl_priority ===")

local cat = dofile("EaxRotations/classes/druid/cat_wotlk.lua")
assert_true(type(cat) == "table", "cat_wotlk should return a table")
assert_true(type(cat.strategies) == "table", "cat_wotlk should expose strategies")
assert_true(#cat.strategies == 8, "cat_wotlk should have 8 strategies")

local registered = _G.EaxRotations._registered_cat
assert_true(registered ~= nil, "cat_wotlk should register under 'cat'")

-- ============================================================================
-- Priority order test
-- ============================================================================
local expected_order = {
    "FaerieFireFeral",
    "Ravage",
    "SavageRoar",
    "Rip",
    "Rake",
    "FerociousBite",
    "MangleCat",
    "Shred",
}

test("priority order: 8 strategies match expected order", function()
    for i = 1, #expected_order do
        assert_true(cat.strategies[i].name == expected_order[i],
            string.format("Strategy %d should be %s, got %s", i, expected_order[i], cat.strategies[i].name))
    end
end)

-- ============================================================================
-- Match gate tests
-- ============================================================================
local ctx = { in_combat = true, target = {}, settings = {} }

-- FaerieFireFeral (1): in combat and debuff remains < 3
test("FaerieFireFeral: matches when in combat and debuff < 3", function()
    local state = cat.build_state(ctx)
    state.faerie_fire_remains = 1
    assert_true(cat.strategies[1].matches(ctx, state), "FaerieFireFeral should match when debuff < 3")
end)

test("FaerieFireFeral: does not match when debuff >= 3", function()
    local state = cat.build_state(ctx)
    state.faerie_fire_remains = 5
    assert_false(cat.strategies[1].matches(ctx, state), "FaerieFireFeral should not match when debuff >= 3")
end)

test("FaerieFireFeral: does not match when out of combat", function()
    local state = cat.build_state(ctx)
    state.in_combat = false
    state.faerie_fire_remains = 1
    assert_false(cat.strategies[1].matches(ctx, state), "FaerieFireFeral should not match out of combat")
end)

-- Ravage (2): in combat, stealthed, behind, energy >= 60
test("Ravage: matches when stealthed + behind + energy >= 60", function()
    local state = cat.build_state(ctx)
    state.is_stealthed = true
    state.is_behind = true
    state.energy = 60
    assert_true(cat.strategies[2].matches(ctx, state), "Ravage should match when all gates true")
end)

test("Ravage: does not match when not stealthed", function()
    local state = cat.build_state(ctx)
    state.is_stealthed = false
    state.is_behind = true
    state.energy = 60
    assert_false(cat.strategies[2].matches(ctx, state), "Ravage should not match without stealth")
end)

-- SavageRoar (3): savage_roar_remains < 3 and combo_points >= 1
test("SavageRoar: matches when buff < 3 and combo >= 1", function()
    local state = cat.build_state(ctx)
    state.savage_roar_remains = 1
    state.combo_points = 1
    assert_true(cat.strategies[3].matches(ctx, state), "SavageRoar should match with combo >= 1 and buff < 3")
end)

test("SavageRoar: does not match with 0 combo points", function()
    local state = cat.build_state(ctx)
    state.savage_roar_remains = 1
    state.combo_points = 0
    assert_false(cat.strategies[3].matches(ctx, state), "SavageRoar should not match with 0 combo")
end)

test("Rip: matches when debuff < 3 and combo >= 5", function()
    local state = cat.build_state(ctx)
    state.rip_remains = 0
    state.combo_points = 5
    assert_true(cat.strategies[4].matches(ctx, state), "Rip should match with combo >= 5 and debuff < 3")
end)

test("Rip: does not match with combo < 5", function()
    local state = cat.build_state(ctx)
    state.rip_remains = 0
    state.combo_points = 4
    assert_false(cat.strategies[4].matches(ctx, state), "Rip should not match with combo < 5")
end)

-- Rake (5): rake_remains < 3 and energy >= 40
test("Rake: matches when debuff < 3 and energy >= 40", function()
    local state = cat.build_state(ctx)
    state.rake_remains = 0
    state.energy = 40
    assert_true(cat.strategies[5].matches(ctx, state), "Rake should match with energy >= 40 and debuff < 3")
end)

test("Rake: does not match with energy < 40", function()
    local state = cat.build_state(ctx)
    state.rake_remains = 0
    state.energy = 30
    assert_false(cat.strategies[5].matches(ctx, state), "Rake should not match with energy < 40")
end)

test("FerociousBite: matches when combo >= 5 and target_hp < 25", function()
    local state = cat.build_state(ctx)
    state.combo_points = 5
    state.target_hp = 20
    assert_true(cat.strategies[6].matches(ctx, state), "FerociousBite should match with combo >= 5 in execute range")
end)

test("FerociousBite: does not match with combo < 5", function()
    local state = cat.build_state(ctx)
    state.combo_points = 4
    state.target_hp = 20
    assert_false(cat.strategies[6].matches(ctx, state), "FerociousBite should not match with combo < 5")
end)

test("FerociousBite: does not match when target_hp >= 25", function()
    local state = cat.build_state(ctx)
    state.combo_points = 5
    state.target_hp = 50
    assert_false(cat.strategies[6].matches(ctx, state), "FerociousBite should not match above execute range")
end)

-- MangleCat (7): energy >= 45
test("MangleCat: matches when energy >= 45", function()
    local state = cat.build_state(ctx)
    state.energy = 45
    assert_true(cat.strategies[7].matches(ctx, state), "MangleCat should match when energy >= 45")
end)

test("MangleCat: does not match when energy < 45", function()
    local state = cat.build_state(ctx)
    state.energy = 30
    assert_false(cat.strategies[7].matches(ctx, state), "MangleCat should not match when energy < 45")
end)

-- Shred (8): is_behind and energy >= 50
test("Shred: matches when behind and energy >= 50", function()
    local state = cat.build_state(ctx)
    state.is_behind = true
    state.energy = 50
    assert_true(cat.strategies[8].matches(ctx, state), "Shred should match when behind with energy >= 50")
end)

test("Shred: does not match when not behind", function()
    local state = cat.build_state(ctx)
    state.is_behind = false
    state.energy = 50
    assert_false(cat.strategies[8].matches(ctx, state), "Shred should not match when not behind")
end)

print(string.format("Tests: %d/%d passed", total_passed, total_tests))
if #failures > 0 then
    print("FAILURES:")
    for _, f in ipairs(failures) do
        print("  " .. f.label .. ": " .. tostring(f.error))
    end
    os.exit(1)
end
