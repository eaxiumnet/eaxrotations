-- test_paladin_leveling_wotlk_dsl_priority.lua — WotLK Paladin leveling DSL priority tests.
-- WHAT:  Validates that the 8 paladin leveling_wotlk strategies are compiled by the DSL
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

package.loaded["shared/aoe_hit_volume_sylvanas"] = {
    install = function(NS) end,
}

_G.EaxRotations = {
    PaladinSpells = {
        SealOfCommand = make_action(20375, "SealOfCommand"),
        SealOfVengeance = make_action(31801, "SealOfVengeance"),
        SealOfRighteousness = make_action(21084, "SealOfRighteousness"),
        BlessingOfMight = make_action(19740, "BlessingOfMight"),
        DevotionAura = make_action(465, "DevotionAura"),
        Judgement = make_action(20271, "Judgement"),
        CrusaderStrike = make_action(35395, "CrusaderStrike"),
        DivineStorm = make_action(53385, "DivineStorm"),
        Consecration = make_action(26573, "Consecration"),
        HammerOfWrath = make_action(24275, "HammerOfWrath"),
    },
    GetPlayer = function() return {
        get_health_percentage = function() return 100 end,
        get_mana_percentage = function() return 100 end,
    } end,
    me = {
        get_health_percentage = function() return 100 end,
        get_mana_percentage = function() return 100 end,
    },
    AOE_RADIUS = { SELF_8 = 8 },
    aoe_self_meets = function(count, radius, context, state) return true end,
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

print("=== test_paladin_leveling_wotlk_dsl_priority ===")

local lv = dofile("EaxRotations/classes/paladin/leveling_wotlk.lua")
assert_true(type(lv) == "table", "leveling_wotlk should return a table")
assert_true(type(lv.strategies) == "table", "leveling_wotlk should expose strategies")
assert_true(#lv.strategies == 8, "leveling_wotlk should have 8 strategies")

local registered = _G.EaxRotations._registered_leveling
assert_true(registered ~= nil and registered.name == "leveling", "leveling_wotlk should register under 'leveling'")

-- ============================================================================
-- Priority order test
-- ============================================================================
local expected_order = {
    "Seal",
    "BlessingOfMight",
    "DevotionAura",
    "Judgement",
    "HammerOfWrath",
    "DivineStorm",
    "Consecration",
    "CrusaderStrike",
}

test("priority order: 8 strategies match expected order", function()
    for i = 1, #expected_order do
        assert_true(lv.strategies[i].name == expected_order[i],
            string.format("Strategy %d should be %s, got %s", i, expected_order[i], lv.strategies[i].name))
    end
end)

-- ============================================================================
-- Match gate tests
-- ============================================================================
local ctx = { in_combat = true, target = {}, settings = {} }

-- Seal (1): not seal_up and mana >= 5
test("Seal: matches when no seal", function()
    local state = lv.build_state(ctx)
    state.seal_up = false
    state.mana_pct = 5
    assert_true(lv.strategies[1].matches(ctx, state), "Seal should match when no seal")
end)

test("Seal: does not match when seal up", function()
    local state = lv.build_state(ctx)
    state.seal_up = true
    state.mana_pct = 100
    assert_false(lv.strategies[1].matches(ctx, state), "Seal should not match when seal up")
end)

-- BlessingOfMight (2): OOC and not might_up and mana >= 5
test("BlessingOfMight: matches OOC without buff", function()
    local state = lv.build_state(ctx)
    state.in_combat = false
    state.might_up = false
    state.mana_pct = 5
    assert_true(lv.strategies[2].matches(ctx, state), "BoM should match OOC without buff")
end)

test("BlessingOfMight: does not match in combat", function()
    local state = lv.build_state(ctx)
    state.in_combat = true
    state.might_up = false
    state.mana_pct = 100
    assert_false(lv.strategies[2].matches(ctx, state), "BoM should not match in combat")
end)

-- DevotionAura (3): OOC and not aura_up
test("DevotionAura: matches OOC without aura", function()
    local state = lv.build_state(ctx)
    state.in_combat = false
    state.aura_up = false
    assert_true(lv.strategies[3].matches(ctx, state), "Aura should match OOC without aura")
end)

-- Judgement (4): in_combat and mana >= 10
test("Judgement: matches with mana", function()
    local state = lv.build_state(ctx)
    state.in_combat = true
    state.mana_pct = 10
    assert_true(lv.strategies[4].matches(ctx, state), "Judgement should match with mana >= 10")
end)

-- HammerOfWrath (5): in_combat and target_hp < 20 and mana >= 10
test("HammerOfWrath: matches on low target", function()
    local state = lv.build_state(ctx)
    state.in_combat = true
    state.target_hp = 15
    state.mana_pct = 10
    assert_true(lv.strategies[5].matches(ctx, state), "HoW should match on low target")
end)

test("HammerOfWrath: does not match on healthy target", function()
    local state = lv.build_state(ctx)
    state.in_combat = true
    state.target_hp = 80
    state.mana_pct = 100
    assert_false(lv.strategies[5].matches(ctx, state), "HoW should not match on healthy target")
end)

-- DivineStorm (6): in_combat and mana >= 20 and aoe gate
test("DivineStorm: matches when AoE meets", function()
    local state = lv.build_state(ctx)
    state.in_combat = true
    state.mana_pct = 20
    assert_true(lv.strategies[6].matches(ctx, state), "DivineStorm should match when AoE meets")
end)

test("DivineStorm: does not match below mana", function()
    local state = lv.build_state(ctx)
    state.in_combat = true
    state.mana_pct = 10
    assert_false(lv.strategies[6].matches(ctx, state), "DivineStorm should not match below 20 mana")
end)

-- Consecration (7): in_combat and mana >= 25 and aoe gate
test("Consecration: matches when AoE meets", function()
    local state = lv.build_state(ctx)
    state.in_combat = true
    state.mana_pct = 25
    assert_true(lv.strategies[7].matches(ctx, state), "Consecration should match when AoE meets")
end)

-- CrusaderStrike (8): in_combat and mana >= 10
test("CrusaderStrike: matches with mana", function()
    local state = lv.build_state(ctx)
    state.in_combat = true
    state.mana_pct = 10
    assert_true(lv.strategies[8].matches(ctx, state), "CrusaderStrike should match with mana >= 10")
end)

test("CrusaderStrike: does not match out of combat", function()
    local state = lv.build_state(ctx)
    state.in_combat = false
    state.mana_pct = 100
    assert_false(lv.strategies[8].matches(ctx, state), "CrusaderStrike should not match OOC")
end)

print(string.format("Tests: %d/%d passed", total_passed, total_tests))
if #failures > 0 then
    print("FAILURES:")
    for _, f in ipairs(failures) do
        print("  " .. f.label .. ": " .. tostring(f.error))
    end
    os.exit(1)
end
