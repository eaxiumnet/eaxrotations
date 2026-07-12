-- subtlety_wotlk.lua — Rogue Subtlety rotation for Wrath of the Lich King (3.3.5).
-- WHAT:  priority-list strategies for Subtlety rogue.
-- WHEN:  combat with valid enemy target.
-- WHY:   mirrors SimulationCraft / wowsims APL with WotLK-era mechanics.
-- SAFETY: state reads nil-guarded via spec_kit.safe_state(); no on_update() allocs.

local NS = _G.EaxRotations
if not NS then return nil end

local spec_kit = require("shared/spec_kit_sylvanas")
local SPELLS = NS.RogueSpells or {}

local define = spec_kit.define_action_for_class(SPELLS)

local ACTION = {
    Premeditation = define("Premeditation", 14183, "Premeditation"),
    ShadowDance = define("ShadowDance", 51713, "ShadowDance"),
    Ambush = define("Ambush", { 27441, 11269, 11268, 11267, 8725, 8724, 8676 }, "Ambush"),
    Backstab = define("Backstab", { 26863, 25300, 11281, 11280, 11279, 8721, 2591, 2590, 2589, 53 }, "Backstab"),
    Eviscerate = define("Eviscerate", { 26865, 31016, 11300, 11299, 8624, 8623, 6762, 6761, 6760, 2098 }, "Eviscerate"),
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
    state.shadow_dance_up = (me and NS.buff_up and NS.buff_up(me, SHADOW_DANCE_BUFF)) or false
    return state
end

local function premeditation_matches(context, state)
    return true
end

local function shadow_dance_matches(context, state)
    return not state.shadow_dance_up
end

local function ambush_matches(context, state)
    return state.shadow_dance_up and state.energy >= 60
end

local function eviscerate_matches(context, state)
    return state.combo_points >= 4
end

local function backstab_matches(context, state)
    return state.energy >= 60
end

local strategies = {
    { name = "Premeditation", matches = premeditation_matches, execute = function(ctx) return ACTION.Premeditation and ACTION.Premeditation:cast_safe(ctx.target) end },
    { name = "ShadowDance", matches = shadow_dance_matches, execute = function(ctx) return ACTION.ShadowDance and ACTION.ShadowDance:cast_safe() end },
    { name = "Ambush", matches = ambush_matches, execute = function(ctx) return ACTION.Ambush and ACTION.Ambush:cast_safe(ctx.target) end },
    { name = "Eviscerate", matches = eviscerate_matches, execute = function(ctx) return ACTION.Eviscerate and ACTION.Eviscerate:cast_safe(ctx.target) end },
    { name = "Backstab", matches = backstab_matches, execute = function(ctx) return ACTION.Backstab and ACTION.Backstab:cast_safe(ctx.target) end },
}

if NS.rotation_registry and NS.rotation_registry.register then
    NS.rotation_registry:register("subtlety", strategies, { get_state = build_state })
end

return { strategies = strategies, build_state = build_state }
