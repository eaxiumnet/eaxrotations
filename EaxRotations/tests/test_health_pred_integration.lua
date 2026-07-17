-- test_health_pred_integration.lua — Integration tests for health_prediction direct API usage.
-- WHAT:  Verifies HealthPred.predicted_hp_pct / incoming_damage integrations across healer/tank specs.
-- WHEN:  regression gate for Phase 2 of integrate-advanced-modules plan.
-- WHY:   Ensures nil-guarded HealthPred usage falls back gracefully and influences strategy matches.
-- SAFETY: Pure unit tests with mocked NS and HealthPred.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local function assert_true(v, label) if not v then error(label or "assert_true failed", 2) end end
local function assert_false(v, label) if v then error(label or "assert_false failed", 2) end end
local function assert_eq(a, b, label) if a ~= b then error((label or "assert_eq") .. ": " .. tostring(a) .. " ~= " .. tostring(b), 2) end end

local function mock_unit(hp, max_hp)
    return {
        get_health_percentage = function() return hp end,
        get_health = function() return hp * (max_hp or 10000) / 100 end,
        get_max_health = function() return max_hp or 10000 end,
    }
end

local function run_helper_tests()
    local orig_hp = _G.EaxRotations and _G.EaxRotations.health_prediction
    _G.EaxRotations = _G.EaxRotations or {}
    _G.EaxRotations.health_prediction = nil
    package.loaded["shared/health_pred_helper_sylvanas"] = nil
    local M = require("shared/health_pred_helper_sylvanas")

    local unit = mock_unit(75)
    assert_eq(M.predicted_hp_pct(unit, 3.0), 75, "predicted_hp_pct returns current HP when no incoming damage")

    _G.EaxRotations.health_prediction = {
        get_incoming_damage = function() return 3000 end,
    }
    package.loaded["shared/health_pred_helper_sylvanas"] = nil
    M = require("shared/health_pred_helper_sylvanas")
    local pred = M.predicted_hp_pct(unit, 3.0)
    assert_true(pred < 75 and pred >= 0, "predicted_hp_pct reduces with incoming damage")

    _G.EaxRotations.health_prediction = nil
    package.loaded["shared/health_pred_helper_sylvanas"] = nil
    M = require("shared/health_pred_helper_sylvanas")
    assert_eq(M.incoming_damage(unit, 3.0), 0, "incoming_damage returns 0 without module")
    assert_eq(M.is_tank_role(unit), false, "is_tank_role returns false without module")

    _G.EaxRotations.health_prediction = orig_hp
end

local function run_priest_holy_test()
    package.loaded["shared/health_pred_helper_sylvanas"] = nil
    local mock_pred_hp = 100
    _G.EaxRotations = _G.EaxRotations or {}
    _G.EaxRotations.CLASS_ID = _G.EaxRotations.CLASS_ID or { PRIEST = 5 }
    package.loaded["shared/health_pred_helper_sylvanas"] = {
        incoming_damage = function() return 0 end,
        predicted_hp_pct = function() return mock_pred_hp end,
        is_tank_role = function() return false end,
        get_damage_types = function() return { physical_damage = {}, magical_damage = {} } end,
    }

    _G.EaxRotations = _G.EaxRotations or {}
    local NS = _G.EaxRotations
    NS.PriestSpells = NS.PriestSpells or {
        FlashHeal = 25235, GreaterHeal = 25213, PrayerofMending = 33076,
        CircleofHealing = 34866, BindingHeal = 32546, Renew = 25222,
        InnerFocus = 14751, Lightwell = 28275, MassDispel = 32375,
        DispelMagic = 988, CureDisease = 528, AbolishDisease = 552,
        FearWard = 6346, Shadowfiend = 34433, SymbolOfHope = 32548,
        DesperatePrayer = 25437, HolyFire = 25384, Smite = 25364,
        ShadowWordPain = 25368, PowerWordShield = 25218,
    }
    NS.PLAYER_UNIT = NS.PLAYER_UNIT or {}
    NS.GetPlayer = function() return { get_class = function() return 5 end, is_mounted = function() return false end, is_moving = function() return false end } end
    NS.import_helpers = function(...) return nil end
    NS.spell_ready = function() return true end
    NS.spell_exists = function() return true end
    NS.has_player_buff = function() return false end
    NS.debuff_remains = function() return 0 end
    NS.buff_up = function() return false end
    NS.gate_overheal = function() return false end
    NS.try_cast = function() return true end
    NS.healing_get_lowest_hp = function() return nil end
    NS.healing_get_tank = function() return nil end
    NS.get_friendly_target_entry = function() return nil end
    NS.rotation_registry = { register = function() end }
    NS.log = function() end

    package.loaded["classes/priest/healing_sylvanas"] = {
        scan_healing_targets = function() return {}, 0 end,
        count_subgroup_below_hp = function() return 0 end,
    }
    package.loaded["shared/profiler_helper_sylvanas"] = { start = function() end, stop = function() end }
    package.loaded["shared/fsr_manager_sylvanas"] = { is_inside_fsr = function() return false end, seconds_until_fsr = function() return 0 end, get_regen_delta = function() return 0 end }
    package.loaded["shared/preemptive_heal_sylvanas"] = { match = function() return false end, execute = function() return false end, DEFAULT_THRESHOLD = 40, get_penalty_adjusted_heal = function(id, size) return id, 1 end }
    package.loaded["shared/ts_helper_sylvanas"] = nil

    local result = dofile("EaxRotations/classes/priest/holy_sylvanas.lua")
    local strategies = result and result.strategies or {}
    local function find(name) for i = 1, #strategies do if strategies[i].name == name then return strategies[i] end end return nil end
    local ef = find("EmergencyFlashHeal")
    assert_true(ef ~= nil, "Priest Holy EmergencyFlashHeal strategy exists")

    mock_pred_hp = 25
    local ctx = { in_combat = true, is_moving = false, settings = {}, mana_pct = 100, hp = 100 }
    local unit = mock_unit(60)
    local state = { flash_heal_ready = true, lowest_hp = 60, lowest = { unit = unit, effective_hp = 60, hp = 60 } }
    assert_true(ef.matches(ctx, state), "EmergencyFlashHeal matches when current HP > threshold but predicted HP < threshold")

    mock_pred_hp = 75
    state.lowest = { unit = unit, effective_hp = 80, hp = 80 }
    state.lowest_hp = 80
    assert_false(ef.matches(ctx, state), "EmergencyFlashHeal does not match when both current and predicted HP are high")

    mock_pred_hp = 90
    state.lowest = { unit = unit, effective_hp = 25, hp = 25 }
    state.lowest_hp = 25
    assert_true(ef.matches(ctx, state), "EmergencyFlashHeal matches when current HP is low regardless of predicted HP")
end

local function run_priest_discipline_test()
    package.loaded["shared/health_pred_helper_sylvanas"] = nil
    local mock_pred_hp = 100
    package.loaded["shared/health_pred_helper_sylvanas"] = {
        incoming_damage = function() return 0 end,
        predicted_hp_pct = function() return mock_pred_hp end,
        is_tank_role = function() return false end,
        get_damage_types = function() return { physical_damage = {}, magical_damage = {} } end,
    }

    _G.EaxRotations = _G.EaxRotations or {}
    local NS = _G.EaxRotations
    NS.PriestSpells = NS.PriestSpells or {
        PowerWordShield = 25218, PrayerofMending = 33076, FlashHeal = 25235,
        GreaterHeal = 25213, Renew = 25222, BindingHeal = 32546,
        CircleofHealing = 34866, PrayerOfHealing = 25308, DispelMagic = 988,
        MassDispel = 32375, DivineSpirit = 25312, Fade = 25429, FearWard = 6346,
        InnerFire = 25431, InnerFocus = 14751, PainSuppression = 33206,
        PowerInfusion = 10060, PowerWordFortitude = 25389, PrayerOfFortitude = 25392,
        PsychicScream = 10890, ShackleUndead = 10955, ShadowWordPain = 25368,
        Shadowfiend = 34433, Smite = 25364, SymbolOfHope = 32548, HolyFire = 25384,
    }
    NS.PLAYER_UNIT = NS.PLAYER_UNIT or {}
    NS.GetPlayer = function() return { get_class = function() return 5 end, is_mounted = function() return false end, is_moving = function() return false end } end
    NS.spell_ready = function() return true end
    NS.spell_exists = function() return true end
    NS.debuff_remains = function() return 0 end
    NS.buff_up = function() return false end
    NS.debuff_up = function() return false end
    NS.has_player_buff = function() return false end
    NS.cooldown_remains = function() return 0 end
    NS.gate_overheal = function() return false end
    NS.try_cast = function() return true end
    NS.same_unit = function(a, b) return a == b end
    NS.unit_is_tank = function() return false end
    NS.GetEnemiesInRange = function() return {} end
    NS.rotation_registry = { register = function() end }
    NS.log = function() end

    package.loaded["classes/priest/healing_sylvanas"] = {
        scan_healing_targets = function() return {}, 0 end,
        pws_absorb_remaining = function() return 0 end,
    }
    package.loaded["shared/fsr_manager_sylvanas"] = { is_inside_fsr = function() return false end, seconds_until_fsr = function() return 0 end, get_regen_delta = function() return 0 end }
    package.loaded["shared/preemptive_heal_sylvanas"] = { match = function() return false end, execute = function() return false end, DEFAULT_THRESHOLD = 40 }

    local result = dofile("EaxRotations/classes/priest/discipline_sylvanas.lua")
    local strategies = result and result.strategies or {}
    local function find(name) for i = 1, #strategies do if strategies[i].name == name then return strategies[i] end end return nil end
    local pws = find("PowerWordShieldTank")
    assert_true(pws ~= nil, "Priest Discipline PowerWordShieldTank strategy exists")

    mock_pred_hp = 25
    local ctx = { in_combat = true, is_moving = false, settings = {} }
    local unit = mock_unit(60)
    local state = { pws_ready = true, tank = { unit = unit, effective_hp = 60, has_weakened_soul = false } }
    assert_true(pws.matches(ctx, state), "PowerWordShieldTank matches when current HP > threshold but predicted HP < threshold")

    mock_pred_hp = 75
    state.tank = { unit = unit, effective_hp = 80, has_weakened_soul = false }
    assert_false(pws.matches(ctx, state), "PowerWordShieldTank does not match when both current and predicted HP are high")

    mock_pred_hp = 90
    state.tank = { unit = unit, effective_hp = 25, has_weakened_soul = false }
    assert_true(pws.matches(ctx, state), "PowerWordShieldTank matches when current HP is low regardless of predicted HP")
end

local function run_shaman_restoration_test()
    package.loaded["shared/health_pred_helper_sylvanas"] = nil
    local mock_pred_hp = 100
    package.loaded["shared/health_pred_helper_sylvanas"] = {
        incoming_damage = function() return 0 end,
        predicted_hp_pct = function() return mock_pred_hp end,
        is_tank_role = function() return false end,
        get_damage_types = function() return { physical_damage = {}, magical_damage = {} } end,
    }

    _G.EaxRotations = _G.EaxRotations or {}
    local NS = _G.EaxRotations
    NS.ShamanSpells = NS.ShamanSpells or {
        ChainHeal = 25423, HealingWave = 25396, LesserHealingWave = 25420,
        NaturesSwiftness = 16188, WaterShield = 33736, EarthShield = 32594,
        Bloodlust = 2825, ManaTideTotem = 16190,
    }
    NS.PLAYER_UNIT = NS.PLAYER_UNIT or {}
    NS.GetPlayer = function() return { is_mounted = function() return false end } end
    NS.spell_ready = function() return true end
    NS.spell_exists = function() return true end
    NS.buff_up = function() return false end
    NS.buff_stacks = function() return 0 end
    NS.buff_remains = function() return 0 end
    NS.debuff_remains = function() return 0 end
    NS.unit_mana_pct = function() return 100 end
    NS.unit_health_pct = function() return 100 end
    NS.gate_overheal = function() return false end
    NS.try_cast = function() return true end
    NS.healing_get_lowest_hp = function() return nil end
    NS.healing_get_tank = function() return nil end
    NS.get_friendly_target_entry = function() return nil end
    NS.rotation_registry = { register = function() end }
    NS.log = function() end

    package.loaded["classes/shaman/healing_sylvanas"] = {
        scan_healing_targets = function() return {}, 0 end,
        select_heal = function(context, state, target)
            local hp = target.effective_hp or 100
            if hp > 70 then return nil end
            return { spell = NS.ShamanSpells.HealingWave, label = "HW" }
        end,
    }
    package.loaded["shared/fsr_manager_sylvanas"] = { is_inside_fsr = function() return false end, seconds_until_fsr = function() return 0 end, get_regen_delta = function() return 0 end }
    package.loaded["shared/preemptive_heal_sylvanas"] = { match = function() return false end, execute = function() return false end, DEFAULT_THRESHOLD = 40, get_penalty_adjusted_heal = function(id, size) return id, 1 end }
    package.loaded["shared/tbc_data_sylvanas"] = { SPELLS = { shaman = { water_shield = { 33736 }, lightning_shield = { 25472 } } } }

    local result = dofile("EaxRotations/classes/shaman/restoration_sylvanas.lua")
    local strategies = result and result.strategies or {}
    local function find(name) for i = 1, #strategies do if strategies[i].name == name then return strategies[i] end end return nil end
    local smart = find("SmartHeal")
    assert_true(smart ~= nil, "Shaman Restoration SmartHeal strategy exists")

    mock_pred_hp = 25
    local ctx = { in_combat = true, is_moving = false, settings = {}, mana_pct = 100 }
    local unit = mock_unit(60)
    local state = { lowest = { unit = unit, effective_hp = 60, hp = 60, deficit = 4000 } }
    assert_true(smart.matches(ctx, state), "SmartHeal matches when current HP > threshold but predicted HP < threshold")

    mock_pred_hp = 75
    state.lowest = { unit = unit, effective_hp = 80, hp = 80, deficit = 2000 }
    assert_false(smart.matches(ctx, state), "SmartHeal does not match when both current and predicted HP are high")

    mock_pred_hp = 25
    state.lowest = { unit = unit, effective_hp = 100, hp = 100, deficit = 0, max_hp = 10000 }
    assert_true(smart.matches(ctx, state), "SmartHeal matches when current HP is full but predicted HP is low")
end

local function run_druid_bear_test()
    package.loaded["shared/health_pred_helper_sylvanas"] = nil
    local mock_pred_hp = 100
    package.loaded["shared/health_pred_helper_sylvanas"] = {
        incoming_damage = function() return 0 end,
        predicted_hp_pct = function() return mock_pred_hp end,
        is_tank_role = function() return false end,
        get_damage_types = function() return { physical_damage = {}, magical_damage = {} } end,
    }

    _G.EaxRotations = _G.EaxRotations or {}
    local NS = _G.EaxRotations
    NS.DruidSpells = NS.DruidSpells or {
        Barkskin = 22812, Bash = 8983, BearForm = 9634, ChallengingRoar = 5209,
        DemoralizingRoar = 26998, Enrage = 5229, FaerieFireFeral = 27011,
        FeralCharge = 16979, FrenziedRegeneration = 26999, GiftOfTheWild = 26991,
        Growl = 6795, Lacerate = 33745, MangleBear = 33987, MarkOfTheWild = 26990,
        Maul = 26996, SwipeBear = 26997, Thorns = 26992,
    }
    NS.PLAYER_UNIT = NS.PLAYER_UNIT or {}
    NS.GetPlayer = function() return { get_class = function() return 11 end, is_mounted = function() return false end } end
    NS.spell_ready = function() return true end
    NS.spell_exists = function(spell) return true end
    NS.buff_up = function() return false end
    NS.buff_remains = function() return 0 end
    NS.debuff_remains = function() return 0 end
    NS.get_debuff_stacks = function() return 0 end
    NS.debuff_stacks = function() return 0 end
    NS.cooldown_remains = function() return 0 end
    NS.try_cast = function() return true end
    NS.GetEnemiesCount = function() return 1 end
    NS.get_player_stance = function() return 1 end
    NS.has_form = function(form) return form == "bear" end
    NS.time_now = function() return 0 end
    NS.swing_time_until = function() return 99 end
    NS.rotation_registry = { register = function() end }
    NS.log = function() end

    local result = dofile("EaxRotations/classes/druid/bear_sylvanas.lua")
    local strategies = result and result.strategies or {}
    local function find(name) for i = 1, #strategies do if strategies[i].name == name then return strategies[i] end end return nil end
    local fr = find("FrenziedRegeneration")
    assert_true(fr ~= nil, "Druid Bear FrenziedRegeneration strategy exists")

    local me = mock_unit(60)
    NS.GetPlayer = function() return me end
    mock_pred_hp = 25
    local ctx = { in_combat = true, settings = { use_cooldowns = true }, me = me, target = {}, has_valid_enemy_target = true, target_hp = 100, ttd = 999, target_range = 5, enemy_count = 1, enemies_count = 1, stance = 1, hp = 60, rage = 50, level = 70 }
    assert_true(fr.matches(ctx, {}), "FrenziedRegeneration matches when current HP > threshold but predicted HP < threshold")

    mock_pred_hp = 75
    ctx.hp = 60
    assert_false(fr.matches(ctx, {}), "FrenziedRegeneration does not match when both current and predicted HP are above threshold")

    ctx.hp = 25
    mock_pred_hp = 90
    assert_true(fr.matches(ctx, {}), "FrenziedRegeneration matches when current HP is below threshold regardless of predicted HP")
end

run_helper_tests()
run_priest_holy_test()
run_priest_discipline_test()
run_shaman_restoration_test()
run_druid_bear_test()

print("PASS test_health_pred_integration")
