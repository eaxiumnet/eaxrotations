-- leveling_wotlk.lua — Shaman leveling rotation for Wrath of the Lich King (3.3.5).
-- WHAT:  priority-list strategies for shaman leveling in WotLK: Wind Shear
--        interrupt, emergency Healing Wave, Lightning Shield, OOC weapon-imbue
--        upkeep (Flametongue Weapon on a ~29.8-min window), fire-totem
--        maintenance (Searing/Magma share one fire-slot timestamp), shock/Lava
--        Burst rotation.
-- WHEN:  combat with valid enemy target.
-- WHY:   simple shock/bolt rotation with emergency heal.
-- SAFETY: state reads nil-guarded via spec_kit.safe_state(); declarative DSL strategies; no on_update() allocs.

local NS = _G.EaxRotations
if not NS then return nil end

local spec_kit = require("shared/spec_kit_sylvanas")
local dsl      = require("shared/strategy_dsl_sylvanas")
local helpers = require("shared/leveling_helpers_sylvanas")

-- Plain define_action (NOT define_action_for_class): NS.ShamanSpells is the
-- TBC-era class table, so the class-first resolver would shadow every WotLK
-- rank ladder below with TBC ids (precedent: mage/fire_wotlk.lua).
local define = spec_kit.define_action

local ACTION = {
    LightningBolt = define("LightningBolt", { 49238, 25449, 25448, 15208, 15207, 10392, 10391, 6041, 943, 915, 548, 529, 403 }, "LightningBolt"),
    EarthShock = define("EarthShock", { 49231, 25454, 10414, 10413, 10412, 8046, 8045, 8044, 8042 }, "EarthShock"),
    FlameShock = define("FlameShock", { 49233, 25457, 29228, 10448, 10447, 8053, 8052, 8050 }, "FlameShock"),
    LavaBurst = define("LavaBurst", { 60043, 51505 }, "LavaBurst"),  -- 60043 = WotLK max rank (51505 = rank 1 / level 75)
    Stormstrike = define("Stormstrike", 17364, "Stormstrike"),
    HealingWave = define("HealingWave", { 49273, 25396, 25391, 25357, 10396, 10395, 8005, 959, 939, 913, 547, 332, 331 }, "HealingWave"),
    WindShear = define("WindShear", 57994, "WindShear"),
    LightningShield = define("LightningShield", { 49281, 49280, 25472, 25469, 10432, 10431, 8134, 945, 905, 325, 324 }, "LightningShield"),
    FlametongueWeapon = define("FlametongueWeapon", { 58790, 58789, 25489, 16342, 16341, 16339, 8030, 8027, 8024 }, "FlametongueWeapon"),
    SearingTotem = define("SearingTotem", { 58704, 58703, 25533, 10438, 10437, 6365, 6364, 6363, 3599 }, "SearingTotem"),
    ChainLightning = define("ChainLightning", { 49271, 49270, 25442, 25439, 10605, 2860, 930, 421 }, "ChainLightning"),
    MagmaTotem = define("MagmaTotem", { 58734, 58733, 25552, 10587, 10586, 10585, 8190 }, "MagmaTotem"),
}

local LIGHTNING_SHIELD_BUFF = { 49281, 49280, 25472, 25469, 10432, 10431, 8134, 945, 905, 325, 324 }
local _core_time = _G.core and _G.core.time
local function time_now() return (_core_time and _core_time()) or 0 end
-- Weapon-imbue duration is 30 min; re-apply OOC on a ~29.8-min window (1790s)
-- so the old 1.5s-esque throttle can never GCD-lock the rotation.
local IMBUE_REFRESH_S = 1790
-- Fire-totem durations: Searing 55s, Magma 18s. ONE shared timestamp keeps
-- Magma from overwriting a fresh Searing and vice versa.
local _last_flametongue = -1e9
local _last_fire_totem = -1e9
-- Totem slot 1 = fire (player:get_totem_info).
local FIRE_SLOT = 1

local FLAME_SHOCK_DEBUFF = { 49233, 25457, 29228, 10448, 10447, 8053, 8052, 8050 }

local shaman_state = {
    hp = 100,
    mana_pct = 100,
    enemy_count = 1,
    in_combat = false,
    flame_shock_remains = 0,
    target_casting = false,
    lightning_shield_up = false,
    fire_slot_free = true,
}

local function build_state(context)
    local state = spec_kit.safe_state(shaman_state)
    local me = NS.me or (NS.GetPlayer and NS.GetPlayer())
    local target = context and context.target
    state.hp = (context and context.hp) or (me and me.get_health_percentage and me:get_health_percentage()) or 100
    state.mana_pct = (context and context.mana_pct) or (me and me.get_mana_percentage and me:get_mana_percentage()) or 100
    state.enemy_count = (context and (context.enemies_count or context.enemy_count)) or 1
    state.in_combat = (context and context.in_combat) or false
    state.flame_shock_remains = (target and NS.debuff_remains and NS.debuff_remains(target, FLAME_SHOCK_DEBUFF)) or 0
    state.target_casting = helpers.should_interrupt(target)
    state.lightning_shield_up = (me and NS.buff_up and NS.buff_up(me, LIGHTNING_SHIELD_BUFF)) or false
    local fire_info = NS.get_totem_info and NS.get_totem_info(FIRE_SLOT) or nil
    state.fire_slot_free = not (type(fire_info) == "table" and fire_info.have_totem == true)
    return state
end

local DSL_DEFS = {
    {
        name = "WindShear",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "target_casting", op = "truthy" },
        },
        action = { type = "cast", spell = ACTION.WindShear, target = "target" },
    },
    {
        name = "HealingWave",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "hp", op = "<", value = 50 },
            { type = "state", field = "mana_pct", op = ">=", value = 25 },
        },
        action = { type = "cast", spell = ACTION.HealingWave, target = "self" },
    },
    {
        name = "LightningShield",
        conditions = {
            { type = "state", field = "lightning_shield_up", op = "falsy" },
            { type = "state", field = "mana_pct", op = ">=", value = 5 },
        },
        action = { type = "cast", spell = ACTION.LightningShield, target = "self" },
    },
    -- Weapon imbues have no player aura; re-apply out of combat on the ~29.8-min
    -- window (30-min imbue minus margin).
    {
        name = "FlametongueWeapon",
        conditions = {
            { type = "state", field = "in_combat", op = "falsy" },
            { type = "custom", fn = function(context, state) return (time_now() - _last_flametongue) >= IMBUE_REFRESH_S end },
            { type = "state", field = "mana_pct", op = ">=", value = 5 },
        },
        action = { type = "custom", fn = function(context, state)
            if NS.try_cast(ACTION.FlametongueWeapon, nil, "FlametongueWeapon") == true then _last_flametongue = time_now(); return true end
            return false
        end },
    },
    -- Fire totems share the fire slot: the single _last_fire_totem timestamp
    -- (plus slot occupancy) prevents Magma from overwriting a fresh Searing and
    -- vice versa.
    {
        name = "SearingTotem",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "enemy_count", op = ">=", value = 1 },
            { type = "state", field = "fire_slot_free", op = "truthy" },
            { type = "custom", fn = function(context, state) return (time_now() - _last_fire_totem) >= 55 end },
            { type = "state", field = "mana_pct", op = ">=", value = 10 },
        },
        action = { type = "custom", fn = function(context, state)
            if NS.try_cast(ACTION.SearingTotem, nil, "SearingTotem") == true then _last_fire_totem = time_now(); return true end
            return false
        end },
    },
    -- Fire AoE totem for tight packs; shares the fire-slot timestamp so it
    -- never clobbers a fresh Searing Totem.
    {
        name = "MagmaTotem",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "enemy_count", op = ">=", value = 3 },
            { type = "state", field = "fire_slot_free", op = "truthy" },
            { type = "custom", fn = function(context, state) return (time_now() - _last_fire_totem) >= 18 end },
            { type = "state", field = "mana_pct", op = ">=", value = 20 },
        },
        action = { type = "custom", fn = function(context, state)
            if NS.try_cast(ACTION.MagmaTotem, nil, "MagmaTotem") == true then _last_fire_totem = time_now(); return true end
            return false
        end },
    },
    {
        name = "ChainLightning",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "enemy_count", op = ">=", value = 2 },
            { type = "state", field = "mana_pct", op = ">=", value = 20 },
        },
        action = { type = "cast", spell = ACTION.ChainLightning, target = "target" },
    },
    {
        name = "FlameShock",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "flame_shock_remains", op = "<", value = 3 },
            { type = "state", field = "mana_pct", op = ">=", value = 15 },
        },
        action = { type = "cast", spell = ACTION.FlameShock, target = "target" },
    },
    -- Lava Burst is only worth casting while Flame Shock is on the target (guaranteed crit).
    {
        name = "LavaBurst",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "flame_shock_remains", op = ">", value = 0 },
            { type = "state", field = "mana_pct", op = ">=", value = 20 },
        },
        action = { type = "cast", spell = ACTION.LavaBurst, target = "target" },
    },
    {
        name = "Stormstrike",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "mana_pct", op = ">=", value = 10 },
        },
        action = { type = "cast", spell = ACTION.Stormstrike, target = "target" },
    },
    {
        name = "EarthShock",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "mana_pct", op = ">=", value = 15 },
        },
        action = { type = "cast", spell = ACTION.EarthShock, target = "target" },
    },
    {
        name = "LightningBolt",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "mana_pct", op = ">=", value = 15 },
        },
        action = { type = "cast", spell = ACTION.LightningBolt, target = "target" },
    },
}

-- Priority order (compiled in place from DSL_DEFS below).
local strategies = {
    { name = "WindShear" },
    { name = "HealingWave" },
    { name = "LightningShield" },
    { name = "FlametongueWeapon" },
    { name = "SearingTotem" },
    { name = "MagmaTotem" },
    { name = "ChainLightning" },
    { name = "FlameShock" },
    { name = "LavaBurst" },
    { name = "Stormstrike" },
    { name = "EarthShock" },
    { name = "LightningBolt" },
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

if NS.log then NS.log("Shaman leveling rotation registered") end

return { strategies = strategies, build_state = build_state }
