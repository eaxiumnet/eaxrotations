-- elemental_sod.lua -- Shaman Elemental rotation for Season of Discovery.
-- WHAT: Flame Shock/Lava Burst core with Chain Lightning AoE and mana recovery.
-- WHEN: SoD Elemental playstyle with a valid hostile target.
-- WHY: follows the pinned wowsims/sod phase-6 Elemental APL.
-- SAFETY: rune actions fail closed; malformed phase and legacy contexts cannot match.

local NS = _G.EaxRotations
if not NS then return nil end
if type(NS.is_sod) == "function" and not NS.is_sod() then return nil end

local spec_kit = require("shared/spec_kit_sylvanas")
local define = spec_kit.define_sod_action_for_class(NS.ShamanSpells or {})
local ACTION = {
    ShamanisticRage = define("ShamanisticRage", 425336, nil, "ShamanisticRage"),
    FeralSpirit = define("FeralSpirit", 440580, { rune_id = 440580, min_phase = 4 }, "FeralSpirit"),
    FlameShock = define("FlameShock", { 29228, 10448, 10447, 8053, 8052, 8050 }, nil, "FlameShock"),
    LavaBurst = define("LavaBurst", 408490, { rune_id = 408490 }, "LavaBurst"),
    ChainLightning = define("ChainLightning", { 10605, 2860, 930, 421 }, nil, "ChainLightning"),
    FireNova = define("FireNova", 408427, { rune_id = 408339, min_phase = 2 }, "FireNova"),
    LightningBolt = define("LightningBolt", { 15208, 15207, 10392, 10391, 943, 930, 548, 529, 403 }, nil, "LightningBolt"),
}

local function build_state(context)
    return spec_kit.safe_state({
        mana_pct = context and context.mana_pct or 100,
        enemy_count = context and context.enemy_count or 0,
        flame_shock_remains = context and context.flame_shock_remains or 0,
    }, { mana_pct = 100, enemy_count = 0, flame_shock_remains = 0 })
end

local function available(context, descriptor, needs_target)
    return type(context) == "table" and context.is_sod == true
        and (not needs_target or context.target ~= nil)
        and spec_kit.sod_action_available(context, descriptor)
end

local function cast_target(descriptor, label)
    return function(context) return NS.try_cast(descriptor.action, context.target, label) end
end

local strategies = {
    { name = "ShamanisticRage", matches = function(context, state)
        return available(context, ACTION.ShamanisticRage, false) and state.mana_pct <= 65
    end, execute = function()
        return NS.try_cast(ACTION.ShamanisticRage.action, NS.PLAYER_UNIT, "[SOD ELEMENTAL] ShamanisticRage", { skip_range = true })
    end },
    { name = "FeralSpirit", matches = function(context)
        return available(context, ACTION.FeralSpirit, false) and context.in_combat == true
    end, execute = function()
        return NS.try_cast(ACTION.FeralSpirit.action, NS.PLAYER_UNIT, "[SOD ELEMENTAL] FeralSpirit", { skip_range = true })
    end },
    { name = "FlameShock", matches = function(context, state)
        return available(context, ACTION.FlameShock, true) and state.flame_shock_remains < 3
    end, execute = cast_target(ACTION.FlameShock, "[SOD ELEMENTAL] FlameShock") },
    { name = "ChainLightning", matches = function(context, state)
        return available(context, ACTION.ChainLightning, true) and state.enemy_count >= 2
    end, execute = cast_target(ACTION.ChainLightning, "[SOD ELEMENTAL] ChainLightning") },
    { name = "LavaBurst", matches = function(context, state)
        return available(context, ACTION.LavaBurst, true) and state.flame_shock_remains >= 2
    end, execute = cast_target(ACTION.LavaBurst, "[SOD ELEMENTAL] LavaBurst") },
    { name = "FireNova", matches = function(context, state)
        return available(context, ACTION.FireNova, true) and state.enemy_count >= 3
    end, execute = cast_target(ACTION.FireNova, "[SOD ELEMENTAL] FireNova") },
    { name = "LightningBolt", matches = function(context)
        return available(context, ACTION.LightningBolt, true) and context.is_moving ~= true
    end, execute = cast_target(ACTION.LightningBolt, "[SOD ELEMENTAL] LightningBolt") },
}

if NS.rotation_registry and NS.rotation_registry.register then
    NS.rotation_registry:register("elemental", strategies, { get_state = build_state })
end

return { strategies = strategies, build_state = build_state, actions = ACTION }
