-- test_druid_leveling_wotlk_dsl_priority.lua — WotLK Druid leveling DSL priority tests.
-- WHAT:  Validates that the 21 druid leveling_wotlk strategies are compiled by the DSL
--        and that their match gates (incl. form-gating and feral opt-in) fire in order.
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

_G.EaxRotations = {
    DruidSpells = {
        Moonfire = make_action(8921, "Moonfire"),
        Wrath = make_action(5176, "Wrath"),
        Starfire = make_action(2912, "Starfire"),
        InsectSwarm = make_action(5570, "InsectSwarm"),
        EntanglingRoots = make_action(339, "EntanglingRoots"),
        Regrowth = make_action(8936, "Regrowth"),
        Rejuvenation = make_action(774, "Rejuvenation"),
        HealingTouch = make_action(5185, "HealingTouch"),
        MarkOfTheWild = make_action(1126, "MarkOfTheWild"),
        Thorns = make_action(467, "Thorns"),
        FaerieFire = make_action(770, "FaerieFire"),
        MangleCat = make_action(33876, "MangleCat"),
        Rake = make_action(1822, "Rake"),
        Rip = make_action(1079, "Rip"),
        FerociousBite = make_action(22568, "FerociousBite"),
        Claw = make_action(1082, "Claw"),
        Shred = make_action(5221, "Shred"),
        MangleBear = make_action(33878, "MangleBear"),
        SwipeBear = make_action(779, "SwipeBear"),
        Lacerate = make_action(33745, "Lacerate"),
        CatForm = make_action(768, "CatForm"),
        DireBearForm = make_action(5487, "DireBearForm"),
    },
    GetPlayer = function() return {
        get_health_percentage = function() return 100 end,
        get_mana_percentage = function() return 100 end,
        get_combo_points = function() return 0 end,
    } end,
    me = {
        get_health_percentage = function() return 100 end,
        get_mana_percentage = function() return 100 end,
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
    has_form = function(form) return false end,
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

print("=== test_druid_leveling_wotlk_dsl_priority ===")

local lv = dofile("EaxRotations/classes/druid/leveling_wotlk.lua")
assert_true(type(lv) == "table", "leveling_wotlk should return a table")
assert_true(type(lv.strategies) == "table", "leveling_wotlk should expose strategies")
assert_true(#lv.strategies == 21, "leveling_wotlk should have 21 strategies")

local registered = _G.EaxRotations._registered_leveling
assert_true(registered ~= nil and registered.name == "leveling", "leveling_wotlk should register under 'leveling'")

-- ============================================================================
-- Priority order test
-- ============================================================================
local expected_order = {
    "MarkOfTheWild",
    "Thorns",
    "Rejuvenation",
    "HealingTouch",
    "DireBearForm",
    "CatForm",
    "EntanglingRoots",
    "Rip",
    "FerociousBite",
    "Rake",
    "MangleCat",
    "Shred",
    "Claw",
    "Swipe",
    "Lacerate",
    "MangleBear",
    "Moonfire",
    "InsectSwarm",
    "FaerieFire",
    "Starfire",
    "Wrath",
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

-- MarkOfTheWild (1): OOC and buff missing (buff_up mock returns false)
test("MarkOfTheWild: matches OOC without buff", function()
    local state = lv.build_state(ctx)
    state.in_combat = false
    assert_true(lv.strategies[1].matches(ctx, state), "MotW should match OOC without buff")
end)

test("MarkOfTheWild: does not match in combat", function()
    local state = lv.build_state(ctx)
    state.in_combat = true
    assert_false(lv.strategies[1].matches(ctx, state), "MotW should not match in combat")
end)

-- Thorns (2): OOC and buff missing
test("Thorns: matches OOC without buff", function()
    local state = lv.build_state(ctx)
    state.in_combat = false
    assert_true(lv.strategies[2].matches(ctx, state), "Thorns should match OOC without buff")
end)

-- Rejuvenation (3): in_combat and hp < 50 and mana >= 20
test("Rejuvenation: matches on low hp", function()
    local state = lv.build_state(ctx)
    state.in_combat = true
    state.hp = 40
    state.mana_pct = 20
    assert_true(lv.strategies[3].matches(ctx, state), "Rejuv should match on low hp")
end)

test("Rejuvenation: does not match at full hp", function()
    local state = lv.build_state(ctx)
    state.in_combat = true
    state.hp = 100
    state.mana_pct = 100
    assert_false(lv.strategies[3].matches(ctx, state), "Rejuv should not match at full hp")
end)

-- HealingTouch (4): in_combat and hp < 30 and mana >= 25
test("HealingTouch: matches on critical hp", function()
    local state = lv.build_state(ctx)
    state.in_combat = true
    state.hp = 25
    state.mana_pct = 25
    assert_true(lv.strategies[4].matches(ctx, state), "HealingTouch should match on critical hp")
end)

-- DireBearForm (5): bear setting on + in_combat + form != bear
local bear_ctx = { in_combat = true, target = {}, settings = { druid_leveling_bear = true } }
test("DireBearForm: matches when bear setting on and not in bear", function()
    local state = lv.build_state(bear_ctx)
    state.in_combat = true
    state.form = "caster"
    assert_true(lv.strategies[5].matches(bear_ctx, state), "DireBearForm should match with bear setting on")
end)

test("DireBearForm: does not match when bear setting off", function()
    local state = lv.build_state(ctx)
    state.in_combat = true
    state.form = "caster"
    assert_false(lv.strategies[5].matches(ctx, state), "DireBearForm should not match with bear setting off")
end)

test("DireBearForm: does not match when already in bear", function()
    local state = lv.build_state(bear_ctx)
    state.in_combat = true
    state.form = "bear"
    assert_false(lv.strategies[5].matches(bear_ctx, state), "DireBearForm should not match when already bear")
end)

-- CatForm (6): bear setting off + feral setting on + in_combat + form != cat
local cat_ctx = { in_combat = true, target = {}, settings = { druid_leveling_feral = true } }
test("CatForm: matches when feral setting on and not in cat", function()
    local state = lv.build_state(cat_ctx)
    state.in_combat = true
    state.form = "caster"
    assert_true(lv.strategies[6].matches(cat_ctx, state), "CatForm should match with feral setting on")
end)

test("CatForm: does not match when feral setting off", function()
    local state = lv.build_state(ctx)
    state.in_combat = true
    state.form = "caster"
    assert_false(lv.strategies[6].matches(ctx, state), "CatForm should not match with feral setting off")
end)

-- Rip (8): in_combat + form cat + combo >= 4 + rip_remains < 3
test("Rip: matches in cat form with combo points", function()
    local state = lv.build_state(ctx)
    state.in_combat = true
    state.form = "cat"
    state.combo_points = 5
    state.rip_remains = 0
    assert_true(lv.strategies[8].matches(ctx, state), "Rip should match in cat form with combos")
end)

test("Rip: does not match in caster form", function()
    local state = lv.build_state(ctx)
    state.in_combat = true
    state.form = "caster"
    state.combo_points = 5
    state.rip_remains = 0
    assert_false(lv.strategies[8].matches(ctx, state), "Rip should not match outside cat form")
end)

-- Lacerate (15): in_combat + form bear
test("Lacerate: matches in bear form", function()
    local state = lv.build_state(ctx)
    state.in_combat = true
    state.form = "bear"
    assert_true(lv.strategies[15].matches(ctx, state), "Lacerate should match in bear form")
end)

test("Lacerate: does not match in cat form", function()
    local state = lv.build_state(ctx)
    state.in_combat = true
    state.form = "cat"
    assert_false(lv.strategies[15].matches(ctx, state), "Lacerate should not match in cat form")
end)

-- Moonfire (17): in_combat + moonfire_remains < 3 + mana >= 15
test("Moonfire: matches when dot missing", function()
    local state = lv.build_state(ctx)
    state.in_combat = true
    state.moonfire_remains = 0
    state.mana_pct = 15
    assert_true(lv.strategies[17].matches(ctx, state), "Moonfire should match when dot missing")
end)

-- Wrath (21): in_combat + mana >= 10
test("Wrath: matches as filler", function()
    local state = lv.build_state(ctx)
    state.in_combat = true
    state.mana_pct = 10
    assert_true(lv.strategies[21].matches(ctx, state), "Wrath should match as filler")
end)

test("Wrath: does not match out of combat", function()
    local state = lv.build_state(ctx)
    state.in_combat = false
    state.mana_pct = 100
    assert_false(lv.strategies[21].matches(ctx, state), "Wrath should not match OOC")
end)

print(string.format("Tests: %d/%d passed", total_passed, total_tests))
if #failures > 0 then
    print("FAILURES:")
    for _, f in ipairs(failures) do
        print("  " .. f.label .. ": " .. tostring(f.error))
    end
    os.exit(1)
end
