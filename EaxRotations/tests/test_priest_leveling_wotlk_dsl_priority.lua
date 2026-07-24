-- test_priest_leveling_wotlk_dsl_priority.lua — WotLK Priest leveling DSL priority tests.
-- WHAT:  Validates that the 11 priest leveling_wotlk strategies are compiled by the DSL
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

_G.EaxRotations = {
    PriestSpells = {
        PowerWordFortitude = make_action(1243, "PowerWordFortitude"),
        InnerFire = make_action(588, "InnerFire"),
        PowerWordShield = make_action(17, "PowerWordShield"),
        Shadowform = make_action(15473, "Shadowform"),
        ShadowWordPain = make_action(589, "ShadowWordPain"),
        MindBlast = make_action(8092, "MindBlast"),
        MindFlay = make_action(15407, "MindFlay"),
        Smite = make_action(585, "Smite"),
        Penance = make_action(47540, "Penance"),
        FlashHeal = make_action(2061, "FlashHeal"),
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

print("=== test_priest_leveling_wotlk_dsl_priority ===")

local lv = dofile("EaxRotations/classes/priest/leveling_wotlk.lua")
assert_true(type(lv) == "table", "leveling_wotlk should return a table")
assert_true(type(lv.strategies) == "table", "leveling_wotlk should expose strategies")
assert_true(#lv.strategies == 11, "leveling_wotlk should have 11 strategies")

local registered = _G.EaxRotations._registered_leveling
assert_true(registered ~= nil and registered.name == "leveling", "leveling_wotlk should register under 'leveling'")

-- ============================================================================
-- Priority order test
-- ============================================================================
local expected_order = {
    "PowerWordFortitude",
    "InnerFire",
    "Shadowform",
    "PowerWordShield",
    "FlashHeal",
    "ShadowWordPain",
    "Penance",
    "MindBlast",
    "MindFlay",
    "Smite",
    "Shoot",
}

test("priority order: 11 strategies match expected order", function()
    for i = 1, #expected_order do
        assert_true(lv.strategies[i].name == expected_order[i],
            string.format("Strategy %d should be %s, got %s", i, expected_order[i], lv.strategies[i].name))
    end
end)

-- ============================================================================
-- Match gate tests
-- ============================================================================
local ctx = { in_combat = true, target = {}, settings = {} }

-- PowerWordFortitude (1): OOC and not fortitude_up and mana >= 10
test("PowerWordFortitude: matches OOC without buff", function()
    local state = lv.build_state(ctx)
    state.in_combat = false
    state.fortitude_up = false
    state.mana_pct = 10
    assert_true(lv.strategies[1].matches(ctx, state), "PWF should match OOC without buff")
end)

test("PowerWordFortitude: does not match in combat", function()
    local state = lv.build_state(ctx)
    state.in_combat = true
    state.fortitude_up = false
    state.mana_pct = 100
    assert_false(lv.strategies[1].matches(ctx, state), "PWF should not match in combat")
end)

-- InnerFire (2): OOC and not inner_fire_up and mana >= 10
test("InnerFire: matches OOC without buff", function()
    local state = lv.build_state(ctx)
    state.in_combat = false
    state.inner_fire_up = false
    state.mana_pct = 10
    assert_true(lv.strategies[2].matches(ctx, state), "InnerFire should match OOC without buff")
end)

-- Shadowform (3): use_shadowform and OOC and not shadowform_up
test("Shadowform: matches when opt-in and OOC", function()
    local state = lv.build_state(ctx)
    state.use_shadowform = true
    state.in_combat = false
    state.shadowform_up = false
    assert_true(lv.strategies[3].matches(ctx, state), "Shadowform should match when opted in OOC")
end)

test("Shadowform: does not match when opt-out", function()
    local state = lv.build_state(ctx)
    state.use_shadowform = false
    state.in_combat = false
    state.shadowform_up = false
    assert_false(lv.strategies[3].matches(ctx, state), "Shadowform should not match when disabled")
end)

-- PowerWordShield (4): in_combat and not pws_up and not weakened_soul and mana >= 15
test("PowerWordShield: matches in combat without shield/lockout", function()
    local state = lv.build_state(ctx)
    state.in_combat = true
    state.pws_up = false
    state.weakened_soul = false
    state.mana_pct = 15
    assert_true(lv.strategies[4].matches(ctx, state), "PWS should match in combat")
end)

test("PowerWordShield: does not match during Weakened Soul", function()
    local state = lv.build_state(ctx)
    state.in_combat = true
    state.pws_up = false
    state.weakened_soul = true
    state.mana_pct = 100
    assert_false(lv.strategies[4].matches(ctx, state), "PWS should not match during Weakened Soul")
end)

-- FlashHeal (5): in_combat and hp < 50 and mana >= 25
test("FlashHeal: matches when hurt in combat", function()
    local state = lv.build_state(ctx)
    state.in_combat = true
    state.hp = 40
    state.mana_pct = 25
    assert_true(lv.strategies[5].matches(ctx, state), "FlashHeal should match when hurt")
end)

test("FlashHeal: does not match at full HP", function()
    local state = lv.build_state(ctx)
    state.in_combat = true
    state.hp = 100
    state.mana_pct = 100
    assert_false(lv.strategies[5].matches(ctx, state), "FlashHeal should not match at full HP")
end)

-- ShadowWordPain (6): in_combat and swp_remains < 3 and mana >= 15
test("ShadowWordPain: matches when dot expiring", function()
    local state = lv.build_state(ctx)
    state.in_combat = true
    state.swp_remains = 0
    state.mana_pct = 15
    assert_true(lv.strategies[6].matches(ctx, state), "SWP should match when expiring")
end)

-- Penance (7): in_combat and mana >= 15
test("Penance: matches with mana", function()
    local state = lv.build_state(ctx)
    state.in_combat = true
    state.mana_pct = 15
    assert_true(lv.strategies[7].matches(ctx, state), "Penance should match with mana >= 15")
end)

-- MindBlast (8): in_combat and mana >= 20
test("MindBlast: matches with mana", function()
    local state = lv.build_state(ctx)
    state.in_combat = true
    state.mana_pct = 20
    assert_true(lv.strategies[8].matches(ctx, state), "MindBlast should match with mana >= 20")
end)

-- MindFlay (9): in_combat and mana >= 20
test("MindFlay: matches with mana", function()
    local state = lv.build_state(ctx)
    state.in_combat = true
    state.mana_pct = 20
    assert_true(lv.strategies[9].matches(ctx, state), "MindFlay should match with mana >= 20")
end)

-- Smite (10): in_combat and mana >= 15
test("Smite: matches with mana", function()
    local state = lv.build_state(ctx)
    state.in_combat = true
    state.mana_pct = 15
    assert_true(lv.strategies[10].matches(ctx, state), "Smite should match with mana >= 15")
end)

-- Shoot (11): in_combat and mana < 10
test("Shoot: matches when OOM in combat", function()
    local state = lv.build_state(ctx)
    state.in_combat = true
    state.mana_pct = 5
    assert_true(lv.strategies[11].matches(ctx, state), "Shoot should match when OOM")
end)

test("Shoot: does not match with mana available", function()
    local state = lv.build_state(ctx)
    state.in_combat = true
    state.mana_pct = 50
    assert_false(lv.strategies[11].matches(ctx, state), "Shoot should not match with mana")
end)

print(string.format("Tests: %d/%d passed", total_passed, total_tests))
if #failures > 0 then
    print("FAILURES:")
    for _, f in ipairs(failures) do
        print("  " .. f.label .. ": " .. tostring(f.error))
    end
    os.exit(1)
end
