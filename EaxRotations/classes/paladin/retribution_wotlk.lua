-- retribution_wotlk.lua — Paladin Retribution DPS rotation for Wrath of the Lich King (3.3.5).
-- WHAT:  priority-list strategies: seal maintenance (SoV/SoC), Judgement, Crusader Strike,
--          Divine Storm, Hammer of Wrath execute, Consecration AoE, Exorcism (Art of War),
--          Avenging Wrath burst, Divine Plea mana management.
-- WHEN:  combat with valid enemy target.
-- WHY:   mirrors SimulationCraft / wowsims APL with WotLK 3.3.5a mechanics.
-- SAFETY: state reads nil-guarded via spec_kit.safe_state(); no on_update() allocs.

local NS = _G.EaxRotations
if not NS then return nil end

-- Hit-volume AoE gates (install if core not loaded, e.g. unit tests)
do
    local _ok_aoe, AoeHV = pcall(require, "shared/aoe_hit_volume_sylvanas")
    if _ok_aoe and AoeHV and AoeHV.install then AoeHV.install(NS) end
end

local spec_kit = require("shared/spec_kit_sylvanas")
local SPELLS = NS.PaladinSpells or {}

local define = spec_kit.define_action_for_class(SPELLS)

local ACTION = {
    Judgement       = define("Judgement",       { 20271, 53407, 53408 }, "Judgement"),
    CrusaderStrike  = define("CrusaderStrike",  { 35395 }, "CrusaderStrike"),
    DivineStorm     = define("DivineStorm",     53385, "DivineStorm"),
    Consecration    = define("Consecration",    { 48819, 27173, 20924, 20923, 20922, 20116, 26573 }, "Consecration"),
    Exorcism        = define("Exorcism",        { 48801, 27138, 10314, 10313, 10312, 5615, 5614, 879 }, "Exorcism"),
    HammerOfWrath   = define("HammerOfWrath",   { 48807, 27180, 24239, 24274, 24275 }, "HammerOfWrath"),
    AvengingWrath   = define("AvengingWrath",   31884, "AvengingWrath"),
    SealOfVengeance = define("SealOfVengeance", 31801, "SealOfVengeance"),
    SealOfCommand   = define("SealOfCommand",   { 27170, 20920, 20919, 20918, 20915, 20375 }, "SealOfCommand"),
    DivinePlea      = define("DivinePlea",      54428, "DivinePlea"),
}

local SEAL_OF_VENGEANCE_BUFF = { 31801 }
local SEAL_OF_COMMAND_BUFF   = { 27170, 20920, 20919, 20918, 20915, 20375 }
local ART_OF_WAR_BUFF        = { 59578, 59579 }
local DIVINE_PLEA_BUFF       = { 54428 }

local ret_state = {
    hp = 100,
    target_hp = 100,
    mana_pct = 100,
    enemy_count = 1,
    in_combat = false,
    seal_up = false,
    seal_of_vengeance_up = false,
    seal_of_command_up = false,
    art_of_war_proc = false,
    divine_plea_up = false,
    avenging_wrath_ready = false,
    judgement_cd = 99,
    crusader_strike_cd = 99,
    divine_storm_cd = 99,
    hammer_of_wrath_cd = 99,
    consecration_cd = 99,
    exorcism_cd = 99,
    divine_plea_cd = 99,
}

local function cd_remaining(action)
    if action and action.cooldown_remaining then return action:cooldown_remaining() end
    return 99
end

local function build_state(context)
    local state = spec_kit.safe_state(ret_state)
    local me = NS.me or (NS.GetPlayer and NS.GetPlayer())
    local target = context and context.target

    state.hp         = (me and me.get_health_percentage and me:get_health_percentage()) or 100
    state.mana_pct   = (me and me.get_mana_percentage and me:get_mana_percentage()) or 100
    state.target_hp  = (target and target.get_health_percentage and target:get_health_percentage()) or 100
    state.enemy_count = (context and context.enemy_count) or 1
    state.in_combat  = (context and context.in_combat) or false

    state.seal_of_vengeance_up = (me and NS.buff_up and NS.buff_up(me, SEAL_OF_VENGEANCE_BUFF)) or false
    state.seal_of_command_up   = (me and NS.buff_up and NS.buff_up(me, SEAL_OF_COMMAND_BUFF)) or false
    state.seal_up              = state.seal_of_vengeance_up or state.seal_of_command_up
    state.art_of_war_proc      = (me and NS.buff_up and NS.buff_up(me, ART_OF_WAR_BUFF)) or false
    state.divine_plea_up       = (me and NS.buff_up and NS.buff_up(me, DIVINE_PLEA_BUFF)) or false

    state.avenging_wrath_ready = cd_remaining(ACTION.AvengingWrath) <= 0
    state.judgement_cd         = cd_remaining(ACTION.Judgement)
    state.crusader_strike_cd   = cd_remaining(ACTION.CrusaderStrike)
    state.divine_storm_cd      = cd_remaining(ACTION.DivineStorm)
    state.hammer_of_wrath_cd   = cd_remaining(ACTION.HammerOfWrath)
    state.consecration_cd      = cd_remaining(ACTION.Consecration)
    state.exorcism_cd          = cd_remaining(ACTION.Exorcism)
    state.divine_plea_cd       = cd_remaining(ACTION.DivinePlea)

    return state
end

-- Seal of Vengeance: preferred for single-target (enemy_count < 2) when no seal is active.
local function seal_of_vengeance_matches(context, state)
    return not state.seal_up and (state.enemy_count or 1) < 2
end

-- Seal of Command: preferred for AoE (enemy_count >= 2) when no seal is active.
local function seal_of_command_matches(context, state)
    return not state.seal_up and (state.enemy_count or 1) >= 2
end

-- Divine Plea: mana recovery when below 40% mana, not already active, off cooldown.
local function divine_plea_matches(context, state)
    return (state.mana_pct or 100) < 40 and not state.divine_plea_up and state.divine_plea_cd <= 0
end

-- Avenging Wrath: burst cooldown for boss fights; gated by setting (default on).
local function avenging_wrath_matches(context, state)
    if not state.in_combat then return false end
    if not state.avenging_wrath_ready then return false end
    if not spec_kit.setting_bool(context, "use_avenging_wrath", true) then return false end
    if NS.should_use_long_cd and not NS.should_use_long_cd(context, 180) then return false end
    return true
end

-- Hammer of Wrath: execute when target HP < 20%, off cooldown.
local function hammer_of_wrath_matches(context, state)
    return (state.target_hp or 100) < 20 and state.hammer_of_wrath_cd <= 0
end

-- Judgement: on cooldown — mana return via Judgements of the Wise + damage.
local function judgement_matches(context, state)
    return state.judgement_cd <= 0
end

-- Crusader Strike: primary melee attack, 4s cooldown.
local function crusader_strike_matches(context, state)
    return state.crusader_strike_cd <= 0
end

-- Divine Storm: weapon strike hitting up to 4 targets, 10s cooldown (AoE + single target).
local function divine_storm_matches(context, state)
    return state.divine_storm_cd <= 0
end

-- Exorcism: instant cast when Art of War proc is active, 15s cooldown.
local function exorcism_matches(context, state)
    return state.art_of_war_proc and state.exorcism_cd <= 0
end

-- Consecration: AoE ground effect for 2+ enemies, mana-gated.
local function consecration_matches(context, state)
    return (state.mana_pct or 100) >= 30 and state.consecration_cd <= 0
        and NS.aoe_self_meets and NS.aoe_self_meets(2, (NS.AOE_RADIUS and NS.AOE_RADIUS.SELF_8) or 8, context, state)
end

local strategies = {
    { name = "SealOfVengeance", matches = seal_of_vengeance_matches, execute = function(ctx) return ACTION.SealOfVengeance and ACTION.SealOfVengeance:cast_safe() end },
    { name = "SealOfCommand",   matches = seal_of_command_matches,   execute = function(ctx) return ACTION.SealOfCommand and ACTION.SealOfCommand:cast_safe() end },
    { name = "DivinePlea",      matches = divine_plea_matches,       execute = function(ctx) return ACTION.DivinePlea and ACTION.DivinePlea:cast_safe() end },
    { name = "AvengingWrath",   matches = avenging_wrath_matches,    execute = function(ctx) return ACTION.AvengingWrath and ACTION.AvengingWrath:cast_safe() end },
    { name = "HammerOfWrath",   matches = hammer_of_wrath_matches,   execute = function(ctx) return ACTION.HammerOfWrath and ACTION.HammerOfWrath:cast_safe(ctx.target) end },
    { name = "Judgement",       matches = judgement_matches,         execute = function(ctx) return ACTION.Judgement and ACTION.Judgement:cast_safe(ctx.target) end },
    { name = "CrusaderStrike",  matches = crusader_strike_matches,   execute = function(ctx) return ACTION.CrusaderStrike and ACTION.CrusaderStrike:cast_safe(ctx.target) end },
    { name = "DivineStorm",     matches = divine_storm_matches,      execute = function(ctx) return ACTION.DivineStorm and ACTION.DivineStorm:cast_safe(ctx.target) end },
    { name = "Exorcism",        matches = exorcism_matches,          execute = function(ctx) return ACTION.Exorcism and ACTION.Exorcism:cast_safe(ctx.target) end },
    { name = "Consecration",    matches = consecration_matches,      execute = function(ctx) return ACTION.Consecration and ACTION.Consecration:cast_safe(ctx.target) end },
}

if NS.rotation_registry and NS.rotation_registry.register then
    NS.rotation_registry:register("retribution", strategies, { get_state = build_state })
end

if NS.log then NS.log("Paladin retribution WotLK rotation registered") end

return { strategies = strategies, build_state = build_state }
