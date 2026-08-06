-- enhancement_sod.lua -- Shaman Enhancement rotation for Season of Discovery.
-- WHAT: Feral Spirit burst, Maelstrom casts, Stormstrike, Lava Lash, shocks, and shields.
-- WHEN: SoD Enhancement playstyle with a valid hostile target.
-- WHY: follows the pinned wowsims/sod phase-6 dual-wield Enhancement APL.
-- SAFETY: rune actions and Maelstrom consumers fail closed; totems are not overwritten.

local NS = _G.EaxRotations
if not NS then return nil end
if type(NS.is_sod) == "function" and not NS.is_sod() then return nil end

local spec_kit = require("shared/spec_kit_sylvanas")
local define = spec_kit.define_sod_action_for_class(NS.ShamanSpells or {})
local ACTION = {
    FeralSpirit = define("FeralSpirit", 440580, { rune_id = 440580, min_phase = 4 }, "FeralSpirit"),
    ShamanisticRage = define("ShamanisticRage", 425336, nil, "ShamanisticRage"),
    LavaBurst = define("LavaBurst", 408490, { rune_id = 408490 }, "LavaBurst"),
    MaelstromGate = define("MaelstromWeapon", 408498, { rune_id = 408498, min_phase = 2 }, "MaelstromWeapon"),
    LightningBolt = define("LightningBolt", { 15208, 15207, 10392, 10391, 943, 930, 548, 529, 403 }, nil, "LightningBolt"),
    ChainLightning = define("ChainLightning", { 10605, 2860, 930, 421 }, nil, "ChainLightning"),
    Stormstrike = define("Stormstrike", 17364, nil, "Stormstrike"),
    LavaLash = define("LavaLash", 408507, { rune_id = 408507 }, "LavaLash"),
    LightningShield = define("LightningShield", { 10432, 10431, 8134, 945, 905, 325, 324 }, nil, "LightningShield"),
    FlameShock = define("FlameShock", { 29228, 10448, 10447, 8053, 8052, 8050 }, nil, "FlameShock"),
    EarthShock = define("EarthShock", { 10414, 10413, 10412, 8046, 8045, 8044, 8042 }, nil, "EarthShock"),
}

local function build_state(context)
    return spec_kit.safe_state({
        mana_pct = context and context.mana_pct or 100,
        enemy_count = context and context.enemy_count or 0,
        maelstrom_stacks = context and context.maelstrom_stacks or 0,
        flame_shock_remains = context and context.flame_shock_remains or 0,
        lightning_shield_up = context and context.lightning_shield_up == true or false,
        auto_swing_remains = context and (context.auto_swing_remains or context.melee_swing_remains) or 0,
    }, { mana_pct = 100, enemy_count = 0, maelstrom_stacks = 0,
        flame_shock_remains = 0, lightning_shield_up = false, auto_swing_remains = 0 })
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
    { name = "FeralSpirit", matches = function(context)
        return available(context, ACTION.FeralSpirit, false) and context.in_combat == true
    end, execute = function()
        return NS.try_cast(ACTION.FeralSpirit.action, NS.PLAYER_UNIT, "[SOD ENHANCEMENT] FeralSpirit", { skip_range = true })
    end },
    { name = "ShamanisticRage", matches = function(context, state)
        return available(context, ACTION.ShamanisticRage, false) and state.mana_pct <= 65
    end, execute = function()
        return NS.try_cast(ACTION.ShamanisticRage.action, NS.PLAYER_UNIT, "[SOD ENHANCEMENT] ShamanisticRage", { skip_range = true })
    end },
    { name = "LavaBurst", matches = function(context, state)
        return available(context, ACTION.LavaBurst, true) and state.auto_swing_remains >= 2
    end, execute = cast_target(ACTION.LavaBurst, "[SOD ENHANCEMENT] LavaBurst") },
    { name = "MaelstromChainLightning", matches = function(context, state)
        return available(context, ACTION.MaelstromGate, true) and state.maelstrom_stacks >= 4
            and state.enemy_count >= 2
    end, execute = cast_target(ACTION.ChainLightning, "[SOD ENHANCEMENT] MaelstromChainLightning") },
    { name = "MaelstromLightningBolt", matches = function(context, state)
        return available(context, ACTION.MaelstromGate, true) and state.maelstrom_stacks >= 5
    end, execute = cast_target(ACTION.LightningBolt, "[SOD ENHANCEMENT] MaelstromLightningBolt") },
    { name = "Stormstrike", matches = function(context)
        return available(context, ACTION.Stormstrike, true)
    end, execute = cast_target(ACTION.Stormstrike, "[SOD ENHANCEMENT] Stormstrike") },
    { name = "LavaLash", matches = function(context)
        return available(context, ACTION.LavaLash, true)
            and (context.offhand_imbue == "flametongue" or context.offhand_imbue == "windfury")
    end, execute = cast_target(ACTION.LavaLash, "[SOD ENHANCEMENT] LavaLash") },
    { name = "LightningShield", matches = function(context, state)
        return available(context, ACTION.LightningShield, false) and not state.lightning_shield_up
    end, execute = function()
        return NS.try_cast(ACTION.LightningShield.action, NS.PLAYER_UNIT, "[SOD ENHANCEMENT] LightningShield", { skip_range = true })
    end },
    { name = "FlameShock", matches = function(context, state)
        return available(context, ACTION.FlameShock, true) and state.flame_shock_remains <= 0
            and (context.ttd == nil or context.ttd > 12)
    end, execute = cast_target(ACTION.FlameShock, "[SOD ENHANCEMENT] FlameShock") },
    { name = "EarthShock", matches = function(context)
        return available(context, ACTION.EarthShock, true)
    end, execute = cast_target(ACTION.EarthShock, "[SOD ENHANCEMENT] EarthShock") },
}

if NS.rotation_registry and NS.rotation_registry.register then
    NS.rotation_registry:register("enhancement", strategies, { get_state = build_state })
end

return { strategies = strategies, build_state = build_state, actions = ACTION }
