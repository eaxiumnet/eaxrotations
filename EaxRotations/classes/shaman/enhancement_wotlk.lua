-- enhancement_wotlk.lua — Shaman Enhancement rotation for Wrath of the Lich King (3.3.5).
-- WHAT:  priority-list strategies for Enhancement shaman: Shamanistic Rage mana/CD,
--        Feral Spirit wolves, Stormstrike debuff, Lava Lash off-hand.
-- WHEN:  combat with valid enemy target.
-- WHY:   mirrors SimulationCraft / wowsims APL with WotLK-era mechanics.
-- SAFETY: state reads nil-guarded via spec_kit.safe_state(); DSL conditions replace
--         imperative match functions; no on_update() allocs.

local NS = _G.EaxRotations
if not NS then return nil end

local spec_kit = require("shared/spec_kit_sylvanas")
local dsl = require("shared/strategy_dsl_sylvanas")
local SPELLS = NS.ShamanSpells or {}

local define = spec_kit.define_action

local ACTION = {
    FeralSpirit = define("FeralSpirit", 51533, "FeralSpirit"),
    Bloodlust = define("Bloodlust", 2825, "Bloodlust"),
    LightningBolt = define("LightningBolt", 49238, "LightningBolt"),
    Stormstrike = define("Stormstrike", 17364, "Stormstrike"),
    FlameShock = define("FlameShock", 49233, "FlameShock"),
    EarthShock = define("EarthShock", 49231, "EarthShock"),
    CallOfTheElements = define("CallOfTheElements", 66842, "CallOfTheElements"),
    MagmaTotem = define("MagmaTotem", 58734, "MagmaTotem"),
    FireNova = define("FireNova", 61657, "FireNova"),
    LightningShield = define("LightningShield", 49281, "LightningShield"),
    LavaLash = define("LavaLash", 60103, "LavaLash"),
}

local MAELSTROM_WEAPON_BUFF = { 53817, 53816, 53815, 53814, 53813 }
local FLAME_SHOCK_DEBUFF = { 49233, 25457, 29228, 10448, 10447, 8053, 8052, 8050 }
local STORMSTRIKE_DEBUFF = { 17364 }
local LIGHTNING_SHIELD_BUFF = { 49281, 49280, 25472, 25469, 10432, 10431, 8134, 945, 905, 325, 324 }

local enhancement_state = {
    hp = 100,
    target_hp = 100,
    mana_pct = 100,
    enemy_count = 1,
    in_combat = false,
    maelstrom_stacks = 0,
    feral_spirit_ready = false,
    bloodlust_ready = false,
    flame_shock_remains = 0,
    stormstrike_remains = 0,
    water_totem_remains = 300,
    lightning_shield_up = false,
}

local function build_state(context)
    local state = spec_kit.safe_state(enhancement_state)
    local me = NS.me or (NS.GetPlayer and NS.GetPlayer())
    local target = context and context.target
    state.hp = (me and me.get_health_percentage and me:get_health_percentage()) or 100
    state.mana_pct = (me and me.get_mana_percentage and me:get_mana_percentage()) or 100
    state.target_hp = (target and target.get_health_percentage and target:get_health_percentage()) or 100
    state.enemy_count = (context and context.enemy_count) or 1
    state.in_combat = (context and context.in_combat) or false
    state.maelstrom_stacks = (me and NS.buff_stacks and NS.buff_stacks(me, MAELSTROM_WEAPON_BUFF)) or 0
    state.feral_spirit_ready = (ACTION.FeralSpirit and ACTION.FeralSpirit.cooldown_remaining and ACTION.FeralSpirit:cooldown_remaining() <= 0) or false
    state.bloodlust_ready = (context and context.bloodlust_ready) or false
    state.flame_shock_remains = (target and NS.debuff_remains and NS.debuff_remains(target, FLAME_SHOCK_DEBUFF)) or 0
    state.stormstrike_remains = (target and NS.debuff_remains and NS.debuff_remains(target, STORMSTRIKE_DEBUFF)) or 0
    state.water_totem_remains = (context and context.water_totem_remains) or 300
    if context and context.lightning_shield_up ~= nil then
        state.lightning_shield_up = context.lightning_shield_up
    else
        state.lightning_shield_up = (me and NS.buff_up and NS.buff_up(me, LIGHTNING_SHIELD_BUFF)) or false
    end
    return state
end

-- -----------------------------------------------------------------------------
-- Declarative Strategy DSL definitions
-- -----------------------------------------------------------------------------
local DSL_DEFS = {
    {
        name = "FeralSpirit",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "feral_spirit_ready", op = "truthy" },
        },
        action = { type = "cast", spell = ACTION.FeralSpirit, target = "target" },
    },
    {
        name = "Bloodlust",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "bloodlust_ready", op = "truthy" },
        },
        action = { type = "cast", spell = ACTION.Bloodlust, target = "self" },
    },
    {
        name = "LightningBolt",
        conditions = {
            { type = "state", field = "maelstrom_stacks", op = ">=", value = 5 },
        },
        action = { type = "cast", spell = ACTION.LightningBolt, target = "target" },
    },
    {
        name = "Stormstrike",
        conditions = {},
        action = { type = "cast", spell = ACTION.Stormstrike, target = "target" },
    },
    {
        name = "FlameShock",
        conditions = {
            { type = "state", field = "flame_shock_remains", op = "<", value = 3 },
        },
        action = { type = "cast", spell = ACTION.FlameShock, target = "target" },
    },
    {
        name = "EarthShock",
        conditions = {},
        action = { type = "cast", spell = ACTION.EarthShock, target = "target" },
    },
    {
        name = "CallOfTheElements",
        conditions = {
            { type = "state", field = "water_totem_remains", op = "<", value = 20 },
        },
        action = { type = "cast", spell = ACTION.CallOfTheElements, target = "self" },
    },
    {
        name = "MagmaTotem",
        conditions = {
            { type = "state", field = "enemy_count", op = ">=", value = 2 },
        },
        action = { type = "cast", spell = ACTION.MagmaTotem, target = "self" },
    },
    {
        name = "FireNova",
        conditions = {
            { type = "state", field = "enemy_count", op = ">=", value = 2 },
        },
        action = { type = "cast", spell = ACTION.FireNova, target = "self" },
    },
    {
        name = "LightningShield",
        conditions = {
            { type = "state", field = "lightning_shield_up", op = "falsy" },
        },
        action = { type = "cast", spell = ACTION.LightningShield, target = "self" },
    },
    {
        name = "LavaLash",
        conditions = {},
        action = { type = "cast", spell = ACTION.LavaLash, target = "target" },
    },
}

-- -----------------------------------------------------------------------------
-- Strategies (name-only placeholders; substituted by DSL)
-- -----------------------------------------------------------------------------
local strategies = {
    { name = "FeralSpirit" },
    { name = "Bloodlust" },
    { name = "LightningBolt" },
    { name = "Stormstrike" },
    { name = "FlameShock" },
    { name = "EarthShock" },
    { name = "CallOfTheElements" },
    { name = "MagmaTotem" },
    { name = "FireNova" },
    { name = "LightningShield" },
    { name = "LavaLash" },
}

-- Name-based substitution preserves the existing priority order.
for i = 1, #strategies do
    for j = 1, #DSL_DEFS do
        if strategies[i].name == DSL_DEFS[j].name then
            strategies[i] = dsl.compile_strategy(DSL_DEFS[j], { get_state = build_state })
            break
        end
    end
end

if NS.rotation_registry and NS.rotation_registry.register then
    NS.rotation_registry:register("enhancement", strategies, { get_state = build_state })
end
if NS.log then NS.log("Shaman Enhancement WotLK rotation registered") end

return { strategies = strategies, build_state = build_state }
