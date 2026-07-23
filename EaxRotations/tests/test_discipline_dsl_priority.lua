-- test_discipline_dsl_priority.lua â Discipline Priest DSL priority + equivalence test.
-- WHAT:  verifies that 7 DSL-converted strategies are present, preserve priority
--        order, and behave equivalently to the original imperative logic.
-- WHEN:  runs as part of the rotation test suite.
-- WHY:   regression guard for the 18th DSL adopter (first absorb/healer spec).
-- SAFETY: standalone â mocks NS, spec_kit, and shared modules; no game API calls.

local _pass, _fail = 0, 0
local function assert_true(cond, msg)
    if cond then _pass = _pass + 1 else _fail = _fail + 1 print("  FAIL: " .. msg) end
end
local function assert_false(cond, msg)
    if not cond then _pass = _pass + 1 else _fail = _fail + 1 print("  FAIL: " .. msg) end
end

-- ============================================================================
-- Mock NS
-- ============================================================================
local NS = {}
_G.EaxRotations = NS

NS.PriestSpells = {
    BindingHeal = 32546, CircleofHealing = 34866, DispelMagic = 988,
    MassDispel = 32375, DivineSpirit = 25312, Fade = 25429, FearWard = 6346,
    FlashHeal = 25235, GreaterHeal = 25213, HolyFire = 25384,
    InnerFire = 25431, InnerFocus = 14751, PainSuppression = 33206,
    PowerInfusion = 10060, PowerWordFortitude = 25389,
    PowerWordShield = 25218, PrayerOfFortitude = 25392,
    PrayerOfHealing = 25308, PrayerofMending = 33076, PsychicScream = 10890,
    Renew = 25222, ShadowWordPain = 25368, Shadowfiend = 34433,
    ShackleUndead = 10955, Smite = 25364, SymbolOfHope = 32548,
}
NS.PriestHealing = {
    scan_healing_targets = function() return {}, 0 end,
    pws_absorb_remaining = function() return 0 end,
    count_subgroup_below_hp = function() return 0 end,
}
NS.PLAYER_UNIT = { get_health = function() return 100 end, is_valid = function() return true end }
NS.GetPlayer = function() return NS.PLAYER_UNIT end
NS.buff_up = function() return false end
NS.debuff_up = function() return false end
NS.debuff_remains = function() return 0 end
NS.has_buff = function() return false end
NS.buff_stacks = function() return 0 end
NS.buff_remains = function() return 0 end
NS.spell_ready = function() return true end
NS.try_cast = function() return true end
NS.unit_mana_pct = function() return 100 end
NS.unit_health_pct = function() return 100 end
NS.unit_distance = function() return 100 end
NS.time_now = function() return 0 end
NS.game_time_ms = function() return 0 end
NS.not_same_unit = function() return true end
NS.same_unit = function(a, b) return a == b end
NS.is_tank_unit = function() return false end
NS.GetPartyMembers = function() return {} end
NS.GetEnemiesCount = function() return 0 end
NS.GetEnemiesInRange = function() return {} end
NS.cooldown_remains = function() return 0 end
NS.broken_api_throttled = function() return false end
NS.gate_overheal = function() return false end
NS.has_debuff = function() return false end
NS.is_item_ready = function() return false end
NS.use_item_by_id = function() return false end
NS.log = function() end
NS.rotation_registry = { register = function() end }

-- Mock shared modules
local _setting = function(context, key, default)
    if context and context.settings and context.settings[key] ~= nil then
        return context.settings[key]
    end
    return default
end
local mock_spec_kit = {
    merge_state = dofile("EaxRotations/tests/spec_kit_merge_state.lua").merge_state,
    define_action_for_class = function(SPELLS)
        return function(field, rank_ids, label)
            if SPELLS and SPELLS[field] then return SPELLS[field] end
            return rank_ids and rank_ids[1] or field
        end
    end,
    safe_state = function(raw, schema)
        return setmetatable({}, {
            __index = function(t, k)
                if raw[k] ~= nil then return raw[k] end
                if schema and schema[k] ~= nil then return schema[k] end
                return nil
            end,
        })
    end,
    setting = _setting,
    setting_bool = function(context, key, default)
        local v = _setting(context, key, nil)
        if v == nil then return default end
        return v ~= false
    end,
    setting_number = function(context, key, default)
        local v = _setting(context, key, nil)
        if type(v) == "number" then return v end
        return default
    end,
}
package.loaded["shared/spec_kit_sylvanas"] = mock_spec_kit
package.loaded["classes/priest/healing_sylvanas"] = NS.PriestHealing
package.loaded["shared/preemptive_heal_sylvanas"] = {
    DEFAULT_THRESHOLD = 40,
    match = function() return false end,
    execute = function() return false end,
    get_penalty_adjusted_heal = function(id, ct) return id, 1 end,
}
package.loaded["shared/fsr_manager_sylvanas"] = {
    is_inside_fsr = function() return false end,
    seconds_until_fsr = function() return 0 end,
    get_regen_delta = function() return 0 end,
    should_pause_for_fsr = function() return false end,
}
package.loaded["shared/health_pred_helper_sylvanas"] = nil
package.loaded["common/utility/inventory_helper"] = { has_item = function() return nil end }

-- Load the real DSL engine so the spec file's require() picks it up
package.loaded["shared/strategy_dsl_sylvanas"] = dofile("EaxRotations/shared/strategy_dsl_sylvanas.lua")

-- Load the discipline spec
local disc = dofile("EaxRotations/classes/priest/discipline_sylvanas.lua")
local strategies = disc.strategies

-- ============================================================================
-- Priority order verification
-- ============================================================================
local expected_order = {
    "FriendlyTarget", "PowerWordShieldTank", "EmergencyPowerWordShield",
    "PrayerOfMendingTank", "EmergencyFlashHeal", "PreemptiveGreaterHeal",
    "GreaterHeal", "FSRPause", "BindingHeal", "CircleOfHealing",
    "PrayerOfHealing", "RenewTank", "RenewLowest", "InnerFire",
    "FearWard", "PowerWordFortitude", "SymbolOfHope", "DivineSpirit",
    "PrayerOfFortitude", "PsychicScream", "ShackleUndead", "DispelMagic",
    "MassDispel", "PainSuppression", "PowerInfusion", "InnerFocus",
    "StopCast", "PreHeal", "Fade", "Shadowfiend", "ManaPotion", "Healthstone",
    "IdleShadowWordPain", "IdleSmite", "HolyFire",
}
assert_true(#strategies == #expected_order, "strategy count matches (" .. #strategies .. " vs " .. #expected_order .. ")")
for i = 1, math.min(#strategies, #expected_order) do
    assert_true(strategies[i].name == expected_order[i],
        string.format("priority[%d] = %s (expected %s)", i, strategies[i].name or "?", expected_order[i]))
end

-- DSL position checks â verify the 7 DSL-converted strategies are at expected indices
local dsl_indices = {}
for i = 1, #strategies do dsl_indices[strategies[i].name] = i end
assert_true(dsl_indices["PowerWordShieldTank"] == 2, "PowerWordShieldTank at index 2")
assert_true(dsl_indices["EmergencyPowerWordShield"] == 3, "EmergencyPowerWordShield at index 3")
assert_true(dsl_indices["PrayerOfMendingTank"] == 4, "PrayerOfMendingTank at index 4")
assert_true(dsl_indices["EmergencyFlashHeal"] == 5, "EmergencyFlashHeal at index 5")
assert_true(dsl_indices["RenewTank"] == 12, "RenewTank at index 12")
assert_true(dsl_indices["InnerFire"] == 14, "InnerFire at index 14")
assert_true(dsl_indices["PainSuppression"] == 24, "PainSuppression at index 24")

-- ============================================================================
-- Mock context + state helpers
-- ============================================================================
local function make_ctx(overrides)
    local ctx = {
        me = NS.PLAYER_UNIT,
        target = { is_valid = function() return true end, is_dead = function() return false end,
                   is_casting = function() return false end, get_creature_type = function() return nil end },
        in_combat = true,
        hp = 100,
        mana_pct = 80,
        settings = {},
        has_valid_enemy_target = true,
        is_moving = false,
        enemies_count = 1,
    }
    for k, v in pairs(overrides or {}) do ctx[k] = v end
    return ctx
end

local function make_state(overrides)
    local s = {
        mana_pct = 80, hp_pct = 100,
        in_combat = true, enemy_count = 1,
        pws_ready = true, pom_ready = true, flash_heal_ready = true,
        greater_heal_ready = true, renew_ready = true,
        pain_suppression_ready = true, inner_fire_ready = true,
        tank = { unit = NS.PLAYER_UNIT, effective_hp = 30, has_weakened_soul = false, has_renew = false },
        lowest = { unit = NS.PLAYER_UNIT, effective_hp = 30, has_weakened_soul = false, has_renew = false },
    }
    for k, v in pairs(overrides or {}) do s[k] = v end
    return s
end

-- ============================================================================
-- PowerWordShieldTank: tank HP below threshold, no weakened soul, low absorb
-- ============================================================================
local idx_pws_tank = 2
-- Positive
assert_true(strategies[idx_pws_tank].matches(make_ctx(), make_state()),
    "PowerWordShieldTank matches when tank is low and spell ready")
-- Negative: tank HP above threshold
assert_false(strategies[idx_pws_tank].matches(make_ctx(), make_state({ tank = { unit = NS.PLAYER_UNIT, effective_hp = 90, has_weakened_soul = false } })),
    "PowerWordShieldTank skips when tank HP is high")
-- Negative: weakened soul
assert_false(strategies[idx_pws_tank].matches(make_ctx(), make_state({ tank = { unit = NS.PLAYER_UNIT, effective_hp = 30, has_weakened_soul = true } })),
    "PowerWordShieldTank skips when tank has Weakened Soul")
-- Negative: not ready
assert_false(strategies[idx_pws_tank].matches(make_ctx(), make_state({ pws_ready = false })),
    "PowerWordShieldTank skips when spell not ready")

-- ============================================================================
-- EmergencyPowerWordShield: lowest non-tank HP below threshold
-- ============================================================================
local idx_pws_low = 3
-- Positive
assert_true(strategies[idx_pws_low].matches(make_ctx(), make_state()),
    "EmergencyPowerWordShield matches when lowest is low and tank-only disabled")
-- Negative: tank-only setting enabled
assert_false(strategies[idx_pws_low].matches(make_ctx({ settings = { disc_shield_tank_only = true } }), make_state()),
    "EmergencyPowerWordShield skips when disc_shield_tank_only is true")
-- Negative: lowest HP too high
assert_false(strategies[idx_pws_low].matches(make_ctx(), make_state({ lowest = { unit = NS.PLAYER_UNIT, effective_hp = 90, has_weakened_soul = false } })),
    "EmergencyPowerWordShield skips when lowest HP is high")

-- ============================================================================
-- PrayerOfMendingTank: in combat, target exists, not already buffed
-- ============================================================================
local idx_pom = 4
-- Positive
assert_true(strategies[idx_pom].matches(make_ctx(), make_state()),
    "PrayerOfMendingTank matches in combat with a target")
-- Negative: out of combat and prepull disabled
assert_false(strategies[idx_pom].matches(make_ctx({ in_combat = false, settings = { disc_prepull_pom = false } }), make_state({ in_combat = false })),
    "PrayerOfMendingTank skips out of combat when prepull disabled")
-- Positive: out of combat but prepull enabled
assert_true(strategies[idx_pom].matches(make_ctx({ in_combat = false }), make_state({ in_combat = false })),
    "PrayerOfMendingTank matches out of combat when prepull enabled")

-- ============================================================================
-- EmergencyFlashHeal: stationary, low lowest, mana sufficient, no overheal
-- ============================================================================
local idx_fh = 5
-- Positive
assert_true(strategies[idx_fh].matches(make_ctx(), make_state()),
    "EmergencyFlashHeal matches when lowest is low and stationary")
-- Negative: moving
assert_false(strategies[idx_fh].matches(make_ctx({ is_moving = true }), make_state()),
    "EmergencyFlashHeal skips when moving")
-- Negative: mana too low
assert_false(strategies[idx_fh].matches(make_ctx(), make_state({ mana_pct = 10 })),
    "EmergencyFlashHeal skips when below mana floor")

-- ============================================================================
-- RenewTank: tank missing renew, HP below threshold
-- ============================================================================
local idx_renew = 12
-- Positive
assert_true(strategies[idx_renew].matches(make_ctx(), make_state()),
    "RenewTank matches when tank missing Renew and HP low")
-- Negative: already has renew
assert_false(strategies[idx_renew].matches(make_ctx(), make_state({ tank = { unit = NS.PLAYER_UNIT, effective_hp = 30, has_renew = true } })),
    "RenewTank skips when tank already has Renew")

-- ============================================================================
-- InnerFire: missing buff, spell ready, safe in combat
-- ============================================================================
local idx_ifire = 14
-- Positive
assert_true(strategies[idx_ifire].matches(make_ctx(), make_state({ has_inner_fire = false })),
    "InnerFire matches when buff missing and in safe combat")
-- Negative: already has inner fire
assert_false(strategies[idx_ifire].matches(make_ctx(), make_state({ has_inner_fire = true })),
    "InnerFire skips when buff already present")

-- ============================================================================
-- PainSuppression: in combat, tank low, spell ready
-- ============================================================================
local idx_ps = 24
-- Positive
assert_true(strategies[idx_ps].matches(make_ctx(), make_state()),
    "PainSuppression matches when tank is low in combat")
-- Negative: out of combat
assert_false(strategies[idx_ps].matches(make_ctx({ in_combat = false }), make_state({ in_combat = false })),
    "PainSuppression skips when not in combat")
-- Negative: tank HP high
assert_false(strategies[idx_ps].matches(make_ctx(), make_state({ tank = { unit = NS.PLAYER_UNIT, effective_hp = 90 } })),
    "PainSuppression skips when tank HP is high")

-- ============================================================================
-- Summary
-- ============================================================================
print(string.format("test_discipline_dsl_priority: %d passed, %d failed", _pass, _fail))
if _fail > 0 then
    os.exit(1)
end
print("PASS test_discipline_dsl_priority")
