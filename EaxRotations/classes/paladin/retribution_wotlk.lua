-- retribution_wotlk.lua — Paladin Retribution DPS rotation for Wrath of the Lich King (3.3.5).
-- WHAT:  priority-list strategies: seal maintenance (SoV/SoC), Judgement, Crusader Strike,
--          Divine Storm, Hammer of Wrath execute, Consecration AoE, Exorcism (Art of War),
--          Avenging Wrath burst, Divine Plea mana management.
-- WHEN:  combat with valid enemy target.
-- WHY:   mirrors SimulationCraft / wowsims APL with WotLK 3.3.5a mechanics.
-- SAFETY: state reads nil-guarded via spec_kit.safe_state(); DSL conditions replace
--         imperative match functions; no on_update() allocs.

local NS = _G.EaxRotations
if not NS then return nil end

-- Hit-volume AoE gates (install if core not loaded, e.g. unit tests)
do
    local _ok_aoe, AoeHV = pcall(require, "shared/aoe_hit_volume_sylvanas")
    if _ok_aoe and AoeHV and AoeHV.install then AoeHV.install(NS) end
end

local spec_kit = require("shared/spec_kit_sylvanas")
local dsl = require("shared/strategy_dsl_sylvanas")
local SPELLS = NS.PaladinSpells or {}

local define = spec_kit.define_action_for_class(SPELLS)

local ACTION = {
    Judgement       = define("Judgement",       { 20271, 53407, 53408 }, "Judgement"),
    CrusaderStrike  = define("CrusaderStrike",  { 35395 }, "CrusaderStrike"),
    DivineStorm     = define("DivineStorm",     53385, "DivineStorm"),
    Consecration    = define("Consecration",    { 48819, 27173, 20924, 20923, 20922, 20116, 26573 }, "Consecration"),
    Exorcism        = define("Exorcism",        { 48801, 27138, 10314, 10313, 10312, 5615, 5614, 879 }, "Exorcism"),
    HammerOfWrath   = define("HammerOfWrath",   { 48806, 27180, 24239, 24274, 24275 }, "HammerOfWrath"),
    AvengingWrath   = define("AvengingWrath",   31884, "AvengingWrath"),
    SealOfVengeance = define("SealOfVengeance", 31801, "SealOfVengeance"),
    SealOfCommand   = define("SealOfCommand",   { 27170, 20920, 20919, 20918, 20915, 20375 }, "SealOfCommand"),
    DivinePlea      = define("DivinePlea",      54428, "DivinePlea"),
}

local SEAL_OF_VENGEANCE_BUFF = { 31801 }
local SEAL_OF_COMMAND_BUFF   = { 27170, 20920, 20919, 20918, 20915, 20375 }
local ART_OF_WAR_BUFF        = { 59578, 59579 }
local DIVINE_PLEA_BUFF       = { 54428 }

local ret_state = {
    target_hp = 100,
    mana_pct = 100,
    enemy_count = 1,
    in_combat = false,
    seal_up = false,
    seal_of_vengeance_up = false,
    seal_of_command_up = false,
    art_of_war_proc = false,
    divine_plea_up = false,
    avenging_wrath_ready = false,
    judgement_cd = 99,
    crusader_strike_cd = 99,
    divine_storm_cd = 99,
    hammer_of_wrath_cd = 99,
    consecration_cd = 99,
    exorcism_cd = 99,
    divine_plea_cd = 99,
}

local function cd_remaining(action)
    if action and action.cooldown_remaining then return action:cooldown_remaining() end
    return 99
end

local function build_state(context)
    local state = spec_kit.safe_state(ret_state)
    local me = NS.me or (NS.GetPlayer and NS.GetPlayer())
    local target = context and context.target

    state.mana_pct   = (me and me.get_mana_percentage and me:get_mana_percentage()) or 100
    state.target_hp  = (target and target.get_health_percentage and target:get_health_percentage()) or 100
    state.enemy_count = (context and context.enemy_count) or 1
    state.in_combat  = (context and context.in_combat) or false

    state.seal_of_vengeance_up = (me and NS.buff_up and NS.buff_up(me, SEAL_OF_VENGEANCE_BUFF)) or false
    state.seal_of_command_up   = (me and NS.buff_up and NS.buff_up(me, SEAL_OF_COMMAND_BUFF)) or false
    state.seal_up              = state.seal_of_vengeance_up or state.seal_of_command_up
    state.art_of_war_proc      = (me and NS.buff_up and NS.buff_up(me, ART_OF_WAR_BUFF)) or false
    state.divine_plea_up       = (me and NS.buff_up and NS.buff_up(me, DIVINE_PLEA_BUFF)) or false

    state.avenging_wrath_ready = cd_remaining(ACTION.AvengingWrath) <= 0
    state.judgement_cd         = cd_remaining(ACTION.Judgement)
    state.crusader_strike_cd   = cd_remaining(ACTION.CrusaderStrike)
    state.divine_storm_cd      = cd_remaining(ACTION.DivineStorm)
    state.hammer_of_wrath_cd   = cd_remaining(ACTION.HammerOfWrath)
    state.consecration_cd      = cd_remaining(ACTION.Consecration)
    state.exorcism_cd          = cd_remaining(ACTION.Exorcism)
    state.divine_plea_cd       = cd_remaining(ACTION.DivinePlea)

    return state
end

-- -----------------------------------------------------------------------------
-- Declarative Strategy DSL definitions
-- -----------------------------------------------------------------------------
local DSL_DEFS = {
    {
        name = "SealOfVengeance",
        conditions = {
            { type = "state", field = "seal_up", op = "falsy" },
            { type = "state", field = "enemy_count", op = "<", value = 2 },
        },
        action = { type = "cast", spell = ACTION.SealOfVengeance, target = "self" },
    },
    {
        name = "SealOfCommand",
        conditions = {
            { type = "state", field = "seal_up", op = "falsy" },
            { type = "state", field = "enemy_count", op = ">=", value = 2 },
        },
        action = { type = "cast", spell = ACTION.SealOfCommand, target = "self" },
    },
    {
        name = "DivinePlea",
        conditions = {
            { type = "state", field = "mana_pct", op = "<", value = 40 },
            { type = "state", field = "divine_plea_up", op = "falsy" },
            { type = "state", field = "divine_plea_cd", op = "<=", value = 0 },
        },
        action = { type = "cast", spell = ACTION.DivinePlea, target = "self" },
    },
    {
        name = "AvengingWrath",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "avenging_wrath_ready", op = "truthy" },
            { type = "custom", fn = function(context, state)
                if not spec_kit.setting_bool(context, "use_avenging_wrath", true) then return false end
                if NS.should_use_long_cd and not NS.should_use_long_cd(context, 180) then return false end
                return true
            end },
        },
        action = { type = "cast", spell = ACTION.AvengingWrath, target = "self" },
    },
    {
        name = "HammerOfWrath",
        conditions = {
            { type = "state", field = "target_hp", op = "<", value = 20 },
            { type = "state", field = "hammer_of_wrath_cd", op = "<=", value = 0 },
        },
        action = { type = "cast", spell = ACTION.HammerOfWrath, target = "target" },
    },
    {
        name = "Judgement",
        conditions = {
            { type = "state", field = "judgement_cd", op = "<=", value = 0 },
        },
        action = { type = "cast", spell = ACTION.Judgement, target = "target" },
    },
    {
        name = "CrusaderStrike",
        conditions = {
            { type = "state", field = "crusader_strike_cd", op = "<=", value = 0 },
        },
        action = { type = "cast", spell = ACTION.CrusaderStrike, target = "target" },
    },
    {
        name = "DivineStorm",
        conditions = {
            { type = "state", field = "divine_storm_cd", op = "<=", value = 0 },
        },
        action = { type = "cast", spell = ACTION.DivineStorm, target = "target" },
    },
    {
        name = "Exorcism",
        conditions = {
            { type = "state", field = "art_of_war_proc", op = "truthy" },
            { type = "state", field = "exorcism_cd", op = "<=", value = 0 },
        },
        action = { type = "cast", spell = ACTION.Exorcism, target = "target" },
    },
    {
        name = "Consecration",
        conditions = {
            { type = "state", field = "mana_pct", op = ">=", value = 30 },
            { type = "state", field = "consecration_cd", op = "<=", value = 0 },
            { type = "custom", fn = function(context, state)
                return NS.aoe_self_meets and NS.aoe_self_meets(2, (NS.AOE_RADIUS and NS.AOE_RADIUS.SELF_8) or 8, context, state)
            end },
        },
        action = { type = "cast", spell = ACTION.Consecration, target = "target" },
    },
}

-- -----------------------------------------------------------------------------
-- Strategies (name-only placeholders; substituted by DSL)
-- -----------------------------------------------------------------------------
local strategies = {
    { name = "SealOfVengeance" },
    { name = "SealOfCommand" },
    { name = "DivinePlea" },
    { name = "AvengingWrath" },
    { name = "HammerOfWrath" },
    { name = "Judgement" },
    { name = "CrusaderStrike" },
    { name = "DivineStorm" },
    { name = "Exorcism" },
    { name = "Consecration" },
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
    NS.rotation_registry:register("retribution", strategies, { get_state = build_state })
end
if NS.log then NS.log("Paladin retribution WotLK rotation registered") end

return { strategies = strategies, build_state = build_state }
