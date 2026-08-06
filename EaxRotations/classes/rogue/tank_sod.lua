-- tank_sod.lua -- Rogue tank rotation for Season of Discovery.
-- WHAT: maintains Blade Dance, uses Main Gauche, and builds threat through finishers.
-- WHEN: SoD tank playstyle with Just a Flesh Wound and a valid hostile target.
-- WHY: mirrors the pinned wowsims/sod tank model's avoidance and threat runes.
-- SAFETY: every active action is phase/rune gated; passive tank and poison state fail closed.

local NS = _G.EaxRotations
if not NS then return nil end
if type(NS.is_sod) == "function" and not NS.is_sod() then return nil end

local spec_kit = require("shared/spec_kit_sylvanas")
local define = spec_kit.define_sod_action_for_class(NS.RogueSpells or {})
local ACTION = {
    TankGate = define("JustAFleshWound", 400014, { rune_id = 400014 }, "JustAFleshWound"),
    BladeDance = define("BladeDance", 400012, { rune_id = 400012 }, "BladeDance"),
    MainGauche = define("MainGauche", 424919, { rune_id = 424919 }, "MainGauche"),
    CrimsonTempest = define("CrimsonTempest", 412096, { rune_id = 412096, min_phase = 4 }, "CrimsonTempest"),
    Envenom = define("Envenom", 399963, { rune_id = 399963 }, "Envenom"),
    Eviscerate = define("Eviscerate", { 31016, 11300, 11299, 8624, 8623, 6762, 6761, 6760, 2098 }, nil, "Eviscerate"),
    SaberSlash = define("SaberSlash", 424785, { rune_id = 424785 }, "SaberSlash"),
    SinisterStrike = define("SinisterStrike", { 11294, 11293, 8621, 1760, 1759, 1758, 1757, 1752 }, nil, "SinisterStrike"),
}

local function build_state(context)
    return spec_kit.safe_state({
        combo_points = context and context.combo_points or 0,
        enemy_count = context and context.enemy_count or 0,
        poison_stacks = context and (context.poison_stacks or context.deadly_poison_stacks) or 0,
        blade_dance_remains = context and context.blade_dance_remains or 0,
        crimson_tempest_remains = context and context.crimson_tempest_remains or 0,
    }, { combo_points = 0, enemy_count = 0, poison_stacks = 0,
        blade_dance_remains = 0, crimson_tempest_remains = 0 })
end

local function available(context, descriptor)
    return type(context) == "table" and context.is_sod == true and context.target ~= nil
        and spec_kit.sod_action_available(context, ACTION.TankGate)
        and spec_kit.sod_action_available(context, descriptor)
end

local function cast(descriptor, label)
    return function(context) return NS.try_cast(descriptor.action, context.target, label) end
end

local strategies = {
    { name = "BladeDance", matches = function(context, state)
        return available(context, ACTION.BladeDance) and state.combo_points >= 1 and state.blade_dance_remains < 2
    end, execute = cast(ACTION.BladeDance, "[SOD TANK] BladeDance") },
    { name = "MainGauche", matches = function(context)
        return available(context, ACTION.MainGauche)
    end, execute = cast(ACTION.MainGauche, "[SOD TANK] MainGauche") },
    { name = "CrimsonTempest", matches = function(context, state)
        return available(context, ACTION.CrimsonTempest) and state.enemy_count >= 2
            and state.combo_points >= 4 and state.crimson_tempest_remains < 2
    end, execute = cast(ACTION.CrimsonTempest, "[SOD TANK] CrimsonTempest") },
    { name = "Envenom", matches = function(context, state)
        return available(context, ACTION.Envenom) and state.combo_points >= 5 and state.poison_stacks > 0
    end, execute = cast(ACTION.Envenom, "[SOD TANK] Envenom") },
    { name = "Eviscerate", matches = function(context, state)
        return available(context, ACTION.Eviscerate) and state.combo_points >= 5
    end, execute = cast(ACTION.Eviscerate, "[SOD TANK] Eviscerate") },
    { name = "SaberSlash", matches = function(context, state)
        return available(context, ACTION.SaberSlash) and state.combo_points < 5
    end, execute = cast(ACTION.SaberSlash, "[SOD TANK] SaberSlash") },
    { name = "SinisterStrike", matches = function(context, state)
        return available(context, ACTION.SinisterStrike) and state.combo_points < 5
    end, execute = cast(ACTION.SinisterStrike, "[SOD TANK] SinisterStrike") },
}

if NS.rotation_registry and NS.rotation_registry.register then
    NS.rotation_registry:register("tank", strategies, { get_state = build_state })
end

return { strategies = strategies, build_state = build_state, actions = ACTION }
