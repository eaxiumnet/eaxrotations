-- leveling_wotlk.lua — Rogue leveling rotation for Wrath of the Lich King (3.3.5).
-- WHAT:  priority-list strategies for rogue leveling in WotLK.
-- WHEN:  combat with valid enemy target.
-- WHY:   simple combo-point builder/finisher rotation.
-- SAFETY: state reads nil-guarded via spec_kit.safe_state(); no on_update() allocs.

local NS = _G.EaxRotations
if not NS then return nil end

-- Hit-volume AoE gates (install if core not loaded, e.g. unit tests)
do
    local _ok_aoe, AoeHV = pcall(require, "shared/aoe_hit_volume_sylvanas")
    if _ok_aoe and AoeHV and AoeHV.install then AoeHV.install(NS) end
end

local spec_kit = require("shared/spec_kit_sylvanas")
local helpers = require("shared/leveling_helpers_sylvanas")
local SPELLS = NS.RogueSpells or {}

local define = spec_kit.define_action_for_class(SPELLS)

local ACTION = {
    SliceAndDice = define("SliceAndDice", { 6774, 5171 }, "SliceAndDice"),
    SinisterStrike = define("SinisterStrike", { 26862, 26861, 11294, 11293, 8621, 1760, 1759, 1758, 1757, 1752 }, "SinisterStrike"),
    Eviscerate = define("Eviscerate", { 26865, 31016, 11300, 11299, 8624, 8623, 6762, 6761, 6760, 2098 }, "Eviscerate"),
    -- WotLK max rank Rupture (48672) prepended over the TBC rank list.
    Rupture = define("Rupture", { 48672, 26867, 11275, 11274, 11273, 8640, 8639, 1943 }, "Rupture"),
    -- Fan of Knives (51723): WotLK physical AoE around the rogue (8yd, 50 energy).
    FanOfKnives = define("FanOfKnives", { 51723 }, "FanOfKnives"),
    Gouge = define("Gouge", { 11286, 11285, 8629, 1777, 1776 }, "Gouge"),
    Kick = define("Kick", { 38768, 1769, 1768, 1767, 1766 }, "Kick"),
    Stealth = define("Stealth", { 1787, 1786, 1785, 1784 }, "Stealth"),
    Ambush = define("Ambush", { 27441, 11269, 11268, 11267, 8725, 8724, 8676 }, "Ambush"),
}

local SLICE_AND_DICE_BUFF = { 6774, 5171 }
local STEALTH_BUFF = { 1787, 1786, 1785, 1784 }
local RUPTURE_DEBUFF = { 48672, 26867, 11275, 11274, 11273, 8640, 8639, 1943 }

local rogue_state = {
    hp = 100,
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
    state.hp = (me and me.get_health_percentage and me:get_health_percentage()) or 100
    state.target_hp = (target and target.get_health_percentage and target:get_health_percentage()) or 100
    state.energy = (me and me.get_energy and me:get_energy()) or 0
    state.combo_points = (me and me.get_combo_points and me:get_combo_points()) or 0
    state.enemy_count = (context and (context.enemies_count or context.enemy_count)) or 1
    state.in_combat = (context and context.in_combat) or false
    state.snd_remains = (me and NS.buff_remains and NS.buff_remains(me, SLICE_AND_DICE_BUFF)) or 0
    state.rupture_remains = (target and NS.debuff_remains and NS.debuff_remains(target, RUPTURE_DEBUFF)) or 0
    state.stealth_active = (me and NS.buff_up and NS.buff_up(me, STEALTH_BUFF)) or false
    state.target_casting = helpers.should_interrupt(target)
    return state
end

local function stealth_matches(context, state)
    -- Enter stealth out of combat so we can open with Ambush.
    return not state.in_combat and not state.stealth_active
end

local function ambush_matches(context, state)
    -- Stealth opener: high-damage strike while stealthed.
    return state.stealth_active and state.energy >= 60
end

local function fan_of_knives_matches(context, state)
    -- Physical AoE when surrounded (>=3 targets) with enough energy.
    return state.in_combat and state.energy >= 50
        and NS.aoe_self_meets and NS.aoe_self_meets(3, (NS.AOE_RADIUS and NS.AOE_RADIUS.SELF_8) or 8, context, state)
end

local function rupture_matches(context, state)
    -- Bleed finisher on long-lived targets; refresh when about to fall off.
    return state.in_combat and state.combo_points >= 4
        and state.rupture_remains < 3 and state.target_hp > 25
end

local function slice_and_dice_matches(context, state)
    return state.in_combat and state.snd_remains < 3 and state.combo_points >= 1
end

local function kick_matches(context, state)
    -- Kick is an interrupt: only fire when the target is actually casting.
    return state.in_combat and state.target_casting == true and state.energy >= 25
end

local function gouge_matches(context, state)
    return state.in_combat and state.energy >= 45
end

local function eviscerate_matches(context, state)
    return state.in_combat and state.combo_points >= 4
end

local function sinister_strike_matches(context, state)
    return state.in_combat and state.energy >= 45
end

local strategies = {
    { name = "Stealth", matches = stealth_matches, execute = function(ctx) return ACTION.Stealth and ACTION.Stealth:cast_safe() end },
    { name = "Ambush", matches = ambush_matches, execute = function(ctx) return ACTION.Ambush and ACTION.Ambush:cast_safe(ctx.target) end },
    { name = "Kick", matches = kick_matches, execute = function(ctx) return ACTION.Kick and ACTION.Kick:cast_safe(ctx.target) end },
    { name = "SliceAndDice", matches = slice_and_dice_matches, execute = function(ctx) return ACTION.SliceAndDice and ACTION.SliceAndDice:cast_safe() end },
    { name = "FanOfKnives", matches = fan_of_knives_matches, execute = function(ctx) return ACTION.FanOfKnives and ACTION.FanOfKnives:cast_safe() end },
    { name = "Rupture", matches = rupture_matches, execute = function(ctx) return ACTION.Rupture and ACTION.Rupture:cast_safe(ctx.target) end },
    { name = "Gouge", matches = gouge_matches, execute = function(ctx) return ACTION.Gouge and ACTION.Gouge:cast_safe(ctx.target) end },
    { name = "Eviscerate", matches = eviscerate_matches, execute = function(ctx) return ACTION.Eviscerate and ACTION.Eviscerate:cast_safe(ctx.target) end },
    { name = "SinisterStrike", matches = sinister_strike_matches, execute = function(ctx) return ACTION.SinisterStrike and ACTION.SinisterStrike:cast_safe(ctx.target) end },
}

if NS.rotation_registry and NS.rotation_registry.register then
    NS.rotation_registry:register("leveling", strategies, { get_state = build_state })
end

return { strategies = strategies, build_state = build_state }
