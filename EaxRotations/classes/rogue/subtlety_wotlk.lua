-- subtlety_wotlk.lua — Rogue Subtlety rotation for Wrath of the Lich King (3.3.5).
-- WHAT:  priority-list strategies for Subtlety rogue.
-- WHEN:  combat with valid enemy target.
-- WHY:   mirrors SimulationCraft / wowsims APL with WotLK-era mechanics.
-- SAFETY: state reads nil-guarded via spec_kit.safe_state(); declarative DSL strategies; no on_update() allocs.

local NS = _G.EaxRotations
if not NS then return nil end

local spec_kit = require("shared/spec_kit_sylvanas")
local dsl      = require("shared/strategy_dsl_sylvanas")
local SPELLS = NS.RogueSpells or {}

local define = spec_kit.define_action_for_class(SPELLS)

local ACTION = {
    Premeditation = define("Premeditation", 14183, "Premeditation"),
    ShadowDance = define("ShadowDance", 51713, "ShadowDance"),
    Ambush = define("Ambush", { 48691, 27441, 11269, 11268, 11267, 8725, 8724, 8676 }, "Ambush"),
    Backstab = define("Backstab", { 48657, 26863, 25300, 11281, 11280, 11279, 8721, 2591, 2590, 2589, 53 }, "Backstab"),
    Eviscerate = define("Eviscerate", { 48668, 26865, 31016, 11300, 11299, 8624, 8623, 6762, 6761, 6760, 2098 }, "Eviscerate"),
    -- Baseline rogue interrupt (3.3.5); not in any wowsims APL fixture.
    Kick = define("Kick", { 38768, 1769, 1768, 1767, 1766 }, "Kick"),
}

local SHADOW_DANCE_BUFF = { 51713 }

local subtlety_state = {
    hp = 100,
    target_hp = 100,
    energy = 0,
    combo_points = 0,
    enemy_count = 1,
    in_combat = false,
    shadow_dance_up = false,
    target_is_casting = false,
}

local function build_state(context)
    local state = spec_kit.safe_state(subtlety_state)
    local me = NS.me or (NS.GetPlayer and NS.GetPlayer())
    local target = context and context.target
    state.hp = (me and me.get_health_percentage and me:get_health_percentage()) or 100
    state.target_hp = (target and target.get_health_percentage and target:get_health_percentage()) or 100
    state.energy = (me and me.get_energy and me:get_energy()) or 0
    state.combo_points = (me and me.get_combo_points and me:get_combo_points()) or 0
    state.enemy_count = (context and context.enemy_count) or 1
    state.in_combat = (context and context.in_combat) or false
    state.target_is_casting = (target and target.is_casting and target:is_casting()) or false
    state.shadow_dance_up = (me and NS.buff_up and NS.buff_up(me, SHADOW_DANCE_BUFF)) or false
    return state
end

local DSL_DEFS = {
    {
        name = "Kick",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "target_is_casting", op = "truthy" },
        },
        action = { type = "cast", spell = ACTION.Kick, target = "target" },
    },
    {
        name = "Premeditation",
        conditions = {},
        action = { type = "cast", spell = ACTION.Premeditation, target = "target" },
    },
    {
        name = "ShadowDance",
        conditions = {
            { type = "state", field = "shadow_dance_up", op = "falsy" },
        },
        action = { type = "cast", spell = ACTION.ShadowDance, target = "self" },
    },
    {
        name = "Ambush",
        conditions = {
            { type = "state", field = "shadow_dance_up", op = "truthy" },
            { type = "state", field = "energy", op = ">=", value = 60 },
        },
        action = { type = "cast", spell = ACTION.Ambush, target = "target" },
    },
    {
        name = "Eviscerate",
        conditions = {
            { type = "state", field = "combo_points", op = ">=", value = 4 },
        },
        action = { type = "cast", spell = ACTION.Eviscerate, target = "target" },
    },
    {
        name = "Backstab",
        conditions = {
            { type = "state", field = "energy", op = ">=", value = 60 },
        },
        action = { type = "cast", spell = ACTION.Backstab, target = "target" },
    },
}

-- Kick is a baseline interrupt, not in the wowsims APL fixtures — first,
-- outside any pinned order.
local strategies = {
    { name = "Kick" },
    { name = "Premeditation" },
    { name = "ShadowDance" },
    { name = "Ambush" },
    { name = "Eviscerate" },
    { name = "Backstab" },
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
    NS.rotation_registry:register("subtlety", strategies, { get_state = build_state })
end
if NS.log then NS.log("Rogue subtlety rotation registered") end

return { strategies = strategies, build_state = build_state }
