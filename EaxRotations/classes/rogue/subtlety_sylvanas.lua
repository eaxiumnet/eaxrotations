-- subtlety_sylvanas.lua — Rogue Subtlety DPS for TBC Anniversary (2.5.5).
-- WHAT:  burst DPS spec (Premeditation, Shadowstep, Hemorrhage, stealth openers
--          Ambush/Garrote/CheapShot, Vanish-reopen, Preparation reset).
-- WHEN:  combat, with valid enemy target.
-- WHY:   mirrors wowsims APL: Premed > Shadowstep > Garrote > Hemo > SnD > Rupture.
-- SAFETY: state.* reads nil-guarded via spec_kit.safe_state(); Backstab gated to
--          dagger+behind; registration guarded.
local NS = _G.EaxRotations
if not NS then return nil end

local potion_helper = require("shared/potion_helper_sylvanas")
local _inv_ok, inventory_helper = pcall(require, "common/utility/inventory_helper")
if not _inv_ok or type(inventory_helper) ~= "table" then inventory_helper = nil end
local BASE_SPELLS = NS.RogueSpells or {}
local CCGateDB = NS.OffensiveDispelDB or require("shared/offensive_dispel_sylvanas")

-- spec_kit migration #25
local spec_kit = require("shared/spec_kit_sylvanas")
local read_combo_points = require("shared/combo_points_reader_sylvanas")
local dsl = require("shared/strategy_dsl_sylvanas")
local define = spec_kit.define_action_for_class(BASE_SPELLS)
local ACTION = {
    Ambush          = define("Ambush",          { 27441, 11269, 11268, 11267, 8725, 8724, 8676 }, "Ambush"),
    Backstab        = define("Backstab",        { 26863, 25300, 11281, 11280, 11279, 8721, 2591, 2590, 2589, 53 }, "Backstab"),
    Blind           = define("Blind",           { 2094 }, "Blind"),
    CheapShot       = define("CheapShot",       { 1833 }, "CheapShot"),
    CloakOfShadows  = define("CloakOfShadows",  { 31224 }, "CloakOfShadows"),
    DeadlyThrow     = define("DeadlyThrow",     { 26679 }, "DeadlyThrow"),
    Evasion         = define("Evasion",         { 26669, 5277 }, "Evasion"),
    Eviscerate      = define("Eviscerate",      { 26865, 31016, 11300, 11299, 8624, 8623, 6762, 6761, 6760, 2098 }, "Eviscerate"),
    ExposeArmor     = define("ExposeArmor",     { 26866, 11198, 8647 }, "ExposeArmor"),
    Feint           = define("Feint",           { 27448, 25302, 11303, 8637, 6768, 1966 }, "Feint"),
    Garrote         = define("Garrote",         { 26884, 26839, 11290, 11289, 8633, 8632, 8631, 703 }, "Garrote"),
    GhostlyStrike   = define("GhostlyStrike",   { 14278 }, "GhostlyStrike"),
    Gouge           = define("Gouge",           { 1776 }, "Gouge"),
    Hemorrhage      = define("Hemorrhage",      { 26864, 17348, 17347, 16511 }, "Hemorrhage"),
    KidneyShot      = define("KidneyShot",      { 8643, 408 }, "KidneyShot"),
    Kick            = define("Kick",            { 38768, 1769, 1768, 1767, 1766 }, "Kick"),
    Premeditation   = define("Premeditation",   { 14183 }, "Premeditation"),
    Preparation     = define("Preparation",     { 14185 }, "Preparation"),
    Rupture         = define("Rupture",         { 26867, 11275, 11274, 11273, 8640, 8639, 1943 }, "Rupture"),
    Sap             = define("Sap",             { 11297, 2070, 6770 }, "Sap"),
    Shadowstep      = define("Shadowstep",      { 36554 }, "Shadowstep"),
    Shiv             = define("Shiv",             { 5938 }, "Shiv"),
    SinisterStrike  = define("SinisterStrike",  { 26862, 26861, 11294, 11293, 8621, 1760, 1759, 1758, 1757, 1752 }, "SinisterStrike"),
    SliceAndDice    = define("SliceAndDice",    { 6774, 5171 }, "SliceAndDice"),
    Sprint          = define("Sprint",          { 11305, 8696, 2983 }, "Sprint"),
    Stealth         = define("Stealth",         { 1787, 1786, 1785, 1784 }, "Stealth"),
    Vanish          = define("Vanish",          { 26889, 1857, 1856 }, "Vanish"),
}

local STEALTH_BUFF = { 1787, 1786, 1785, 1784 }
local SLICE_AND_DICE_BUFF = { 6774, 5171 }
local SHADOWSTEP_BUFF = { 36554 }
local MASTER_OF_SUBTLETY_BUFF = { 31665, 31223, 31222, 31221 }
local RUPTURE_DEBUFF = { 26867, 11275, 11274, 11273, 8640, 8639, 1943 }
local HEMORRHAGE_DEBUFF = { 26864, 17348, 17347, 16511 }
local GARROTE_DEBUFF = { 26884, 26839, 11290, 11289, 8633, 8632, 8631, 703 }
local EXPOSE_ARMOR_DEBUFF = { 26866, 11198, 8647 }
local CHEAP_SHOT_DEBUFF = { 1833 }

local HEALTHSTONE_IDS = { 22105, 22104, 22103, 19013, 19012, 19011, 5512 }
local function first_ready_item(ids)
    if not inventory_helper then return nil end
    for _, id in ipairs(ids) do
        if inventory_helper.has_item(id) then return id end
    end
    return nil
end
local KIDNEY_SHOT_DEBUFF = { 8643, 408 }
local CONTROL_DEBUFFS = { 1833, 8643, 408, 1776, 2094, 11297, 2070, 6770 }

local ENERGY_CHEAP_SHOT = 60
local ENERGY_GARROTE = 50
local ENERGY_AMBUSH = 60
local ENERGY_HEMORRHAGE = 35
local ENERGY_BACKSTAB = 60
local ENERGY_GHOSTLY = 40
local ENERGY_KIDNEY = 25
local ENERGY_FINISHER = 35
local ENERGY_DEADLY_THROW = 35
local ENERGY_EXPOSE = 25
local ENERGY_FEINT = 20
local ENERGY_KICK = 25
local MELEE_RANGE = 5
local SHADOWSTEP_MIN_RANGE = 10
local SHADOWSTEP_MAX_RANGE = 25
local HEMO_REFRESH = 3
local RUPTURE_REFRESH = 3
local SND_REFRESH = 3
local ENERGY_LOW_BUILDER = 40
local ENERGY_LOW_FINISHER = 25
local RUPTURE_TTD_FLOOR = 12
local FEINT_THREAT_DEFAULT = 90

-- ============================================================================
-- Energy Tick Optimization (ported from combat_sylvanas.lua)
-- ============================================================================
local _last_energy = 0
local _last_tick_time = 0

local function get_next_tick_in(energy)
    local now = NS.time_now and NS.time_now() or 0
    local energy_gained = energy - _last_energy
    if energy_gained >= 19 and energy_gained <= 21 then
        _last_tick_time = now
        _last_energy = energy
        return 2.0
    end
    if energy_gained > 0 then
        _last_energy = energy
    end
    local time_since_tick = now - _last_tick_time
    if time_since_tick < 0 or time_since_tick > 4.0 then
        _last_tick_time = now
        return 2.0
    end
    return math.max(0, 2.0 - time_since_tick)
end

local function should_pool_energy(context)
    if not spec_kit.setting_bool(context, "subtlety_energy_tick_sync", false) then return false end
    local energy = context.energy or 0
    local offset = spec_kit.setting_number(context, "subtlety_energy_tick_offset", 100) / 1000
    local next_tick_in = get_next_tick_in(energy)
    if next_tick_in <= offset + 0.1 then
        local projected_energy = energy + 20
        if projected_energy <= 100 then
            return true
        end
    end
    return false
end

local function should_spend_energy(context, cost)
    if not spec_kit.setting_bool(context, "subtlety_energy_tick_sync", false) then return true end
    local energy = context.energy or 0
    local offset = spec_kit.setting_number(context, "subtlety_energy_tick_offset", 100) / 1000
    local next_tick_in = get_next_tick_in(energy)
    local projected_energy = energy + 20
    if projected_energy > 100 then
        return true
    end
    if next_tick_in > offset + 0.3 then
        return true
    end
    if next_tick_in <= offset then
        return true
    end
    return false
end

-- ============================================================================
-- State schema (nil-guard defaults for spec_kit.safe_state)
-- ============================================================================
local SUB_SCHEMA = {
    stealth_up = false,  slice_remains = 0,  rupture_remains = 0,
    hemo_remains = 0,  expose_remains = 0,  garrote_remains = 0,
    cheap_shot_remains = 0,  kidney_remains = 0,
    shadowstep_buff = false,  master_of_subtlety = false,
    combo = 0,  energy = 0,  energy_low = false,  energy_pool_finisher = false,
    hp = 100,  target_hp = 100,  target_distance = 40,  target_count = 1,
    healthstone_ready = 0,  is_behind = false,  is_caster_target = false,
    control_active = false,  threat_pct = 0,
    vanish_cd = 0,  sprint_cd = 0,  evasion_cd = 0,
    shiv_ready = false,  shiv_purge_name = nil,  is_group = false,
}

local subtlety_state = {
    stealth_up = false,
    slice_remains = 0,
    rupture_remains = 0,
    hemo_remains = 0,
    expose_remains = 0,
    garrote_remains = 0,
    cheap_shot_remains = 0,
    kidney_remains = 0,
    shadowstep_buff = false,
    master_of_subtlety = false,
    combo = 0,
    energy = 0,
    energy_low = false,
    energy_pool_finisher = false,
    hp = 100,
    target_hp = 100,
    target_distance = 40,
    target_count = 1,
    healthstone_ready = 0,
    is_behind = false,
    is_caster_target = false,
    control_active = false,
    threat_pct = 0,
    vanish_cd = 0,
    sprint_cd = 0,
    evasion_cd = 0,
    -- Shiv Purge (PvP buff dispel via Wound Poison)
    shiv_ready = false,
    shiv_purge_name = nil,
}

local function player_buff_up(ids)
    return NS.has_player_buff(ids) == true
end

local function target_debuff_remains(target, ids)
    if not target then return 0 end
    return NS.debuff_remains(target, ids) or 0
end

local setting = spec_kit.setting

local function option(context, key, default)
    local value = setting(context, key, default)
    if value == nil or value == "" then return default end
    return value
end

local function target_is_casting(target)
    if not target then return false end
    if NS.try_interrupt and NS.try_interrupt(target) then return true end
    return false
end

local function build_state(context)
    local target = context.target
    subtlety_state.is_group = context.is_group or false
    subtlety_state.stealth_up = player_buff_up(STEALTH_BUFF)
    subtlety_state.slice_remains = NS.buff_remains and (NS.buff_remains(context.me, SLICE_AND_DICE_BUFF) or 0) or 0
    subtlety_state.rupture_remains = target_debuff_remains(target, RUPTURE_DEBUFF)
    subtlety_state.hemo_remains = target_debuff_remains(target, HEMORRHAGE_DEBUFF)
    subtlety_state.expose_remains = target_debuff_remains(target, EXPOSE_ARMOR_DEBUFF)
    subtlety_state.garrote_remains = target_debuff_remains(target, GARROTE_DEBUFF)
    subtlety_state.cheap_shot_remains = target_debuff_remains(target, CHEAP_SHOT_DEBUFF)
    subtlety_state.kidney_remains = target_debuff_remains(target, KIDNEY_SHOT_DEBUFF)
    subtlety_state.shadowstep_buff = player_buff_up(SHADOWSTEP_BUFF)
    subtlety_state.master_of_subtlety = player_buff_up(MASTER_OF_SUBTLETY_BUFF)
    subtlety_state.control_active = target_debuff_remains(target, CONTROL_DEBUFFS) > 0
    subtlety_state.combo = context.combo_points or context.combo or 0
    subtlety_state.energy = context.energy or 0
    -- IZI SDK: energy_predicted for smarter pooling decisions
    local me = context.me or (NS.GetPlayer and NS.GetPlayer())
    local combo_points = read_combo_points(me, NS.POWER_COMBO or 4)
    if type(combo_points) == "number" then subtlety_state.combo = combo_points end
    if me and type(me.energy_predicted) == "function" then
        local ok, pred = pcall(me.energy_predicted, me)
        subtlety_state.energy_predicted = (ok and type(pred) == "number") and pred or subtlety_state.energy
    else
        subtlety_state.energy_predicted = subtlety_state.energy
    end
    subtlety_state.energy_low = subtlety_state.energy < ENERGY_LOW_BUILDER
    subtlety_state.energy_pool_finisher = subtlety_state.energy < ENERGY_LOW_FINISHER
    subtlety_state.hp = context.hp or context.player_hp or 100
    subtlety_state.target_hp = context.target_hp or 100
    subtlety_state.target_distance = context.target_distance or context.target_range or 40
    subtlety_state.target_count = context.enemy_count or context.enemies_count or 1
    subtlety_state.is_behind = NS.is_behind_target and NS.is_behind_target(target) or false
    subtlety_state.is_caster_target = target_is_casting(target)
    subtlety_state.threat_pct = context.threat_pct or 0
    subtlety_state.vanish_cd = NS.get_spell_cd and NS.get_spell_cd(ACTION.Vanish) or 0
    subtlety_state.sprint_cd = NS.get_spell_cd and NS.get_spell_cd(ACTION.Sprint) or 0
    subtlety_state.evasion_cd = NS.get_spell_cd and NS.get_spell_cd(ACTION.Evasion) or 0
    -- Shiv Purge (PvP buff dispel via Wound Poison)
    subtlety_state.shiv_ready = context.target and NS.spell_ready(ACTION.Shiv, context.target, { expected_cooldown = 10 }) or false
    subtlety_state.shiv_purge_name = nil
    if context.in_combat and (context.is_pvp or false) and context.target and CCGateDB.find_best_dispel_target then
        local best_id, _, best_name = CCGateDB.find_best_dispel_target(context.target, NS)
        if best_id then subtlety_state.shiv_purge_name = best_name end
    end
    subtlety_state.healthstone_ready = first_ready_item(HEALTHSTONE_IDS) or 0
    return spec_kit.safe_state(subtlety_state, SUB_SCHEMA)
end

local function has_enemy(context)
    return context and context.target and context.has_valid_enemy_target ~= false
end

local function enough_energy(state, cost)
    return (state.energy or 0) >= cost
end

local function in_melee(state)
    return (state.target_distance or 40) <= MELEE_RANGE + 1
end

local function in_shadowstep_range(context, state)
    local dist = state.target_distance or 40
    local min_range = setting(context, "shadowstep_min_range", SHADOWSTEP_MIN_RANGE)
    return dist > min_range and dist <= SHADOWSTEP_MAX_RANGE
end

local function is_pvp_target(context)
    return context.is_pvp == true or context.target_is_player == true
end

local function use_shadowstep_now(context)
    local usage = option(context, "shadowstep_usage", "always")
    if usage == "burst_only" then return context.should_burst == true or false end
    return usage ~= "off" and usage ~= false
end

local function opener_preference(context, state)
    local opener = option(context, "opener_preference", "auto")
    if opener == "auto" then
        if state.is_caster_target then return "garrote" end
        if is_pvp_target(context) then return "cheap_shot" end
        return "ambush"
    end
    return opener
end

local function hemo_refresh_needed(context, state)
    if not has_enemy(context) then return false end
    if (state.hemo_remains or 0) <= 0 then return true end
    if setting(context, "hemo_debuff_priority", true) and (state.hemo_remains or 0) < HEMO_REFRESH then return true end
    return false
end

local function cast(spell_obj, target, reason, opts)
    return NS.try_cast(spell_obj, target, reason, opts)
end

local function stealth_matches(context, state)
    if context.in_combat then return false end
    if state.stealth_up then return false end
    return NS.spell_ready(ACTION.Stealth, NS.PLAYER_UNIT, { skip_range = true })
end

local function sap_matches(context, state)
    if context.in_combat then return false end
    if not state.stealth_up then return false end
    if not has_enemy(context) then return false end
    return NS.spell_ready(ACTION.Sap, context.target)
end

local function premeditation_matches(context, state)
    if not state.stealth_up then return false end
    if (state.combo or 0) >= 3 then return false end
    return NS.spell_ready(ACTION.Premeditation, context.target, { skip_range = true })
end

local function shadowstep_opener_matches(context, state)
    if not state.stealth_up then return false end
    if not use_shadowstep_now(context) then return false end
    if not in_shadowstep_range(context, state) and not state.is_behind then return false end
    return NS.spell_ready(ACTION.Shadowstep, context.target)
end

local function ambush_opener_matches(context, state)
    if not state.stealth_up then return false end
    local opener = opener_preference(context, state)
    if opener ~= "ambush" and not state.shadowstep_buff then return false end
    if not enough_energy(state, ENERGY_AMBUSH) then return false end
    return NS.spell_ready(ACTION.Ambush, context.target)
end

local function garrote_opener_matches(context, state)
    if not state.stealth_up then return false end
    local opener = opener_preference(context, state)
    if opener ~= "garrote" then return false end
    if not enough_energy(state, ENERGY_GARROTE) then return false end
    return NS.spell_ready(ACTION.Garrote, context.target)
end

local function cheap_shot_opener_matches(context, state)
    if not state.stealth_up then return false end
    local opener = opener_preference(context, state)
    if opener ~= "cheap_shot" then return false end
    if not enough_energy(state, ENERGY_CHEAP_SHOT) then return false end
    return NS.spell_ready(ACTION.CheapShot, context.target)
end

local function kick_matches(context, state)
    -- Route through InterruptManager for cast window + humanization
    if not spec_kit.setting_bool(context, "use_interrupt", true) then return false end
    local mgr = NS.InterruptManager
    if mgr then
        if not NS.try_interrupt(context.target) then return false end
        if not mgr.cast_has_interrupt_window(context.target, context.settings or {}) then return false end
        if not mgr.humanize_interrupt_elapsed(context.target, context.settings or {}) then return false end
    else
        if not target_is_casting(context.target) then return false end
    end
    if not enough_energy(state, ENERGY_KICK) then return false end
    return NS.spell_ready(ACTION.Kick, context.target)
end

local function shiv_purge_matches(context, state)
    if not spec_kit.setting_bool(context, "use_shiv_purge", true) then return false end
    if not (NS.is_spell_learned and NS.is_spell_learned(5938)) then return false end
    if not context.in_combat then return false end
    if not (context.is_pvp or false) then return false end
    if not context.target then return false end
    if not (context.in_melee_range or false) then return false end
    if not state.shiv_ready then return false end
    if not state.shiv_purge_name then return false end
    if spec_kit.setting_bool(context, "shiv_purge_pvp_only", true) then
        local ok, is_player = pcall(function() return context.target:is_player() end)
        if not (ok and is_player) then return false end
    end
    return true
end

local function cloak_matches(context, state)
    if setting(context, "rogue_use_cloak", true) == false then return false end
    if (state.hp or 100) > setting(context, "rogue_cloak_hp", 45) and not state.is_caster_target then return false end
    return NS.spell_ready(ACTION.CloakOfShadows, NS.PLAYER_UNIT, { skip_range = true })
end

local function evasion_matches(context, state)
    if setting(context, "rogue_use_evasion", true) == false then return false end
    if (state.hp or 100) > setting(context, "rogue_evasion_hp", 35) then return false end
    return NS.spell_ready(ACTION.Evasion, NS.PLAYER_UNIT, { skip_range = true })
end

local function ghostly_strike_matches(context, state)
    if not is_pvp_target(context) and (state.hp or 100) > 55 then return false end
    if not in_melee(state) or not enough_energy(state, ENERGY_GHOSTLY) then return false end
    return NS.spell_ready(ACTION.GhostlyStrike, context.target)
end

local function blind_matches(context, state)
    if not is_pvp_target(context) then return false end
    if state.control_active then return false end
    -- IZI SDK: skip Blind if target is already CC'd
    local target = context.target
    if target and type(target.is_cc) == "function" then
        local ok, cc = pcall(target.is_cc, target)
        if ok and cc then return false end
    end
    if (state.hp or 100) > 35 and (state.target_hp or 100) > 25 then return false end
    return NS.spell_ready(ACTION.Blind, context.target)
end

local function gouge_matches(context, state)
    if not is_pvp_target(context) then return false end
    if state.control_active then return false end
    -- IZI SDK: skip Gouge if target is already CC'd
    local target = context.target
    if target and type(target.is_cc) == "function" then
        local ok, cc = pcall(target.is_cc, target)
        if ok and cc then return false end
    end
    if not in_melee(state) or (state.energy or 0) < 45 then return false end
    return NS.spell_ready(ACTION.Gouge, context.target)
end

local function shadowstep_gap_matches(context, state)
    if not use_shadowstep_now(context) then return false end
    if not in_shadowstep_range(context, state) then return false end
    return NS.spell_ready(ACTION.Shadowstep, context.target)
end

local function sprint_gap_matches(context, state)
    if (state.target_distance or 40) <= 12 or (state.target_distance or 40) > 35 then return false end
    return NS.spell_ready(ACTION.Sprint, NS.PLAYER_UNIT, { skip_range = true })
end

local function vanish_burst_matches(context, state)
    if state.stealth_up then return false end
    if (state.hp or 100) <= setting(context, "rogue_vanish_hp", 20) and setting(context, "rogue_use_vanish_defensive", false) then
        return NS.spell_ready(ACTION.Vanish, NS.PLAYER_UNIT, { skip_range = true })
    end
    if not (context.should_burst) then return false end
    return NS.spell_ready(ACTION.Vanish, NS.PLAYER_UNIT, { skip_range = true })
end

local function preparation_matches(context, state)
    local in_burst = context.should_burst or false
    if setting(context, "use_cooldowns", true) == false and not in_burst then return false end
    if (state.hp or 100) > setting(context, "subtlety_prep_hp", 40) then return false end
    -- Only use when at least one major cooldown is actually on cooldown
    if NS.get_spell_cd then
        local has_cd_burned = (state.vanish_cd or 0) > 0 or (state.sprint_cd or 0) > 0 or (state.evasion_cd or 0) > 0
        if not has_cd_burned then return false end
    end
    if not context.in_combat then return false end
    return NS.spell_ready(ACTION.Preparation, NS.PLAYER_UNIT, { skip_range = true })
end

local function kidney_shot_matches(context, state)
    if NS.DRTracker and NS.DRTracker.is_dr_immune and context.target and NS.DRTracker.is_dr_immune(context.target, "stun") then return false end
    if (state.combo or 0) < 3 or not enough_energy(state, ENERGY_KIDNEY) then return false end
    if (state.kidney_remains or 0) > 0 then return false end
    if not is_pvp_target(context) and (state.target_hp or 100) > 35 then return false end
    return NS.spell_ready(ACTION.KidneyShot, context.target)
end

local function shadowstep_hemo_matches(context, state)
    if not state.shadowstep_buff then return false end
    if not enough_energy(state, ENERGY_HEMORRHAGE) then return false end
    return NS.spell_ready(ACTION.Hemorrhage, context.target)
end

local function hemo_debuff_matches(context, state)
    if not hemo_refresh_needed(context, state) then return false end
    if not enough_energy(state, ENERGY_HEMORRHAGE) then return false end
    return NS.spell_ready(ACTION.Hemorrhage, context.target)
end

local function slice_matches(context, state)
    if (state.combo or 0) < 2 then return false end
    if (state.slice_remains or 0) > SND_REFRESH then return false end
    if state.energy_pool_finisher then return false end
    if not should_spend_energy(context, ENERGY_FINISHER) then return false end
    return NS.spell_ready(ACTION.SliceAndDice, NS.PLAYER_UNIT, { skip_range = true })
end

local function rupture_matches(context, state)
    if (state.combo or 0) < 4 then return false end
    if state.energy_pool_finisher then return false end
    if (state.target_hp or 100) < 25 or (context.ttd or 999) < RUPTURE_TTD_FLOOR then return false end
    if (state.rupture_remains or 0) > RUPTURE_REFRESH then return false end
    if not should_spend_energy(context, ENERGY_FINISHER) then return false end
    return NS.spell_ready(ACTION.Rupture, context.target)
end

local function expose_armor_matches(context, state)
    if not setting(context, "subtlety_expose_assigned", false) then return false end
    if (context.has_sunder or false) then return false end
    -- Skip if target has no armor (API unavailable or already fully reduced)
    if (context.target_armor or 0) <= 0 then return false end
    if (state.combo or 0) < 4 then return false end
    if (state.expose_remains or 0) > 3 then return false end
    if not context.target_is_boss and (context.ttd or 999) < 20 then return false end
    return NS.spell_ready(ACTION.ExposeArmor, context.target)
end

local function deadly_throw_matches(context, state)
    if (state.combo or 0) < 3 or not enough_energy(state, ENERGY_DEADLY_THROW) then return false end
    if (state.target_distance or 40) <= MELEE_RANGE or (state.target_distance or 40) > 30 then return false end
    return NS.spell_ready(ACTION.DeadlyThrow, context.target)
end

local function eviscerate_kill_matches(context, state)
    if (state.combo or 0) < 4 then return false end
    if state.energy_pool_finisher then return false end
    if (state.energy or 0) < ENERGY_FINISHER then return false end  -- hard floor
    if (state.target_hp or 100) > 30 and not state.shadowstep_buff then return false end
    if not should_spend_energy(context, ENERGY_FINISHER) then return false end
    return NS.spell_ready(ACTION.Eviscerate, context.target)
end

local function eviscerate_matches(context, state)
    if (state.combo or 0) < 4 then return false end
    if state.energy_pool_finisher then return false end
    if (state.energy or 0) < ENERGY_FINISHER then return false end  -- hard floor
    if not should_spend_energy(context, ENERGY_FINISHER) then return false end
    return NS.spell_ready(ACTION.Eviscerate, context.target)
end

local function feint_matches(context, state)
    if not context.in_combat then return false end
    local feint_threat = setting(context, "subtlety_feint_threat", FEINT_THREAT_DEFAULT)
    if (state.threat_pct or 0) <= 0 or (state.threat_pct or 0) < feint_threat then return false end
    if not enough_energy(state, ENERGY_FEINT) then return false end
    return NS.spell_ready(ACTION.Feint, NS.PLAYER_UNIT, { skip_range = true })
end

local function hemorrhage_matches(context, state)
    if state.energy_low then return false end  -- pool energy below 40
    if not enough_energy(state, ENERGY_HEMORRHAGE) then return false end
    if not should_spend_energy(context, ENERGY_HEMORRHAGE) then return false end
    return NS.spell_ready(ACTION.Hemorrhage, context.target)
end

local function backstab_matches(context, state)
    if not state.is_behind then return false end
    if state.energy_low then return false end
    if not enough_energy(state, ENERGY_BACKSTAB) then return false end
    if state.stealth_up then return false end  -- use Ambush instead
    -- Backstab is positional burst; Hemorrhage is primary builder per Research
    local in_burst = context.should_burst or false
    if (state.energy or 0) < 75 and not in_burst then return false end
    if not should_spend_energy(context, ENERGY_BACKSTAB) then return false end
    return NS.spell_ready(ACTION.Backstab, context.target)
end

local function fallback_builder_matches(context, state)
    if not enough_energy(state, 45) then return false end
    if not should_spend_energy(context, 45) then return false end
    return NS.spell_ready(ACTION.SinisterStrike, context.target)
end

local DSL_DEFS = {
    {
        name = "HealthPotion",
        conditions = {
            { type = "in_combat" },
            { type = "setting", key = "use_auto_potions", op = "truthy", default = true },
            { type = "context", field = "has_health_potion", op = "truthy" },
            { type = "hp_threshold", op = "<=", value = 35 },
        },
        action = { type = "custom", fn = function(context)
            return potion_helper.try_use_potion(context, potion_helper.HEALTH_POTION_IDS)
        end },
    },
    {
        name = "DamagePotion",
        conditions = {
            { type = "in_combat" },
            { type = "setting", key = "use_auto_potions", op = "truthy", default = true },
            { type = "context", field = "has_damage_potion", op = "truthy" },
            { type = "context", field = "should_burst", op = "truthy" },
        },
        action = { type = "custom", fn = function(context)
            return potion_helper.try_use_potion(context, potion_helper.DAMAGE_POTION_IDS)
        end },
    },
    {
        name = "Healthstone",
        conditions = {
            { type = "in_combat" },
            { type = "state", field = "hp", op = "<=", value = 28 },
            { type = "custom", fn = function(context, state)
                return (state.healthstone_ready or 0) > 0
            end },
        },
        action = { type = "custom", fn = function(context)
            local id = first_ready_item(HEALTHSTONE_IDS)
            if id then NS.use_item_by_id(id, context.me) end
            return true
        end },
    },
    {
        name = "Kick",
        conditions = {
            { type = "custom", fn = function(context, state)
                return kick_matches(context, state)
            end },
        },
        action = { type = "cast", spell = ACTION.Kick, target = "target" },
    },
    {
        name = "ShivPurge",
        conditions = {
            { type = "custom", fn = function(context, state)
                if not shiv_purge_matches(context, state) then return false end
                context._shiv_purge_name = state.shiv_purge_name
                return true
            end },
        },
        action = { type = "custom", fn = function(context)
            local name = context._shiv_purge_name or "buff"
            return NS.try_cast(ACTION.Shiv, context.target, "[SUBTLETY] Shiv purge → " .. name, { expected_cooldown = 10 })
        end },
    },
    {
        name = "CloakOfShadows",
        conditions = {
            { type = "custom", fn = function(context, state)
                return cloak_matches(context, state)
            end },
        },
        action = { type = "cast", spell = ACTION.CloakOfShadows, target = "self" },
    },
}

local strategies = {
    { name = "HealthPotion" },
    { name = "DamagePotion" },
    { name = "Healthstone" },
    { name = "Kick" },
    { name = "ShivPurge" },
    { name = "CloakOfShadows" },
    { name = "Evasion", matches = evasion_matches, execute = function() return cast(ACTION.Evasion, NS.PLAYER_UNIT, "[SUBTLETY] Evasion", { skip_range = true }) end },
    { name = "GhostlyStrike", matches = ghostly_strike_matches, execute = function(context) return cast(ACTION.GhostlyStrike, context.target, "[SUBTLETY] Ghostly Strike") end },
    { name = "Blind", matches = blind_matches, execute = function(context) return cast(ACTION.Blind, context.target, "[SUBTLETY] Blind") end },
    { name = "Gouge", matches = gouge_matches, execute = function(context) return cast(ACTION.Gouge, context.target, "[SUBTLETY] Gouge") end },
    { name = "Stealth", matches = stealth_matches, execute = function() return cast(ACTION.Stealth, NS.PLAYER_UNIT, "[SUBTLETY] Stealth", { skip_range = true }) end },
    { name = "Sap", matches = sap_matches, execute = function(context) return cast(ACTION.Sap, context.target, "[SUBTLETY] Sap") end },
    { name = "Premeditation", matches = premeditation_matches, execute = function(context) return cast(ACTION.Premeditation, context.target, "[SUBTLETY] Premeditation", { skip_range = true }) end },
    { name = "ShadowstepOpener", matches = shadowstep_opener_matches, is_burst = true, execute = function(context) return cast(ACTION.Shadowstep, context.target, "[SUBTLETY] Shadowstep opener") end },
    { name = "Ambush", spell = ACTION.Ambush, requires_buff = { 1787, 1786, 1785, 1784 }, requires_behind = true, min_energy = ENERGY_AMBUSH, matches = ambush_opener_matches, execute = function(context) return cast(ACTION.Ambush, context.target, "[SUBTLETY] Ambush") end },
    { name = "Garrote", matches = garrote_opener_matches, execute = function(context) return cast(ACTION.Garrote, context.target, "[SUBTLETY] Garrote caster opener") end },
    { name = "CheapShot", matches = cheap_shot_opener_matches, execute = function(context) return cast(ACTION.CheapShot, context.target, "[SUBTLETY] Cheap Shot opener") end },
    { name = "Vanish", matches = vanish_burst_matches, is_burst = true, execute = function() return cast(ACTION.Vanish, NS.PLAYER_UNIT, "[SUBTLETY] Vanish reopen", { skip_range = true }) end },
    { name = "Preparation", matches = preparation_matches, is_burst = true, execute = function() return cast(ACTION.Preparation, NS.PLAYER_UNIT, "[SUBTLETY] Preparation reset", { skip_range = true }) end },
    { name = "Sprint", matches = sprint_gap_matches, execute = function() return cast(ACTION.Sprint, NS.PLAYER_UNIT, "[SUBTLETY] Sprint gap close", { skip_range = true }) end },
    { name = "Shadowstep", matches = shadowstep_gap_matches, is_burst = true, execute = function(context) return cast(ACTION.Shadowstep, context.target, "[SUBTLETY] Shadowstep") end },
    { name = "KidneyShot", matches = kidney_shot_matches, execute = function(context) return cast(ACTION.KidneyShot, context.target, "[SUBTLETY] Kidney Shot stun chain") end },
    { name = "ShadowstepHemorrhage", matches = shadowstep_hemo_matches, execute = function(context) return cast(ACTION.Hemorrhage, context.target, "[SUBTLETY] Shadowstep Hemorrhage") end },
    { name = "HemorrhageDebuff", matches = hemo_debuff_matches, execute = function(context) return cast(ACTION.Hemorrhage, context.target, "[SUBTLETY] Hemorrhage debuff") end },
    { name = "SliceAndDice", matches = slice_matches, execute = function() return cast(ACTION.SliceAndDice, NS.PLAYER_UNIT, "[SUBTLETY] Slice and Dice", { skip_range = true }) end },
    { name = "ExposeArmor", matches = expose_armor_matches, execute = function(context) return cast(ACTION.ExposeArmor, context.target, "[SUBTLETY] Expose Armor") end },
    { name = "Rupture", matches = rupture_matches, execute = function(context) return cast(ACTION.Rupture, context.target, "[SUBTLETY] Rupture") end },
    { name = "DeadlyThrow", matches = deadly_throw_matches, execute = function(context) return cast(ACTION.DeadlyThrow, context.target, "[SUBTLETY] Deadly Throw") end },
    { name = "EviscerateKill", matches = eviscerate_kill_matches, execute = function(context) return cast(ACTION.Eviscerate, context.target, "[SUBTLETY] Eviscerate kill") end },
    { name = "Eviscerate", matches = eviscerate_matches, execute = function(context) return cast(ACTION.Eviscerate, context.target, "[SUBTLETY] Eviscerate") end },
    { name = "Feint", matches = feint_matches, execute = function() return cast(ACTION.Feint, NS.PLAYER_UNIT, "[SUBTLETY] Feint AoE reduction", { skip_range = true }) end },
    { name = "Backstab", matches = backstab_matches, execute = function(context) return cast(ACTION.Backstab, context.target, "[SUBTLETY] Backstab positional") end },
    { name = "Hemorrhage", matches = hemorrhage_matches, execute = function(context) return cast(ACTION.Hemorrhage, context.target, "[SUBTLETY] Hemorrhage") end },
    { name = "SinisterStrikeFallback", matches = fallback_builder_matches, execute = function(context) return cast(ACTION.SinisterStrike, context.target, "[SUBTLETY] Sinister Strike fallback") end },
}

-- Substitute declarative DSL strategies into the priority list by name.
local DSL_BY_NAME = {}
for _, def in ipairs(DSL_DEFS) do DSL_BY_NAME[def.name] = def end
for i = 1, #strategies do
    local name = strategies[i].name
    if DSL_BY_NAME[name] then
        strategies[i] = dsl.compile_strategy(DSL_BY_NAME[name])
    end
end

if NS.rotation_registry and NS.rotation_registry.register then
    NS.rotation_registry:register("subtlety", strategies, { get_state = build_state })
end
if NS.log then NS.log("Rogue subtlety rotation registered") end
-- Rogue subtlety rotation registered (Shadowstep control enhanced, spec_kit #25)
return { strategies = strategies, build_state = build_state }
