-- leveling_wotlk.lua — Rogue leveling rotation for Wrath of the Lich King (3.3.5).
-- WHAT:  priority-list strategies for rogue leveling in WotLK.
-- WHEN:  combat with valid enemy target.
-- WHY:   simple combo-point builder/finisher rotation.
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
local read_combo_points = require("shared/combo_points_reader_sylvanas")

-- Plain define_action (fire_wotlk precedent): define_action_for_class would
-- shadow the file-local WotLK rank lists with the TBC-era NS.RogueSpells
-- entries, so the WotLK max-rank ids (48638/48668/48672) would never be cast.
local define = spec_kit.define_action

local ACTION = {
    SliceAndDice = define("SliceAndDice", { 6774, 5171 }, "SliceAndDice"),
    SinisterStrike = define("SinisterStrike", { 48638, 26862, 26861, 11294, 11293, 8621, 1760, 1759, 1758, 1757, 1752 }, "SinisterStrike"),
    Eviscerate = define("Eviscerate", { 48668, 26865, 31016, 11300, 11299, 8624, 8623, 6762, 6761, 6760, 2098 }, "Eviscerate"),
    -- WotLK max rank Rupture (48672) prepended over the TBC rank list.
    Rupture = define("Rupture", { 48672, 26867, 11275, 11274, 11273, 8640, 8639, 1943 }, "Rupture"),
    -- Fan of Knives (51723): WotLK physical AoE around the rogue (8yd, 50 energy).
    FanOfKnives = define("FanOfKnives", { 51723 }, "FanOfKnives"),
    Gouge = define("Gouge", { 11286, 11285, 8629, 1777, 1776 }, "Gouge"),
    Kick = define("Kick", { 38768, 1769, 1768, 1767, 1766 }, "Kick"),
    Stealth = define("Stealth", { 1787, 1786, 1785, 1784 }, "Stealth"),
    Ambush = define("Ambush", { 48691, 27441, 11269, 11268, 11267, 8725, 8724, 8676 }, "Ambush"),
}

local SLICE_AND_DICE_BUFF = { 6774, 5171 }
local STEALTH_BUFF = { 1787, 1786, 1785, 1784 }
local RUPTURE_DEBUFF = { 48672, 26867, 11275, 11274, 11273, 8640, 8639, 1943 }

local rogue_state = {
    target_hp = 100,
    energy = 0,
    combo_points = 0,
    enemy_count = 1,
    in_combat = false,
    snd_remains = 0,
    rupture_remains = 0,
    stealth_active = false,
    target_casting = false,
}

local function build_state(context)
    local state = spec_kit.safe_state(rogue_state)
    local me = NS.me or (NS.GetPlayer and NS.GetPlayer())
    local target = context and context.target
    state.target_hp = (target and target.get_health_percentage and target:get_health_percentage()) or 100
    -- context.energy / context.combo_points are engine-populated real fields
    -- (main_sylvanas.lua:816/878); me:get_energy()/get_combo_points() are
    -- mock-only unit methods and collapse to 0 in live play.
    state.energy = (context and context.energy) or (me and me.get_power and me:get_power(NS.POWER_ENERGY or 3)) or 0
    state.combo_points = (context and context.combo_points) or (me and read_combo_points and read_combo_points(me, NS.POWER_COMBO or 4)) or 0
    state.enemy_count = (context and (context.enemies_count or context.enemy_count)) or 1
    state.in_combat = (context and context.in_combat) or false
    state.snd_remains = (me and NS.buff_remains and NS.buff_remains(me, SLICE_AND_DICE_BUFF)) or 0
    state.rupture_remains = (target and NS.debuff_remains and NS.debuff_remains(target, RUPTURE_DEBUFF)) or 0
    state.stealth_active = (me and NS.buff_up and NS.buff_up(me, STEALTH_BUFF)) or false
    state.target_casting = helpers.should_interrupt(target)
    return state
end

local DSL_DEFS = {
    -- Enter stealth out of combat so we can open with Ambush.
    {
        name = "Stealth",
        conditions = {
            { type = "state", field = "in_combat", op = "falsy" },
            { type = "state", field = "stealth_active", op = "falsy" },
        },
        action = { type = "cast", spell = ACTION.Stealth, target = "self" },
    },
    -- Stealth opener: high-damage strike while stealthed.
    {
        name = "Ambush",
        conditions = {
            { type = "state", field = "stealth_active", op = "truthy" },
            { type = "state", field = "energy", op = ">=", value = 60 },
        },
        action = { type = "cast", spell = ACTION.Ambush, target = "target" },
    },
    -- Kick is an interrupt: only fire when the target is actually casting.
    {
        name = "Kick",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "target_casting", op = "truthy" },
            { type = "state", field = "energy", op = ">=", value = 25 },
        },
        action = { type = "cast", spell = ACTION.Kick, target = "target" },
    },
    {
        name = "SliceAndDice",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "snd_remains", op = "<", value = 3 },
            { type = "state", field = "combo_points", op = ">=", value = 1 },
        },
        action = { type = "cast", spell = ACTION.SliceAndDice, target = "self" },
    },
    -- Physical AoE when surrounded (>=3 targets) with enough energy.
    {
        name = "FanOfKnives",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "energy", op = ">=", value = 50 },
            { type = "custom", fn = function(context, state)
                if not NS.aoe_self_meets then return false end
                local radius = (NS.AOE_RADIUS and NS.AOE_RADIUS.SELF_8) or 8
                return NS.aoe_self_meets(3, radius, context, state) and true or false
            end },
        },
        action = { type = "cast", spell = ACTION.FanOfKnives, target = "self" },
    },
    -- Bleed finisher on long-lived targets; refresh when about to fall off.
    {
        name = "Rupture",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "combo_points", op = ">=", value = 4 },
            { type = "state", field = "rupture_remains", op = "<", value = 3 },
            { type = "state", field = "target_hp", op = ">", value = 25 },
        },
        action = { type = "cast", spell = ACTION.Rupture, target = "target" },
    },
    {
        name = "Gouge",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "energy", op = ">=", value = 45 },
        },
        action = { type = "cast", spell = ACTION.Gouge, target = "target" },
    },
    {
        name = "Eviscerate",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "combo_points", op = ">=", value = 4 },
        },
        action = { type = "cast", spell = ACTION.Eviscerate, target = "target" },
    },
    {
        name = "SinisterStrike",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "energy", op = ">=", value = 45 },
        },
        action = { type = "cast", spell = ACTION.SinisterStrike, target = "target" },
    },
}

local strategies = {
    { name = "Stealth" },
    { name = "Ambush" },
    { name = "Kick" },
    { name = "SliceAndDice" },
    { name = "FanOfKnives" },
    { name = "Rupture" },
    { name = "Gouge" },
    { name = "Eviscerate" },
    { name = "SinisterStrike" },
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
if NS.log then NS.log("Rogue leveling rotation registered") end

return { strategies = strategies, build_state = build_state }
