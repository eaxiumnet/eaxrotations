-- holy_sylvanas.lua — Priest Holy healing for TBC Anniversary (2.5.5).
-- WHAT: raid healer (Greater Heal, Flash Heal, CoH, Prayer of Mending, Renew, Lightwell).
-- WHEN: combat or pre-combat, with valid friendly targets.
-- WHY:   mirrors TBC holy priest consensus from wowsims (no APL but community), Icy Veins, Wowhead: PoM on CD + CoH (3+ hurt) + GH/Flash spot + Lightwell + Renew rolling.
-- SAFETY: Pattern 14 eliminated via spec_kit.safe_state(); no on_update() allocs.
local _G = _G
local NS = _G.EaxRotations
if not NS then return nil end

local load_player = NS.GetPlayer and NS.GetPlayer()

local _ok_enums, enums = pcall(require, "common/enums")
if not _ok_enums or type(enums) ~= "table" or type(enums.class_id) ~= "table" then enums = { class_id = NS.CLASS_ID } end
if not load_player then return end
local ok_cls, cls_id = pcall(function() return load_player:get_class() end)
if not ok_cls or cls_id ~= enums.class_id.PRIEST then return end

local SPELLS = NS.PriestSpells or {}
local spec_kit = require("shared/spec_kit_sylvanas")
local dsl = require("shared/strategy_dsl_sylvanas")

local function load_healing_helpers()
 if NS.PriestHealing then return NS.PriestHealing end
 local ok, module = pcall(require, "classes/priest/healing_sylvanas")
 if ok then
  return module or NS.PriestHealing or {}
 end
 if NS.log_warning then
  NS.log_warning("Failed to load Priest healing helpers: " .. tostring(module))
 end
 return NS.PriestHealing or {}
end

local Healing = load_healing_helpers()

local _ns_gate_overheal = NS.gate_overheal
local function gate_overheal(spell_key, unit, cast_time, settings, spell_id)
    if NS.HealerDeficit and NS.HealerDeficit.gate_spell_overheal then
        return NS.HealerDeficit.gate_spell_overheal(spell_key, unit, cast_time, settings, spell_id)
    end
    return _ns_gate_overheal and _ns_gate_overheal(spell_key, unit, cast_time, settings, spell_id) or false
end

-- Preemptive heal module (Sonah-style predictive healing)
local PreemptiveHeal = require("shared/preemptive_heal_sylvanas")
local FsrManager = require("shared/fsr_manager_sylvanas")
local Profiler = require("shared/profiler_helper_sylvanas")
local _ts_ok, TSHelper = pcall(require, "shared/ts_helper_sylvanas")
if not _ts_ok or type(TSHelper) ~= "table" then TSHelper = nil end
local _hp_ok, HealthPred = pcall(require, "shared/health_pred_helper_sylvanas")
if not _hp_ok or type(HealthPred) ~= "table" then HealthPred = nil end

-- Centralized spell resolver via spec_kit (rank IDs from class_sylvanas.lua).
local define = spec_kit.define_action_for_class(SPELLS)
local ACTION = {
    AbolishDisease   = define("AbolishDisease",   { 552 }, "AbolishDisease"),
    BindingHeal      = define("BindingHeal",      { 32546 }, "BindingHeal"),
    CircleofHealing  = define("CircleofHealing",  { 34866, 34865, 34864, 34863, 34861 }, "CircleofHealing"),
    CureDisease      = define("CureDisease",      { 528 }, "CureDisease"),
    DesperatePrayer  = define("DesperatePrayer",  { 25437, 19243, 19242, 19241, 19240, 19238, 19236, 13908 }, "DesperatePrayer"),
    DispelMagic      = define("DispelMagic",      { 988, 527 }, "DispelMagic"),
    FearWard         = define("FearWard",         { 6346 }, "FearWard"),
    Fade             = define("Fade",             { 25429, 10942, 10941, 9592, 9579, 9578, 586 }, "Fade"),
    FlashHeal        = define("FlashHeal",        { 25235, 25233, 10917, 10916, 10915, 9474, 9473, 9472, 2061 }, "FlashHeal"),
    GreaterHeal      = define("GreaterHeal",      { 25213, 25210, 25314, 10965, 10964, 10963, 2060 }, "GreaterHeal"),
    HolyFire         = define("HolyFire",         { 25384, 15261, 15267, 15266, 15265, 15264, 15263, 15262, 14914 }, "HolyFire"),
    InnerFocus       = define("InnerFocus",       { 14751 }, "InnerFocus"),
    Lightwell        = define("Lightwell",        { 28275, 27871, 27870, 724 }, "Lightwell"),
    MassDispel       = define("MassDispel",       { 32375 }, "MassDispel"),  -- TBC: AoE magic dispel for dungeon pack efficiency (per WoWHead)
    PowerWordShield  = define("PowerWordShield",  { 25218, 25217, 10901, 10900, 10899, 10898, 6066, 6065, 3747, 600, 592, 17 }, "PowerWordShield"),
    PrayerofMending  = define("PrayerofMending",  { 33076 }, "PrayerofMending"),
    PrayerOfHealing  = define("PrayerOfHealing",  { 25308, 25316, 10961, 10960, 996, 596 }, "PrayerOfHealing"),
    Renew            = define("Renew",            { 25222, 25221, 25315, 10929, 10928, 10927, 6078, 6077, 6076, 6075, 6074, 139 }, "Renew"),
    ShadowWordPain   = define("ShadowWordPain",   { 25368, 25367, 10894, 10893, 10892, 2767, 992, 970, 594, 589 }, "ShadowWordPain"),
    Shadowfiend      = define("Shadowfiend",      { 34433 }, "Shadowfiend"),
    Smite            = define("Smite",            { 25364, 25363, 10934, 10933, 6060, 1004, 984, 598, 591, 585 }, "Smite"),
    SymbolOfHope     = define("SymbolOfHope",     { 32548 }, "SymbolOfHope"),
}

local format = string.format
-- ipairs unused in holy (no ipairs iteration needed)
local tostring = tostring
local EMPTY_SETTINGS = {}

-- ============================================================================
-- IMPORT SHARED RANK TABLES + UTILITIES (from class_sylvanas.lua)
-- class_sylvanas.lua loads at order=61, holy at order=66 — safe to import.
-- ============================================================================
local FLASH_HEAL_RANKS = NS.PriestFLASH_HEAL_RANKS
local GREATER_HEAL_RANKS = NS.PriestGREATER_HEAL_RANKS
local PRAYER_OF_HEALING_RANKS = NS.PriestPRAYER_OF_HEALING_RANKS
local BINDING_HEAL_RANKS = NS.PriestBINDING_HEAL_RANKS
local cast_best_heal_rank = NS.cast_best_heal_rank or function() return false end

local INNER_FOCUS_BUFF = { 14751 }  -- matches ACTION.InnerFocus rank ID
local SURGE_OF_LIGHT_BUFF = { 33151, 33154 }
local HOLY_CONCENTRATION_BUFF = { 34753, 34754, 34859, 34860 }
local PRAYER_OF_MENDING_BUFF = { 33076 } -- PoM buff on target (TBC rank 1)
local SHADOW_WORD_PAIN_DEBUFF = { 25368, 25367, 10894, 10893, 10892, 2767, 992, 970, 594, 589 }
local HOLY_FIRE_DOT_DEBUFF = { 14914, 15262, 15263, 15264, 15265, 15266, 15267, 15261, 25384 }

-- parity feature constants
-- ============================================================================
-- Fade buff IDs (all ranks)
local FADE_BUFF = { 25429, 10942, 10941, 9592, 9579, 9578, 586 }

-- Healthstone item IDs (TBC, best to worst)
local HEALTHSTONE_IDS = {
 19004, 19005, 19006, 19007, 19008, 19009, 19010, 19011, 19012, 19013,
}

-- Karazhan encounter map ID
local KARAZHAN_MAP_ID = 532

-- Pushback detection for Greater Heal (parity v0.5.0 style)
-- Tracks recent damage taken to gate long-cast heals during pushback
--- Checks if the player is taking damage or in pushback using available API.
--- Uses fallback detection when standard enemy scanner isn't exposed.
---@param context table The combat context.
---@return boolean has_pushback True if pushback is likely active.
local function _check_pushback(context)
 if not (context and context.me) then return false end
 local enemies = NS.GetEnemiesInRange and NS.GetEnemiesInRange(8) or {}
 for _, enemy in ipairs(enemies) do
  if enemy then
   local ok, is_casting = pcall(function() return enemy:is_casting() end)
   if ok and is_casting then return true end
   local ok2, can_atk = pcall(function()
    if context.me.can_attack then return enemy:can_attack(context.me) end
    return false
   end)
   if ok2 and can_atk then return true end
  end
 end
 return false
end

-- [PRE-ALLOC] Heal rank option tables — created once at load time, not per-frame in execute().
-- Avoids Lua 5.1 GC pressure from repeated inline table creation in combat path.
local HOLY_OPTS_EMERGENCY_FH = { prioritize_speed = true, cast_time = 1.5, overheal_threshold = 1.4 }
local HOLY_OPTS_BH = { bh_coefficient = true, cast_time = 2.0, overheal_threshold = 1.3 }
local HOLY_OPTS_CLEARCAST_GH = { prioritize_efficiency = true, gh_coefficient = true, cast_time = 2.5, overheal_threshold = 1.3 }
local HOLY_OPTS_GH = { gh_coefficient = true, cast_time = 2.5, overheal_threshold = 1.3 }
local HOLY_OPTS_FH = { cast_time = 1.5, overheal_threshold = 1.3 }
local HOLY_OPTS_POH = { poh_coefficient = true, cast_time = 3.0, overheal_threshold = 1.3 }

-- Greater Heal tiered ranks for mana-based downranking
local GREATER_HEAL_MAX = 25213      -- Rank 7 (max)
local GREATER_HEAL_CONSERVE = 25210 -- Rank 6 (conserve)
local GREATER_HEAL_EFFICIENT = 25314 -- Rank 5 (efficient)

-- Flash Heal tiered ranks for mana-based downranking
local FLASH_HEAL_MAX = 25235        -- Rank 9 (max)
local FLASH_HEAL_CONSERVE = 25233   -- Rank 8 (conserve)
local FLASH_HEAL_EFFICIENT = 10917  -- Rank 7 (efficient)

-- ============================================================================
-- Schema for safe_state (Pattern 14 nil-guard elimination).
local HOLY_SCHEMA = {
    lowest_hp = 100,
    tank_hp = 100,
    group_damaged_count = 0,
    subgroup_damaged_count = 0,
    surge_of_light = false,
    clearcasting = false,
    pom_ready = false,
    coh_ready = false,
    has_inner_focus = false,
    swp_remaining = 0,
    holy_fire_remaining = 0,
    healthstone_ready = false,
    has_fade_buff = false,
    fade_ready = false,
    encounter_id = 0,
    flash_heal_ready = false,
    prayer_of_healing_ready = false,
    greater_heal_ready = false,
    lightwell_ready = false,
    shadowfiend_ready = false,
    dispel_magic_ready = false,
    mass_dispel_ready = false,
    cure_disease_ready = false,
    abolish_disease_ready = false,
    symbol_of_hope_ready = false,
    friendly_target_ready = false,
    mana_pct = 100,
    -- FSR state (Five-Second Rule)
    fsr_inside = false, fsr_seconds = 0, fsr_regen_delta = 0,
}

local holy_state = {
 lowest = nil,
 lowest_hp = 100,
 fear_ward_ready = false,
 has_fear_ward = false,
 fear_ward_target = nil,
 tank = nil,
 tank_hp = 100,
 group_damaged_count = 0,
 surge_of_light = false,
 clearcasting = false,
 pom_ready = false,
 coh_ready = false,
 has_inner_focus = false,
 swp_remaining = 0,
 holy_fire_remaining = 0,
 -- parity feature state
 healthstone_ready = false,
 healthstone_id = nil,
 has_fade_buff = false,
 fade_ready = false,
 encounter_id = 0,
 flash_heal_ready = false,
 prayer_of_healing_ready = false,
 greater_heal_ready = false,
 lightwell_ready = false,
 shadowfiend_ready = false,
 dispel_magic_ready = false,
 cure_disease_ready = false,
 abolish_disease_ready = false,
 friendly_target = nil,
 friendly_target_ready = false,
}
-- Shared helpers from core_sylvanas.lua
local try_cast, spell_exists, spell_ready, debuff_remains, health_pct, player_control_locked, has_player_buff = NS.import_helpers(
 "try_cast", "spell_exists", "spell_ready", "debuff_remains", "health_pct",
 "player_control_locked", "has_player_buff"
)
local function build_state(context)
 context.settings = context.settings or EMPTY_SETTINGS
 local aoe_hp = spec_kit.setting_number(context, "holy_aoe_hp", 80)
 local lowest_entry = nil
 local tank_entry = nil
 local lowest_hp = 100
 local tank_hp = 100
 local damaged_count = 0

 local player = NS.GetPlayer()
 if not player then return spec_kit.safe_state(holy_state, HOLY_SCHEMA) end
 -- Mounted bail: healer should not queue buffs/heals while mounted
 if player.is_mounted and player:is_mounted() then
  return spec_kit.safe_state(holy_state, HOLY_SCHEMA)
 end
 -- Guard: player_control_locked may be nil in some environments
local pcl_ok, pcl_result = pcall(function()
    return type(player_control_locked) == "function" and player_control_locked() or false
end)
context.player_control_locked = (pcl_ok and pcl_result) or false
 context.is_moving = context.is_moving or (player.is_moving and player:is_moving()) or false
 context.hp = health_pct(NS.PLAYER_UNIT)
 context.mana_pct = context.player_mana_pct or (player.mana_pct and player:mana_pct()) or 100

 if Healing.scan_healing_targets then
  local profile_key = "holy_scan_healing_targets"
  if spec_kit.setting_bool(context, "debug_profile", false) then Profiler.start(profile_key) end
  local entries, count = Healing.scan_healing_targets()
  entries = entries or {}
  count = count or 0

  if TSHelper and TSHelper.get_heal_targets then
   local ts_targets = TSHelper.get_heal_targets(3)
   if type(ts_targets) == "table" then
    local seen = {}
    for i = 1, count do
     local e = entries[i]
     if e and e.unit then
      seen[e.unit] = i
     end
    end
    for _, unit in ipairs(ts_targets) do
     if unit then
      local ok_hp, hp = pcall(function()
       return unit.get_health_percentage and unit:get_health_percentage()
      end)
      if ok_hp and type(hp) == "number" then
       local idx = seen[unit]
       if idx then
        local e = entries[idx]
        e.hp = hp
        if e.effective_hp == nil then
         e.effective_hp = hp
        end
       else
        count = count + 1
        entries[count] = {
         unit = unit,
         hp = hp,
         effective_hp = hp,
         is_tank = false,
        }
        seen[unit] = count
       end
      end
     end
    end
   end
  end

  if count > 0 then
   -- Triage-ranked target selection: smarter than naive lowest-HP
   if NS.Triage and NS.Triage.rank then
    local ranked = NS.Triage.rank(entries, count, context.settings)
    lowest_entry = ranked[1] or entries[1]
   else
    lowest_entry = entries[1]
   end
   lowest_hp = (lowest_entry and lowest_entry.effective_hp) or 100

   for i = 1, count do
    local entry = entries[i]
    if entry and entry.effective_hp and entry.effective_hp < aoe_hp then
     damaged_count = damaged_count + 1
    end
    if entry and entry.is_tank and (not tank_entry or (entry.effective_hp or 100) < tank_hp) then
     tank_entry = entry
     tank_hp = entry.effective_hp or 100
    end
   end
  end
  if spec_kit.setting_bool(context, "debug_profile", false) then Profiler.stop(profile_key) end
 end

 holy_state.lowest = lowest_entry
 holy_state.lowest_hp = lowest_hp
 holy_state.tank = tank_entry
 holy_state.tank_hp = tank_hp
 holy_state.group_damaged_count = damaged_count
 -- Subgroup count for Prayer of Healing: in raids, only count your own party
 if Healing.count_subgroup_below_hp then
  holy_state.subgroup_damaged_count = Healing.count_subgroup_below_hp(aoe_hp)
 else
  holy_state.subgroup_damaged_count = damaged_count
 end
 holy_state.surge_of_light = has_player_buff(SURGE_OF_LIGHT_BUFF)
 holy_state.clearcasting = has_player_buff(HOLY_CONCENTRATION_BUFF)
 -- parity: Healthstone scanning
 holy_state.healthstone_id = nil
 holy_state.healthstone_ready = false
 if NS.is_item_ready then
  for _, id in ipairs(HEALTHSTONE_IDS) do
   local ok, ready = pcall(NS.is_item_ready, id)
   if ok and ready then
    holy_state.healthstone_id = id
    holy_state.healthstone_ready = true
    break
   end
  end
 end

 -- parity: Fade state
 holy_state.has_fade_buff = has_player_buff(FADE_BUFF)
 holy_state.fade_ready = spell_exists(ACTION.Fade) and spell_ready(ACTION.Fade)

 -- parity: Encounter ID for Karazhan reactions
 holy_state.encounter_id = (NS.core and NS.core.get_map_id and NS.core.get_map_id())
  or 0

 holy_state.pom_ready = spell_exists(ACTION.PrayerofMending) and spell_ready(ACTION.PrayerofMending, (tank_entry and tank_entry.unit) or NS.PLAYER_UNIT)
 holy_state.coh_ready = spell_exists(ACTION.CircleofHealing) and spell_ready(ACTION.CircleofHealing, (lowest_entry and lowest_entry.unit) or NS.PLAYER_UNIT)
 holy_state.has_inner_focus = has_player_buff(INNER_FOCUS_BUFF)
 holy_state.flash_heal_ready = spell_exists(ACTION.FlashHeal) and spell_ready(ACTION.FlashHeal, NS.PLAYER_UNIT)
 holy_state.prayer_of_healing_ready = spell_exists(ACTION.PrayerOfHealing) and spell_ready(ACTION.PrayerOfHealing, NS.PLAYER_UNIT, { skip_range = true })
 holy_state.greater_heal_ready = spell_exists(ACTION.GreaterHeal) and spell_ready(ACTION.GreaterHeal, NS.PLAYER_UNIT)
 -- Broken-API guard: skip aura checks if API is unhealthy (prevents crash loops on private servers)
 local skip_aura = NS.broken_api_throttled and NS.broken_api_throttled(14752, 3.0) or false
 if not skip_aura then
  holy_state.swp_remaining = context.target and debuff_remains(context.target, SHADOW_WORD_PAIN_DEBUFF) or 0
  holy_state.holy_fire_remaining = context.target and debuff_remains(context.target, HOLY_FIRE_DOT_DEBUFF) or 0
 end
 -- Fear Ward target logic for dungeons (WoWHead): ward tank on fear risk
 local ward_target = player
 local fear_risk = context and (context.fear_nearby or context.known_fear_boss or context.fear_on_tank or context.control_risk)
 if context and context.is_group and fear_risk then
  if context.party_tanks and #context.party_tanks > 0 then
   ward_target = context.party_tanks[1]
  end
 end
 holy_state.fear_ward_target = ward_target
 holy_state.has_fear_ward = ward_target and NS.buff_up(ward_target, {6346}) or false
 holy_state.lightwell_ready = spell_exists(ACTION.Lightwell) and spell_ready(ACTION.Lightwell, NS.PLAYER_UNIT)
 holy_state.shadowfiend_ready = spell_exists(ACTION.Shadowfiend) and spell_ready(ACTION.Shadowfiend, NS.PLAYER_UNIT)
 holy_state.dispel_magic_ready = spell_exists(ACTION.DispelMagic) and spell_ready(ACTION.DispelMagic, (lowest_entry and lowest_entry.unit) or NS.PLAYER_UNIT)
 holy_state.mass_dispel_ready = spell_exists(ACTION.MassDispel) and spell_ready(ACTION.MassDispel, NS.PLAYER_UNIT, { skip_range = true })
 holy_state.cure_disease_ready = spell_exists(ACTION.CureDisease) and spell_ready(ACTION.CureDisease, (lowest_entry and lowest_entry.unit) or NS.PLAYER_UNIT)
 holy_state.abolish_disease_ready = spell_exists(ACTION.AbolishDisease) and spell_ready(ACTION.AbolishDisease, (lowest_entry and lowest_entry.unit) or NS.PLAYER_UNIT)
 holy_state.symbol_of_hope_ready = spell_exists(ACTION.SymbolOfHope) and spell_ready(ACTION.SymbolOfHope, NS.PLAYER_UNIT)
 holy_state.fear_ward_ready = spell_exists(ACTION.FearWard) and spell_ready(ACTION.FearWard, NS.PLAYER_UNIT, { skip_range = true })
 local ft = NS.get_friendly_target_entry and NS.get_friendly_target_entry(context)
 holy_state.friendly_target = ft
 holy_state.friendly_target_ready = ft ~= nil

  -- parity: Smart Stop-Cast — cancel overhealing casts mid-flight
  if NS.StopCast and type(NS.StopCast.update) == "function" then
   NS.StopCast.update(player, context.settings)
  end

  -- FSR (Five-Second Rule) tracking for mana efficiency
  if FsrManager then
   holy_state.fsr_inside = FsrManager.is_inside_fsr()
   holy_state.fsr_seconds = FsrManager.seconds_until_fsr()
   holy_state.fsr_regen_delta = FsrManager.get_regen_delta()
  else
   holy_state.fsr_inside = false
   holy_state.fsr_seconds = 0
   holy_state.fsr_regen_delta = 0
  end

  return spec_kit.safe_state(holy_state, HOLY_SCHEMA)
end

local function _engaged_with_player(context)
 if not context.in_combat then return true end
 local target = context.target
 local me = context.me
 if not target or not me then return true end
 if (context.target_hp or 100) < 100 then return true end
 local ok, enemy_target = pcall(function() return target:get_target() end)
 if not ok or not enemy_target then return false end
 if NS.same_unit and NS.same_unit(enemy_target, me) then return true end
 return false
end

local function holy_idle_damage_enabled(context)
 if spec_kit.setting_bool(context, "holy_dps_when_idle", false) then return true end
 return context and (context.is_solo == true or context.is_leveling == true)
end

-- ============================================================================
-- parity Feature: StopCast
-- Mid-cast cancellation: if a higher-priority target emerges during a long cast,
-- interrupt the current cast to switch to the higher-priority target.
-- ============================================================================
local function stop_cast_matches(context, state)
 if not context.in_combat then return false end
 if context.player_control_locked then return false end
 -- Only fire if player is currently casting
 if not context.me then return false end
 local ok, is_casting = pcall(function() return context.me:is_casting() end)
 if not ok or not is_casting then return false end
 -- Someone is critically low and we're casting something else — interrupt
 if not state.lowest then return false end
 if (state.lowest_hp or 100) < 30 then
  return true
 end
 -- If tank dropped below safe zone during cast, stop and heal them
 if state.tank and (state.tank_hp or 100) < 50 then
  return true
 end
 return false
end

-- ============================================================================
-- parity Feature: PreHeal
-- Pre-cast Greater Heal when tank is about to take predictable damage.
-- Timed to land just after the damage hits.
-- ============================================================================
local function pre_heal_matches(context, state)
 if not context.in_combat then return false end
 if context.player_control_locked or context.is_moving then return false end
 if not state.tank then return false end
 -- Tank HP should be in the "pre-heal" range: healthy enough to survive
 -- the cast, but damage is incoming
 if (state.tank_hp or 100) < 60 or (state.tank_hp or 100) > 95 then return false end
 -- Check for incoming damage: enemy casting
 if not _check_pushback(context) then return false end
 -- Don't pre-heal if already casting
 if context.me then
  local ok, casting = pcall(function() return context.me:is_casting() end)
  if ok and casting then return false end
 end
 return spell_exists(ACTION.GreaterHeal) and spell_ready(ACTION.GreaterHeal, state.tank.unit)
end

-- ============================================================================
-- parity Feature: Fade
-- Auto-use Fade when player has aggro and Fade is ready.
-- ============================================================================
local function fade_matches(context, state)
 local auto_fade = spec_kit.setting_bool(context, "priest_auto_fade", true)
 if not auto_fade then return false end
 if not context.in_combat then return false end
 if context.player_control_locked then return false end
 if state.has_fade_buff then return false end
 if not state.fade_ready then return false end
 local threshold = spec_kit.setting_number(context, "priest_fade_threat_threshold", 80)
 if context.threat_pct and context.threat_pct >= threshold then return true end
 if context.threat_status and context.threat_status >= 2 then return true end
 -- Fallback: scan enemies targeting player
 local enemies = NS.GetEnemiesInRange and NS.GetEnemiesInRange(20) or {}
 for _, enemy in ipairs(enemies) do
  if enemy and enemy.is_valid and enemy:is_valid() and enemy.is_alive and enemy:is_alive() then
   local ok, target = pcall(function() return enemy:get_target() end)
   if ok and target and context.me and NS.same_unit(target, context.me) then
    return true
   end
  end
 end
 return false
end

-- ============================================================================
-- parity Feature: MountedProtection
-- Safety net: prevent actions while mounted.
-- build_state returns early when mounted, but this strategy acts as
-- an additional guard at the strategy evaluation level.
-- ============================================================================
local function mounted_protection_matches(context, state)
 if not context.me then return false end
 -- build_state already returns early when mounted (state is empty),
 -- so other strategies won't fire. This is a named safety net.
 if context.me.is_mounted and context.me:is_mounted() then
  return true
 end
 return false
end

-- ============================================================================
-- parity Feature: EncounterReactions
-- React to specific Karazhan encounter mechanics:
-- Netherspite: avoid long casts during Nether Breath
-- Maiden: cleanse/heal through Repentance
-- Moroes: heal Garrote targets quickly
-- ============================================================================
local function encounter_reactions_matches(context, state)
 if not context.in_combat then return false end
 if state.encounter_id ~= KARAZHAN_MAP_ID then return false end
 if not state.flash_heal_ready then return false end
 -- Netherspite: player control locked (Nether Breath fear) — dispel/prepare
 if context.player_control_locked then
   return (state.tank_hp or 100) < 80
 end
 -- Maiden / Moroes: tank taking heavy damage
 if state.tank and (state.tank_hp or 100) < 45 then
  return true
 end
 return false
end

-- ============================================================================
-- Declarative strategy DSL definitions
-- Replaces 6 imperative strategies with compiled DSL equivalents while preserving
-- the existing priority order via name-based substitution.
-- ============================================================================
local DSL_DEFS = {
    {
        name = "DesperatePrayer",
        conditions = {
            { type = "in_combat" },
            { type = "context", field = "player_control_locked", op = "falsy" },
            { type = "custom", fn = function(context, state)
                if not spec_kit.setting_bool(context, "holy_use_desperate_prayer", true) then return false end
                local threshold = spec_kit.setting_number(context, "holy_desp_prayer_hp", 30)
                return (context.hp or 100) <= threshold and spell_exists(ACTION.DesperatePrayer) and spell_ready(ACTION.DesperatePrayer, NS.PLAYER_UNIT)
            end },
        },
        action = { type = "custom", fn = function()
            return try_cast(ACTION.DesperatePrayer, NS.PLAYER_UNIT, "[HOLY] Desperate Prayer")
        end },
    },
    {
        name = "Shadowfiend",
        conditions = {
            { type = "in_combat" },
            { type = "context", field = "player_control_locked", op = "falsy" },
            { type = "custom", fn = function(context, state)
                if not spec_kit.setting_bool(context, "use_shadowfiend", spec_kit.setting_bool(context, "use_cooldowns", true)) then return false end
                if not state.shadowfiend_ready then return false end
                local threshold = spec_kit.setting_number(context, "shadowfiend_mana_threshold", 30)
                return (context.mana_pct or 100) < threshold and spell_exists(ACTION.Shadowfiend) and spell_ready(ACTION.Shadowfiend, NS.PLAYER_UNIT)
            end },
        },
        action = { type = "custom", fn = function()
            return try_cast(ACTION.Shadowfiend, nil, "[HOLY] Shadowfiend (mana regen)", { skip_range = true })
        end },
    },
    {
        name = "ManaPotion",
        conditions = {
            { type = "in_combat" },
            { type = "custom", fn = function(context, state)
                if not spec_kit.setting_bool(context, "use_mana_potions", true) then return false end
                local threshold = spec_kit.setting_number(context, "mana_potion_threshold", 20)
                local mana = state.mana_pct or context.mana_pct or 100
                return mana < threshold
            end },
        },
        action = { type = "custom", fn = function()
            if NS.ConsumableManager and NS.ConsumableManager.use_mana_potion then
                return pcall(NS.ConsumableManager.use_mana_potion, NS.ConsumableManager)
            end
            return false
        end },
    },
    {
        name = "Healthstone",
        conditions = {
            { type = "custom", fn = function(context, state)
                if not spec_kit.setting_bool(context, "auto_healthstone", true) then return false end
                if not state.healthstone_ready then return false end
                local hs_hp = spec_kit.setting_number(context, "healthstone_hp_threshold", 30)
                return (context.hp or 100) <= hs_hp
            end },
        },
        action = { type = "custom", fn = function(context, state)
            if state.healthstone_id and state.healthstone_ready then
                if NS.use_item_by_id then
                    return NS.use_item_by_id(state.healthstone_id)
                end
                return try_cast(state.healthstone_id, nil, "[HOLY] Healthstone", { skip_range = true })
            end
            return false
        end },
    },
    {
        name = "SymbolOfHope",
        conditions = {
            { type = "state", field = "symbol_of_hope_ready", op = "truthy" },
            { type = "context", field = "is_group", op = "truthy" },
            { type = "context", field = "player_control_locked", op = "falsy" },
        },
        action = { type = "custom", fn = function()
            return try_cast(ACTION.SymbolOfHope, NS.PLAYER_UNIT, "[HOLY] Symbol of Hope")
        end },
    },
    {
        name = "FearWard",
        conditions = {
            { type = "state", field = "has_fear_ward", op = "falsy" },
            { type = "state", field = "fear_ward_ready", op = "truthy" },
        },
        action = { type = "custom", fn = function(context, state)
            local target = (state and state.fear_ward_target) or NS.PLAYER_UNIT
            if context and context.is_group and (context.fear_nearby or context.known_fear_boss or context.fear_on_tank or context.control_risk) then
                if context.party_tanks and #context.party_tanks > 0 then target = context.party_tanks[1] end
            end
            return try_cast(ACTION.FearWard, target, "[HOLY] FearWard (tank protection)")
        end },
    },
}

local strategies = {
 -- FriendlyTarget (Step 0): honor the player's manually-selected friendly target.
 -- TOP priority: works in and out of combat. Threshold-gated so full-health
 -- targets are ignored. State is populated in build_state().
 {
  name = "FriendlyTarget",
  matches = function(context, state)
   if not state.friendly_target_ready then return false end
   local ft = state.friendly_target
   if not ft then return false end
   if (ft.hp_pct or 100) >= spec_kit.setting_number(context, "holy_friendly_target_threshold", 90) then return false end
   if context.is_moving then return false end
   if context.player_control_locked then return false end
   return spell_exists(ACTION.GreaterHeal) and spell_ready(ACTION.GreaterHeal, ft.unit)
  end,
  execute = function(context, state)
   local ft = state.friendly_target
   if not ft or not ft.unit then return false end
   local chosen_spell, spell_label = cast_best_heal_rank(GREATER_HEAL_RANKS, ft.unit, context, "FriendlyTarget GH", HOLY_OPTS_GH)
   if not chosen_spell then return false end
   return try_cast(chosen_spell, ft.unit, format("[HOLY] %s (friendly target) %.0f%%", spell_label, ft.hp_pct or 0))
  end,
 },
 {
  name = "EmergencyPWS",
  matches = function(context, state)
   if context.player_control_locked then return false end
   if not spec_kit.setting_bool(context, "holy_use_pws", true) then return false end
   -- Tank-only gate: when disc_shield_tank_only is set, only shield the tank
   if spec_kit.setting_bool(context, "disc_shield_tank_only", false) then
    if not state.tank then return false end
    if (state.tank.effective_hp or 100) > spec_kit.setting_number(context, "holy_pws_hp", 30) then return false end
    if state.tank.has_weakened_soul then return false end
    return spell_exists(ACTION.PowerWordShield) and spell_ready(ACTION.PowerWordShield, state.tank.unit)
   end
   if not state.lowest then return false end
   if (state.lowest.effective_hp or 100) > spec_kit.setting_number(context, "holy_pws_hp", 30) then return false end
   if state.lowest.has_weakened_soul then return false end
   return spell_exists(ACTION.PowerWordShield) and spell_ready(ACTION.PowerWordShield, state.lowest.unit)
  end,
  execute = function(context, state)
   if spec_kit.setting_bool(context, "disc_shield_tank_only", false) and state.tank then
    return try_cast(ACTION.PowerWordShield, state.tank.unit, format("[HOLY] Emergency PW:S Tank %.0f%%", state.tank.effective_hp or 0))
   end
   return try_cast(ACTION.PowerWordShield, state.lowest.unit, format("[HOLY] Emergency PW:S %.0f%%", state.lowest.effective_hp or 0))
  end,
 },
 {
  name = "PreemptiveGreaterHeal",
  matches = function(context, state)
   if not context.in_combat then return false end
   if context.player_control_locked or context.is_moving then return false end
   local threshold = spec_kit.setting_number(context, "holy_preemptive_threshold", PreemptiveHeal.DEFAULT_THRESHOLD)
   if not PreemptiveHeal.match(context, state, threshold, 2.5) then return false end
   if not spell_exists(ACTION.GreaterHeal) or not spell_ready(ACTION.GreaterHeal, state._preemptive_target.unit) then return false end
   return true
  end,
  execute = function(context, state)
   local target = state._preemptive_target
   if not target or not target.unit then return false end
   local chosen_spell, spell_label = cast_best_heal_rank(GREATER_HEAL_RANKS, target.unit, context, "Preemptive GH", HOLY_OPTS_GH)
   if not chosen_spell then return false end
   return PreemptiveHeal.execute(context, state, chosen_spell, format("[HOLY] %s %.0f%%", spell_label, target.effective_hp or 0), { cast_time = 2.5, heal_size = 3500 })
  end,
 },
  {
   name = "EmergencyFlashHeal",
   matches = function(context, state)
    if not context.in_combat then return false end
    if context.player_control_locked or context.is_moving then return false end
    if not state.flash_heal_ready then return false end
    if not state.lowest then return false end
    local threshold = spec_kit.setting_number(context, "holy_emergency_hp", 30)
    local current_hp = state.lowest_hp or 100
    local pred_hp = current_hp
    if state.lowest.unit and HealthPred and HealthPred.predicted_hp_pct then
     local ok, pct = pcall(HealthPred.predicted_hp_pct, state.lowest.unit, 1.5)
     if ok and type(pct) == "number" then pred_hp = pct end
    end
    return current_hp < threshold or pred_hp < threshold
   end,
  execute = function(context, state)
   local target = state.lowest.unit
   local chosen_spell, spell_label = cast_best_heal_rank(FLASH_HEAL_RANKS, target, context, "Emergency FH", HOLY_OPTS_EMERGENCY_FH)
   if not chosen_spell then return false end
   return try_cast(chosen_spell, target, format("[HOLY] %s %.0f%%", spell_label, state.lowest.effective_hp or 0))
  end,
 },
 -- FriendlyTarget (B6): honor the player's manually-selected friendly target.
 -- Placed AFTER EmergencyPWS / PreemptiveGreaterHeal / EmergencyFlashHeal so
 -- life-critical saves still win, but BEFORE routine heals (PoM / CoH / GH /
 -- FH / Renew) so a manual friendly target wins over auto-lowest-scan for
 {
  name = "PrayerOfMending",
  matches = function(context, state)
   if context.player_control_locked then return false end
   if not state.pom_ready then return false end
   if not context.in_combat and spec_kit.setting_bool(context, "holy_prepull_pom", true) == false then return false end
   if not (state.tank ~= nil or state.lowest ~= nil) then return false end
   -- Skip if PoM already active on target (don't overwrite bounces in progress)
   local target = (state.tank and state.tank.unit) or (state.lowest and state.lowest.unit)
   if target and NS.has_buff and NS.has_buff(target, PRAYER_OF_MENDING_BUFF) then return false end
   return true
  end,
  execute = function(_, state)
   local target = (state.tank and state.tank.unit) or (state.lowest and state.lowest.unit) or NS.PLAYER_UNIT
   local hp = (state.tank and state.tank.effective_hp) or (state.lowest and state.lowest.effective_hp) or 100
   return try_cast(ACTION.PrayerofMending, target, format("[HOLY] Prayer of Mending %.0f%%", hp))
  end,
 },
 {
  name = "CircleOfHealing",
  matches = function(context, state)
   if not context.in_combat then return false end
   if context.player_control_locked then return false end
   if not spec_kit.setting_bool(context, "holy_use_coh", true) then return false end
   if not state.coh_ready then return false end
   return (state.group_damaged_count or 0) >= spec_kit.setting_number(context, "holy_aoe_count", 3)
  end,
  execute = function(_, state)
   local target = (state.lowest and state.lowest.unit) or (state.tank and state.tank.unit) or NS.PLAYER_UNIT
   return try_cast(ACTION.CircleofHealing, target, format("[HOLY] Circle of Healing count=%d", state.group_damaged_count or 0))
  end,
 },
 {
  name = "BindingHeal",
  matches = function(context, state)
   if not context.in_combat then return false end
   if context.player_control_locked or context.is_moving then return false end
   if not spec_kit.setting_bool(context, "holy_use_binding_heal", true) then return false end
   if context.hp > spec_kit.setting_number(context, "holy_binding_self_hp", 80) then return false end
   if not state.lowest or state.lowest.is_player then return false end
   if not spell_exists(ACTION.BindingHeal) or not spell_ready(ACTION.BindingHeal, state.lowest.unit) then return false end
    -- Predictive overheal gate
    if gate_overheal("BindingHeal", state.lowest.unit, 2.0, context.settings, ACTION.BindingHeal:id()) then return false end
   return true
  end,
  execute = function(context, state)
   local chosen_spell, spell_label = cast_best_heal_rank(BINDING_HEAL_RANKS, state.lowest.unit, context, "BH", HOLY_OPTS_BH)
   if not chosen_spell then return false end
   return try_cast(chosen_spell, state.lowest.unit, format("[HOLY] %s target=%.0f%% self=%.0f%%", spell_label, state.lowest.effective_hp or 0, context and context.hp or 0))
  end,
 },
 {
  name = "PrayerOfHealing",
  matches = function(context, state)
   if not context.in_combat then return false end
   if context.player_control_locked or context.is_moving then return false end
   if not spec_kit.setting_bool(context, "holy_use_poh", true) then return false end
   if not state.prayer_of_healing_ready then return false end
   -- Use subgroup count for PoH (only counts your party in raids)
   local poh_count = state.subgroup_damaged_count or state.group_damaged_count
   if poh_count < spec_kit.setting_number(context, "holy_aoe_count", 3) then return false end
    -- Predictive overheal gate
    if gate_overheal("PrayerOfHealing", state.lowest and state.lowest.unit or NS.PLAYER_UNIT, 3.0, context.settings, ACTION.PrayerOfHealing:id()) then return false end
   return true
  end,
  execute = function(context, state)
   local chosen_spell, spell_label = cast_best_heal_rank(PRAYER_OF_HEALING_RANKS, NS.PLAYER_UNIT, context, "PoH", HOLY_OPTS_POH)
   if not chosen_spell then return false end
   return try_cast(chosen_spell, NS.PLAYER_UNIT, format("[HOLY] %s count=%d", spell_label, state.group_damaged_count or 0))
  end,
 },
 {
  name = "ClearcastingGreaterHeal",
  matches = function(context, state)
   if not context.in_combat then return false end
   if context.player_control_locked or context.is_moving then return false end
   if not state.clearcasting then return false end
   if not state.greater_heal_ready then return false end
   if not state.lowest then return false end
   -- Pushback gate: skip long-cast heals when taking damage
   if _check_pushback(context) then return false end
    -- Predictive overheal gate: don't waste clearcast GH if predicted deficit is small
    local mana_pct = state.mana_pct or context.mana_pct or 100
    local spell_id = (mana_pct > 30) and GREATER_HEAL_MAX or ((mana_pct > 15) and GREATER_HEAL_CONSERVE or GREATER_HEAL_EFFICIENT)
    if gate_overheal("GreaterHeal", state.lowest.unit, 2.5, context.settings, spell_id) then return false end
    return (state.lowest_hp or 100) < 95
  end,
  execute = function(context, state)
   local target = state.lowest.unit
   local chosen_spell, spell_label = cast_best_heal_rank(GREATER_HEAL_RANKS, target, context, "Clearcasting GH", HOLY_OPTS_CLEARCAST_GH)
   if not chosen_spell then return false end
   return try_cast(chosen_spell, target, format("[HOLY] %s %.0f%%", spell_label, state.lowest.effective_hp or 0))
  end,
 },
 {
  name = "InnerFocus",
  is_gcd_gated = false,
  is_burst = true,
  matches = function(context, state)
   if not context.in_combat then return false end
   if context.player_control_locked then return false end
   if not spec_kit.setting_bool(context, "holy_use_inner_focus", true) then return false end
   if state.has_inner_focus then return false end
   if not spell_exists(ACTION.InnerFocus) or not spell_ready(ACTION.InnerFocus, NS.PLAYER_UNIT) then return false end
   if not state.lowest then return false end
   return (state.lowest_hp or 100) < spec_kit.setting_number(context, "holy_renew_hp", 90)
  end,
  execute = function()
   return try_cast(ACTION.InnerFocus, NS.PLAYER_UNIT, "[HOLY] Inner Focus")
  end,
 },
 {
  name = "Lightwell",
  matches = function(context, state)
   if not context.in_combat then return false end
   if context.player_control_locked then return false end
   if not spec_kit.setting_bool(context, "holy_use_lightwell", true) then return false end
   if not state.lightwell_ready then return false end
   -- Only place Lightwell when raid HP is under sustained pressure (3+ injured)
   return (state.group_damaged_count or 0) >= spec_kit.setting_number(context, "holy_aoe_count", 3)
  end,
  execute = function()
   return try_cast(ACTION.Lightwell, NS.PLAYER_UNIT, "[HOLY] Lightwell (raid sustain)")
  end,
 },
 {
  name = "GreaterHeal",
  matches = function(context, state)
   if not context.in_combat then return false end
   if context.player_control_locked or context.is_moving then return false end
   if not state.greater_heal_ready then return false end
   if not state.lowest then return false end
   -- Pushback gate: skip GH when taking damage, fallback to FH
   if _check_pushback(context) then return false end
   -- Mana conservation: drop GH below 30% mana, use FH+Renew only
   if context.mana_pct < spec_kit.setting_number(context, "holy_gh_mana_floor", 30) then return false end
   local flash_hp = spec_kit.setting_number(context, "holy_flash_heal_hp", 50)
   local renew_hp = spec_kit.setting_number(context, "holy_renew_hp", 90)
   if not ((state.lowest_hp or 100) < renew_hp and (state.lowest_hp or 100) >= flash_hp) then return false end
    -- Predictive overheal gate
    local mana_pct = state.mana_pct or context.mana_pct or 100
    local spell_id = (mana_pct > 30) and GREATER_HEAL_MAX or ((mana_pct > 15) and GREATER_HEAL_CONSERVE or GREATER_HEAL_EFFICIENT)
    if gate_overheal("GreaterHeal", state.lowest.unit, 2.5, context.settings, spell_id) then return false end
   return true
  end,
   execute = function(context, state)
    local target = state.lowest.unit
    local mana_pct = state.mana_pct or context.mana_pct or 100
    local spell_id
    if mana_pct > 30 then
     spell_id = GREATER_HEAL_MAX
    elseif mana_pct > 15 then
     spell_id = GREATER_HEAL_CONSERVE
    else
     spell_id = GREATER_HEAL_EFFICIENT
    end
    local adjusted, penalty = PreemptiveHeal.get_penalty_adjusted_heal(spell_id, 3500)
    return try_cast(spell_id, target, format("[HOLY] Greater Heal %.0f%% (rank %s, penalty %.0f%%)", state.lowest.effective_hp or 0, mana_pct > 30 and "7" or (mana_pct > 15 and "6" or "5"), (penalty or 1) * 100))
   end,
  },
  {
   name = "FSRPause",
   matches = function(context, state)
    if not FsrManager then return false end
    if not context.in_combat then return false end
    if (state.mana_pct or 100) > 35 then return false end
    if not state.fsr_inside then return false end
    if (state.fsr_regen_delta or 0) <= 0 then return false end
    local pause_ok, reason = FsrManager.should_pause_for_fsr(state, context)
    return pause_ok
   end,
    execute = function(_, state)
     return true
    end,
  },
  {
   name = "FlashHeal",
  matches = function(context, state)
   if not context.in_combat then return false end
   if context.player_control_locked or context.is_moving then return false end
   if not state.flash_heal_ready then return false end
   if not state.lowest then return false end
   -- Mana conservation: drop direct heals below 15% mana, Renew only
   if context.mana_pct < spec_kit.setting_number(context, "holy_fh_mana_floor", 15) then return false end
   if not (state.lowest_hp < spec_kit.setting_number(context, "holy_flash_heal_hp", 50)) then return false end
    -- Predictive overheal gate
    local mana_pct = state.mana_pct or context.mana_pct or 100
    local spell_id = (mana_pct > 30) and FLASH_HEAL_MAX or ((mana_pct > 15) and FLASH_HEAL_CONSERVE or FLASH_HEAL_EFFICIENT)
    if gate_overheal("FlashHeal", state.lowest.unit, 1.5, context.settings, spell_id) then return false end
   return true
  end,
   execute = function(context, state)
    local target = state.lowest.unit
    local mana_pct = state.mana_pct or context.mana_pct or 100
    local spell_id
    if mana_pct > 30 then
     spell_id = FLASH_HEAL_MAX
    elseif mana_pct > 15 then
     spell_id = FLASH_HEAL_CONSERVE
    else
     spell_id = FLASH_HEAL_EFFICIENT
    end
    local adjusted, penalty = PreemptiveHeal.get_penalty_adjusted_heal(spell_id, 1500)
    return try_cast(spell_id, target, format("[HOLY] Flash Heal %.0f%% (rank %s, penalty %.0f%%)", state.lowest.effective_hp or 0, mana_pct > 30 and "9" or (mana_pct > 15 and "8" or "7"), (penalty or 1) * 100))
   end,
 },
 { name = "DesperatePrayer" },
 { name = "Shadowfiend", is_gcd_gated = false, is_burst = true },
 { name = "ManaPotion" },
 {
  name = "DispelMagic",
  matches = function(context, state)
    if NS.broken_api_throttled and NS.broken_api_throttled(ACTION.DispelMagic, 3.0) then return false end
   if not context.in_combat then return false end
   if context.player_control_locked then return false end
   if not spec_kit.setting_bool(context, "use_party_dispel", true) then return false end
   if not state.dispel_magic_ready then return false end
   if context.mana_pct < spec_kit.setting_number(context, "party_dispel_mana_floor", 30) then return false end
   -- Dungeon opt: if control_risk or fear_nearby (from WoWHead researched mechanics), dispel magic aggressively to avoid deaths and speed clear
   if context.control_risk or context.fear_nearby then
    if Healing.has_dangerous_dispel then
     local target = (state.tank and state.tank.unit) or (state.lowest and state.lowest.unit) or context.me
     if target and Healing.has_dangerous_dispel(target) then return true end
    end
    return true -- force if risk
   end
   -- Dispel dangerous magic debuffs on tank first, then lowest ally
   if not state.tank and not state.lowest then return false end
   local target = (state.tank and state.tank.unit) or (state.lowest and state.lowest.unit)
   -- Gate: only dispel if the target has a harmful magic effect (Healing module tracks this)
   if Healing.has_dangerous_dispel then
    return Healing.has_dangerous_dispel(target)
   end
   return false
  end,
  execute = function(_, state)
   local target = (state.tank and state.tank.unit) or (state.lowest and state.lowest.unit)
   return try_cast(ACTION.DispelMagic, target, "[HOLY] Dispel Magic")
  end,
 },
 {
  name = "MassDispel",
  matches = function(context, state)
   if NS.broken_api_throttled and NS.broken_api_throttled(ACTION.MassDispel, 3.0) then return false end
   if not context.in_combat then return false end
   if context.player_control_locked then return false end
   if not spec_kit.setting_bool(context, "use_party_dispel", true) then return false end
   if not state.mass_dispel_ready then return false end
   if context.mana_pct < spec_kit.setting_number(context, "party_dispel_mana_floor", 30) then return false end
   -- Dungeon opt: use Mass Dispel for AoE magic in packs (WoWHead: removes undispellable magic too, speeds clears, prevents deaths)
   if not context.is_group then return false end
   -- Check if any party has dangerous magic (reuse)
   if Healing.has_dangerous_dispel then
    -- scan a few to see if worth
    local party = context.party_members or {}
    for _, u in ipairs(party) do
     if u and Healing.has_dangerous_dispel(u) then return true end
    end
   end
   return false
  end,
  execute = function(context, state)
   -- Mass Dispel is self cast AoE
   return try_cast(ACTION.MassDispel, NS.PLAYER_UNIT, "[HOLY] Mass Dispel (dungeon pack clear)")
  end,
 },
 {
  name = "CureDisease",
  matches = function(context, state)
    if NS.broken_api_throttled and NS.broken_api_throttled(ACTION.CureDisease, 3.0) then return false end
   if not context.in_combat then return false end
   if context.player_control_locked then return false end
   if not state.cure_disease_ready then return false end
   if context.mana_pct < spec_kit.setting_number(context, "party_dispel_mana_floor", 30) then return false end
   if not state.lowest then return false end
   -- Gate: only cure if the target actually has a disease
   if Healing.has_disease then
    return Healing.has_disease((state.tank and state.tank.unit) or state.lowest.unit)
   end
   return false
  end,
  execute = function(_, state)
   local target = (state.tank and state.tank.unit) or (state.lowest and state.lowest.unit)
   return try_cast(ACTION.CureDisease, target, "[HOLY] Cure Disease")
  end,
 },
 {
  name = "AbolishDisease",
  matches = function(context, state)
    if NS.broken_api_throttled and NS.broken_api_throttled(ACTION.AbolishDisease, 3.0) then return false end
   if not context.in_combat then return false end
   if context.player_control_locked then return false end
   if not state.abolish_disease_ready then return false end
   if context.mana_pct < spec_kit.setting_number(context, "party_dispel_mana_floor", 30) then return false end
    -- Only cast if tank actually has a disease (not pre-emptive -- wastes mana/GCD)
    if not state.tank then return false end
    if Healing.has_disease then
     return Healing.has_disease(state.tank.unit)
    end
    return false
  end,
  execute = function(_, state)
   return try_cast(ACTION.AbolishDisease, state.tank.unit, "[HOLY] Abolish Disease (preventive)")
  end,
 },
 { name = "SymbolOfHope" },
 { name = "FearWard" },
 {
  name = "RenewTank",
  matches = function(context, state)
   if context.player_control_locked then return false end
   if not state.tank then return false end
   if not spell_exists(ACTION.Renew) or not spell_ready(ACTION.Renew, state.tank.unit) then return false end
   if not context.in_combat and spec_kit.setting_bool(context, "holy_prepull_renew", true) == false then return false end

   -- Refresh timing gate: only refresh if < 3s remaining (avoid wasted ticks)
   -- Use explicit nil-check to avoid Lua 0-falsy edge case with renew_remains
   local tank_renew = state.tank.renew_remains
   if tank_renew == nil then
    tank_renew = (state.tank.has_renew and 999 or 0)
   end
   if tank_renew > 3 then return false end

   local threshold = spec_kit.setting_number(context, "holy_renew_hp", 90)
   if (state.tank.effective_hp or 100) > threshold and context.in_combat then
    return false
   end

   return true
  end,
  execute = function(_, state)
   return try_cast(ACTION.Renew, state.tank.unit, format("[HOLY] Renew Tank %.0f%%", state.tank.effective_hp or 0))
  end,
 },
 {
  name = "RenewSpread",
  matches = function(context, state)
   if not context.in_combat then return false end
   if context.player_control_locked then return false end
   if not state.lowest then return false end
   if not spell_exists(ACTION.Renew) or not spell_ready(ACTION.Renew, state.lowest.unit) then return false end

   -- Refresh timing gate: only refresh if < 3s remaining (avoid wasted ticks)
   -- Use explicit nil-check to avoid Lua 0-falsy edge case with renew_remains
   local lowest_renew = state.lowest.renew_remains
   if lowest_renew == nil then
    lowest_renew = (state.lowest.has_renew and 999 or 0)
   end
   if lowest_renew > 3 then return false end

   return (state.lowest_hp or 100) < spec_kit.setting_number(context, "holy_renew_hp", 90)
  end,
  execute = function(_, state)
   return try_cast(ACTION.Renew, state.lowest.unit, format("[HOLY] Renew %.0f%%", state.lowest.effective_hp or 0))
  end,
 },
 {
  name = "SurgeOfLightSmite",
  matches = function(context, state)
   if not context.in_combat then return false end
   if context.player_control_locked then return false end
   if not state.surge_of_light then return false end
   if not context.has_valid_enemy_target then return false end
   if not _engaged_with_player(context) then return false end
    if (state.lowest_hp or 100) < spec_kit.setting_number(context, "holy_flash_heal_hp", 50) then return false end
   return spell_exists(ACTION.Smite) and spell_ready(ACTION.Smite, context.target)
  end,
  execute = function(context)
   return try_cast(ACTION.Smite, context.target, "[HOLY] Surge of Light Smite")
  end,
 },
 {
  name = "IdleSWP",
  matches = function(context, state)
   if not context.in_combat then return false end
   if context.player_control_locked then return false end
   if not holy_idle_damage_enabled(context) then return false end
   if not context.has_valid_enemy_target then return false end
   if not _engaged_with_player(context) then return false end
    if (state.lowest_hp or 100) < spec_kit.setting_number(context, "holy_renew_hp", 90) then return false end
    if context.mana_pct < spec_kit.setting_number(context, "holy_dps_mana_floor", (context.is_solo and 35 or 70)) then return false end
    if (state.swp_remaining or 0) > 0 then return false end
   return spell_exists(ACTION.ShadowWordPain) and spell_ready(ACTION.ShadowWordPain, context.target)
  end,
  execute = function(context)
   return try_cast(ACTION.ShadowWordPain, context.target, "[HOLY] Idle SW:P")
  end,
 },
 {
  name = "IdleHolyFire",
  matches = function(context, state)
   if not context.in_combat then return false end
   if context.player_control_locked or context.is_moving then return false end
   if not holy_idle_damage_enabled(context) then return false end
   if not context.has_valid_enemy_target then return false end
   if not _engaged_with_player(context) then return false end
    if (state.lowest_hp or 100) < spec_kit.setting_number(context, "holy_renew_hp", 90) then return false end
    if context.mana_pct < spec_kit.setting_number(context, "holy_dps_mana_floor", (context.is_solo and 45 or 70)) then return false end
    if (state.holy_fire_remaining or 0) > 0 then return false end
   return spell_exists(ACTION.HolyFire) and spell_ready(ACTION.HolyFire, context.target)
  end,
  execute = function(context)
   return try_cast(ACTION.HolyFire, context.target, "[HOLY] Idle Holy Fire")
  end,
 },
 {
  name = "IdleSmite",
  matches = function(context, state)
   if not context.in_combat then return false end
   if context.player_control_locked or context.is_moving then return false end
   if not holy_idle_damage_enabled(context) then return false end
   if not context.has_valid_enemy_target then return false end
   if not _engaged_with_player(context) then return false end
    if (state.lowest_hp or 100) < spec_kit.setting_number(context, "holy_renew_hp", 90) then return false end
    if context.mana_pct < spec_kit.setting_number(context, "holy_dps_mana_floor", (context.is_solo and 35 or 70)) then return false end
   return spell_exists(ACTION.Smite) and spell_ready(ACTION.Smite, context.target)
  end,
  execute = function(context)
   return try_cast(ACTION.Smite, context.target, "[HOLY] Idle Smite")
  end,
 },
 -- Mana < 5%: wand/auto-attack only — all spells forbidden (Research resource floor)
 {
  name = "ManaBelow5Wand",
  matches = function(context, state)
   if not context.in_combat then return false end
   if context.player_control_locked then return false end
   if context.mana_pct >= 5 then return false end
   -- Still allow Desperate Prayer if we're about to die
   if context.hp < 15 and state.lowest and state.lowest.is_player then return false end
   return context.has_valid_enemy_target
  end,
  execute = function()
   -- Wand if auto-shoot is not active; otherwise do nothing (auto-attack handles itself)
   if NS.start_auto_attack then
    return NS.start_auto_attack()
   end
   return false
  end,
 },
 -- parity Feature: StopCast
 {
  name = "StopCast",
  matches = stop_cast_matches,
  execute = function()
   if NS.stop_casting then
    return NS.stop_casting()
   end
   -- Fallback: cancel current form/cast via spell book
   if NS.cancel_current_cast then
    return NS.cancel_current_cast()
   end
   return false
  end,
 },
 -- parity Feature: PreHeal
 {
  name = "PreHeal",
  matches = pre_heal_matches,
  execute = function(context, state)
   local target = (state.tank and state.tank.unit) or (state.lowest and state.lowest.unit) or NS.PLAYER_UNIT
   local chosen_spell, spell_label = cast_best_heal_rank(GREATER_HEAL_RANKS, target, context, "PreHeal GH", HOLY_OPTS_GH)
   if not chosen_spell then return false end
   return try_cast(chosen_spell, target, format("[HOLY] %s (PreHeal) %.0f%%", spell_label, state.tank_hp or 0))
  end,
 },
 -- parity Feature: Fade
 {
  name = "Fade",
  matches = fade_matches,
  execute = function(_, state)
   return try_cast(ACTION.Fade, nil, "[HOLY] Fade (aggro drop)", { skip_range = true })
  end,
 },
 -- parity Feature: Healthstone
 { name = "Healthstone" },
 -- parity Feature: MountedProtection
 {
  name = "MountedProtection",
  matches = mounted_protection_matches,
  execute = function()
   return true -- No-op: mount check is handled in build_state
  end,
 },
 -- parity Feature: EncounterReactions
 {
  name = "EncounterReactions",
  matches = encounter_reactions_matches,
  execute = function(context, state)
   local target = (state.tank and state.tank.unit) or (state.lowest and state.lowest.unit) or NS.PLAYER_UNIT
   local chosen_spell, spell_label = cast_best_heal_rank(FLASH_HEAL_RANKS, target, context, "Encounter FH", HOLY_OPTS_FH)
   if not chosen_spell then return false end
   return try_cast(chosen_spell, target, format("[HOLY] %s (Encounter) %.0f%%", spell_label, (state.tank_hp or state.lowest_hp or 0)))
  end,  },
}

-- ============================================================================
-- Apply DSL definitions to name-only strategy placeholders.
-- Preserves original extra fields (e.g. is_gcd_gated / is_burst) when present.
-- ============================================================================
for i = 1, #strategies do
    local s = strategies[i]
    if s and s.name and s.matches == nil then
        for _, def in ipairs(DSL_DEFS) do
            if def.name == s.name then
                local is_gcd_gated = s.is_gcd_gated
                local is_burst = s.is_burst
                local compiled = dsl.compile_strategy(def, { get_state = build_state })
                compiled.is_gcd_gated = is_gcd_gated
                compiled.is_burst = is_burst
                strategies[i] = compiled
                break
            end
        end
    end
end

if NS.rotation_registry and NS.rotation_registry.register then
 NS.rotation_registry:register("holy", strategies, {
 get_state = build_state,
 format_context_log = function(_, state)
  return format(
   "lowest=%.0f tank=%.0f damaged=%d sol=%s clear=%s",
   state.lowest_hp or 100,
   state.tank_hp or 100,
   state.group_damaged_count or 0,
   tostring(state.surge_of_light),   tostring(state.clearcasting)
  )
 end,
})
end

-- Holy priest rotation registered
return { strategies = strategies, build_state = build_state }
