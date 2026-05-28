-- =========================================================================
-- EaxRotations File Version: 1.1.1
-- Last Modified: 2026-05-28
-- Change: Classic Vanilla Subtlety Rogue rotation
-- =========================================================================
local __eax_file = "classes/rogue/subtlety_vanilla.lua"
local __eax_version = "1.1.1"
local __eax_modified = "2026-05-28"
local __eax_change = "Classic Vanilla Subtlety Rogue rotation"
local __eax_versions = rawget(_G, "EaxRotationsFileVersions") or {}
_G.EaxRotationsFileVersions = __eax_versions
__eax_versions[__eax_file] = { version = __eax_version, modified = __eax_modified, change = __eax_change }
local __eax_core = rawget(_G, "core")
if type(__eax_core) == "table" and type(__eax_core.log) == "function" then
    pcall(__eax_core.log, "[EaxRotations] Loaded " .. __eax_file .. " v" .. __eax_version)
end
local __eax_ns = rawget(_G, "EaxRotations")
if type(__eax_ns) == "table" then __eax_ns.file_versions = __eax_versions end
-- Rogue Subtlety priority list: Classic Vanilla ClassicRemovedMobilityA burst, Hemorrhage upkeep, and PvP control chains.
-- ============================================================================
-- What: Classic Vanilla Rogue Subtlety rotation with stealth openers, ClassicRemovedMobilityA burst, and control
-- When: Per tick
-- Why: Priority list balances openers, burst, and PvP control chains
-- Safety: Nil-guarded target/state checks, bounded range logic, conservative opener rules
-- ============================================================================
-- Order is intentional: survival/interrupts, stealth setup, burst/control, finishers, builders.
local NS = _G.EaxRotations
if not NS then return nil end

local BASE_SPELLS = NS.RogueSpells or {}
local CCGateDB = NS.OffensiveDispelDB or require("shared/offensive_dispel_sylvanas")

local function spell(ids, label)
    return NS.spell_action(ids, label)
end

local SPELLS = {
    Ambush = BASE_SPELLS.Ambush or spell({ 27441, 11269, 11268, 11267, 8725, 8724, 8676 }, "Ambush"),
    Backstab = BASE_SPELLS.Backstab or spell({ 26863, 25300, 11281, 11280, 11279, 8721, 2591, 2590, 2589, 53 }, "Backstab"),
    Blind = BASE_SPELLS.Blind or spell({ 2094 }, "Blind"),
    CheapShot = BASE_SPELLS.CheapShot or spell({ 1833 }, "CheapShot"),
    ClassicRemovedDefensiveA = BASE_SPELLS.ClassicRemovedDefensiveA or spell({ 31224 }, "ClassicRemovedDefensiveA"),
    ClassicRemovedThrowA = BASE_SPELLS.ClassicRemovedThrowA or spell({ 26679 }, "ClassicRemovedThrowA"),
    Dismantle = BASE_SPELLS.Dismantle or spell({ 51722 }, "Dismantle"),
    Evasion = BASE_SPELLS.Evasion or spell({ 26669, 5277 }, "Evasion"),
    Eviscerate = BASE_SPELLS.Eviscerate or spell({ 26865, 31016, 11300, 11299, 8624, 8623, 6762, 6761, 6760, 2098 }, "Eviscerate"),
    ExposeArmor = BASE_SPELLS.ExposeArmor or spell({ 26866, 11198, 8647 }, "ExposeArmor"),
    Feint = BASE_SPELLS.Feint or spell({ 27448, 25302, 11303, 8637, 6768, 1966 }, "Feint"),
    Garrote = BASE_SPELLS.Garrote or spell({ 26884, 26839, 11290, 11289, 8633, 8632, 8631, 703 }, "Garrote"),
    GhostlyStrike = BASE_SPELLS.GhostlyStrike or spell({ 14278 }, "GhostlyStrike"),
    Gouge = BASE_SPELLS.Gouge or spell({ 1776 }, "Gouge"),
    Hemorrhage = BASE_SPELLS.Hemorrhage or spell({ 26864, 17348, 17347, 16511 }, "Hemorrhage"),
    KidneyShot = BASE_SPELLS.KidneyShot or spell({ 8643, 408 }, "KidneyShot"),
    Kick = BASE_SPELLS.Kick or spell({ 38768, 1769, 1768, 1767, 1766 }, "Kick"),
    Premeditation = BASE_SPELLS.Premeditation or spell({ 14183 }, "Premeditation"),
    Preparation = BASE_SPELLS.Preparation or spell({ 14185 }, "Preparation"),
    Rupture = BASE_SPELLS.Rupture or spell({ 26867, 11275, 11274, 11273, 8640, 8639, 1943 }, "Rupture"),
    Sap = BASE_SPELLS.Sap or spell({ 11297, 2070, 6770 }, "Sap"),
    ClassicRemovedMobilityA = BASE_SPELLS.ClassicRemovedMobilityA or spell({ 36554 }, "ClassicRemovedMobilityA"),
    ClassicRemovedUtilityA = BASE_SPELLS.ClassicRemovedUtilityA or spell({ 5938 }, "ClassicRemovedUtilityA"),
    SinisterStrike = BASE_SPELLS.SinisterStrike or spell({ 26862, 26861, 11294, 11293, 8621, 1760, 1759, 1758, 1757, 1752 }, "SinisterStrike"),
    SliceAndDice = BASE_SPELLS.SliceAndDice or spell({ 6774, 5171 }, "SliceAndDice"),
    Sprint = BASE_SPELLS.Sprint or spell({ 11305, 8696, 2983 }, "Sprint"),
    Stealth = BASE_SPELLS.Stealth or spell({ 1787, 1786, 1785, 1784 }, "Stealth"),
    Vanish = BASE_SPELLS.Vanish or spell({ 26889, 1857, 1856 }, "Vanish"),
}

local STEALTH_BUFF = { 1787, 1786, 1785, 1784 }
local SLICE_AND_DICE_BUFF = { 6774, 5171 }
local SHADOWSTEP_BUFF = { 36554, 44373 }
local MASTER_OF_SUBTLETY_BUFF = { 31665 }
local RUPTURE_DEBUFF = { 26867, 11275, 11274, 11273, 8640, 8639, 1943 }
local HEMORRHAGE_DEBUFF = { 26864, 17348, 17347, 16511 }
local GARROTE_DEBUFF = { 26884, 26839, 11290, 11289, 8633, 8632, 8631, 703 }
local EXPOSE_ARMOR_DEBUFF = { 26866, 11198, 8647 }
local CHEAP_SHOT_DEBUFF = { 1833 }
local KIDNEY_SHOT_DEBUFF = { 8643, 408 }
local CONTROL_DEBUFFS = { 1833, 8643, 408, 1776, 2094, 11297, 2070, 6770 }

-- Disarm target classes: melee classes that lose weapon-based damage when disarmed
local DISARM_CLASS_IDS = { [1] = true, [2] = true, [4] = true, [7] = true }  -- Warrior, Paladin, Rogue, Shaman

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
    is_behind = false,
    is_caster_target = false,
    control_active = false,
    threat_pct = 0,
    vanish_cd = 0,
    sprint_cd = 0,
    evasion_cd = 0,
    -- ClassicRemovedUtilityA Purge (PvP buff dispel via Wound Poison)
    shiv_ready = false,
    shiv_purge_name = nil,
    -- Disarm (PvP Dismantle)
    disarm_ready = false,
    disarm_class_ok = false,
    disarm_buff_name = nil,
}

local function player_buff_up(ids)
    return NS.has_player_buff(ids) == true
end

local function target_debuff_remains(target, ids)
    if not target then return 0 end
    return NS.debuff_remains(target, ids) or 0
end

local setting = NS.setting

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
    -- Broken-API guard: skip aura checks if API is unhealthy (prevents crash loops on private servers)
    local skip_aura = NS.broken_api_throttled and NS.broken_api_throttled(1787, 3.0) or false
    if not skip_aura then
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
    end
    subtlety_state.combo = context.combo_points or context.combo or 0
    subtlety_state.energy = context.energy or 0
    subtlety_state.energy_low = subtlety_state.energy < ENERGY_LOW_BUILDER
    subtlety_state.energy_pool_finisher = subtlety_state.energy < ENERGY_LOW_FINISHER
    subtlety_state.hp = context.hp or context.player_hp or 100
    subtlety_state.target_hp = context.target_hp or 100
    subtlety_state.target_distance = context.target_distance or context.target_range or 40
    subtlety_state.target_count = context.enemy_count or context.enemies_count or 1
    subtlety_state.is_behind = NS.is_behind_target and NS.is_behind_target(target) or false
    subtlety_state.is_caster_target = target_is_casting(target)
    subtlety_state.threat_pct = context.threat_pct or 0
    subtlety_state.vanish_cd = NS.get_spell_cd and NS.get_spell_cd(SPELLS.Vanish) or 0
    subtlety_state.sprint_cd = NS.get_spell_cd and NS.get_spell_cd(SPELLS.Sprint) or 0
    subtlety_state.evasion_cd = NS.get_spell_cd and NS.get_spell_cd(SPELLS.Evasion) or 0
    -- ClassicRemovedUtilityA Purge (PvP buff dispel via Wound Poison)
    subtlety_state.shiv_ready = context.target and NS.spell_ready(SPELLS.ClassicRemovedUtilityA, context.target, { expected_cooldown = 10 }) or false
    subtlety_state.shiv_purge_name = nil
    if context.in_combat and (context.is_pvp or false) and context.target and CCGateDB.find_best_dispel_target then
        local best_id, _, best_name = CCGateDB.find_best_dispel_target(context.target, NS)
        if best_id then subtlety_state.shiv_purge_name = best_name end
    end
    -- Disarm (PvP Dismantle — weapon removal vs melee)
    subtlety_state.disarm_ready = context.target and NS.spell_ready(SPELLS.Dismantle, context.target, { expected_cooldown = 60 }) or false
    subtlety_state.disarm_class_ok = false
    subtlety_state.disarm_buff_name = nil
    if context.target and (context.is_pvp or false) and subtlety_state.disarm_ready then
        local ok, class_id = pcall(function() return context.target:get_class() end)
        if ok and type(class_id) == "number" and DISARM_CLASS_IDS[class_id] then
            subtlety_state.disarm_class_ok = true
            if CCGateDB.find_best_dispel_target then
                local best_id, best_priority, best_name = CCGateDB.find_best_dispel_target(context.target, NS)
                if best_id and (best_priority or 0) >= 3 then
                    subtlety_state.disarm_buff_name = best_name
                end
            end
        end
    end
    return subtlety_state
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
    if usage == "burst_only" then return context.should_burst == true or context.force_burst == true end
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
    if state.hemo_remains <= 0 then return true end
    if setting(context, "hemo_debuff_priority", true) and state.hemo_remains < HEMO_REFRESH then return true end
    return false
end

local function cast(spell_obj, target, reason, opts)
    return NS.try_cast(spell_obj, target, reason, opts)
end

local function stealth_matches(context, state)
    if context.in_combat then return false end
    if state.stealth_up then return false end
    return NS.spell_ready(SPELLS.Stealth, NS.PLAYER_UNIT, { skip_range = true })
end

local function sap_matches(context, state)
    if context.in_combat then return false end
    if not state.stealth_up then return false end
    if not has_enemy(context) then return false end
    return NS.spell_ready(SPELLS.Sap, context.target)
end

local function premeditation_matches(context, state)
    if not state.stealth_up then return false end
    if state.combo >= 3 then return false end
    return NS.spell_ready(SPELLS.Premeditation, context.target, { skip_range = true })
end

local function shadowstep_opener_matches(context, state)
    if not state.stealth_up then return false end
    if not use_shadowstep_now(context) then return false end
    if not in_shadowstep_range(context, state) and not state.is_behind then return false end
    return NS.spell_ready(SPELLS.ClassicRemovedMobilityA, context.target)
end

local function ambush_opener_matches(context, state)
    if not state.stealth_up then return false end
    local opener = opener_preference(context, state)
    if opener ~= "ambush" and not state.shadowstep_buff then return false end
    if not enough_energy(state, ENERGY_AMBUSH) then return false end
    return NS.spell_ready(SPELLS.Ambush, context.target)
end

local function garrote_opener_matches(context, state)
    if not state.stealth_up then return false end
    local opener = opener_preference(context, state)
    if opener ~= "garrote" then return false end
    if not enough_energy(state, ENERGY_GARROTE) then return false end
    return NS.spell_ready(SPELLS.Garrote, context.target)
end

local function cheap_shot_opener_matches(context, state)
    if not state.stealth_up then return false end
    local opener = opener_preference(context, state)
    if opener ~= "cheap_shot" then return false end
    if not enough_energy(state, ENERGY_CHEAP_SHOT) then return false end
    return NS.spell_ready(SPELLS.CheapShot, context.target)
end

local function kick_matches(context, state)
    if not target_is_casting(context.target) then return false end
    if not enough_energy(state, ENERGY_KICK) then return false end
    return NS.spell_ready(SPELLS.Kick, context.target)
end

local function shiv_purge_matches(context, state)
    local settings = context.settings or {}
    if settings.use_shiv_purge == false then return false end
    if not (NS.is_spell_learned and NS.is_spell_learned(5938)) then return false end
    if not context.in_combat then return false end
    if not (context.is_pvp or false) then return false end
    if not context.target then return false end
    if not (context.in_melee_range or false) then return false end
    if not state.shiv_ready then return false end
    if not state.shiv_purge_name then return false end
    if settings.shiv_purge_pvp_only ~= false then
        local ok, is_player = pcall(function() return context.target:is_player() end)
        if not (ok and is_player) then return false end
    end
    return true
end

local function disarm_matches(context, state)
    local settings = context.settings or {}
    if settings.use_disarm == false then return false end
    if not (NS.is_spell_learned and NS.is_spell_learned(51722)) then return false end
    if not context.in_combat then return false end
    if not (context.is_pvp or false) then return false end
    if not context.target then return false end
    if not (context.in_melee_range or false) then return false end
    if not state.disarm_ready then return false end
    if not state.disarm_class_ok then return false end
    if settings.disarm_pvp_only ~= false then
        local ok, is_player = pcall(function() return context.target:is_player() end)
        if not (ok and is_player) then return false end
    end
    local trigger = settings.disarm_trigger or "on_burst"
    if trigger == "on_burst" then
        if not state.disarm_buff_name then return false end
        context._disarm_buff_name = state.disarm_buff_name
    end
    return true
end

local function cloak_matches(context, state)
    if setting(context, "rogue_use_cloak", true) == false then return false end
    if (state.hp or 100) > setting(context, "rogue_cloak_hp", 45) and not state.is_caster_target then return false end
    return NS.spell_ready(SPELLS.ClassicRemovedDefensiveA, NS.PLAYER_UNIT, { skip_range = true })
end

local function evasion_matches(context, state)
    if setting(context, "rogue_use_evasion", true) == false then return false end
    if (state.hp or 100) > setting(context, "rogue_evasion_hp", 35) then return false end
    return NS.spell_ready(SPELLS.Evasion, NS.PLAYER_UNIT, { skip_range = true })
end

local function ghostly_strike_matches(context, state)
    if not is_pvp_target(context) and state.hp > 55 then return false end
    if not in_melee(state) or not enough_energy(state, ENERGY_GHOSTLY) then return false end
    return NS.spell_ready(SPELLS.GhostlyStrike, context.target)
end

local function blind_matches(context, state)
    if not is_pvp_target(context) then return false end
    if state.control_active then return false end
    if state.hp > 35 and state.target_hp > 25 then return false end
    return NS.spell_ready(SPELLS.Blind, context.target)
end

local function gouge_matches(context, state)
    if not is_pvp_target(context) then return false end
    if state.control_active then return false end
    if not in_melee(state) or state.energy < 45 then return false end
    return NS.spell_ready(SPELLS.Gouge, context.target)
end

local function shadowstep_gap_matches(context, state)
    if not use_shadowstep_now(context) then return false end
    if not in_shadowstep_range(context, state) then return false end
    return NS.spell_ready(SPELLS.ClassicRemovedMobilityA, context.target)
end

local function sprint_gap_matches(context, state)
    if state.target_distance <= 12 or state.target_distance > 35 then return false end
    return NS.spell_ready(SPELLS.Sprint, NS.PLAYER_UNIT, { skip_range = true })
end

local function vanish_burst_matches(context, state)
    if state.stealth_up then return false end
    if state.hp <= setting(context, "rogue_vanish_hp", 20) and setting(context, "rogue_use_vanish_defensive", false) then
        return NS.spell_ready(SPELLS.Vanish, NS.PLAYER_UNIT, { skip_range = true })
    end
    if not (context.should_burst or context.force_burst) then return false end
    return NS.spell_ready(SPELLS.Vanish, NS.PLAYER_UNIT, { skip_range = true })
end

local function preparation_matches(context, state)
    local in_burst = context.should_burst or context.force_burst or false
    if setting(context, "use_cooldowns", true) == false and not in_burst then return false end
    if state.hp > setting(context, "subtlety_prep_hp", 40) then return false end
    -- Only use when at least one major cooldown is actually on cooldown
    if NS.get_spell_cd then
        local has_cd_burned = state.vanish_cd > 0 or state.sprint_cd > 0 or state.evasion_cd > 0
        if not has_cd_burned then return false end
    end
    if not context.in_combat then return false end
    return NS.spell_ready(SPELLS.Preparation, NS.PLAYER_UNIT, { skip_range = true })
end

local function kidney_shot_matches(context, state)
    if state.combo < 3 or not enough_energy(state, ENERGY_KIDNEY) then return false end
    if state.kidney_remains > 0 then return false end
    if not is_pvp_target(context) and state.target_hp > 35 then return false end
    return NS.spell_ready(SPELLS.KidneyShot, context.target)
end

local function shadowstep_hemo_matches(context, state)
    if not state.shadowstep_buff then return false end
    if not enough_energy(state, ENERGY_HEMORRHAGE) then return false end
    return NS.spell_ready(SPELLS.Hemorrhage, context.target)
end

local function hemo_debuff_matches(context, state)
    if not hemo_refresh_needed(context, state) then return false end
    if not enough_energy(state, ENERGY_HEMORRHAGE) then return false end
    return NS.spell_ready(SPELLS.Hemorrhage, context.target)
end

local function slice_matches(context, state)
    if state.combo < 2 then return false end
    if state.slice_remains > SND_REFRESH then return false end
    if state.energy_pool_finisher then return false end
    return NS.spell_ready(SPELLS.SliceAndDice, NS.PLAYER_UNIT, { skip_range = true })
end

local function rupture_matches(context, state)
    if state.combo < 4 then return false end
    if state.energy_pool_finisher then return false end
    if state.target_hp < 25 or (context.ttd or 999) < RUPTURE_TTD_FLOOR then return false end
    if state.rupture_remains > RUPTURE_REFRESH then return false end
    return NS.spell_ready(SPELLS.Rupture, context.target)
end

local function expose_armor_matches(context, state)
    if state.combo < 4 then return false end
    if state.expose_remains > 3 then return false end
    if not context.target_is_boss and (context.ttd or 999) < 20 then return false end
    return NS.spell_ready(SPELLS.ExposeArmor, context.target)
end

local function deadly_throw_matches(context, state)
    if state.combo < 3 or not enough_energy(state, ENERGY_DEADLY_THROW) then return false end
    if state.target_distance <= MELEE_RANGE or state.target_distance > 30 then return false end
    return NS.spell_ready(SPELLS.ClassicRemovedThrowA, context.target)
end

local function eviscerate_kill_matches(context, state)
    if state.combo < 4 then return false end
    if state.energy_pool_finisher then return false end
    if state.energy < ENERGY_FINISHER then return false end  -- hard floor
    if state.target_hp > 30 and not state.shadowstep_buff then return false end
    return NS.spell_ready(SPELLS.Eviscerate, context.target)
end

local function eviscerate_matches(context, state)
    if state.combo < 4 then return false end
    if state.energy_pool_finisher then return false end
    if state.energy < ENERGY_FINISHER then return false end  -- hard floor
    return NS.spell_ready(SPELLS.Eviscerate, context.target)
end

local function feint_matches(context, state)
    if not context.in_combat then return false end
    local feint_threat = setting(context, "subtlety_feint_threat", FEINT_THREAT_DEFAULT)
    if state.threat_pct <= 0 or state.threat_pct < feint_threat then return false end
    if not enough_energy(state, ENERGY_FEINT) then return false end
    return NS.spell_ready(SPELLS.Feint, NS.PLAYER_UNIT, { skip_range = true })
end

local function hemorrhage_matches(context, state)
    if state.energy_low then return false end  -- pool energy below 40
    if not enough_energy(state, ENERGY_HEMORRHAGE) then return false end
    return NS.spell_ready(SPELLS.Hemorrhage, context.target)
end

local function backstab_matches(context, state)
    if not state.is_behind then return false end
    if state.energy_low then return false end
    if not enough_energy(state, ENERGY_BACKSTAB) then return false end
    if state.stealth_up then return false end  -- use Ambush instead
    -- Backstab is positional burst; Hemorrhage is primary builder per Research
    local in_burst = context.should_burst or context.force_burst or false
    if state.energy < 75 and not in_burst then return false end
    return NS.spell_ready(SPELLS.Backstab, context.target)
end

local function fallback_builder_matches(context, state)
    if not enough_energy(state, 45) then return false end
    return NS.spell_ready(SPELLS.SinisterStrike, context.target)
end

local strategies = {
    { name = "Kick", matches = kick_matches, execute = function(context) return cast(SPELLS.Kick, context.target, "[SUBTLETY] Kick") end },
    { name = "ClassicRemovedUtilityAPurge", matches = function(context, state) if shiv_purge_matches(context, state) then context._shiv_purge_name = state.shiv_purge_name return true end return false end, execute = function(context) local name = context._shiv_purge_name or "buff" return cast(SPELLS.ClassicRemovedUtilityA, context.target, "[SUBTLETY] ClassicRemovedUtilityA purge → " .. name, { expected_cooldown = 10 }) end },
    { name = "Disarm", matches = disarm_matches, execute = function(context) local label = context._disarm_buff_name and ("[SUBTLETY] Dismantle → " .. context._disarm_buff_name) or "[SUBTLETY] Dismantle" return cast(SPELLS.Dismantle, context.target, label, { expected_cooldown = 60 }) end },
    { name = "ClassicRemovedDefensiveA", matches = cloak_matches, execute = function() return cast(SPELLS.ClassicRemovedDefensiveA, NS.PLAYER_UNIT, "[SUBTLETY] Cloak of Shadows", { skip_range = true }) end },
    { name = "Evasion", matches = evasion_matches, execute = function() return cast(SPELLS.Evasion, NS.PLAYER_UNIT, "[SUBTLETY] Evasion", { skip_range = true }) end },
    { name = "GhostlyStrike", matches = ghostly_strike_matches, execute = function(context) return cast(SPELLS.GhostlyStrike, context.target, "[SUBTLETY] Ghostly Strike") end },
    { name = "Blind", matches = blind_matches, execute = function(context) return cast(SPELLS.Blind, context.target, "[SUBTLETY] Blind") end },
    { name = "Gouge", matches = gouge_matches, execute = function(context) return cast(SPELLS.Gouge, context.target, "[SUBTLETY] Gouge") end },
    { name = "Stealth", matches = stealth_matches, execute = function() return cast(SPELLS.Stealth, NS.PLAYER_UNIT, "[SUBTLETY] Stealth", { skip_range = true }) end },
    { name = "Sap", matches = sap_matches, execute = function(context) return cast(SPELLS.Sap, context.target, "[SUBTLETY] Sap") end },
    { name = "Premeditation", matches = premeditation_matches, execute = function(context) return cast(SPELLS.Premeditation, context.target, "[SUBTLETY] Premeditation", { skip_range = true }) end },
    { name = "ClassicRemovedMobilityAOpener", matches = shadowstep_opener_matches, is_burst = true, execute = function(context) return cast(SPELLS.ClassicRemovedMobilityA, context.target, "[SUBTLETY] ClassicRemovedMobilityA opener") end },
    { name = "Ambush", spell = SPELLS.Ambush, requires_buff = { 1787, 1786, 1785, 1784 }, requires_behind = true, min_energy = ENERGY_AMBUSH, matches = ambush_opener_matches, execute = function(context) return cast(SPELLS.Ambush, context.target, "[SUBTLETY] Ambush") end },
    { name = "Garrote", matches = garrote_opener_matches, execute = function(context) return cast(SPELLS.Garrote, context.target, "[SUBTLETY] Garrote caster opener") end },
    { name = "CheapShot", matches = cheap_shot_opener_matches, execute = function(context) return cast(SPELLS.CheapShot, context.target, "[SUBTLETY] Cheap Shot opener") end },
    { name = "Vanish", matches = vanish_burst_matches, is_burst = true, execute = function() return cast(SPELLS.Vanish, NS.PLAYER_UNIT, "[SUBTLETY] Vanish reopen", { skip_range = true }) end },
    { name = "Preparation", matches = preparation_matches, is_burst = true, execute = function() return cast(SPELLS.Preparation, NS.PLAYER_UNIT, "[SUBTLETY] Preparation reset", { skip_range = true }) end },
    { name = "Sprint", matches = sprint_gap_matches, execute = function() return cast(SPELLS.Sprint, NS.PLAYER_UNIT, "[SUBTLETY] Sprint gap close", { skip_range = true }) end },
    { name = "ClassicRemovedMobilityA", matches = shadowstep_gap_matches, is_burst = true, execute = function(context) return cast(SPELLS.ClassicRemovedMobilityA, context.target, "[SUBTLETY] ClassicRemovedMobilityA") end },
    { name = "KidneyShot", matches = kidney_shot_matches, execute = function(context) return cast(SPELLS.KidneyShot, context.target, "[SUBTLETY] Kidney Shot stun chain") end },
    { name = "ClassicRemovedMobilityAHemorrhage", matches = shadowstep_hemo_matches, execute = function(context) return cast(SPELLS.Hemorrhage, context.target, "[SUBTLETY] ClassicRemovedMobilityA Hemorrhage") end },
    { name = "HemorrhageDebuff", matches = hemo_debuff_matches, execute = function(context) return cast(SPELLS.Hemorrhage, context.target, "[SUBTLETY] Hemorrhage debuff") end },
    { name = "SliceAndDice", matches = slice_matches, execute = function() return cast(SPELLS.SliceAndDice, NS.PLAYER_UNIT, "[SUBTLETY] Slice and Dice", { skip_range = true }) end },
    { name = "ExposeArmor", matches = expose_armor_matches, execute = function(context) return cast(SPELLS.ExposeArmor, context.target, "[SUBTLETY] Expose Armor") end },
    { name = "Rupture", matches = rupture_matches, execute = function(context) return cast(SPELLS.Rupture, context.target, "[SUBTLETY] Rupture") end },
    { name = "ClassicRemovedThrowA", matches = deadly_throw_matches, execute = function(context) return cast(SPELLS.ClassicRemovedThrowA, context.target, "[SUBTLETY] Deadly Throw") end },
    { name = "EviscerateKill", matches = eviscerate_kill_matches, execute = function(context) return cast(SPELLS.Eviscerate, context.target, "[SUBTLETY] Eviscerate kill") end },
    { name = "Eviscerate", matches = eviscerate_matches, execute = function(context) return cast(SPELLS.Eviscerate, context.target, "[SUBTLETY] Eviscerate") end },
    { name = "Feint", matches = feint_matches, execute = function() return cast(SPELLS.Feint, NS.PLAYER_UNIT, "[SUBTLETY] Feint AoE reduction", { skip_range = true }) end },
    { name = "Backstab", matches = backstab_matches, execute = function(context) return cast(SPELLS.Backstab, context.target, "[SUBTLETY] Backstab positional") end },
    { name = "Hemorrhage", matches = hemorrhage_matches, execute = function(context) return cast(SPELLS.Hemorrhage, context.target, "[SUBTLETY] Hemorrhage") end },
    { name = "SinisterStrikeFallback", matches = fallback_builder_matches, execute = function(context) return cast(SPELLS.SinisterStrike, context.target, "[SUBTLETY] Sinister Strike fallback") end },
}

NS.rotation_registry:register("subtlety", strategies, { get_state = build_state })
NS.log("Rogue subtlety rotation registered (ClassicRemovedMobilityA control enhanced)")
return strategies
