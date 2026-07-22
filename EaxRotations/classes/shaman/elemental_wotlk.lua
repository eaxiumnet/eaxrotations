-- elemental_wotlk.lua — Shaman Elemental rotation for Wrath of the Lich King (3.3.5).
-- WHAT:  priority-list strategies for Elemental shaman.
-- WHEN:  combat with valid enemy target.
-- WHY:   mirrors SimulationCraft / wowsims APL with WotLK-era mechanics.
-- SAFETY: state reads nil-guarded via spec_kit.safe_state(); no on_update() allocs.

local NS = _G.EaxRotations
if not NS then return nil end

local spec_kit = require("shared/spec_kit_sylvanas")
local dsl      = require("shared/strategy_dsl_sylvanas")
local SPELLS = NS.ShamanSpells or {}

local define = spec_kit.define_action_for_class(SPELLS)

local ACTION = {
    FlameShock = define("FlameShock", { 25457, 29228, 10448, 10447, 8053, 8052, 8050 }, "FlameShock"),
    LavaBurst = define("LavaBurst", 51505, "LavaBurst"),
    LightningBolt = define("LightningBolt", { 25449, 25448, 15208, 15207, 10392, 10391, 6041, 943, 915, 548, 529, 403 }, "LightningBolt"),
    ChainLightning = define("ChainLightning", { 25442, 25439, 10605, 2860, 930, 421 }, "ChainLightning"),
    Thunderstorm = define("Thunderstorm", 51490, "Thunderstorm"),
}

local FLAME_SHOCK_DEBUFF = { 25457, 29228, 10448, 10447, 8053, 8052, 8050 }

local elemental_state = {
    hp = 100,
    target_hp = 100,
    mana_pct = 100,
    enemy_count = 1,
    in_combat = false,
    flame_shock_remains = 0,
}

local function build_state(context)
    local state = spec_kit.safe_state(elemental_state)
    local me = NS.me or (NS.GetPlayer and NS.GetPlayer())
    local target = context and context.target
    state.hp = (me and me.get_health_percentage and me:get_health_percentage()) or 100
    state.mana_pct = (me and me.get_mana_percentage and me:get_mana_percentage()) or 100
    state.target_hp = (target and target.get_health_percentage and target:get_health_percentage()) or 100
    state.enemy_count = (context and context.enemy_count) or 1
    state.in_combat = (context and context.in_combat) or false
    state.flame_shock_remains = (target and NS.debuff_remains and NS.debuff_remains(target, FLAME_SHOCK_DEBUFF)) or 0
    return state
end

local DSL_DEFS = {
    {
        name = "FlameShock",
        conditions = {
            { type = "state", field = "flame_shock_remains", op = "<", value = 3 },
        },
        action = { type = "cast", spell = ACTION.FlameShock, target = "target" },
    },
    {
        name = "LavaBurst",
        conditions = {
            { type = "state", field = "mana_pct", op = ">=", value = 20 },
        },
        action = { type = "cast", spell = ACTION.LavaBurst, target = "target" },
    },
    {
        name = "ChainLightning",
        conditions = {
            { type = "state", field = "enemy_count", op = ">=", value = 2 },
            { type = "state", field = "mana_pct", op = ">=", value = 25 },
        },
        action = { type = "cast", spell = ACTION.ChainLightning, target = "target" },
    },
    {
        name = "Thunderstorm",
        conditions = {
            { type = "state", field = "mana_pct", op = "<", value = 50 },
        },
        action = { type = "cast", spell = ACTION.Thunderstorm, target = "self" },
    },
    {
        name = "LightningBolt",
        conditions = {
            { type = "state", field = "mana_pct", op = ">=", value = 15 },
        },
        action = { type = "cast", spell = ACTION.LightningBolt, target = "target" },
    },
}

local strategies = {
    { name = "FlameShock" },
    { name = "LavaBurst" },
    { name = "ChainLightning" },
    { name = "Thunderstorm" },
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
    NS.rotation_registry:register("elemental", strategies, { get_state = build_state })
end
if NS.log then NS.log("Shaman elemental rotation registered") end

return { strategies = strategies, build_state = build_state }
