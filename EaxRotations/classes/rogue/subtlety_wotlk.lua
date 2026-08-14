-- subtlety_wotlk.lua — Rogue Subtlety rotation for Wrath of the Lich King (3.3.5).
-- WHAT:  priority-list strategies for Subtlety rogue.
-- WHEN:  combat with valid enemy target.
-- WHY:   mirrors SimulationCraft / wowsims APL with WotLK-era mechanics.
-- SAFETY: state reads nil-guarded via spec_kit.safe_state(); Backstab gated to
--         dagger + behind, Ambush gated to behind (TBC sibling convention);
--         energy/combo read context first; no on_update() allocs.

local NS = _G.EaxRotations
if not NS then return nil end

local spec_kit = require("shared/spec_kit_sylvanas")
local dsl      = require("shared/strategy_dsl_sylvanas")
local read_combo_points = require("shared/combo_points_reader_sylvanas")

-- Dagger set for the Backstab eligibility check (mirrors the TBC siblings).
local _dagger_set_ok, dagger_set = pcall(require, "shared/dagger_set_sylvanas")
if not _dagger_set_ok then dagger_set = nil end

-- Plain define_action (fire_wotlk precedent): define_action_for_class would
-- shadow the file-local WotLK rank lists with the TBC-era NS.RogueSpells
-- entries, so the WotLK max-rank ids (48691/48657) would never be cast.
local define = spec_kit.define_action

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
    energy = 0,
    combo_points = 0,
    enemy_count = 1,
    in_combat = false,
    shadow_dance_up = false,
    has_daggers = false,
    is_behind = false,
    target_is_casting = false,
}

local function build_state(context)
    local state = spec_kit.safe_state(subtlety_state)
    local me = NS.me or (NS.GetPlayer and NS.GetPlayer())
    local target = context and context.target
    -- context.energy / context.combo_points are engine-populated real fields
    -- (main_sylvanas.lua:816/878); me:get_energy()/get_combo_points() are
    -- mock-only unit methods and collapse to 0 in live play.
    state.energy = (context and context.energy) or (me and me.get_power and me:get_power(NS.POWER_ENERGY or 3)) or 0
    state.combo_points = (context and context.combo_points) or (me and read_combo_points and read_combo_points(me, NS.POWER_COMBO or 4)) or 0
    state.enemy_count = (context and context.enemy_count) or 1
    state.in_combat = (context and context.in_combat) or false
    state.target_is_casting = (target and target.is_casting and target:is_casting()) or false
    state.shadow_dance_up = (me and NS.buff_up and NS.buff_up(me, SHADOW_DANCE_BUFF)) or false
    -- Dagger check: Backstab requires a dagger main-hand (TBC sibling
    -- convention — dagger_set.is_dagger map over equipped item ids).
    local main_id, off_id
    if NS.get_equipped_item_id and NS.EQUIPMENT_SLOTS then
        main_id = NS.get_equipped_item_id(NS.EQUIPMENT_SLOTS.MAIN_HAND)
        off_id  = NS.get_equipped_item_id(NS.EQUIPMENT_SLOTS.OFF_HAND)
    end
    local is_dagger = dagger_set and dagger_set.is_dagger or {}
    state.has_daggers = (main_id and main_id ~= 0 and is_dagger[main_id])
        and (off_id and off_id ~= 0 and is_dagger[off_id])
    -- Strict behind check (real API — NS.is_behind_target, core_sylvanas.lua).
    if context and context.is_behind ~= nil then
        state.is_behind = context.is_behind == true
    elseif NS.is_behind_target and target then
        state.is_behind = NS.is_behind_target(target) == true
    else
        state.is_behind = false
    end
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
            -- Ambush requires being behind the target; without the gate the
            -- lane queues failed casts in front (TBC sibling convention).
            { type = "state", field = "is_behind", op = "truthy" },
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
            -- Backstab requires a dagger in the main hand AND being behind the
            -- target; without the gates the lane queues failed casts (TBC
            -- sibling convention). When blocked the rotation degrades to the
            -- fallback builder.
            { type = "state", field = "is_behind", op = "truthy" },
            { type = "state", field = "has_daggers", op = "truthy" },
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
