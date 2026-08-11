-- leveling_wotlk.lua — Mage leveling rotation for Wrath of the Lich King (3.3.5).
-- WHAT:  priority-list strategies for mage leveling in WotLK.
-- WHEN:  combat with valid enemy target.
-- WHY:   simple nuke/dot rotation with emergency shields and mana recovery.
-- SAFETY: state reads nil-guarded via spec_kit.safe_state(); declarative DSL strategies; no on_update() allocs.

local NS = _G.EaxRotations
if not NS then return nil end

-- Hit-volume AoE gates (install if core not loaded, e.g. unit tests)
do
    local _ok_aoe, AoeHV = pcall(require, "shared/aoe_hit_volume_sylvanas")
    if _ok_aoe and AoeHV and AoeHV.install then AoeHV.install(NS) end
end

local spec_kit = require("shared/spec_kit_sylvanas")
local dsl      = require("shared/strategy_dsl_sylvanas")
local helpers = require("shared/leveling_helpers_sylvanas")
local pet_manager = require("shared/pet_manager_sylvanas")
local SPELLS = NS.MageSpells or {}

local define = spec_kit.define_action_for_class(SPELLS)

local ACTION = {
    ArcaneMissiles = define("ArcaneMissiles", { 42846, 42845, 42844, 42843, 38704, 38699, 25346, 10212, 10211, 5143, 5144, 5145, 8417, 8418, 8419 }, "ArcaneMissiles"),
    ArcaneBarrage = define("ArcaneBarrage", { 44425, 44780, 44781 }, "ArcaneBarrage"),
    Fireball = define("Fireball", { 42833, 27070, 25306, 10151, 10150, 10149, 10148, 8402, 8401, 8400, 3140, 145, 143, 133 }, "Fireball"),
    Pyroblast = define("Pyroblast", { 42891, 33938, 27132, 18809, 12526, 12525, 12524, 12523, 12522, 12505, 11366 }, "Pyroblast"),
    FireBlast = define("FireBlast", { 42873, 27079, 27078, 10199, 10197, 8413, 8412, 2138, 2137, 2136 }, "FireBlast"),
    LivingBomb = define("LivingBomb", 55360, "LivingBomb"),
    Scorch = define("Scorch", { 42859, 27074, 27073, 10207, 10206, 10205, 8446, 8445, 8444, 2948 }, "Scorch"),
    Frostbolt = define("Frostbolt", { 42842, 27072, 27071, 25304, 10181, 10180, 10179, 10177, 10176, 10175, 116, 205 }, "Frostbolt"),
    IceLance = define("IceLance", { 42914, 30455 }, "IceLance"),
    FrostfireBolt = define("FrostfireBolt", 44614, "FrostfireBolt"),
    DeepFreeze = define("DeepFreeze", 44572, "DeepFreeze"),
    ConeOfCold = define("ConeOfCold", { 42931, 27087, 10161, 10160, 10159, 8492, 120 }, "ConeOfCold"),
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
    mana_pct = 100,
    enemy_count = 1,
    in_combat = false,
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
    state.mana_pct = (me and me.get_mana_percentage and me:get_mana_percentage()) or 100
    state.enemy_count = (context and (context.enemies_count or context.enemy_count)) or 1
    state.in_combat = (context and context.in_combat) or false
    state.living_bomb_remains = (target and NS.debuff_remains and NS.debuff_remains(target, LIVING_BOMB_DEBUFF)) or 0
    state.ice_barrier_up = (me and NS.buff_up and NS.buff_up(me, ICE_BARRIER_BUFF)) or false
    state.mana_shield_up = (me and NS.buff_up and NS.buff_up(me, MANA_SHIELD_BUFF)) or false
    state.target_casting = helpers.should_interrupt(target)
    state.arcane_intellect_up = (me and NS.buff_up and NS.buff_up(me, ARCANE_INTELLECT_BUFF)) or false
    state.mage_armor_up = (me and NS.buff_up and NS.buff_up(me, MAGE_ARMOR_BUFF)) or false
    state.pet_alive = pet_manager.pet_alive(pet_manager.get_pet(me))
    return state
end

local DSL_DEFS = {
    {
        name = "Counterspell",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "target_casting", op = "==", value = true },
        },
        action = { type = "cast", spell = ACTION.Counterspell, target = "target" },
    },
    {
        name = "ArcaneIntellect",
        conditions = {
            { type = "state", field = "arcane_intellect_up", op = "falsy" },
            { type = "state", field = "mana_pct", op = ">=", value = 20 },
        },
        action = { type = "cast", spell = ACTION.ArcaneIntellect, target = "self" },
    },
    {
        name = "MageArmor",
        conditions = {
            { type = "state", field = "mage_armor_up", op = "falsy" },
            { type = "state", field = "mana_pct", op = ">=", value = 20 },
        },
        action = { type = "cast", spell = ACTION.MageArmor, target = "self" },
    },
    {
        name = "IceBarrier",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "hp", op = "<", value = 50 },
            { type = "state", field = "ice_barrier_up", op = "falsy" },
        },
        action = { type = "cast", spell = ACTION.IceBarrier, target = "self" },
    },
    {
        name = "ManaShield",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "hp", op = "<", value = 40 },
            { type = "state", field = "mana_shield_up", op = "falsy" },
        },
        action = { type = "cast", spell = ACTION.ManaShield, target = "self" },
    },
    {
        name = "Evocation",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "mana_pct", op = "<", value = 20 },
        },
        action = { type = "cast", spell = ACTION.Evocation, target = "self" },
    },
    {
        name = "Blink",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "hp", op = "<", value = 30 },
        },
        action = { type = "cast", spell = ACTION.Blink, target = "self" },
    },
    {
        name = "ConjureManaGem",
        conditions = {
            { type = "state", field = "in_combat", op = "falsy" },
            { type = "state", field = "mana_pct", op = "<", value = 80 },
        },
        action = { type = "cast", spell = ACTION.ConjureManaGem, target = "self" },
    },
    {
        name = "ConeOfCold",
        -- Cone of Cold ~10yd frontal sector (ESP-style facing cone; not 40yd density)
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "custom", fn = function(context, state)
                local r = (NS.AOE_RADIUS and NS.AOE_RADIUS.SELF_10) or 10
                if NS.aoe_cone_meets then
                    return NS.aoe_cone_meets(2, r, nil, context, state) and true or false
                end
                return (NS.aoe_self_meets and NS.aoe_self_meets(2, r, context, state)) and true or false
            end },
        },
        action = { type = "cast", spell = ACTION.ConeOfCold, target = "target" },
    },
    {
        name = "ArcaneExplosion",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "mana_pct", op = ">=", value = 15 },
            { type = "custom", fn = function(context, state)
                if not NS.aoe_self_meets then return false end
                local r = (NS.AOE_RADIUS and NS.AOE_RADIUS.SELF_10) or 10
                return NS.aoe_self_meets(3, r, context, state) and true or false
            end },
        },
        action = { type = "cast", spell = ACTION.ArcaneExplosion, target = "self" },
    },
    {
        name = "Blizzard",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "mana_pct", op = ">=", value = 25 },
            { type = "custom", fn = function(context, state)
                if not NS.aoe_target_meets then return false end
                local r = (NS.AOE_RADIUS and NS.AOE_RADIUS.GROUND_8) or 8
                return NS.aoe_target_meets(4, r, context and context.target, context, state) and true or false
            end },
        },
        action = { type = "cast", spell = ACTION.Blizzard, target = "target" },
    },
    {
        name = "SummonWaterElemental",
        -- Frost talent pet on a 3-min CD; try_cast gates the actual cooldown.
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "pet_alive", op = "falsy" },
            { type = "state", field = "mana_pct", op = ">=", value = 16 },
            { type = "custom", fn = function(context, state)
                if not NS.should_use_long_cd then return true end
                return NS.should_use_long_cd(context, 180) and true or false
            end },
        },
        action = { type = "cast", spell = ACTION.SummonWaterElemental, target = "self" },
    },
    {
        name = "LivingBomb",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "living_bomb_remains", op = "<", value = 3 },
            { type = "state", field = "mana_pct", op = ">=", value = 15 },
        },
        action = { type = "cast", spell = ACTION.LivingBomb, target = "target" },
    },
    {
        name = "Pyroblast",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "mana_pct", op = ">=", value = 20 },
        },
        action = { type = "cast", spell = ACTION.Pyroblast, target = "target" },
    },
    {
        name = "Fireball",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "mana_pct", op = ">=", value = 15 },
        },
        action = { type = "cast", spell = ACTION.Fireball, target = "target" },
    },
    {
        name = "Frostbolt",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "mana_pct", op = ">=", value = 15 },
        },
        action = { type = "cast", spell = ACTION.Frostbolt, target = "target" },
    },
    {
        name = "FrostfireBolt",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "mana_pct", op = ">=", value = 15 },
        },
        action = { type = "cast", spell = ACTION.FrostfireBolt, target = "target" },
    },
    {
        name = "ArcaneBarrage",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "mana_pct", op = ">=", value = 20 },
        },
        action = { type = "cast", spell = ACTION.ArcaneBarrage, target = "target" },
    },
    {
        name = "ArcaneMissiles",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "mana_pct", op = ">=", value = 25 },
        },
        action = { type = "cast", spell = ACTION.ArcaneMissiles, target = "target" },
    },
    {
        name = "FireBlast",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "mana_pct", op = ">=", value = 10 },
        },
        action = { type = "cast", spell = ACTION.FireBlast, target = "target" },
    },
    {
        name = "Scorch",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "mana_pct", op = ">=", value = 10 },
        },
        action = { type = "cast", spell = ACTION.Scorch, target = "target" },
    },
    {
        name = "IceLance",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "mana_pct", op = ">=", value = 5 },
        },
        action = { type = "cast", spell = ACTION.IceLance, target = "target" },
    },
    {
        name = "DeepFreeze",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "mana_pct", op = ">=", value = 10 },
        },
        action = { type = "cast", spell = ACTION.DeepFreeze, target = "target" },
    },
    {
        name = "Shoot",
        -- OOM fallback: fire the wand when too low on mana to cast a real nuke.
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "mana_pct", op = "<", value = 10 },
        },
        action = { type = "cast", spell = ACTION.Shoot, target = "target" },
    },
}

-- Priority order (compiled in place from DSL_DEFS below).
local strategies = {
    { name = "Counterspell" },
    { name = "ArcaneIntellect" },
    { name = "MageArmor" },
    { name = "IceBarrier" },
    { name = "ManaShield" },
    { name = "Evocation" },
    { name = "Blink" },
    { name = "ConjureManaGem" },
    { name = "ConeOfCold" },
    { name = "ArcaneExplosion" },
    { name = "Blizzard" },
    { name = "SummonWaterElemental" },
    { name = "LivingBomb" },
    { name = "Pyroblast" },
    { name = "Fireball" },
    { name = "Frostbolt" },
    { name = "FrostfireBolt" },
    { name = "ArcaneBarrage" },
    { name = "ArcaneMissiles" },
    { name = "FireBlast" },
    { name = "Scorch" },
    { name = "IceLance" },
    { name = "DeepFreeze" },
    { name = "Shoot" },
}

for i = 1, #strategies do
    for j = 1, #DSL_DEFS do
        if strategies[i].name == DSL_DEFS[j].name then
            strategies[i] = dsl.compile_strategy(DSL_DEFS[j], { get_state = build_state })
            break
        end
    end
end

if NS.rotation_registry and NS.rotation_registry.register then
    NS.rotation_registry:register("leveling", strategies, { get_state = build_state })
end

if NS.log then NS.log("Mage leveling rotation registered") end

return { strategies = strategies, build_state = build_state }
