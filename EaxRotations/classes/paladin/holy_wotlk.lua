-- holy_wotlk.lua — Paladin Holy rotation for Wrath of the Lich King (3.3.5).
-- WHAT:  priority-list strategies for Holy paladin.
-- WHEN:  combat with valid friendly target.
-- WHY:   mirrors SimulationCraft / wowsims APL with WotLK-era mechanics.
-- SAFETY: state reads nil-guarded via spec_kit.safe_state(); declarative DSL strategies; no on_update() allocs.

local NS = _G.EaxRotations
if not NS then return nil end

local spec_kit = require("shared/spec_kit_sylvanas")
local dsl      = require("shared/strategy_dsl_sylvanas")
local SPELLS = NS.PaladinSpells or {}

local define = spec_kit.define_action_for_class(SPELLS)

local ACTION = {
    BeaconOfLight = define("BeaconOfLight", 53563, "BeaconOfLight"),
    HolyShock = define("HolyShock", { 33074, 33073, 33072, 33071, 33070, 20473 }, "HolyShock"),
    -- FoL/HL ranks verified lexxer (removed FoL/HL mixups 1022-1025 HoP, 19993 invalid, HL IDs that are FoL).
    FlashOfLight = define("FlashOfLight", { 48785, 27137, 19943, 19942, 19941, 19940, 19939, 19750 }, "FlashOfLight"),
    HolyLight = define("HolyLight", { 48782, 27136, 27135, 25292, 10329, 10328, 3472, 1026, 647, 639, 635 }, "HolyLight"),
    SacredShield = define("SacredShield", 53601, "SacredShield"),
}

local BEACON_OF_LIGHT_BUFF = { 53563 }
-- Sacred Shield player buff is 53601 only (lexxer wotlk). 53602/603/604 are unrelated.
local SACRED_SHIELD_BUFF = { 53601 }

local holy_state = {
    hp = 100,
    target_hp = 100,
    mana_pct = 100,
    enemy_count = 1,
    in_combat = false,
    beacon_up = false,
    sacred_shield_up = false,
}

local function build_state(context)
    local state = spec_kit.safe_state(holy_state)
    local me = NS.me or (NS.GetPlayer and NS.GetPlayer())
    local target = context and context.target
    state.hp = (me and me.get_health_percentage and me:get_health_percentage()) or 100
    state.mana_pct = (me and me.get_mana_percentage and me:get_mana_percentage()) or 100
    state.target_hp = (target and target.get_health_percentage and target:get_health_percentage()) or 100
    state.enemy_count = (context and context.enemy_count) or 1
    state.in_combat = (context and context.in_combat) or false
    state.beacon_up = (target and NS.buff_up and NS.buff_up(target, BEACON_OF_LIGHT_BUFF)) or false
    state.sacred_shield_up = (target and NS.buff_up and NS.buff_up(target, SACRED_SHIELD_BUFF)) or false
    return state
end

local DSL_DEFS = {
    {
        name = "BeaconOfLight",
        conditions = {
            { type = "state", field = "beacon_up", op = "falsy" },
        },
        action = { type = "cast", spell = ACTION.BeaconOfLight, target = "target" },
    },
    {
        name = "SacredShield",
        conditions = {
            { type = "state", field = "sacred_shield_up", op = "falsy" },
        },
        action = { type = "cast", spell = ACTION.SacredShield, target = "target" },
    },
    {
        name = "HolyShock",
        conditions = {
            { type = "state", field = "target_hp", op = "<", value = 80 },
        },
        action = { type = "cast", spell = ACTION.HolyShock, target = "target" },
    },
    {
        name = "HolyLight",
        conditions = {
            { type = "state", field = "target_hp", op = "<", value = 50 },
            { type = "state", field = "mana_pct", op = ">=", value = 30 },
        },
        action = { type = "cast", spell = ACTION.HolyLight, target = "target" },
    },
    {
        name = "FlashOfLight",
        conditions = {
            { type = "state", field = "target_hp", op = "<", value = 70 },
            { type = "state", field = "mana_pct", op = ">=", value = 20 },
        },
        action = { type = "cast", spell = ACTION.FlashOfLight, target = "target" },
    },
}

local strategies = {
    { name = "BeaconOfLight" },
    { name = "SacredShield" },
    { name = "HolyShock" },
    { name = "HolyLight" },
    { name = "FlashOfLight" },
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
    NS.rotation_registry:register("holy", strategies, { get_state = build_state })
end
if NS.log then NS.log("Paladin holy rotation registered") end

return { strategies = strategies, build_state = build_state }
