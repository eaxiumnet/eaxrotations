-- dps_hunter_sod.lua -- Hunter DPS rotation for Season of Discovery.
-- WHAT: pet recovery, Chimera Shot, Kill Shot, Multi-Shot, Arcane Shot, and sting.
-- WHEN: SoD combat with a valid hostile target, plus safe out-of-combat pet recovery.
-- WHY: translates representative pinned wowsims/sod phase 7 ranged priorities.
-- SAFETY: pet, execute, phase, and rune state fail closed on missing host data.

local NS = _G.EaxRotations
if not NS then return nil end
if type(NS.is_sod) == "function" and not NS.is_sod() then return nil end

local spec_kit = require("shared/spec_kit_sylvanas")
local define = spec_kit.define_sod_action_for_class({})
local ACTION = {
    MendPet = define("MendPet", { 13542, 3661, 136 }, {}, "MendPet"),
    CallPet = define("CallPet", 883, {}, "CallPet"),
    RevivePet = define("RevivePet", 982, {}, "RevivePet"),
    ChimeraShot = define("ChimeraShot", 409433, { rune_id = 409433 }, "ChimeraShot"),
    KillShot = define("KillShot", 409593, { rune_id = 409593 }, "KillShot"),
    MultiShot = define("MultiShot", { 25294, 14290 }, {}, "MultiShot"),
    ArcaneShot = define("ArcaneShot", { 14287, 14286 }, {}, "ArcaneShot"),
    SerpentSting = define("SerpentSting", { 25295, 13555 }, {}, "SerpentSting"),
}

local function number(context, key, fallback)
    return type(context[key]) == "number" and context[key] or fallback
end

local function build_state(context)
    context = type(context) == "table" and context or {}
    local has_pet = context.pet ~= nil or context.has_pet == true
    return spec_kit.safe_state({
        has_pet = has_pet,
        pet_alive = context.pet_alive == true or (context.pet ~= nil and context.pet_dead ~= true),
        pet_dead = context.pet_dead == true,
        pet_hp_pct = number(context, "pet_hp_pct", 100),
        target_hp_pct = number(context, "target_hp_pct", 100),
        serpent_sting_remains = number(context, "serpent_sting_remains", 0),
        enemy_count = number(context, "enemy_count", 1),
    }, { pet_hp_pct = 100, target_hp_pct = 100, serpent_sting_remains = 0, enemy_count = 0 })
end

local function valid(context, descriptor)
    return type(context) == "table" and context.is_sod == true
        and spec_kit.sod_action_available(context, descriptor)
end

local function ready(descriptor, target)
    return type(NS.spell_ready) == "function" and NS.spell_ready(descriptor.action, target) == true
end

local function cast(descriptor, target, label)
    return NS.try_cast(descriptor.action, target, "[SOD HUNTER] " .. label)
end

local strategies = {
    { name = "MendPet", matches = function(c, s) return valid(c, ACTION.MendPet) and s.pet_alive and s.pet_hp_pct <= 35 and ready(ACTION.MendPet, c.pet) end,
      execute = function(c) return cast(ACTION.MendPet, c.pet, "Mend Pet") end },
    { name = "CallPet", matches = function(c, s) return valid(c, ACTION.CallPet) and not c.in_combat and not s.has_pet and not s.pet_dead and ready(ACTION.CallPet, c.me) end,
      execute = function(c) return cast(ACTION.CallPet, c.me, "Call Pet") end },
    { name = "RevivePet", matches = function(c, s) return valid(c, ACTION.RevivePet) and not c.in_combat and s.pet_dead and ready(ACTION.RevivePet, c.me) end,
      execute = function(c) return cast(ACTION.RevivePet, c.me, "Revive Pet") end },
    { name = "ChimeraShot", matches = function(c, s) return valid(c, ACTION.ChimeraShot) and c.in_combat == true and c.target ~= nil and s.serpent_sting_remains <= 5 and ready(ACTION.ChimeraShot, c.target) end,
      execute = function(c) return cast(ACTION.ChimeraShot, c.target, "Chimera Shot") end },
    { name = "KillShot", matches = function(c, s) return valid(c, ACTION.KillShot) and c.in_combat == true and c.target ~= nil and s.target_hp_pct <= 20 and ready(ACTION.KillShot, c.target) end,
      execute = function(c) return cast(ACTION.KillShot, c.target, "Kill Shot") end },
    { name = "MultiShot", matches = function(c, s) return valid(c, ACTION.MultiShot) and c.in_combat == true and c.target ~= nil and s.enemy_count >= 2 and ready(ACTION.MultiShot, c.target) end,
      execute = function(c) return cast(ACTION.MultiShot, c.target, "Multi-Shot") end },
    { name = "ArcaneShot", matches = function(c) return valid(c, ACTION.ArcaneShot) and c.in_combat == true and c.target ~= nil and ready(ACTION.ArcaneShot, c.target) end,
      execute = function(c) return cast(ACTION.ArcaneShot, c.target, "Arcane Shot") end },
    { name = "SerpentSting", matches = function(c, s) return valid(c, ACTION.SerpentSting) and c.in_combat == true and c.target ~= nil and s.serpent_sting_remains <= 0 and ready(ACTION.SerpentSting, c.target) end,
      execute = function(c) return cast(ACTION.SerpentSting, c.target, "Serpent Sting") end },
}

if NS.rotation_registry and NS.rotation_registry.register then
    NS.rotation_registry:register("dps_hunter", strategies, { get_state = build_state })
end

return { strategies = strategies, build_state = build_state, actions = ACTION }
