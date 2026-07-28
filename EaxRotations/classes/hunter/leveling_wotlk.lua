-- leveling_wotlk.lua — Hunter leveling rotation for Wrath of the Lich King (3.3.5).
-- WHAT:  priority-list strategies for hunter leveling in WotLK.
-- WHEN:  combat with valid enemy target.
-- WHY:   simple shot rotation with pet cooldowns.
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
local SPELLS = NS.HunterSpells or {}

local define = spec_kit.define_action_for_class(SPELLS)

local ACTION = {
    HuntersMark = define("HuntersMark", { 14325, 14324, 14323, 1130 }, "HuntersMark"),
    SerpentSting = define("SerpentSting", { 49001, 27016, 25295, 13555, 13554, 13553, 13552, 13551, 13550, 13549, 1978 }, "SerpentSting"),
    SteadyShot = define("SteadyShot", 34120, "SteadyShot"),
    ArcaneShot = define("ArcaneShot", { 27019, 14287, 14286, 14285, 14284, 14283, 14282, 14281, 3044 }, "ArcaneShot"),
    KillCommand = define("KillCommand", 34026, "KillCommand"),
    BestialWrath = define("BestialWrath", 19574, "BestialWrath"),
    SilencingShot = define("SilencingShot", 34490, "SilencingShot"),
    AspectOfTheDragonhawk = define("AspectOfTheDragonhawk", 61847, "AspectOfTheDragonhawk"),
    AspectOfTheHawk = define("AspectOfTheHawk", { 27044, 25296, 14322, 14321, 14320, 13165 }, "AspectOfTheHawk"),
    AspectOfTheViper = define("AspectOfTheViper", 34074, "AspectOfTheViper"),
    CallPet = define("CallPet", 883, "CallPet"),
    RevivePet = define("RevivePet", 982, "RevivePet"),
    -- Mend Pet ranks (lexxer); removed invalid 13539-43/1515 (1515 is Tame Beast).
    MendPet = define("MendPet", { 48990, 48989, 27046, 13544, 13543, 13542, 3662, 3661, 3111 }, "MendPet"),
    MultiShot = define("MultiShot", { 49048, 49047, 27021, 25294, 14290, 14289, 14288, 2643 }, "MultiShot"),
    Volley = define("Volley", { 58434, 58433, 42243, 27022, 1543 }, "Volley"),
}

local DRAGONHAWK_BUFF = { 61847 }
local HAWK_BUFF = { 27044, 25296, 14322, 14321, 14320, 13165 }
local VIPER_BUFF = { 34074 }

local SERPENT_STING_DEBUFF = { 49001, 27016, 25295, 13555, 13554, 13553, 13552, 13551, 13550, 13549, 1978 }
local HUNTERS_MARK_DEBUFF = { 14325, 14324, 14323, 1130 }

local hunter_state = {
    hp = 100,
    target_hp = 100,
    mana_pct = 100,
    enemy_count = 1,
    in_combat = false,
    serpent_remains = 0,
    mark_remains = 0,
    bestial_wrath_ready = false,
    target_casting = false,
    dps_aspect_up = false,
    viper_up = false,
    pet_alive = false,
    has_pet = false,
    pet_hp = 100,
}

local function build_state(context)
    local state = spec_kit.safe_state(hunter_state)
    local me = NS.me or (NS.GetPlayer and NS.GetPlayer())
    local target = context and context.target
    state.hp = (me and me.get_health_percentage and me:get_health_percentage()) or 100
    state.mana_pct = (me and me.get_mana_percentage and me:get_mana_percentage()) or 100
    state.target_hp = (target and target.get_health_percentage and target:get_health_percentage()) or 100
    state.enemy_count = (context and (context.enemies_count or context.enemy_count)) or 1
    state.in_combat = (context and context.in_combat) or false
    state.serpent_remains = (target and NS.debuff_remains and NS.debuff_remains(target, SERPENT_STING_DEBUFF)) or 0
    state.mark_remains = (target and NS.debuff_remains and NS.debuff_remains(target, HUNTERS_MARK_DEBUFF)) or 0
    state.bestial_wrath_ready = (ACTION.BestialWrath and ACTION.BestialWrath.cooldown_remaining and ACTION.BestialWrath:cooldown_remaining() <= 0) or false
    state.target_casting = helpers.should_interrupt(target)
    state.dps_aspect_up = (me and NS.buff_up and (NS.buff_up(me, DRAGONHAWK_BUFF) or NS.buff_up(me, HAWK_BUFF))) or false
    state.viper_up = (me and NS.buff_up and NS.buff_up(me, VIPER_BUFF)) or false
    local pet = pet_manager.get_pet(me)
    state.has_pet = pet ~= nil
    state.pet_alive = pet_manager.pet_alive(pet)
    state.pet_hp = (state.pet_alive and pet_manager.pet_hp_pct(pet)) or 100
    return state
end

local DSL_DEFS = {
    -- Silencing Shot is an interrupt: only fire when the target is actually casting.
    {
        name = "SilencingShot",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "target_casting", op = "truthy" },
            { type = "state", field = "mana_pct", op = ">=", value = 6 },
        },
        action = { type = "cast", spell = ACTION.SilencingShot, target = "target" },
    },
    -- Mana recovery stance: swap to Viper when low, hysteresis vs dps-aspect switch-back.
    {
        name = "AspectOfTheViper",
        conditions = {
            { type = "state", field = "viper_up", op = "falsy" },
            { type = "state", field = "mana_pct", op = "<", value = 20 },
        },
        action = { type = "cast", spell = ACTION.AspectOfTheViper, target = "self" },
    },
    -- Establish/return to Hawk/Dragonhawk once mana recovers past the hysteresis gap.
    -- Custom action preserves the Dragonhawk-first, Hawk-fallback cast order.
    {
        name = "DpsAspect",
        conditions = {
            { type = "state", field = "dps_aspect_up", op = "falsy" },
            { type = "state", field = "mana_pct", op = ">=", value = 40 },
        },
        action = { type = "custom", fn = function(context, state)
            if NS.try_cast(ACTION.AspectOfTheDragonhawk, nil, "AspectOfTheDragonhawk") == true then return true end
            return NS.try_cast(ACTION.AspectOfTheHawk, nil, "AspectOfTheHawk") == true
        end },
    },
    {
        name = "CallPet",
        conditions = {
            { type = "state", field = "in_combat", op = "falsy" },
            { type = "state", field = "has_pet", op = "falsy" },
        },
        action = { type = "cast", spell = ACTION.CallPet, target = "self" },
    },
    {
        name = "RevivePet",
        conditions = {
            { type = "state", field = "in_combat", op = "falsy" },
            { type = "state", field = "has_pet", op = "truthy" },
            { type = "state", field = "pet_alive", op = "falsy" },
        },
        action = { type = "cast", spell = ACTION.RevivePet, target = "self" },
    },
    {
        name = "MendPet",
        conditions = {
            { type = "state", field = "pet_alive", op = "truthy" },
            { type = "state", field = "pet_hp", op = "<", value = 80 },
            { type = "state", field = "mana_pct", op = ">=", value = 10 },
        },
        action = { type = "cast", spell = ACTION.MendPet, target = "self" },
    },
    {
        name = "HuntersMark",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "mark_remains", op = "<", value = 3 },
            { type = "state", field = "mana_pct", op = ">=", value = 10 },
        },
        action = { type = "cast", spell = ACTION.HuntersMark, target = "target" },
    },
    -- Ground AoE volley when enough enemies cluster near the target.
    {
        name = "Volley",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "mana_pct", op = ">=", value = 17 },
            { type = "custom", fn = function(context, state)
                if not NS.aoe_target_meets then return false end
                local radius = (NS.AOE_RADIUS and NS.AOE_RADIUS.GROUND_8) or 8
                return NS.aoe_target_meets(3, radius, context and context.target, context, state) and true or false
            end },
        },
        action = { type = "cast", spell = ACTION.Volley, target = "target" },
    },
    -- Multi-Shot cleave when 2+ enemies are near the target.
    {
        name = "MultiShot",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "mana_pct", op = ">=", value = 9 },
            { type = "custom", fn = function(context, state)
                if not NS.aoe_target_meets then return false end
                local radius = (NS.AOE_RADIUS and NS.AOE_RADIUS.TARGET_8) or 8
                return NS.aoe_target_meets(2, radius, context and context.target, context, state) and true or false
            end },
        },
        action = { type = "cast", spell = ACTION.MultiShot, target = "target" },
    },
    {
        name = "BestialWrath",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "bestial_wrath_ready", op = "truthy" },
        },
        action = { type = "cast", spell = ACTION.BestialWrath, target = "self" },
    },
    {
        name = "KillCommand",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "mana_pct", op = ">=", value = 15 },
        },
        action = { type = "cast", spell = ACTION.KillCommand, target = "target" },
    },
    {
        name = "SerpentSting",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "serpent_remains", op = "<", value = 3 },
            { type = "state", field = "mana_pct", op = ">=", value = 15 },
        },
        action = { type = "cast", spell = ACTION.SerpentSting, target = "target" },
    },
    {
        name = "ArcaneShot",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "mana_pct", op = ">=", value = 20 },
        },
        action = { type = "cast", spell = ACTION.ArcaneShot, target = "target" },
    },
    {
        name = "SteadyShot",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "mana_pct", op = ">=", value = 10 },
        },
        action = { type = "cast", spell = ACTION.SteadyShot, target = "target" },
    },
}

local strategies = {
    { name = "SilencingShot" },
    { name = "AspectOfTheViper" },
    { name = "DpsAspect" },
    { name = "CallPet" },
    { name = "RevivePet" },
    { name = "MendPet" },
    { name = "HuntersMark" },
    { name = "Volley" },
    { name = "MultiShot" },
    { name = "BestialWrath" },
    { name = "KillCommand" },
    { name = "SerpentSting" },
    { name = "ArcaneShot" },
    { name = "SteadyShot" },
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
if NS.log then NS.log("Hunter leveling rotation registered") end

return { strategies = strategies, build_state = build_state }
