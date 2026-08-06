-- warden_sod.lua -- Shaman Warden tank rotation for Season of Discovery.
-- WHAT: Rockbiter/Way of Earth tanking with Molten Blast, shocks, and fire totems.
-- WHEN: SoD Warden playstyle with the tank rune and verified main-hand imbue.
-- WHY: follows the pinned wowsims/sod phase-4 enhancement-tank APL.
-- SAFETY: passive rune, Rockbiter, rune actions, and occupied totem slots fail closed.

local NS = _G.EaxRotations
if not NS then return nil end
if type(NS.is_sod) == "function" and not NS.is_sod() then return nil end

local spec_kit = require("shared/spec_kit_sylvanas")
local define = spec_kit.define_sod_action_for_class(NS.ShamanSpells or {})
local ACTION = {
    WardenGate = define("WayOfEarth", 408531, { rune_id = 408531 }, "WayOfEarth"),
    ShamanisticRage = define("ShamanisticRage", 425336, nil, "ShamanisticRage"),
    FlameShock = define("FlameShock", { 29228, 10448, 10447, 8053, 8052, 8050 }, nil, "FlameShock"),
    MaelstromGate = define("MaelstromWeapon", 408498, { rune_id = 408498, min_phase = 2 }, "MaelstromWeapon"),
    ChainLightning = define("ChainLightning", { 10605, 2860, 930, 421 }, nil, "ChainLightning"),
    LightningBolt = define("LightningBolt", { 15208, 15207, 10392, 10391, 943, 930, 548, 529, 403 }, nil, "LightningBolt"),
    MoltenBlast = define("MoltenBlast", 425339, { rune_id = 425339 }, "MoltenBlast"),
    Stormstrike = define("Stormstrike", 17364, nil, "Stormstrike"),
    EarthShock = define("EarthShock", { 10414, 10413, 10412, 8046, 8045, 8044, 8042 }, nil, "EarthShock"),
    FrostShock = define("FrostShock", { 10473, 10472, 8058, 8056 }, nil, "FrostShock"),
    MagmaTotem = define("MagmaTotem", { 10587, 10586, 10585, 8190 }, nil, "MagmaTotem"),
    SearingTotem = define("SearingTotem", { 10438, 10437, 6365, 6364, 6363, 3599 }, nil, "SearingTotem"),
}

local function build_state(context)
    return spec_kit.safe_state({
        mana_pct = context and context.mana_pct or 100,
        enemy_count = context and context.enemy_count or 0,
        maelstrom_stacks = context and context.maelstrom_stacks or 0,
        flame_shock_remains = context and context.flame_shock_remains or 0,
        fire_totem_active = context and context.fire_totem_active == true or false,
        rockbiter_imbued = context and (context.mainhand_imbue == "rockbiter"
            or context.has_rockbiter_imbue == true) or false,
    }, { mana_pct = 100, enemy_count = 0, maelstrom_stacks = 0,
        flame_shock_remains = 0, fire_totem_active = false, rockbiter_imbued = false })
end

local function available(context, state, descriptor, needs_target)
    return type(context) == "table" and context.is_sod == true and state.rockbiter_imbued
        and (not needs_target or context.target ~= nil)
        and spec_kit.sod_action_available(context, ACTION.WardenGate)
        and spec_kit.sod_action_available(context, descriptor)
end

local function cast_target(descriptor, label)
    return function(context) return NS.try_cast(descriptor.action, context.target, label) end
end

local function cast_self(descriptor, label)
    return function() return NS.try_cast(descriptor.action, NS.PLAYER_UNIT, label, { skip_range = true }) end
end

local strategies = {
    { name = "ShamanisticRage", matches = function(context, state)
        return available(context, state, ACTION.ShamanisticRage, false) and state.mana_pct <= 65
    end, execute = cast_self(ACTION.ShamanisticRage, "[SOD WARDEN] ShamanisticRage") },
    { name = "FlameShock", matches = function(context, state)
        return available(context, state, ACTION.FlameShock, true) and state.flame_shock_remains <= 0
    end, execute = cast_target(ACTION.FlameShock, "[SOD WARDEN] FlameShock") },
    { name = "MaelstromChainLightning", matches = function(context, state)
        return available(context, state, ACTION.MaelstromGate, true)
            and state.maelstrom_stacks >= 5 and state.enemy_count >= 2
    end, execute = cast_target(ACTION.ChainLightning, "[SOD WARDEN] MaelstromChainLightning") },
    { name = "MoltenBlast", matches = function(context, state)
        return available(context, state, ACTION.MoltenBlast, true) and state.enemy_count >= 5
    end, execute = cast_target(ACTION.MoltenBlast, "[SOD WARDEN] MoltenBlast") },
    { name = "Stormstrike", matches = function(context, state)
        return available(context, state, ACTION.Stormstrike, true)
    end, execute = cast_target(ACTION.Stormstrike, "[SOD WARDEN] Stormstrike") },
    { name = "EarthShock", matches = function(context, state)
        return available(context, state, ACTION.EarthShock, true)
    end, execute = cast_target(ACTION.EarthShock, "[SOD WARDEN] EarthShock") },
    { name = "MaelstromLightningBolt", matches = function(context, state)
        return available(context, state, ACTION.MaelstromGate, true)
            and state.maelstrom_stacks >= 5 and state.enemy_count == 1
    end, execute = cast_target(ACTION.LightningBolt, "[SOD WARDEN] MaelstromLightningBolt") },
    { name = "FrostShock", matches = function(context, state)
        return available(context, state, ACTION.FrostShock, true)
    end, execute = cast_target(ACTION.FrostShock, "[SOD WARDEN] FrostShock") },
    { name = "MagmaTotem", matches = function(context, state)
        return available(context, state, ACTION.MagmaTotem, false)
            and state.enemy_count >= 2 and not state.fire_totem_active
    end, execute = cast_self(ACTION.MagmaTotem, "[SOD WARDEN] MagmaTotem") },
    { name = "SearingTotem", matches = function(context, state)
        return available(context, state, ACTION.SearingTotem, false)
            and state.enemy_count == 1 and not state.fire_totem_active
    end, execute = cast_self(ACTION.SearingTotem, "[SOD WARDEN] SearingTotem") },
}

if NS.rotation_registry and NS.rotation_registry.register then
    NS.rotation_registry:register("warden", strategies, { get_state = build_state })
end

return { strategies = strategies, build_state = build_state, actions = ACTION }
