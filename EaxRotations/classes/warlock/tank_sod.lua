local NS = _G.EaxRotations
if not NS then return nil end
if type(NS.is_sod) == "function" and not NS.is_sod() then return nil end

local spec_kit = require("shared/spec_kit_sylvanas")
local define = spec_kit.define_sod_action_for_class({})
local ACTION = {
    Metamorphosis = define("SodMetamorphosis", 403789, { rune_id = 403789, min_phase = 1 }, "Metamorphosis"),
    DemonicGrace = define("SodDemonicGrace", 425463, { rune_id = 425463, min_phase = 4 }, "DemonicGrace"),
    ShadowCleave = define("SodShadowCleave", 403851, { rune_id = 403789, min_phase = 1 }, "ShadowCleave"),
    HealthFunnel = define("SodHealthFunnel", 11695, {}, "HealthFunnel"),
    CurseOfRecklessness = define("SodCurseOfRecklessness", 11717, {}, "CurseOfRecklessness"),
    Incinerate = define("SodIncinerate", 412758, { rune_id = 412758, min_phase = 1 }, "Incinerate"),
    SearingPain = define("SodSearingPain", 17923, {}, "SearingPain"),
    LifeTap = define("SodLifeTap", 11689, {}, "LifeTap"),
    Immolate = define("SodImmolate", 11668, {}, "Immolate"),
    Corruption = define("SodCorruption", 11672, {}, "Corruption"),
    DrainLife = define("SodDrainLife", 11700, {}, "DrainLife"),
}

local function number(context, key, fallback)
    return type(context[key]) == "number" and context[key] or fallback
end

local function build_state(context)
    context = type(context) == "table" and context or {}
    local has_pet = context.pet ~= nil or context.has_pet == true
    return spec_kit.safe_state({
        has_pet = has_pet,
        pet_alive = context.pet_alive == true
            or (context.pet_alive == nil and context.pet ~= nil and context.pet_dead ~= true),
        pet_dead = context.pet_dead == true,
        pet_hp_pct = number(context, "pet_hp_pct", 100),
        mana_pct = number(context, "mana_pct", 100),
        enemy_count = number(context, "enemy_count", 1),
        target_hp_pct = number(context, "target_hp_pct", 100),
        curse_remains = number(context, "curse_remains", 0),
        immolate_remains = number(context, "immolate_remains", 0),
        corruption_remains = number(context, "corruption_remains", 0),
        shadow_cleave_remains = number(context, "shadow_cleave_remains", 0),
        metamorphosis_active = context.metamorphosis_active == true,
    }, {
        pet_hp_pct = 100, mana_pct = 100, enemy_count = 0, target_hp_pct = 100,
        curse_remains = 0, immolate_remains = 0, corruption_remains = 0,
        shadow_cleave_remains = 0, metamorphosis_active = false,
    })
end

local function available(context, state, descriptor, target_required)
    return type(context) == "table" and context.is_sod == true and context.in_combat == true
        and (not target_required or context.target ~= nil)
        and spec_kit.sod_action_available(context, ACTION.Metamorphosis)
        and spec_kit.sod_action_available(context, descriptor)
        and state.metamorphosis_active
end

local function ready(descriptor, target)
    return type(NS.spell_ready) == "function" and NS.spell_ready(descriptor.action, target) == true
end

local function cast(descriptor, target, label)
    return NS.try_cast(descriptor.action, target, "[SOD WARLOCK TANK] " .. label)
end

local strategies = {
    { name = "Metamorphosis", matches = function(c, s)
        return type(c) == "table" and c.is_sod == true and c.in_combat == true and c.target ~= nil
            and not s.metamorphosis_active and spec_kit.sod_action_available(c, ACTION.Metamorphosis)
            and ready(ACTION.Metamorphosis, c.me)
    end, execute = function(c) return cast(ACTION.Metamorphosis, c.me, "Metamorphosis") end },
    { name = "DemonicGrace", matches = function(c, s)
        return available(c, s, ACTION.DemonicGrace, false) and ready(ACTION.DemonicGrace, c.me)
    end, execute = function(c) return cast(ACTION.DemonicGrace, c.me, "DemonicGrace") end },
    { name = "HealthFunnel", matches = function(c, s)
        return available(c, s, ACTION.HealthFunnel, false) and s.pet_alive and s.pet_hp_pct <= 35
            and ready(ACTION.HealthFunnel, c.pet)
    end, execute = function(c) return cast(ACTION.HealthFunnel, c.pet, "HealthFunnel") end },
    { name = "CurseOfRecklessness", matches = function(c, s)
        return available(c, s, ACTION.CurseOfRecklessness, true) and s.curse_remains <= 0
            and ready(ACTION.CurseOfRecklessness, c.target)
    end, execute = function(c) return cast(ACTION.CurseOfRecklessness, c.target, "CurseOfRecklessness") end },
    { name = "ShadowCleave", matches = function(c, s)
        return available(c, s, ACTION.ShadowCleave, true) and s.enemy_count >= 2
            and s.shadow_cleave_remains <= 0 and ready(ACTION.ShadowCleave, c.target)
    end, execute = function(c) return cast(ACTION.ShadowCleave, c.target, "ShadowCleave") end },
    { name = "Incinerate", matches = function(c, s)
        return available(c, s, ACTION.Incinerate, true) and s.immolate_remains <= 2
            and ready(ACTION.Incinerate, c.target)
    end, execute = function(c) return cast(ACTION.Incinerate, c.target, "Incinerate") end },
    { name = "Immolate", matches = function(c, s)
        return available(c, s, ACTION.Immolate, true) and s.immolate_remains <= 0
            and ready(ACTION.Immolate, c.target)
    end, execute = function(c) return cast(ACTION.Immolate, c.target, "Immolate") end },
    { name = "Corruption", matches = function(c, s)
        return available(c, s, ACTION.Corruption, true) and s.corruption_remains <= 0
            and ready(ACTION.Corruption, c.target)
    end, execute = function(c) return cast(ACTION.Corruption, c.target, "Corruption") end },
    { name = "LifeTap", matches = function(c, s)
        return available(c, s, ACTION.LifeTap, false) and s.mana_pct <= 15 and c.moving ~= true
            and ready(ACTION.LifeTap, c.me)
    end, execute = function(c) return cast(ACTION.LifeTap, c.me, "LifeTap") end },
    { name = "DrainLife", matches = function(c, s)
        return available(c, s, ACTION.DrainLife, true) and s.target_hp_pct <= 35
            and ready(ACTION.DrainLife, c.target)
    end, execute = function(c) return cast(ACTION.DrainLife, c.target, "DrainLife") end },
    { name = "SearingPain", matches = function(c, s)
        return available(c, s, ACTION.SearingPain, true) and ready(ACTION.SearingPain, c.target)
    end, execute = function(c) return cast(ACTION.SearingPain, c.target, "SearingPain") end },
}

if NS.rotation_registry and NS.rotation_registry.register then
    NS.rotation_registry:register("tank", strategies, { get_state = build_state })
end

return { strategies = strategies, build_state = build_state, actions = ACTION }
