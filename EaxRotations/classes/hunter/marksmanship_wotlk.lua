-- marksmanship_wotlk.lua — Hunter Marksmanship rotation for Wrath of the Lich King (3.3.5).
-- WHAT:  priority-list strategies for Marksmanship hunter.
-- WHEN:  combat with valid enemy target.
-- WHY:   mirrors SimulationCraft / wowsims APL with WotLK-era mechanics.
-- SAFETY: state reads nil-guarded via spec_kit.safe_state(); no on_update() allocs.

local NS = _G.EaxRotations
if not NS then return nil end

local spec_kit = require("shared/spec_kit_sylvanas")
local dsl      = require("shared/strategy_dsl_sylvanas")
local SPELLS = NS.HunterSpells or {}

local define = spec_kit.define_action

local ACTION = {
    AspectOfTheViper = define("AspectOfTheViper", 34074, "AspectOfTheViper"),
    AspectOfTheDragonhawk = define("AspectOfTheDragonhawk", 61847, "AspectOfTheDragonhawk"),
    SilencingShot = define("SilencingShot", 34490, "SilencingShot"),
    KillShot = define("KillShot", 61006, "KillShot"),
    ExplosiveTrap = define("ExplosiveTrap", 49067, "ExplosiveTrap"),
    SerpentSting = define("SerpentSting", { 49001, 27016, 25295, 13555, 13554, 13553, 13552, 13551, 13550, 13549, 1978 }, "SerpentSting"),
    ChimeraShot = define("ChimeraShot", 53209, "ChimeraShot"),
    AimedShot = define("AimedShot", { 49050, 27065, 20904, 20903, 20902, 20901, 20900, 19434 }, "AimedShot"),
    MultiShot = define("MultiShot", { 49048, 49047, 27021, 25294, 14290, 14289, 14288, 2643 }, "MultiShot"),
    ArcaneShot = define("ArcaneShot", { 49045, 27019, 14287, 14286, 14285, 14284, 14283, 14282, 14281, 3044 }, "ArcaneShot"),
    SteadyShot = define("SteadyShot", { 49052, 34120 }, "SteadyShot"),
    HuntersMark = define("HuntersMark", { 14325, 14324, 14323, 1130 }, "HuntersMark"),
}

local ASPECT_VIPER_BUFF = { 34074 }
local ASPECT_DRAGONHAWK_BUFF = { 61847 }
local SERPENT_STING_DEBUFF = { 49001, 27016, 25295, 13555, 13554, 13553, 13552, 13551, 13550, 13549, 1978 }
local EXPLOSIVE_TRAP_DEBUFF = { 49067 }
local HUNTERS_MARK_DEBUFF = { 14325, 14324, 14323, 1130 }

local mm_state = {
    target_hp = 100,
    mana_pct = 100,
    enemy_count = 1,
    in_combat = false,
    serpent_remains = 0,
    explosive_trap_remains = 0,
    mark_remains = 0,
    viper_up = false,
    dragonhawk_up = false,
}

local function build_state(context)
    local state = spec_kit.safe_state(mm_state)
    local me = NS.me or (NS.GetPlayer and NS.GetPlayer())
    local target = context and context.target
    state.mana_pct = (me and me.get_mana_percentage and me:get_mana_percentage()) or 100
    state.target_hp = (target and target.get_health_percentage and target:get_health_percentage()) or 100
    state.enemy_count = (context and context.enemy_count) or 1
    state.in_combat = (context and context.in_combat) or false
    state.serpent_remains = (target and NS.debuff_remains and NS.debuff_remains(target, SERPENT_STING_DEBUFF)) or 0
    state.explosive_trap_remains = (target and NS.debuff_remains and NS.debuff_remains(target, EXPLOSIVE_TRAP_DEBUFF)) or 0
    state.mark_remains = (target and NS.debuff_remains and NS.debuff_remains(target, HUNTERS_MARK_DEBUFF)) or 0
    if context and context.viper_up ~= nil then
        state.viper_up = context.viper_up
    else
        state.viper_up = (me and NS.buff_up and NS.buff_up(me, ASPECT_VIPER_BUFF)) or false
    end
    if context and context.dragonhawk_up ~= nil then
        state.dragonhawk_up = context.dragonhawk_up
    else
        state.dragonhawk_up = (me and NS.buff_up and NS.buff_up(me, ASPECT_DRAGONHAWK_BUFF)) or false
    end
    return state
end

local DSL_DEFS = {
    {
        name = "AspectOfTheViper",
        conditions = {
            { type = "state", field = "viper_up", op = "falsy" },
            { type = "state", field = "mana_pct", op = "<", value = 10 },
        },
        action = { type = "cast", spell = ACTION.AspectOfTheViper, target = "self" },
    },
    {
        name = "AspectOfTheDragonhawk",
        conditions = {
            { type = "state", field = "dragonhawk_up", op = "falsy" },
            { type = "state", field = "mana_pct", op = ">=", value = 30 },
        },
        action = { type = "cast", spell = ACTION.AspectOfTheDragonhawk, target = "self" },
    },
    {
        name = "SilencingShot",
        conditions = {},
        action = { type = "cast", spell = ACTION.SilencingShot, target = "target" },
    },
    {
        name = "HuntersMark",
        conditions = {
            { type = "state", field = "mark_remains", op = "<", value = 3 },
        },
        action = { type = "cast", spell = ACTION.HuntersMark, target = "target" },
    },
    {
        name = "KillShot",
        conditions = {
            { type = "state", field = "target_hp", op = "<", value = 20 },
        },
        action = { type = "cast", spell = ACTION.KillShot, target = "target" },
    },
    {
        name = "SerpentSting",
        conditions = {
            { type = "state", field = "serpent_remains", op = "<", value = 3 },
        },
        action = { type = "cast", spell = ACTION.SerpentSting, target = "target" },
    },
    {
        name = "ExplosiveTrap",
        conditions = {
            { type = "state", field = "explosive_trap_remains", op = "<", value = 1 },
        },
        action = { type = "cast", spell = ACTION.ExplosiveTrap, target = "target" },
    },
    {
        name = "ChimeraShot",
        conditions = {},
        action = { type = "cast", spell = ACTION.ChimeraShot, target = "target" },
    },
    {
        name = "AimedShot",
        conditions = {},
        action = { type = "cast", spell = ACTION.AimedShot, target = "target" },
    },
    {
        name = "MultiShot",
        conditions = {
            { type = "state", field = "enemy_count", op = ">=", value = 2 },
        },
        action = { type = "cast", spell = ACTION.MultiShot, target = "target" },
    },
    {
        name = "ArcaneShot",
        conditions = {
            { type = "state", field = "mana_pct", op = ">=", value = 20 },
        },
        action = { type = "cast", spell = ACTION.ArcaneShot, target = "target" },
    },
    {
        name = "SteadyShot",
        conditions = {},
        action = { type = "cast", spell = ACTION.SteadyShot, target = "target" },
    },
}

local strategies = {
    { name = "AspectOfTheViper" },
    { name = "AspectOfTheDragonhawk" },
    { name = "SilencingShot" },
    { name = "HuntersMark" },
    { name = "KillShot" },
    { name = "SerpentSting" },
    { name = "ExplosiveTrap" },
    { name = "ChimeraShot" },
    { name = "AimedShot" },
    { name = "MultiShot" },
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
    NS.rotation_registry:register("marksmanship", strategies, { get_state = build_state })
end
if NS.log then NS.log("Hunter marksmanship rotation registered") end

return { strategies = strategies, build_state = build_state }
