-- leveling_wotlk.lua — Mage leveling rotation for Wrath of the Lich King (3.3.5).
-- WHAT:  priority-list strategies for mage leveling in WotLK.
-- WHEN:  combat with valid enemy target.
-- WHY:   simple nuke/dot rotation with emergency shields and mana recovery.
-- SAFETY: state reads nil-guarded via spec_kit.safe_state(); no on_update() allocs.

local NS = _G.EaxRotations
if not NS then return nil end

-- Hit-volume AoE gates (install if core not loaded, e.g. unit tests)
do
    local _ok_aoe, AoeHV = pcall(require, "shared/aoe_hit_volume_sylvanas")
    if _ok_aoe and AoeHV and AoeHV.install then AoeHV.install(NS) end
end

local spec_kit = require("shared/spec_kit_sylvanas")
local helpers = require("shared/leveling_helpers_sylvanas")
local pet_manager = require("shared/pet_manager_sylvanas")
local SPELLS = NS.MageSpells or {}

local define = spec_kit.define_action_for_class(SPELLS)

local ACTION = {
    ArcaneMissiles = define("ArcaneMissiles", { 42846, 42845, 42844, 42843, 38704, 38699, 25346, 10212, 10211, 5143, 5144, 5145, 8417, 8418, 8419 }, "ArcaneMissiles"),
    ArcaneBarrage = define("ArcaneBarrage", { 44425, 44780, 44781 }, "ArcaneBarrage"),
    Fireball = define("Fireball", { 42833, 27070, 25306, 10151, 10150, 10149, 10148, 8402, 8401, 8400, 3140, 145, 143, 133 }, "Fireball"),
    Pyroblast = define("Pyroblast", { 33938, 27132, 18809, 12526, 12525, 12524, 12523, 12522, 12505, 11366 }, "Pyroblast"),
    FireBlast = define("FireBlast", { 27079, 27078, 10199, 10197, 8413, 8412, 2138, 2137, 2136 }, "FireBlast"),
    LivingBomb = define("LivingBomb", 44457, "LivingBomb"),
    Scorch = define("Scorch", { 42859, 27074, 27073, 10207, 10206, 10205, 8446, 8445, 8444, 2948 }, "Scorch"),
    Frostbolt = define("Frostbolt", { 42842, 27072, 27071, 25304, 10181, 10180, 10179, 10177, 10176, 10175, 116, 205 }, "Frostbolt"),
    IceLance = define("IceLance", 30455, "IceLance"),
    FrostfireBolt = define("FrostfireBolt", 44614, "FrostfireBolt"),
    DeepFreeze = define("DeepFreeze", 44572, "DeepFreeze"),
    ConeOfCold = define("ConeOfCold", { 27087, 10161, 10160, 10159, 8492, 120 }, "ConeOfCold"),
    Blink = define("Blink", 1953, "Blink"),
    IceBarrier = define("IceBarrier", { 33405, 27134, 13033, 13032, 13031, 11426 }, "IceBarrier"),
    ManaShield = define("ManaShield", { 27131, 10193, 10192, 10191, 8495, 8494, 1463 }, "ManaShield"),
    Evocation = define("Evocation", 12051, "Evocation"),
    ConjureManaGem = define("ConjureManaGem", { 27101, 10054, 10053, 3552, 759 }, "ConjureManaGem"),
    Counterspell = define("Counterspell", 2139, "Counterspell"),
    ArcaneIntellect = define("ArcaneIntellect", { 42995, 27126, 10157, 10156, 1461, 1460, 1459 }, "ArcaneIntellect"),
    MageArmor = define("MageArmor", { 43024, 43023, 27125, 22783, 22782, 6117 }, "MageArmor"),
    ArcaneExplosion = define("ArcaneExplosion", { 42921, 42920, 27082, 10202, 10201, 8439, 8438, 8437, 1449 }, "ArcaneExplosion"),
    SummonWaterElemental = define("SummonWaterElemental", 31687, "SummonWaterElemental"),
    Blizzard = define("Blizzard", { 42940, 42939, 27085, 10187, 10186, 10185, 8427, 8426, 10, 1449 }, "Blizzard"),
    Shoot = define("Shoot", 5019, "Shoot"),
}

local FIREBALL_DEBUFF = { 42833, 27070, 25306, 10151, 10150, 10149, 10148, 8402, 8401, 8400, 3140, 145, 143, 133 }
local LIVING_BOMB_DEBUFF = { 44457 }
local ICE_BARRIER_BUFF = { 33405, 27134, 13033, 13032, 13031, 11426 }
local MANA_SHIELD_BUFF = { 27131, 10193, 10192, 10191, 8495, 8494, 1463 }
local ARCANE_INTELLECT_BUFF = { 42995, 27126, 10157, 10156, 1461, 1460, 1459 }
local MAGE_ARMOR_BUFF = { 43024, 43023, 27125, 22783, 22782, 6117 }

local mage_state = {
    hp = 100,
    target_hp = 100,
    mana_pct = 100,
    enemy_count = 1,
    in_combat = false,
    fireball_remains = 0,
    living_bomb_remains = 0,
    ice_barrier_up = false,
    mana_shield_up = false,
    target_casting = false,
    arcane_intellect_up = false,
    mage_armor_up = false,
    pet_alive = false,
}

local function build_state(context)
    local state = spec_kit.safe_state(mage_state)
    local me = NS.me or (NS.GetPlayer and NS.GetPlayer())
    local target = context and context.target
    state.hp = (me and me.get_health_percentage and me:get_health_percentage()) or 100
    state.target_hp = (target and target.get_health_percentage and target:get_health_percentage()) or 100
    state.mana_pct = (me and me.get_mana_percentage and me:get_mana_percentage()) or 100
    state.enemy_count = (context and (context.enemies_count or context.enemy_count)) or 1
    state.in_combat = (context and context.in_combat) or false
    state.fireball_remains = (target and NS.debuff_remains and NS.debuff_remains(target, FIREBALL_DEBUFF)) or 0
    state.living_bomb_remains = (target and NS.debuff_remains and NS.debuff_remains(target, LIVING_BOMB_DEBUFF)) or 0
    state.ice_barrier_up = (me and NS.buff_up and NS.buff_up(me, ICE_BARRIER_BUFF)) or false
    state.mana_shield_up = (me and NS.buff_up and NS.buff_up(me, MANA_SHIELD_BUFF)) or false
    state.target_casting = helpers.should_interrupt(target)
    state.arcane_intellect_up = (me and NS.buff_up and NS.buff_up(me, ARCANE_INTELLECT_BUFF)) or false
    state.mage_armor_up = (me and NS.buff_up and NS.buff_up(me, MAGE_ARMOR_BUFF)) or false
    state.pet_alive = pet_manager.pet_alive(pet_manager.get_pet(me))
    return state
end

local function summon_water_elemental_matches(context, state)
    -- Frost talent pet on a 3-min CD; cast_safe() gates the actual cooldown.
    -- Bring it out in combat when we don't already have one active.
    if not state.in_combat then return false end
    if state.pet_alive then return false end
    if state.mana_pct < 16 then return false end
    if NS.should_use_long_cd and not NS.should_use_long_cd(context, 180) then return false end
    return true
end

local function counterspell_matches(context, state)
    return state.in_combat and state.target_casting == true
end

local function arcane_intellect_matches(context, state)
    return not state.arcane_intellect_up and state.mana_pct >= 20
end

local function mage_armor_matches(context, state)
    return not state.mage_armor_up and state.mana_pct >= 20
end

local function arcane_explosion_matches(context, state)
    return state.in_combat and state.mana_pct >= 15
        and NS.aoe_self_meets and NS.aoe_self_meets(3, (NS.AOE_RADIUS and NS.AOE_RADIUS.SELF_10) or 10, context, state)
end

local function blizzard_matches(context, state)
    return state.in_combat and state.mana_pct >= 25
        and NS.aoe_target_meets and NS.aoe_target_meets(4, (NS.AOE_RADIUS and NS.AOE_RADIUS.GROUND_8) or 8, context and context.target, context, state)
end

local function shoot_wand_matches(context, state)
    -- OOM fallback: fire the wand when too low on mana to cast a real nuke.
    return state.in_combat and state.mana_pct < 10
end

local function ice_barrier_matches(context, state)
    return state.in_combat and state.hp < 50 and not state.ice_barrier_up
end

local function mana_shield_matches(context, state)
    return state.in_combat and state.hp < 40 and not state.mana_shield_up
end

local function evocation_matches(context, state)
    return state.in_combat and state.mana_pct < 20
end

local function blink_matches(context, state)
    return state.in_combat and state.hp < 30
end

local function cone_of_cold_matches(context, state)
    -- Cone of Cold ~10yd frontal sector (ESP-style facing cone; not 40yd density)
    if not state.in_combat then return false end
    local r = (NS.AOE_RADIUS and NS.AOE_RADIUS.SELF_10) or 10
    if NS.aoe_cone_meets then
        return NS.aoe_cone_meets(2, r, nil, context, state)
    end
    return NS.aoe_self_meets and NS.aoe_self_meets(2, r, context, state)
end

local function living_bomb_matches(context, state)
    return state.in_combat and state.living_bomb_remains < 3 and state.mana_pct >= 15
end

local function pyroblast_matches(context, state)
    return state.in_combat and state.mana_pct >= 20
end

local function fireball_matches(context, state)
    return state.in_combat and state.mana_pct >= 15
end

local function frostbolt_matches(context, state)
    return state.in_combat and state.mana_pct >= 15
end

local function arcane_missiles_matches(context, state)
    return state.in_combat and state.mana_pct >= 25
end

local function arcane_barrage_matches(context, state)
    return state.in_combat and state.mana_pct >= 20
end

local function fire_blast_matches(context, state)
    return state.in_combat and state.mana_pct >= 10
end

local function scorch_matches(context, state)
    return state.in_combat and state.mana_pct >= 10
end

local function ice_lance_matches(context, state)
    return state.in_combat and state.mana_pct >= 5
end

local function frostfire_bolt_matches(context, state)
    return state.in_combat and state.mana_pct >= 15
end

local function deep_freeze_matches(context, state)
    return state.in_combat and state.mana_pct >= 10
end

local function conjure_mana_gem_matches(context, state)
    return not state.in_combat and state.mana_pct < 80
end

local strategies = {
    { name = "Counterspell", matches = counterspell_matches, execute = function(ctx) return ACTION.Counterspell and ACTION.Counterspell:cast_safe(ctx.target) end },
    { name = "ArcaneIntellect", matches = arcane_intellect_matches, execute = function(ctx) return ACTION.ArcaneIntellect and ACTION.ArcaneIntellect:cast_safe() end },
    { name = "MageArmor", matches = mage_armor_matches, execute = function(ctx) return ACTION.MageArmor and ACTION.MageArmor:cast_safe() end },
    { name = "IceBarrier", matches = ice_barrier_matches, execute = function(ctx) return ACTION.IceBarrier and ACTION.IceBarrier:cast_safe() end },
    { name = "ManaShield", matches = mana_shield_matches, execute = function(ctx) return ACTION.ManaShield and ACTION.ManaShield:cast_safe() end },
    { name = "Evocation", matches = evocation_matches, execute = function(ctx) return ACTION.Evocation and ACTION.Evocation:cast_safe() end },
    { name = "Blink", matches = blink_matches, execute = function(ctx) return ACTION.Blink and ACTION.Blink:cast_safe() end },
    { name = "ConjureManaGem", matches = conjure_mana_gem_matches, execute = function(ctx) return ACTION.ConjureManaGem and ACTION.ConjureManaGem:cast_safe() end },
    { name = "ConeOfCold", matches = cone_of_cold_matches, execute = function(ctx) return ACTION.ConeOfCold and ACTION.ConeOfCold:cast_safe(ctx.target) end },
    { name = "ArcaneExplosion", matches = arcane_explosion_matches, execute = function(ctx) return ACTION.ArcaneExplosion and ACTION.ArcaneExplosion:cast_safe() end },
    { name = "Blizzard", matches = blizzard_matches, execute = function(ctx) return ACTION.Blizzard and ACTION.Blizzard:cast_safe(ctx.target) end },
    { name = "SummonWaterElemental", matches = summon_water_elemental_matches, execute = function(ctx) return ACTION.SummonWaterElemental and ACTION.SummonWaterElemental:cast_safe() end },
    { name = "LivingBomb", matches = living_bomb_matches, execute = function(ctx) return ACTION.LivingBomb and ACTION.LivingBomb:cast_safe(ctx.target) end },
    { name = "Pyroblast", matches = pyroblast_matches, execute = function(ctx) return ACTION.Pyroblast and ACTION.Pyroblast:cast_safe(ctx.target) end },
    { name = "Fireball", matches = fireball_matches, execute = function(ctx) return ACTION.Fireball and ACTION.Fireball:cast_safe(ctx.target) end },
    { name = "Frostbolt", matches = frostbolt_matches, execute = function(ctx) return ACTION.Frostbolt and ACTION.Frostbolt:cast_safe(ctx.target) end },
    { name = "FrostfireBolt", matches = frostfire_bolt_matches, execute = function(ctx) return ACTION.FrostfireBolt and ACTION.FrostfireBolt:cast_safe(ctx.target) end },
    { name = "ArcaneBarrage", matches = arcane_barrage_matches, execute = function(ctx) return ACTION.ArcaneBarrage and ACTION.ArcaneBarrage:cast_safe(ctx.target) end },
    { name = "ArcaneMissiles", matches = arcane_missiles_matches, execute = function(ctx) return ACTION.ArcaneMissiles and ACTION.ArcaneMissiles:cast_safe(ctx.target) end },
    { name = "FireBlast", matches = fire_blast_matches, execute = function(ctx) return ACTION.FireBlast and ACTION.FireBlast:cast_safe(ctx.target) end },
    { name = "Scorch", matches = scorch_matches, execute = function(ctx) return ACTION.Scorch and ACTION.Scorch:cast_safe(ctx.target) end },
    { name = "IceLance", matches = ice_lance_matches, execute = function(ctx) return ACTION.IceLance and ACTION.IceLance:cast_safe(ctx.target) end },
    { name = "DeepFreeze", matches = deep_freeze_matches, execute = function(ctx) return ACTION.DeepFreeze and ACTION.DeepFreeze:cast_safe(ctx.target) end },
    { name = "Shoot", matches = shoot_wand_matches, execute = function(ctx) return ACTION.Shoot and ACTION.Shoot:cast_safe(ctx.target) end },
}

if NS.rotation_registry and NS.rotation_registry.register then
    NS.rotation_registry:register("leveling", strategies, { get_state = build_state })
end

return { strategies = strategies, build_state = build_state }
