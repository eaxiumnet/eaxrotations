local NS = _G.EaxRotations
if not NS then return nil end
if type(NS.is_sod) == "function" and not NS.is_sod() then return nil end

local spec_kit = require("shared/spec_kit_sylvanas")
local define = spec_kit.define_sod_action_for_class({})
local ACTION = {
    CallPet = define("SodCallPet", 883, {}, "CallPet"),
    RevivePet = define("SodRevivePet", 982, {}, "RevivePet"),
    MendPet = define("SodMendPet", { 13542, 3661, 136 }, {}, "MendPet"),
    HealthFunnel = define("SodHealthFunnel", 11695, {}, "HealthFunnel"),
    CurseOfRecklessness = define("SodCurseOfRecklessness", 7658, {}, "CurseOfRecklessness"),
    Shadowburn = define("SodShadowburn", 17920, {}, "Shadowburn"),
    ChaosBolt = define("SodChaosBolt", 403629, { rune_id = 403629, min_phase = 1 }, "ChaosBolt"),
    Incinerate = define("SodIncinerate", 412758, { rune_id = 412758, min_phase = 1 }, "Incinerate"),
    Conflagrate = define("SodConflagrate", 18932, {}, "Conflagrate"),
    Immolate = define("SodImmolate", 11665, {}, "Immolate"),
    Corruption = define("SodCorruption", 11672, {}, "Corruption"),
    LifeTap = define("SodLifeTap", 11687, {}, "LifeTap"),
    ShadowBolt = define("SodShadowBolt", 7641, {}, "ShadowBolt"),
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
        hp_pct = number(context, "hp_pct", 100),
        target_hp_pct = number(context, "target_hp_pct", 100),
        enemy_count = number(context, "enemy_count", 1),
        curse_remains = number(context, "curse_remains", 0),
        immolate_remains = number(context, "immolate_remains", 0),
        corruption_remains = number(context, "corruption_remains", 0),
    }, {
        pet_hp_pct = 100, mana_pct = 100, hp_pct = 100, target_hp_pct = 100,
        enemy_count = 0, curse_remains = 0, immolate_remains = 0,
        corruption_remains = 0,
    })
end

local function available(context, descriptor, target_required)
    return type(context) == "table" and context.is_sod == true
        and (not target_required or context.target ~= nil)
        and spec_kit.sod_action_available(context, descriptor)
end

local function ready(descriptor, target)
    return type(NS.spell_ready) == "function" and NS.spell_ready(descriptor.action, target) == true
end

local function cast(descriptor, target, label)
    return NS.try_cast(descriptor.action, target, "[SOD WARLOCK DPS] " .. label)
end

local strategies = {
    { name = "MendPet", matches = function(c, s)
        return available(c, ACTION.MendPet, false) and not c.in_combat and s.pet_alive
            and s.pet_hp_pct <= 35 and ready(ACTION.MendPet, c.pet)
    end, execute = function(c) return cast(ACTION.MendPet, c.pet, "MendPet") end },
    { name = "CallPet", matches = function(c, s)
        return available(c, ACTION.CallPet, false) and not c.in_combat and not s.has_pet
            and not s.pet_dead and ready(ACTION.CallPet, c.me)
    end, execute = function(c) return cast(ACTION.CallPet, c.me, "CallPet") end },
    { name = "RevivePet", matches = function(c, s)
        return available(c, ACTION.RevivePet, false) and not c.in_combat and s.pet_dead
            and ready(ACTION.RevivePet, c.me)
    end, execute = function(c) return cast(ACTION.RevivePet, c.me, "RevivePet") end },
    { name = "HealthFunnel", matches = function(c, s)
        return available(c, ACTION.HealthFunnel, false) and c.in_combat == true
            and s.pet_alive and s.pet_hp_pct <= 35 and ready(ACTION.HealthFunnel, c.pet)
    end, execute = function(c) return cast(ACTION.HealthFunnel, c.pet, "HealthFunnel") end },
    { name = "CurseOfRecklessness", matches = function(c, s)
        return available(c, ACTION.CurseOfRecklessness, true) and c.in_combat == true
            and s.curse_remains <= 0 and ready(ACTION.CurseOfRecklessness, c.target)
    end, execute = function(c) return cast(ACTION.CurseOfRecklessness, c.target, "CurseOfRecklessness") end },
    { name = "Shadowburn", matches = function(c, s)
        return available(c, ACTION.Shadowburn, true) and c.in_combat == true
            and s.target_hp_pct <= 20 and ready(ACTION.Shadowburn, c.target)
    end, execute = function(c) return cast(ACTION.Shadowburn, c.target, "Shadowburn") end },
    { name = "ChaosBolt", matches = function(c) return available(c, ACTION.ChaosBolt, true)
        and c.in_combat == true and ready(ACTION.ChaosBolt, c.target)
    end, execute = function(c) return cast(ACTION.ChaosBolt, c.target, "ChaosBolt") end },
    { name = "Incinerate", matches = function(c) return available(c, ACTION.Incinerate, true)
        and c.in_combat == true and ready(ACTION.Incinerate, c.target)
    end, execute = function(c) return cast(ACTION.Incinerate, c.target, "Incinerate") end },
    { name = "Conflagrate", matches = function(c, s) return available(c, ACTION.Conflagrate, true)
        and c.in_combat == true and s.immolate_remains > 0 and ready(ACTION.Conflagrate, c.target)
    end, execute = function(c) return cast(ACTION.Conflagrate, c.target, "Conflagrate") end },
    { name = "Immolate", matches = function(c, s) return available(c, ACTION.Immolate, true)
        and c.in_combat == true and s.immolate_remains <= 0 and ready(ACTION.Immolate, c.target)
    end, execute = function(c) return cast(ACTION.Immolate, c.target, "Immolate") end },
    { name = "Corruption", matches = function(c, s) return available(c, ACTION.Corruption, true)
        and c.in_combat == true and s.corruption_remains <= 0 and ready(ACTION.Corruption, c.target)
    end, execute = function(c) return cast(ACTION.Corruption, c.target, "Corruption") end },
    { name = "LifeTap", matches = function(c, s)
        return available(c, ACTION.LifeTap, false) and c.in_combat == true
            and s.mana_pct <= 15 and s.hp_pct > 30 and c.moving ~= true
            and ready(ACTION.LifeTap, c.me)
    end, execute = function(c) return cast(ACTION.LifeTap, c.me, "LifeTap") end },
    { name = "ShadowBolt", matches = function(c)
        return available(c, ACTION.ShadowBolt, true) and c.in_combat == true
            and ready(ACTION.ShadowBolt, c.target)
    end, execute = function(c) return cast(ACTION.ShadowBolt, c.target, "ShadowBolt") end },
}

if NS.rotation_registry and NS.rotation_registry.register then
    NS.rotation_registry:register("dps", strategies, { get_state = build_state })
end

return { strategies = strategies, build_state = build_state, actions = ACTION }
