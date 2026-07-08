-- test_subtlety_vanilla_nil_guards.lua -- Subtlety Vanilla-era compatibility nil-guard tests.
-- WHAT:  Subtlety Vanilla-era compatibility nil-guard tests
-- WHEN:  During rotation test suite execution.
-- WHY:   Validates nil-guard safety on all numeric state reads (Pattern 14).
-- SAFETY: Must pass after any state table change.

-- Regression test: subtlety_vanilla.lua Pattern 14 nil-guards.
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
    RogueSpells = {
        Ambush = 11269, Backstab = 11281, Blind = 2094, CheapShot = 1833,
        Evasion = 5277, Eviscerate = 11300, ExposeArmor = 11198, Feint = 25302,
        Garrote = 11290, GhostlyStrike = 14278, Gouge = 1776, Hemorrhage = 17348,
        KidneyShot = 8643, Premeditation = 14183, Preparation = 14185,
        Rupture = 11275, Sap = 11297, SinisterStrike = 11294, SliceAndDice = 6774,
        Sprint = 11305, Stealth = 1787, Vanish = 1857,
    },
    action_matches = function(ctx, act) return true end,
    buff_up = function(me, buff_list) return me and me._buff_up or false end,
    buff_remains = function(me, buff_list) return me and me._buff_remains or 0 end,
    debuff_remains = function(target, debuff_list) return target and target._debuff_remains or 0 end,
    is_spell_learned = function(spell_id) return true end,
    spell_exists = function(spell) return true end,
    spell_ready = function(spell, target, opts) return true end,
    spell_action = function(ids, label) return { id = ids[1], label = label } end,
    setting_number = function(settings, key, default) return default end,
    setting_bool = function(settings, key, default) return default end,
    setting = function(context, key, default)
        local s = context and context.settings
        if s and s[key] ~= nil then return s[key] end
        return default
    end,
    log = function() end,
    time_now = function() return 0 end,
    rotation_registry = { register = function() end },
    PLAYER_UNIT = "player",
    GetPlayer = function() return nil end,
}

package.preload["shared/potion_helper_sylvanas"] = function()
    return { try_use_potion = function() end, HEALTH_POTION_IDS = {}, MANA_POTION_IDS = {} }
end

package.preload["shared/offensive_dispel_sylvanas"] = function()
    return { find_best_dispel_target = function() return nil end }
end

print("=== test_subtlety_vanilla_nil_guards ===")

local sub_strategies = dofile("EaxRotations/classes/rogue/subtlety_vanilla.lua")
assert_true(type(sub_strategies) == "table", "subtlety_vanilla strategies should load")

local function find_strategy(name)
    for i = 1, #sub_strategies do
        if sub_strategies[i].name == name then return sub_strategies[i] end
    end
    error("subtlety_vanilla strategy not found: " .. name)
end

-- Minimal state with nil fields to test guards
local function min_state(overrides)
    local state = {
        stealth_up = false,
        hp = nil, energy = nil, combo = nil,
        energy_pool_finisher = false,
        slice_remains = nil, target_hp = nil,
        kidney_remains = nil, rupture_remains = nil,
        expose_remains = nil, threat_pct = nil,
        vanish_cd = nil, sprint_cd = nil, evasion_cd = nil,
        target_distance = nil, energy_low = false,
        shadowstep_buff = false, is_behind = false,
    }
    if overrides then for k, v in pairs(overrides) do state[k] = v end end
    return state
end

local base_ctx = { in_combat = true, target = {}, me = { _buff_up = false }, settings = {}, should_burst = false }

expect_no_crash("subtlety_vanilla: Vanish with nil hp/energy (L340, L413, L421)", function()
    return find_strategy("Vanish").matches(base_ctx, min_state())
end)

expect_no_crash("subtlety_vanilla: Preparation with nil hp (L350)", function()
    return find_strategy("Preparation").matches(base_ctx, min_state({ vanish_cd = 0, sprint_cd = 0, evasion_cd = 1 }))
end)

expect_no_crash("subtlety_vanilla: EviscerateKill with nil combo/energy (L411, L413)", function()
    return find_strategy("EviscerateKill").matches(base_ctx, min_state())
end)

expect_no_crash("subtlety_vanilla: Eviscerate with nil combo/energy (L419, L421)", function()
    return find_strategy("Eviscerate").matches(base_ctx, min_state())
end)

expect_no_crash("subtlety_vanilla: KidneyShot with nil combo/kidney_remains (L361, L362)", function()
    return find_strategy("KidneyShot").matches(base_ctx, min_state())
end)

expect_no_crash("subtlety_vanilla: SliceAndDice with nil combo/slice_remains (L380, L381)", function()
    return find_strategy("SliceAndDice").matches(base_ctx, min_state())
end)

expect_no_crash("subtlety_vanilla: Rupture with nil combo/rupture_remains (L387, L390)", function()
    return find_strategy("Rupture").matches(base_ctx, min_state())
end)

expect_no_crash("subtlety_vanilla: ExposeArmor with nil combo/expose_remains (L395, L399)", function()
    return find_strategy("ExposeArmor").matches(base_ctx, min_state({ expose_remains = 0 }))
end)

expect_no_crash("subtlety_vanilla: Feint with nil threat_pct (L428)", function()
    return find_strategy("Feint").matches(base_ctx, min_state())
end)

expect_no_crash("subtlety_vanilla: Sprint with nil target_distance (L334)", function()
    return find_strategy("Sprint").matches(base_ctx, min_state())
end)

-- ============================================================================
-- REPORT
-- ============================================================================
print()
if #failures == 0 then
    print(string.format("PASS test_subtlety_vanilla_nil_guards — %d/%d passed", total_passed, total_tests))
else
    print(string.format("FAIL test_subtlety_vanilla_nil_guards — %d/%d passed, %d failures:",
        total_passed, total_tests, #failures))
    for i, f in ipairs(failures) do
        print(string.format("  %d. [%s] %s", i, f.label, f.error))
    end
    error(string.format("test_subtlety_vanilla_nil_guards: %d failure(s)", #failures))
end
