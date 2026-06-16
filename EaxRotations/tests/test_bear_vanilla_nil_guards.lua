-- Regression test: bear_vanilla.lua Pattern 14 nil-guards.
--
-- Verifies that match functions do not crash when state fields that were
-- previously compared bare become nil / are supplied via settings that may
-- return nil.
--
-- Expected: RED before nil-guards; GREEN after.
--
package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local assert_true

local function setup_asserts()
    assert_true = function(v, label) if not v then error(label or "assert_true failed", 2) end end
end
setup_asserts()

local failures = {}
local total_tests = 0
local total_passed = 0

local function expect_no_crash(label, fn)
    total_tests = total_tests + 1
    local ok, err = pcall(fn)
    if ok then
        total_passed = total_passed + 1
    else
        failures[#failures + 1] = { label = label, error = err }
    end
end

-- ============================================================================
-- Mock NS
-- ============================================================================
_G.EaxRotations = {
    DruidSpells = {
        Shred = 5221,
        MangleBear = 33878,
        Lacerate = 33745,
        SwipeBear = 779,
        Maul = 6807,
        FaerieFireFeral = 27011,
        Growl = 6794,
        DemoralizingRoar = 25203,
        ChallengingRoar = 5209,
        FeralCharge = 16979,
        Bash = 8983,
        Enrage = 5229,
        BearForm = 5487,
        FrenziedRegeneration = 22842,
        Barkskin = 22812,
        FerociousBite = 22568,
        MarkOfTheWild = 1126,
        GiftOfTheWild = 21849,
        Thorns = 467,
    },
    action_matches = function(ctx, act) return true end,
    buff_up = function(me, buff_list) return me and me._buff_up or false end,
    buff_remains = function(me, buff_list) return me and me._buff_remains or 0 end,
    debuff_remains = function(target, debuff_list) return target and target._debuff_remains or 0 end,
    is_spell_learned = function(spell_id) return true end,
    spell_exists = function(spell) return true end,
    spell_ready = function(spell, target, opts) return true end,
    -- Default: behave like a normal setting_number. Tests that need nil will override.
    setting_number = function(settings, key, default)
        return type(settings) == "table" and type(settings[key]) == "number" and settings[key] or default
    end,
    setting_bool = function(settings, key, default)
        local value = settings and settings[key]
        if value == nil then return default end
        return value ~= false
    end,
    log = function() end,
    time_now = function() return 0 end,
    rotation_registry = { register = function() end },
    has_form = function(form) return form == "bear" end,
}

package.preload["shared/tbc_data_sylvanas"] = function()
    return { ITEMS = { healthstones = {}, potions = {} }, SPELLS = { mage = {} } }
end

print("=== test_bear_vanilla_nil_guards ===")

local bear_strategies = dofile("EaxRotations/classes/druid/bear_vanilla.lua")
assert_true(type(bear_strategies) == "table", "bear_vanilla strategies should load")

local function find_strategy(name)
    for i = 1, #bear_strategies do
        if bear_strategies[i].name == name then return bear_strategies[i] end
    end
    error("bear_vanilla strategy not found: " .. name)
end

local base_ctx = {
    in_combat = true,
    target = nil,
    me = { _buff_up = false },
    settings = {},
}

-- ============================================================================
-- Triggerable guards: settings may return nil
-- ============================================================================

-- SwipeAoE: L542 state.enemy_count < state.aoe_threshold
-- If NS.setting_number returns nil, state.aoe_threshold becomes nil.
expect_no_crash("bear_vanilla: SwipeAoE with nil aoe_threshold (L542)", function()
    local old = _G.EaxRotations.setting_number
    _G.EaxRotations.setting_number = function(settings, key, default)
        if key == "bear_aoe_threshold" or key == "aoe_threshold" then return nil end
        return old(settings, key, default)
    end
    local ok, err = pcall(function()
        local s = find_strategy("SwipeAoE")
        return s.matches(base_ctx)
    end)
    _G.EaxRotations.setting_number = old
    if not ok then error(err) end
end)

-- Maul: L561 state.enemy_count >= state.aoe_threshold, L562 state.rage < state.maul_rage
expect_no_crash("bear_vanilla: Maul with nil aoe_threshold and maul_rage (L561, L562)", function()
    local old = _G.EaxRotations.setting_number
    _G.EaxRotations.setting_number = function(settings, key, default)
        if key == "bear_aoe_threshold" or key == "aoe_threshold" then return nil end
        if key == "bear_maul_rage" then return nil end
        return old(settings, key, default)
    end
    local ok, err = pcall(function()
        local s = find_strategy("Maul")
        return s.matches(base_ctx)
    end)
    _G.EaxRotations.setting_number = old
    if not ok then error(err) end
end)

-- ============================================================================
-- Defense-in-depth: minimal contexts should not crash
-- ============================================================================

expect_no_crash("bear_vanilla: PrePullEnrage with minimal context (L442, L443)", function()
    return find_strategy("PrePullEnrage").matches({ in_combat = false, me = { _buff_up = false }, settings = {} })
end)

expect_no_crash("bear_vanilla: FaerieFirePull with minimal context (L453, L454)", function()
    return find_strategy("FaerieFirePull").matches({ in_combat = true, me = { _buff_up = false }, settings = {}, target = {} })
end)

expect_no_crash("bear_vanilla: ChallengingRoar with minimal context (L494, L495)", function()
    return find_strategy("ChallengingRoar").matches(base_ctx)
end)

expect_no_crash("bear_vanilla: SwipeAoE with minimal context (L542, L544)", function()
    return find_strategy("SwipeAoE").matches(base_ctx)
end)

expect_no_crash("bear_vanilla: Swipe with minimal context (L552, L554)", function()
    return find_strategy("Swipe").matches(base_ctx)
end)

expect_no_crash("bear_vanilla: Maul with minimal context (L561, L562)", function()
    return find_strategy("Maul").matches(base_ctx)
end)

expect_no_crash("bear_vanilla: FerociousBiteExecute with minimal context (L578, L580)", function()
    return find_strategy("FerociousBiteExecute").matches({ in_combat = true, me = { _buff_up = false }, settings = {}, target = {} })
end)

-- ============================================================================
-- REPORT
-- ============================================================================
print()
if #failures == 0 then
    print(string.format("PASS test_bear_vanilla_nil_guards — %d/%d passed", total_passed, total_tests))
else
    print(string.format("FAIL test_bear_vanilla_nil_guards — %d/%d passed, %d failures:",
        total_passed, total_tests, #failures))
    for i, f in ipairs(failures) do
        print(string.format("  %d. [%s] %s", i, f.label, f.error))
    end
    error(string.format("test_bear_vanilla_nil_guards: %d failure(s)", #failures))
end
