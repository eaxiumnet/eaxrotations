-- restoration_sod.lua -- Shaman Restoration rotation for Season of Discovery.
-- WHAT: Riptide and Healing Rain triage with Chain Heal, direct heals, and shield/totem sustain.
-- WHEN: SoD Restoration playstyle with normalized lowest-unit and injury context.
-- WHY: combines pinned wowsims/sod healing runes with the simulator's Classic heal toolkit.
-- SAFETY: friendly targets and rune actions fail closed; occupied water totems are preserved.

local NS = _G.EaxRotations
if not NS then return nil end
if type(NS.is_sod) == "function" and not NS.is_sod() then return nil end

local spec_kit = require("shared/spec_kit_sylvanas")
local define = spec_kit.define_sod_action_for_class(NS.ShamanSpells or {})
local ACTION = {
    ShamanisticRage = define("ShamanisticRage", 425336, nil, "ShamanisticRage"),
    WaterShield = define("WaterShield", 408510, { rune_id = 408510 }, "WaterShield"),
    Riptide = define("Riptide", 408521, { rune_id = 408521, min_phase = 3 }, "Riptide"),
    HealingRain = define("HealingRain", 415236, { rune_id = 415236 }, "HealingRain"),
    ChainHeal = define("ChainHeal", { 10623, 10622, 1064 }, nil, "ChainHeal"),
    LesserHealingWave = define("LesserHealingWave", { 10468, 10467, 10466, 8010, 8008, 8004 }, nil, "LesserHealingWave"),
    HealingWave = define("HealingWave", { 25357, 10396, 10395, 8005, 959, 939, 913, 547, 332, 331 }, nil, "HealingWave"),
    HealingStreamTotem = define("HealingStreamTotem", { 10463, 10462, 6377, 6375, 5394 }, nil, "HealingStreamTotem"),
}

local function build_state(context)
    local lowest = context and context.lowest or nil
    local heal_target = lowest and lowest.unit or context and context.lowest_unit or nil
    local lowest_hp = lowest and lowest.hp or context and context.lowest_hp or 100
    return spec_kit.safe_state({
        heal_target = heal_target,
        lowest_hp = lowest_hp,
        injured_count = context and context.injured_count or 0,
        mana_pct = context and context.mana_pct or 100,
        riptide_remains = context and context.riptide_remains or 0,
        water_shield_up = context and context.water_shield_up == true or false,
        water_totem_active = context and context.water_totem_active == true or false,
    }, { lowest_hp = 100, injured_count = 0, mana_pct = 100,
        riptide_remains = 0, water_shield_up = false, water_totem_active = false })
end

local function available(context, descriptor)
    return type(context) == "table" and context.is_sod == true
        and spec_kit.sod_action_available(context, descriptor)
end

local function cast_heal(descriptor, label)
    return function(context, state)
        local target = state and state.heal_target
        if not target then return false end
        return NS.try_cast(descriptor.action, target, label)
    end
end

local function cast_self(descriptor, label)
    return function() return NS.try_cast(descriptor.action, NS.PLAYER_UNIT, label, { skip_range = true }) end
end

local strategies = {
    { name = "ShamanisticRage", matches = function(context, state)
        return available(context, ACTION.ShamanisticRage) and state.mana_pct <= 65
    end, execute = cast_self(ACTION.ShamanisticRage, "[SOD RESTORATION] ShamanisticRage") },
    { name = "WaterShield", matches = function(context, state)
        return available(context, ACTION.WaterShield) and state.mana_pct < 90 and not state.water_shield_up
    end, execute = cast_self(ACTION.WaterShield, "[SOD RESTORATION] WaterShield") },
    { name = "Riptide", matches = function(context, state)
        return available(context, ACTION.Riptide) and state.heal_target ~= nil
            and state.lowest_hp < 90 and state.riptide_remains < 3
    end, execute = cast_heal(ACTION.Riptide, "[SOD RESTORATION] Riptide") },
    { name = "HealingRain", matches = function(context, state)
        return available(context, ACTION.HealingRain) and state.heal_target ~= nil
            and state.injured_count >= 3 and state.lowest_hp < 85
    end, execute = cast_heal(ACTION.HealingRain, "[SOD RESTORATION] HealingRain") },
    { name = "ChainHeal", matches = function(context, state)
        return available(context, ACTION.ChainHeal) and state.heal_target ~= nil
            and state.injured_count >= 2 and state.lowest_hp < 85
    end, execute = cast_heal(ACTION.ChainHeal, "[SOD RESTORATION] ChainHeal") },
    { name = "LesserHealingWave", matches = function(context, state)
        return available(context, ACTION.LesserHealingWave) and state.heal_target ~= nil and state.lowest_hp < 35
    end, execute = cast_heal(ACTION.LesserHealingWave, "[SOD RESTORATION] LesserHealingWave") },
    { name = "HealingWave", matches = function(context, state)
        return available(context, ACTION.HealingWave) and state.heal_target ~= nil and state.lowest_hp < 70
    end, execute = cast_heal(ACTION.HealingWave, "[SOD RESTORATION] HealingWave") },
    { name = "HealingStreamTotem", matches = function(context, state)
        return available(context, ACTION.HealingStreamTotem) and state.injured_count >= 2
            and not state.water_totem_active
    end, execute = cast_self(ACTION.HealingStreamTotem, "[SOD RESTORATION] HealingStreamTotem") },
}

if NS.rotation_registry and NS.rotation_registry.register then
    NS.rotation_registry:register("restoration", strategies, { get_state = build_state })
end

return { strategies = strategies, build_state = build_state, actions = ACTION }
