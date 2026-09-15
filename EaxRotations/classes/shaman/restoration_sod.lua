-- restoration_sod.lua -- Shaman Restoration rotation for Season of Discovery.
-- WHAT: Riptide and Healing Rain triage with Chain Heal, direct heals, and shield/totem sustain.
-- WHEN: SoD Restoration playstyle with normalized lowest-unit and injury context.
-- WHY: combines pinned wowsims/sod healing runes with the simulator's Classic heal toolkit.
--      2026-09-09 guide pass (Wowhead SoD shaman-healer rune guide): adds Earth Shield
--      (the leg-rune signature the guide's best-runes list leads with), the Nature's
--      Swiftness + Healing Wave emergency pair, and Mana Tide Totem (the spec's mana
--      game) — ids verified in the SoD client DBC (wowsims.db).
-- SAFETY: friendly targets and rune actions fail closed; occupied water totems are preserved.

local NS = _G.EaxRotations
if not NS then return nil end
if type(NS.is_sod) == "function" and not NS.is_sod() then return nil end

local spec_kit = require("shared/spec_kit_sylvanas")
local define = spec_kit.define_sod_action_for_class(NS.ShamanSpells or {})
local _ok_int, interrupt_manager = pcall(require, "shared/interrupt_manager_sylvanas")
local ACTION = {
    EarthShock = define("EarthShock", { 10414, 10413, 10412, 8046, 8045, 8044, 8042 }, nil, "EarthShock"),
    ShamanisticRage = define("ShamanisticRage", 425336, nil, "ShamanisticRage"),
    WaterShield = define("WaterShield", 408510, { rune_id = 408510 }, "WaterShield"),
    Riptide = define("Riptide", 408521, { rune_id = 408521, min_phase = 3 }, "Riptide"),
    HealingRain = define("HealingRain", 415236, { rune_id = 415236 }, "HealingRain"),
    ChainHeal = define("ChainHeal", { 10623, 10622, 1064 }, nil, "ChainHeal"),
    LesserHealingWave = define("LesserHealingWave", { 10468, 10467, 10466, 8010, 8008, 8004 }, nil, "LesserHealingWave"),
    HealingWave = define("HealingWave", { 25357, 10396, 10395, 8005, 959, 939, 913, 547, 332, 331 }, nil, "HealingWave"),
    HealingStreamTotem = define("HealingStreamTotem", { 10463, 10462, 6377, 6375, 5394 }, nil, "HealingStreamTotem"),
    -- 2026-09-09 guide-pass additions (DBC-verified):
    -- Earth Shield SoD cast = 408514 (Wowhead: leg rune, 9 charges, 10 min,
    -- "can only be placed on one target at a time"); 408519 is the proc-heal
    -- side, NOT a cast. TBC rank 32594 kept as a tail alias.
    EarthShield = define("EarthShield", { 408514, 32594, 32593, 974 }, { rune_id = 408514 }, "EarthShield"),
    -- Nature's Swiftness: shaman version is 16188 in this client (druid 17116;
    -- SLA rows prove the split), 3-min CD, next nature spell instant.
    NaturesSwiftness = define("NaturesSwiftness", 16188, nil, "NaturesSwiftness"),
    -- Mana Tide Totem: totem cast 16190 (4% mana/sec water slot); 16191 is the
    -- buff the totem applies.
    ManaTideTotem = define("ManaTideTotem", { 16190, 16191 }, nil, "ManaTideTotem"),
}

-- 2026-09-15 SoD healer wave: deficit-fit rank ladders from the shared
-- heal-value module (full SoD HW/LHW id overlap proved in scoping).
-- Fail-closed: without the module the lanes keep the single max-rank
-- action exactly as before; Chain Heal stays single-action (its rank
-- choice needs a group-deficit aggregate, same reason as TBC pass 1).
local HEALING_WAVE_RANKS, LESSER_HEALING_WAVE_RANKS
local _hv_ok, _HealValue = pcall(require, "shared/heal_value_sylvanas")
if _hv_ok and type(_HealValue) == "table" then
    NS.HealValue = NS.HealValue or _HealValue
    -- Positional spell_action calls: the SoD action-map generator's capture
    -- mock reads ids[1] positionally (rich-format tables would assert as
    -- "invalid action id"). The real engine handles a plain number id.
    local function _mk_hw(id)
        return NS.spell_action(id, "HealingWave")
    end
    local function _mk_lhw(id)
        return NS.spell_action(id, "LesserHealingWave")
    end
    HEALING_WAVE_RANKS = _HealValue.build_ladder("shaman", "HealingWave", _mk_hw, nil, "sod")
    LESSER_HEALING_WAVE_RANKS = _HealValue.build_ladder("shaman", "LesserHealingWave", _mk_lhw, nil, "sod")
end

local NATURES_SWIFTNESS_BUFF = { 16188 }

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
        earth_shield_up = context and context.earth_shield_up == true or false,
        player_hp = context and (context.player_hp or context.hp) or 100,
        natures_swiftness_up = (context and NS.buff_up and NS.buff_up(NS.PLAYER_UNIT or (NS.me and NS.me), NATURES_SWIFTNESS_BUFF) == true) or false,
    }, { lowest_hp = 100, injured_count = 0, mana_pct = 100,
        riptide_remains = 0, water_shield_up = false, water_totem_active = false,
        earth_shield_up = false, player_hp = 100, natures_swiftness_up = false })
end

local function available(context, descriptor)
    return type(context) == "table" and context.is_sod == true
        and spec_kit.sod_action_available(context, descriptor)
end

local cast_best_heal_rank = NS.cast_best_heal_rank or function() return nil end

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
    -- Shared interrupt-manager lane (strategy #1 -- must beat casts).
    (interrupt_manager and interrupt_manager.register_interrupt_spell
        and interrupt_manager.register_interrupt_spell("shaman", "EarthShock", { EarthShock = ACTION.EarthShock.action }))
        or { name = "EarthShockSkip", matches = function() return false end, execute = function() return false end },
    { name = "NaturesSwiftness", matches = function(context, state)
        return available(context, ACTION.NaturesSwiftness)
            and state.natures_swiftness_up == false and state.player_hp <= 30
    end, execute = cast_self(ACTION.NaturesSwiftness, "[SOD RESTORATION] NaturesSwiftness") },
    { name = "NaturesSwiftnessHealingWave", matches = function(context, state)
        return available(context, ACTION.NaturesSwiftness) and state.natures_swiftness_up
            and state.heal_target ~= nil and state.lowest_hp < 50
    end, execute = cast_heal(ACTION.HealingWave, "[SOD RESTORATION] NaturesSwiftnessHealingWave") },
    { name = "ShamanisticRage", matches = function(context, state)
        return available(context, ACTION.ShamanisticRage) and state.mana_pct <= 65
    end, execute = cast_self(ACTION.ShamanisticRage, "[SOD RESTORATION] ShamanisticRage") },
    { name = "WaterShield", matches = function(context, state)
        return available(context, ACTION.WaterShield) and state.mana_pct < 90 and not state.water_shield_up
    end, execute = cast_self(ACTION.WaterShield, "[SOD RESTORATION] WaterShield") },
    { name = "ManaTideTotem", matches = function(context, state)
        return available(context, ACTION.ManaTideTotem) and state.mana_pct <= 40
            and not state.water_totem_active
    end, execute = cast_self(ACTION.ManaTideTotem, "[SOD RESTORATION] ManaTideTotem") },
    { name = "EarthShield", matches = function(context, state)
        return available(context, ACTION.EarthShield) and state.heal_target ~= nil
            and state.injured_count >= 2 and state.earth_shield_up == false
    end, execute = cast_heal(ACTION.EarthShield, "[SOD RESTORATION] EarthShield") },
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
    end, execute = function(context, state)
        if LESSER_HEALING_WAVE_RANKS and state.heal_target then
            local chosen, rank_label = cast_best_heal_rank(LESSER_HEALING_WAVE_RANKS,
                state.heal_target, context, "[SOD RESTORATION] LesserHealingWave", { player_level = 60 })
            if chosen then return NS.try_cast(chosen, state.heal_target, rank_label) end
        end
        return NS.try_cast(ACTION.LesserHealingWave.action, state.heal_target, "[SOD RESTORATION] LesserHealingWave")
    end },
    { name = "HealingWave", matches = function(context, state)
        return available(context, ACTION.HealingWave) and state.heal_target ~= nil and state.lowest_hp < 70
    end, execute = function(context, state)
        if HEALING_WAVE_RANKS and state.heal_target then
            local chosen, rank_label = cast_best_heal_rank(HEALING_WAVE_RANKS,
                state.heal_target, context, "[SOD RESTORATION] HealingWave", { player_level = 60 })
            if chosen then return NS.try_cast(chosen, state.heal_target, rank_label) end
        end
        return NS.try_cast(ACTION.HealingWave.action, state.heal_target, "[SOD RESTORATION] HealingWave")
    end },
    { name = "HealingStreamTotem", matches = function(context, state)
        return available(context, ACTION.HealingStreamTotem) and state.injured_count >= 2
            and not state.water_totem_active
    end, execute = cast_self(ACTION.HealingStreamTotem, "[SOD RESTORATION] HealingStreamTotem") },
}

if NS.rotation_registry and NS.rotation_registry.register then
    NS.rotation_registry:register("restoration", strategies, { get_state = build_state })
end

return { strategies = strategies, build_state = build_state, actions = ACTION }
