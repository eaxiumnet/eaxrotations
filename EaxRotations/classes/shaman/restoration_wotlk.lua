-- restoration_wotlk.lua — Shaman Restoration rotation for Wrath of the Lich King (3.3.5).
-- WHAT:  priority-list strategies for Restoration shaman.
-- WHEN:  combat with valid friendly target.
-- WHY:   mirrors SimulationCraft / wowsims APL with WotLK-era mechanics.
-- SAFETY: state reads nil-guarded via spec_kit.safe_state(); declarative DSL strategies; no on_update() allocs.

local NS = _G.EaxRotations
if not NS then return nil end

local spec_kit = require("shared/spec_kit_sylvanas")
local dsl      = require("shared/strategy_dsl_sylvanas")
local SPELLS = NS.ShamanSpells or {}

local define = spec_kit.define_action

local ACTION = {
    ManaTideTotem = define("ManaTideTotem", 16190, "ManaTideTotem"),
    EarthShield = define("EarthShield", 49284, "EarthShield"),
    Riptide = define("Riptide", 61301, "Riptide"),
    ChainHeal = define("ChainHeal", 55459, "ChainHeal"),
    HealingWave = define("HealingWave", 49273, "HealingWave"),
    LesserHealingWave = define("LesserHealingWave", 49276, "LesserHealingWave"),
}

local RIPTIDE_BUFF = { 61301, 61300, 61299, 61295 }
local EARTH_SHIELD_BUFF = { 49284, 32594, 32593, 974 }

local restoration_state = {
    target_hp = 100,
    mana_pct = 100,
    enemy_count = 1,
    in_combat = false,
    riptide_remains = 0,
    earth_shield_up = false,
    mana_tide_ready = false,
    injured_count = 0,
    lowest_hp = 100,
}

local function build_state(context)
    local state = spec_kit.safe_state(restoration_state)
    local me = NS.me or (NS.GetPlayer and NS.GetPlayer())
    local target = context and context.target
    state.mana_pct = (me and me.get_mana_percentage and me:get_mana_percentage()) or 100
    state.target_hp = (target and target.get_health_percentage and target:get_health_percentage()) or 100
    state.enemy_count = (context and context.enemy_count) or 1
    state.in_combat = (context and context.in_combat) or false
    state.riptide_remains = (target and NS.buff_remains and NS.buff_remains(target, RIPTIDE_BUFF)) or 0
    state.earth_shield_up = (target and NS.buff_up and NS.buff_up(target, EARTH_SHIELD_BUFF)) or false
    state.mana_tide_ready = (context and context.mana_tide_ready) or false
    state.injured_count = (context and context.injured_count) or 0
    state.lowest_hp = (context and context.lowest_hp) or state.target_hp
    return state
end

local DSL_DEFS = {
    {
        name = "ManaTideTotem",
        conditions = {
            { type = "state", field = "mana_tide_ready", op = "truthy" },
            { type = "state", field = "mana_pct", op = "<", value = 30 },
        },
        action = { type = "cast", spell = ACTION.ManaTideTotem, target = "self" },
    },
    {
        name = "EarthShield",
        conditions = {
            { type = "state", field = "earth_shield_up", op = "falsy" },
        },
        action = { type = "cast", spell = ACTION.EarthShield, target = "target" },
    },
    {
        name = "Riptide",
        conditions = {
            { type = "state", field = "riptide_remains", op = "<", value = 3 },
        },
        action = { type = "cast", spell = ACTION.Riptide, target = "target" },
    },
    {
        name = "ChainHeal",
        conditions = {
            { type = "state", field = "injured_count", op = ">=", value = 2 },
            { type = "state", field = "lowest_hp", op = "<", value = 85 },
            { type = "state", field = "mana_pct", op = ">=", value = 25 },
        },
        action = { type = "cast", spell = ACTION.ChainHeal, target = "target" },
    },
    {
        name = "LesserHealingWave",
        conditions = {
            { type = "state", field = "target_hp", op = "<", value = 90 },
            { type = "state", field = "mana_pct", op = ">=", value = 10 },
        },
        action = { type = "cast", spell = ACTION.LesserHealingWave, target = "target" },
    },
    {
        name = "HealingWave",
        conditions = {
            { type = "state", field = "target_hp", op = "<", value = 70 },
            { type = "state", field = "mana_pct", op = ">=", value = 20 },
        },
        action = { type = "cast", spell = ACTION.HealingWave, target = "target" },
    },
}

local strategies = {
    { name = "ManaTideTotem" },
    { name = "EarthShield" },
    { name = "Riptide" },
    { name = "ChainHeal" },
    { name = "HealingWave" },
    { name = "LesserHealingWave" },
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
    NS.rotation_registry:register("restoration", strategies, { get_state = build_state })
end
if NS.log then NS.log("Shaman restoration rotation registered") end

return { strategies = strategies, build_state = build_state }
