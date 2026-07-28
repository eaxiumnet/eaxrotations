-- restoration_sylvanas.lua -- Shaman Restoration healer for TBC Anniversary (2.5.5).
-- WHAT:  chain-heal-based group healer with Earth Shield tank maintenance,
--         Mana Tide + Bloodlust CDs, Water Shield mana management, and
--         totem auto-management (tremor/grounding/cleansing/stat totems).
-- WHEN:  combat or pre-combat, with valid friendly targets.
-- WHY:   mirrors TBC resto shaman consensus from wowsims (no APL), Icy Veins, Wowhead: Chain Heal primary + Earth Shield tank + downrank CH + Water Shield + totem twisting.
-- SAFETY: Pattern 14 eliminated via spec_kit.safe_state(); no on_update() allocs.
--         6 strategies use the declarative strategy DSL (sixth DSL adopter, first healer).

-- Shaman Restoration group-healing playstyle.

local NS = _G.EaxRotations
if not NS then return nil end
local potion_helper = require("shared/potion_helper_sylvanas")
local FsrManager = require("shared/fsr_manager_sylvanas")
local _inv_ok, inventory_helper = pcall(require, "common/utility/inventory_helper")
if not _inv_ok or type(inventory_helper) ~= "table" then inventory_helper = nil end
local SPELLS = NS.ShamanSpells or {}
local spec_kit = require("shared/spec_kit_sylvanas")
local dsl = require("shared/strategy_dsl_sylvanas")

-- Centralized spell resolver via spec_kit (rank IDs from shaman/class_sylvanas.lua).
local define = spec_kit.define_action_for_class(SPELLS)
local ACTION = {
    Bloodlust               = define("Bloodlust",               { 2825 }, "Bloodlust"),
    ChainHeal               = define("ChainHeal",               { 25423, 25422, 10623, 10622, 1064 }, "ChainHeal"),
    ChainLightning          = define("ChainLightning",          { 25442, 25439, 10605, 2860, 930, 421 }, "ChainLightning"),
    CureDisease             = define("CureDisease",             { 2870 }, "CureDisease"),
    CurePoison              = define("CurePoison",              { 526 }, "CurePoison"),
    DiseaseCleansingTotem   = define("DiseaseCleansingTotem",   { 8170 }, "DiseaseCleansingTotem"),
    EarthShield             = define("EarthShield",             { 32594, 32593, 974 }, "EarthShield"),
    EarthShock              = define("EarthShock",              { 25454, 10414, 10413, 10412, 8046, 8045, 8044, 8042 }, "EarthShock"),
    FlameShock              = define("FlameShock",              { 25457, 29228, 10448, 10447, 8053, 8052, 8050 }, "FlameShock"),
    GraceOfAirTotem         = define("GraceOfAirTotem",         { 25359, 10627, 8835 }, "GraceOfAirTotem"),
    GroundingTotem          = define("GroundingTotem",          { 8177 }, "GroundingTotem"),
    HealingWave             = define("HealingWave",             { 25396, 25391, 25357, 10396, 10395, 8005, 959, 939, 913, 547, 332, 331 }, "HealingWave"),
    LesserHealingWave       = define("LesserHealingWave",       { 25420, 10468, 10467, 10466, 8010, 8008, 8004 }, "LesserHealingWave"),
    LightningBolt           = define("LightningBolt",           { 25449, 25448, 15208, 15207, 10392, 10391, 6041, 943, 915, 548, 529, 403 }, "LightningBolt"),
    LightningShield         = define("LightningShield",         { 25472, 25469, 10432, 10431, 8134, 945, 905, 325, 324 }, "LightningShield"),
    ManaSpringTotem         = define("ManaSpringTotem",         { 25570, 10497, 10496, 10495, 5675 }, "ManaSpringTotem"),
    ManaTideTotem           = define("ManaTideTotem",           { 16190 }, "ManaTideTotem"),
    NaturesSwiftness        = define("NaturesSwiftness",        { 16188 }, "NaturesSwiftness"),
    PoisonCleansingTotem    = define("PoisonCleansingTotem",    { 8166 }, "PoisonCleansingTotem"),
    Purge                   = define("Purge",                   { 8012, 370 }, "Purge"),
    StrengthOfEarthTotem    = define("StrengthOfEarthTotem",    { 25528, 25361, 10442, 8161, 8160, 8075 }, "StrengthOfEarthTotem"),
    TremorTotem             = define("TremorTotem",             { 8143 }, "TremorTotem"),
    WaterShield             = define("WaterShield",             { 33736, 24398, 23575 }, "WaterShield"),
    WindfuryTotem           = define("WindfuryTotem",           { 25587, 25585, 10614, 10613, 8512 }, "WindfuryTotem"),
}
local Healing = NS.ShamanHealing or require("classes/shaman/healing_sylvanas")

local _ns_gate_overheal = NS.gate_overheal
local function gate_overheal(spell_key, unit, cast_time, settings, spell_id)
    if NS.HealerDeficit and NS.HealerDeficit.gate_spell_overheal then
        return NS.HealerDeficit.gate_spell_overheal(spell_key, unit, cast_time, settings, spell_id)
    end
    return _ns_gate_overheal and _ns_gate_overheal(spell_key, unit, cast_time, settings, spell_id) or false
end

-- Preemptive heal module (Sonah-style predictive healing)
local PreemptiveHeal = require("shared/preemptive_heal_sylvanas")
local _ts_ok, TSHelper = pcall(require, "shared/ts_helper_sylvanas")
if not _ts_ok or type(TSHelper) ~= "table" then TSHelper = nil end
local _data_ok, TBC = pcall(require, "shared/tbc_data_sylvanas")
if not _data_ok or type(TBC) ~= "table" then TBC = { SPELLS = { shaman = {} } } end
local TBC_SHAMAN = (TBC.SPELLS and TBC.SPELLS.shaman) or {}
local _hp_ok, HealthPred = pcall(require, "shared/health_pred_helper_sylvanas")
if not _hp_ok or type(HealthPred) ~= "table" then HealthPred = nil end

local WATER_SHIELD_SPELL = ACTION.WaterShield or 33736
local LIGHTNING_SHIELD_SPELL = ACTION.LightningShield or 25472

-- ============================================================================
-- Buff & Debuff ID tables
-- ============================================================================
local WATER_SHIELD_BUFF = TBC_SHAMAN.water_shield or { 33736, 24398, 23575 }
local LIGHTNING_SHIELD_BUFF = TBC_SHAMAN.lightning_shield or { 25472, 25469, 10432, 10431, 8134, 945, 905, 325, 324 }
local EARTH_SHIELD_BUFF = { 32594, 32593, 974 }
local FLAME_SHOCK_DEBUFF = { 25457, 29228, 10448, 10447, 8053, 8052, 8050 }
local NATURES_SWIFTNESS_BUFF = { 16188 }
local HEALING_WAY_BUFF = { 29277, 29276, 29275 }

local function _ns_is_active(unit)
 local me = unit or (NS.GetPlayer and NS.GetPlayer()) or NS.PLAYER_UNIT
 return me and NS.buff_up and NS.buff_up(me, NATURES_SWIFTNESS_BUFF) or false
end

local function _totem_ready(spell)
 local me = (NS.GetPlayer and NS.GetPlayer()) or NS.PLAYER_UNIT
 return spell and me and NS.spell_ready and NS.spell_ready(spell, me, { skip_range = true }) or false
end

-- Mana conservation tier defaults (configurable via schema)
local MANA_LOW_DEFAULT = 30

local CHAIN_HEAL_MAX = 25423
local CHAIN_HEAL_CONSERVE = 25422
local CHAIN_HEAL_EFFICIENT = 10623
local MANA_CONSERVE_DEFAULT = 15
local MANA_EMERGENCY_DEFAULT = 5
-- Earth Shield charge refresh threshold
local EARTH_SHIELD_CHARGE_DEFAULT = 2

-- Healing Wave rank tiers for mana-based downranking
local HEALING_WAVE_MAX = 25396      -- Rank 12 (max)
local HEALING_WAVE_CONSERVE = 25391 -- Rank 11 (conserve)
local HEALING_WAVE_EFFICIENT = 25357 -- Rank 10 (efficient)

-- Lesser Healing Wave rank tiers
local LESSER_HEALING_WAVE_MAX = 25420     -- Rank 7 (max)
local LESSER_HEALING_WAVE_CONSERVE = 10468 -- Rank 6 (conserve)

-- Small helper to keep rank selection consistent and reduce duplication
-- across FriendlyTarget, HealingWay, and their execute paths.
local function choose_healing_wave(mana_pct)
  mana_pct = mana_pct or 100
  if mana_pct > 30 then return HEALING_WAVE_MAX end
  if mana_pct > 15 then return HEALING_WAVE_CONSERVE end
  return HEALING_WAVE_EFFICIENT
end

local HEALTHSTONE_IDS = { 22105, 22104, 22103, 19013, 19012, 19011, 5512 }
local function first_ready_item(ids)
    if not inventory_helper then return nil end
    for _, id in ipairs(ids) do
        if inventory_helper.has_item(id) then return id end
    end
    return nil
end

-- ============================================================================
-- Schema for safe_state (Pattern 14 nil-guard elimination).
-- ============================================================================
local RESTO_SCHEMA = {
    -- Buff presence
    has_water_shield = false, has_lightning_shield = false,
    natures_swiftness_active = false,
    -- Spell readiness
    water_shield_ready = false, lightning_shield_ready = false,
    earth_shield_ready = false, chain_heal_ready = false,
    healing_wave_ready = false, lesser_healing_wave_ready = false,
    mana_tide_ready = false, bloodlust_ready = false,
    natures_swiftness_ready = false, earth_shock_ready = false,
    flame_shock_ready = false, lightning_bolt_ready = false,
    chain_lightning_ready = false, purge_ready = false,
    cure_poison_ready = false, cure_disease_ready = false,
    tremor_totem_ready = false, grounding_totem_ready = false,
    poison_cleansing_totem_ready = false, disease_cleansing_totem_ready = false,
    -- Resource
    mana_pct = 100, hp_pct = 100,
    mana_low = false, mana_conserve = false, mana_emergency = false,
    -- Combat
    in_combat = false, is_group = false, enemy_count = 0,
    -- Target
    target_casting = false,
    -- Numeric
    earth_shield_charges = 0, earth_shield_remains = 0,
    water_shield_charges = 0, flame_shock_remains = 0,
    healing_way_stacks = 0, healing_way_remains = 0,
    chain_heal_target_count = 0, chain_heal_cluster_count = 0,
    lowest_hp_pct = 100, lowest_time_to_die = 999,
    healthstone_ready = 0,
    -- Boolean
    friendly_target_ready = false,
    -- FSR state (Five-Second Rule)
    fsr_inside = false, fsr_seconds = 0, fsr_regen_delta = 0,
}

-- ============================================================================
-- State builder
-- ============================================================================
local resto_state = {
 lowest = nil,
 tank = nil,
 natures_swiftness_active = false,
 has_water_shield = false,
 has_lightning_shield = false,
 water_shield_ready = false,
 lightning_shield_ready = false,
 earth_shield_ready = false,
 earth_shield_charges = 0,
 earth_shield_remains = 0,
 water_shield_charges = 0,
 chain_heal_ready = false,
 healing_wave_ready = false,
 lesser_healing_wave_ready = false,
 mana_tide_ready = false,
 bloodlust_ready = false,
 natures_swiftness_ready = false,
 earth_shock_ready = false,
 flame_shock_ready = false,
 lightning_bolt_ready = false,
 chain_lightning_ready = false,
 purge_ready = false,
 cure_poison_ready = false,
 cure_disease_ready = false,
 mana_pct = 100,
 hp_pct = 100,
 mana_low = false,
 mana_conserve = false,
 mana_emergency = false,
 in_combat = false,
 enemy_count = 1,
 target_casting = false,
 flame_shock_remains = 0,
 healing_way_stacks = 0,
 healing_way_remains = 0,
 chain_heal_target_count = 0,
 tremor_totem_ready = false,
 grounding_totem_ready = false,
 poison_cleansing_totem_ready = false,
 disease_cleansing_totem_ready = false,
 cleanse_target = nil,
 lowest_hp_pct = 100,
 lowest_time_to_die = 999,
 triage_ranked = nil,
 chain_heal_optimal_target = nil,
 chain_heal_cluster_count = 0,
 friendly_target = nil,
 friendly_target_ready = false,
 healthstone_ready = 0,
}

local function build_state(context)
 local me = context.me or NS.GetPlayer()
 if not me then return spec_kit.safe_state(resto_state, RESTO_SCHEMA) end
 -- Mounted bail: healer should not queue buffs/heals while mounted
 if me.is_mounted and me:is_mounted() then
  return spec_kit.safe_state(resto_state, RESTO_SCHEMA)
 end
 local target = context.target
 local entries, count = Healing.scan_healing_targets()

 -- Triage ranking: sort entries by urgency (HP + TTD + role + debuffs)
 if NS.Triage and NS.Triage.rank then
  resto_state.triage_ranked = NS.Triage.rank(entries, count, context.settings)
 else
  resto_state.triage_ranked = nil
 end
 -- Use triage-ranked entries for lowest target if available
 if resto_state.triage_ranked and resto_state.triage_ranked[1] then
  resto_state.lowest = resto_state.triage_ranked[1]
 else
  resto_state.lowest = NS.healing_get_lowest_hp(entries, count, 92)
 end
 resto_state.tank = NS.healing_get_tank(entries, count) or resto_state.lowest

 -- AoE Heal cluster targeting: find optimal Chain Heal primary target
 if NS.AoEHeal and NS.AoEHeal.chain_heal_target then
  local ch_primary, ch_total, ch_bounces = NS.AoEHeal.chain_heal_target(entries, count, 12.5, 3)
  resto_state.chain_heal_optimal_target = ch_primary
  resto_state.chain_heal_cluster_count = ch_bounces and #ch_bounces or 0
 elseif TSHelper and TSHelper.get_heal_targets then
  -- target_selector direct query: lowest-HP heal target as Chain Heal anchor
  local ts_targets = TSHelper.get_heal_targets(3)
  if type(ts_targets) == "table" and #ts_targets > 0 then
   local best = nil
   local best_hp = 999
   for _, unit in ipairs(ts_targets) do
    if unit then
     local ok_hp, hp = pcall(function() return unit:get_health_percentage() end)
     if ok_hp and hp and hp < best_hp then
      best_hp = hp
      best = unit
     end
    end
   end
   if best then
    resto_state.chain_heal_optimal_target = { unit = best, effective_hp = best_hp, hp = best_hp }
    resto_state.chain_heal_cluster_count = #ts_targets
   end
  end
 else
  resto_state.chain_heal_optimal_target = nil
  resto_state.chain_heal_cluster_count = 0
 end
 -- Apply explicit TBC AoE cap via shared (Phase 2 closure)
 if NS.Targeting and NS.Targeting.get_aoe_targets_with_cap then
  local _capped, ccount = NS.Targeting.get_aoe_targets_with_cap(entries or {}, 25423, 3)
  if ccount and ccount > 0 then
   resto_state.chain_heal_cluster_count = math.min(resto_state.chain_heal_cluster_count or 0, ccount)
  end
 end
 resto_state.natures_swiftness_active = _ns_is_active()
 resto_state.has_water_shield = me and NS.buff_up and NS.buff_up(me, WATER_SHIELD_BUFF) or false
 resto_state.has_lightning_shield = me and NS.buff_up and NS.buff_up(me, LIGHTNING_SHIELD_BUFF) or false
 resto_state.water_shield_ready = me and NS.spell_ready(ACTION.WaterShield, me, { skip_range = true }) or false
 resto_state.lightning_shield_ready = me and NS.spell_ready(ACTION.LightningShield, me, { skip_range = true }) or false
 resto_state.earth_shield_ready = me and NS.spell_ready(ACTION.EarthShield, me, { skip_range = true }) or false
 -- Earth Shield charge/remains tracking (for tank)
 local es_target = resto_state.tank and resto_state.tank.unit
 if es_target then
  resto_state.earth_shield_charges = NS.buff_stacks and NS.buff_stacks(es_target, EARTH_SHIELD_BUFF) or 0
  resto_state.earth_shield_remains = NS.buff_remains and NS.buff_remains(es_target, EARTH_SHIELD_BUFF) or 0
 else
  resto_state.earth_shield_charges = 0
  resto_state.earth_shield_remains = 0
 end
 -- Water Shield charge tracking (self)
 resto_state.water_shield_charges = (me and NS.buff_stacks and NS.buff_stacks(me, WATER_SHIELD_BUFF)) or 0
 resto_state.chain_heal_ready = me and NS.spell_ready(ACTION.ChainHeal, me, { skip_range = true }) or false
 resto_state.healing_wave_ready = me and NS.spell_ready(ACTION.HealingWave, me, { skip_range = true }) or false
 resto_state.lesser_healing_wave_ready = me and NS.spell_ready(ACTION.LesserHealingWave, me, { skip_range = true }) or false
 resto_state.mana_tide_ready = me and NS.spell_ready(ACTION.ManaTideTotem, me, { skip_range = true }) or false
 resto_state.bloodlust_ready = me and NS.spell_ready(ACTION.Bloodlust, me, { skip_range = true }) or false
 resto_state.natures_swiftness_ready = me and NS.spell_ready(ACTION.NaturesSwiftness, me, { skip_range = true }) or false
 resto_state.earth_shock_ready = me and NS.spell_ready(ACTION.EarthShock, me, { expected_cooldown = 6 }) or false
 resto_state.flame_shock_ready = me and NS.spell_ready(ACTION.FlameShock, me, { expected_cooldown = 6 }) or false
 resto_state.lightning_bolt_ready = me and NS.spell_ready(ACTION.LightningBolt, me, { expected_cooldown = 2.5 }) or false
 resto_state.chain_lightning_ready = me and NS.spell_ready(ACTION.ChainLightning, me, { expected_cooldown = 6 }) or false
 resto_state.purge_ready = target and NS.spell_ready(ACTION.Purge, target) or false
 resto_state.cure_poison_ready = me and ACTION.CurePoison and NS.spell_ready(ACTION.CurePoison, me, { skip_range = true }) or false
 resto_state.cure_disease_ready = me and ACTION.CureDisease and NS.spell_ready(ACTION.CureDisease, me, { skip_range = true }) or false
 resto_state.is_group = context.is_group or false
 resto_state.mana_pct = context.mana_pct or (me and NS.unit_mana_pct(me)) or 100
 resto_state.hp_pct = context.hp or (me and NS.unit_health_pct(me)) or 100
 -- Mana conservation tiers (configurable via schema)
 local mana_low_pct = spec_kit.setting_number(context, "restoration_mana_low_pct", MANA_LOW_DEFAULT)
 local mana_conserve_pct = spec_kit.setting_number(context, "restoration_mana_conserve_pct", MANA_CONSERVE_DEFAULT)
 local mana_emergency_pct = spec_kit.setting_number(context, "restoration_mana_emergency_pct", MANA_EMERGENCY_DEFAULT)
 resto_state.mana_low = resto_state.mana_pct < mana_low_pct
 resto_state.mana_conserve = resto_state.mana_pct < mana_conserve_pct
 resto_state.mana_emergency = resto_state.mana_pct < mana_emergency_pct
 resto_state.in_combat = context.in_combat or false
 resto_state.enemy_count = context.enemy_count or context.enemies_count or 1
 resto_state.target_casting = target and target.is_casting and target:is_casting() or false
 resto_state.flame_shock_remains = target and NS.debuff_remains and NS.debuff_remains(target, FLAME_SHOCK_DEBUFF) or 0
 local hw_target = resto_state.tank and resto_state.tank.unit
 resto_state.healing_way_stacks = hw_target and NS.buff_stacks and NS.buff_stacks(hw_target, HEALING_WAY_BUFF) or 0
 resto_state.healing_way_remains = hw_target and NS.buff_remains and NS.buff_remains(hw_target, HEALING_WAY_BUFF) or 0
 -- Use AoE cluster count if available, fall back to HP-based count
 local cluster_count = resto_state.chain_heal_cluster_count or 0
 local hp_count = Healing.count_below_hp and Healing.count_below_hp(80) or 1
 resto_state.chain_heal_target_count = math.max(cluster_count, hp_count)
 resto_state.tremor_totem_ready = me and NS.spell_ready(ACTION.TremorTotem, me, { skip_range = true }) or false
 resto_state.grounding_totem_ready = me and NS.spell_ready(ACTION.GroundingTotem, me, { skip_range = true }) or false
 resto_state.poison_cleansing_totem_ready = me and ACTION.PoisonCleansingTotem and NS.spell_ready(ACTION.PoisonCleansingTotem, me, { skip_range = true }) or false
 resto_state.disease_cleansing_totem_ready = me and ACTION.DiseaseCleansingTotem and NS.spell_ready(ACTION.DiseaseCleansingTotem, me, { skip_range = true }) or false
 -- Track lowest ally HP + estimated time-to-die for NS emergency gating
 if resto_state.lowest then
  resto_state.lowest_hp_pct = resto_state.lowest.effective_hp or 100
  resto_state.lowest_time_to_die = resto_state.lowest.time_to_die or 999
 else
  resto_state.lowest_hp_pct = 100
  resto_state.lowest_time_to_die = 999
 end
 -- Resolve cleanse target for dispel strategies (cached per frame)
 resto_state.cleanse_target = Healing.get_cleanse_target and Healing.get_cleanse_target() or nil
 local ft = NS.get_friendly_target_entry and NS.get_friendly_target_entry(context)
 resto_state.friendly_target = ft
 resto_state.friendly_target_ready = ft ~= nil

  -- parity: Smart Stop-Cast — cancel overhealing casts mid-flight
  if NS.StopCast and type(NS.StopCast.update) == "function" then
   NS.StopCast.update(me, context.settings)
  end
  resto_state.healthstone_ready = first_ready_item(HEALTHSTONE_IDS) or 0

  -- FSR (Five-Second Rule) tracking for mana efficiency
  if FsrManager then
   resto_state.fsr_inside = FsrManager.is_inside_fsr()
   resto_state.fsr_seconds = FsrManager.seconds_until_fsr()
   resto_state.fsr_regen_delta = FsrManager.get_regen_delta()
  else
   resto_state.fsr_inside = false
   resto_state.fsr_seconds = 0
   resto_state.fsr_regen_delta = 0
  end

  return spec_kit.safe_state(resto_state, RESTO_SCHEMA)
end

local function cooldowns_enabled(context)
 return spec_kit.setting_bool(context, "use_cooldowns", true)
end


-- ============================================================================
-- Match functions
-- ============================================================================
local function water_shield_matches(context, state)
    local shield_type = spec_kit.setting(context, "restoration_shield_type", "water")
    if shield_type ~= "water" then return false end
 -- Water Shield costs 0 mana and returns mana — allow even during conserve
 -- Only block during mana emergency (ManaEmergencyWand catches it first)
 if state.mana_emergency then return false end
 if not state.water_shield_ready then return false end
 -- Refresh if Water Shield is missing
 if not state.has_water_shield then
  return true
 end
 -- Refresh if Water Shield charges are depleted (0 charges remaining)
 if (state.water_shield_charges or 0) <= 0 then
  return true
 end
 return false
end

local function lightning_shield_matches(context, state)
 local shield_type = spec_kit.setting(context, "restoration_shield_type", "water")
 -- Default is "water" (level 62+). Below that, fall back to Lightning Shield (level 8)
 -- so low-level resto shamans are not left unshielded.
 if shield_type == "water" then
  if state.water_shield_ready or state.has_water_shield then return false end
 elseif shield_type ~= "lightning" then
  return false
 end
 if state.has_lightning_shield then return false end
 if not state.lightning_shield_ready then return false end
 if (state.enemy_count or 0) < 1 then return false end
 return true
end

local function earth_shield_tank_matches(context, state)
 if state.mana_emergency then return false end
 if not state.tank then return false end
 local target = state.tank.unit or NS.PLAYER_UNIT
 if not target then return false end
 if not state.earth_shield_ready then return false end
 -- Refresh when charges are low (configurable threshold, default ≤ 2)    local charge_threshold = spec_kit.setting_number(context, "restoration_earth_shield_charge_threshold", EARTH_SHIELD_CHARGE_DEFAULT)
 if NS.buff_up(target, EARTH_SHIELD_BUFF) then
  if (state.earth_shield_charges or 0) > charge_threshold then return false end
  -- Earth Shield is expiring soon and charges are low
  if (state.earth_shield_remains or 0) > 5 and (state.earth_shield_charges or 0) >= 1 then return false end
 end
 return true
end

local function natures_swiftness_matches(context, state)
 if state.mana_emergency then return false end
 if not state.lowest then return false end
 if (state.lowest.effective_hp or 100) > 30 then return false end
 if NS.buff_up and NS.buff_up(NS.PLAYER_UNIT, NATURES_SWIFTNESS_BUFF) then return false end
 local me = context.me or NS.GetPlayer()
 if not me or not NS.spell_ready(ACTION.NaturesSwiftness, me, { skip_range = true }) then return false end
 if (state.lowest_time_to_die or 999) > 3 then return false end
 return true
end


local function bloodlust_matches(context, state)
 if not cooldowns_enabled(context) then return false end
 if not state.in_combat then return false end
 -- Fire when group is healthy OR during PvP burst-heal window
 local group_healthy = Healing.all_members_above_hp and Healing.all_members_above_hp(85)
 if not group_healthy then
  if NS.PvPBurstWindow and context.is_pvp then
   local ok, should = pcall(NS.PvPBurstWindow.should_burst, NS.PvPBurstWindow, context)
   if not (ok and should) then return false end
  else
   return false
  end
 end
 local me = context.me or NS.GetPlayer()
 if not me or not NS.spell_ready(ACTION.Bloodlust, me, { skip_range = true }) then return false end
 return true
end

local function smart_heal_matches(context, state)
 if not state.lowest then return false end
 local lowest = state.lowest
 local current_hp = lowest.effective_hp or lowest.hp or 100
 local pred_hp = current_hp
 if lowest.unit and HealthPred and HealthPred.predicted_hp_pct then
  local ok, pct = pcall(HealthPred.predicted_hp_pct, lowest.unit, 2.5)
  if ok and type(pct) == "number" then pred_hp = pct end
 end
 if pred_hp < current_hp then
  local max_hp = lowest.max_hp or 10000
  local predicted_deficit = math.floor((100 - pred_hp) / 100 * max_hp)
  lowest = {
   unit = lowest.unit,
   effective_hp = pred_hp,
   hp = pred_hp,
   max_hp = max_hp,
   deficit = math.max(predicted_deficit, lowest.deficit or 0),
   effective_deficit = math.max(predicted_deficit, lowest.effective_deficit or 0),
  }
 end
 local heal = Healing.select_heal(context, state, lowest)
 context._shaman_heal = heal
 return heal and heal.spell and NS.spell_ready(heal.spell, lowest.unit)
end

local function solo_damage_enabled(context, state, mana_floor)
 if not context.has_valid_enemy_target then return false end
 if not (context.is_solo == true or context.is_leveling == true or spec_kit.setting_bool(context, "restoration_dps_when_idle", false)) then return false end
 if state.lowest and (state.lowest.effective_hp or 100) < spec_kit.setting_number(context, "restoration_idle_hp", 88) then return false end
 if (state.mana_pct or context.mana_pct or 100) < (mana_floor or spec_kit.setting_number(context, "restoration_dps_mana_floor", 35)) then return false end
 return true
end

local function earth_shock_matches(context, state)
 if not state.earth_shock_ready then return false end
 if not state.target_casting then return false end
 if state.mana_emergency then return false end
 -- Range check: Earth Shock is 20yd; validate target is in range
 local target = context.target
 if target and NS.unit_distance then
  local dist_sq = NS.unit_distance(context.me, target)
  if dist_sq and dist_sq > 400 then return false end -- 20yd squared = 400
 end
 return true
end

local function flame_shock_matches(context, state)
 if not state.flame_shock_ready then return false end
 if (state.flame_shock_remains or 0) > 3 then return false end
 if state.mana_conserve then return false end
 if not solo_damage_enabled(context, state, 30) then return false end
 return true
end

local function lightning_bolt_matches(context, state)
 if not state.lightning_bolt_ready then return false end
 if context.is_moving then return false end
 if (state.enemy_count or 0) < 1 then return false end
 if state.mana_emergency then return false end
 if not solo_damage_enabled(context, state, 35) then return false end
 return true
end

local function chain_lightning_matches(context, state)
 if not state.chain_lightning_ready then return false end
 if context.is_moving then return false end
 if (state.enemy_count or 0) < 3 then return false end
 if state.mana_conserve or state.mana_emergency then return false end
 if not solo_damage_enabled(context, state, 45) then return false end
 return true
end


-- ============================================================================
-- Cleanse target helper (used by DSL_DEFS for CurePoison / CureDisease)
-- ============================================================================

local function _get_cleanse_target(state)
 return state and state.cleanse_target
end


local function poison_cleansing_totem_matches(context, state)
 if not state.poison_cleansing_totem_ready then return false end
 if state.mana_emergency then return false end
 local dispel_target = _get_cleanse_target(state)
 if not dispel_target then return false end
 if not dispel_target.has_poison then return false end
 return true
end

local function disease_cleansing_totem_matches(context, state)
 if not state.disease_cleansing_totem_ready then return false end
 if state.mana_emergency then return false end
 local dispel_target = _get_cleanse_target(state)
 if not dispel_target then return false end
 if not dispel_target.has_disease then return false end
 return true
end

local function totem_strength_matches(context, state)
 if not spec_kit.setting_bool(context, "restoration_manage_totems", true) then return false end
 if _totem_ready(ACTION.StrengthOfEarthTotem) then
  return true
 end
 return false
end

local function totem_mana_spring_matches(context, state)
 if not spec_kit.setting_bool(context, "restoration_manage_totems", true) then return false end
 if _totem_ready(ACTION.ManaSpringTotem) then
  return true
 end
 return false
end

local function totem_grace_air_matches(context, state)
 if not spec_kit.setting_bool(context, "restoration_manage_totems", true) then return false end
 if _totem_ready(ACTION.GraceOfAirTotem) then
  return true
 end
 return false
end

local function totem_windfury_matches(context, state)
 if not spec_kit.setting_bool(context, "restoration_manage_totems", true) then return false end
 if _totem_ready(ACTION.WindfuryTotem) then
  return true
 end
 return false
end

-- ============================================================================
-- Healing Way tracking: cast Healing Wave on tank to maintain stacks
-- ============================================================================
local function healing_way_matches(context, state)
 if not state.tank then return false end
 if (state.healing_way_stacks or 0) >= 3 then return false end
 if (state.healing_way_remains or 0) > 8 then return false end
 if not state.healing_wave_ready then return false end
 if not NS.spell_ready(ACTION.HealingWave, state.tank.unit, { skip_range = true }) then return false end
  -- Predictive overheal gate: don't cast a full Healing Wave just to maintain stacks
  -- if the tank doesn't actually need the healing
  local mana_pct = state.mana_pct or context.mana_pct or 100
  local spell_id = choose_healing_wave(mana_pct)
  if gate_overheal("HealingWave", state.tank.unit, 2.5, context.settings, spell_id) then return false end
 return true
end

 local function healing_way_execute(context, state)
 if not state.tank then return false end
 local mana_pct = state.mana_pct or context.mana_pct or 100
 local spell_id = choose_healing_wave(mana_pct)
 local adjusted, penalty = PreemptiveHeal.get_penalty_adjusted_heal(spell_id, 2500)
 local rank_label = (mana_pct > 30) and "12" or ((mana_pct > 15) and "11" or "10")
 return NS.try_cast(spell_id, state.tank.unit, string.format("[RESTO] HealingWay (stack %d/3) rank %s (penalty %.0f%%)", state.healing_way_stacks, rank_label, (penalty or 1) * 100))
end

-- ============================================================================
-- Standalone Chain Heal: AoE cluster targeting + Triage
-- ============================================================================
local function chain_heal_matches(context, state)
 if not state.chain_heal_ready then return false end
 -- Use AoE cluster target if available, otherwise fall back to lowest
 local ch_target = state.chain_heal_optimal_target
 if ch_target and ch_target.unit then
  -- AoEHeal found a cluster; use cluster count for gate
  if (state.chain_heal_cluster_count or 0) < 2 then return false end
  if (ch_target.effective_hp or 100) > spec_kit.setting_number(context, "restoration_chain_heal_hp", 65) then return false end
   if gate_overheal("ChainHeal", ch_target.unit, 2.5, context.settings, ACTION.ChainHeal:id()) then return false end
  return true
 end
 -- Fallback: naive lowest-HP targeting
 if not state.lowest or not state.lowest.unit then return false end
 if (state.chain_heal_target_count or 0) < 2 then return false end  if (state.lowest.effective_hp or 100) > spec_kit.setting_number(context, "restoration_chain_heal_hp", 65) then return false end
  if gate_overheal("ChainHeal", state.lowest.unit, 2.5, context.settings, ACTION.ChainHeal:id()) then return false end
 return true
end

local function chain_heal_execute(context, state)
 -- Prefer AoE cluster target over naive lowest
 local ch_target = state.chain_heal_optimal_target
 if ch_target and ch_target.unit then
  local mana = context.mana_pct or 100
  local spell = ACTION.ChainHeal
  local label = string.format("[RESTO] ChainHeal %.0f%% (cluster %d)", ch_target.effective_hp or 0, state.chain_heal_cluster_count)
  if mana < 25 then
   spell = CHAIN_HEAL_EFFICIENT
   label = string.format("[RESTO] Downrank ChainHeal (efficient) %.0f%% (cluster %d)", ch_target.effective_hp or 0, state.chain_heal_cluster_count)
  elseif mana < 45 then
   spell = CHAIN_HEAL_CONSERVE
   label = string.format("[RESTO] Downrank ChainHeal (conserve) %.0f%% (cluster %d)", ch_target.effective_hp or 0, state.chain_heal_cluster_count)
  end
  return NS.try_cast(spell, ch_target.unit, label)
 end
 if not state.lowest or not state.lowest.unit then return false end
 local target = state.lowest.unit or NS.PLAYER_UNIT
  local mana = context.mana_pct or 100
  local spell = ACTION.ChainHeal
  local label = string.format("[RESTO] ChainHeal %.0f%% (%d targets)", state.lowest.effective_hp or 0, state.chain_heal_target_count)
  if mana < 25 then
   spell = CHAIN_HEAL_EFFICIENT
   label = string.format("[RESTO] Downrank ChainHeal (efficient) %.0f%% (%d targets)", state.lowest.effective_hp or 0, state.chain_heal_target_count)
  elseif mana < 45 then
   spell = CHAIN_HEAL_CONSERVE
   label = string.format("[RESTO] Downrank ChainHeal (conserve) %.0f%% (%d targets)", state.lowest.effective_hp or 0, state.chain_heal_target_count)
  end
  return NS.try_cast(spell, target, label)
end

-- ============================================================================
-- Strategies
-- ============================================================================
local healing_strategies = {
 -- FriendlyTarget (Step 0): honor the player's manually-selected friendly target.
 -- TOP priority: works in and out of combat. Threshold-gated so full-health
 -- targets are ignored. State is populated in build_state().
 { name = "FriendlyTarget", matches = function(context, state)
  if not state.friendly_target_ready then return false end
  local ft = state.friendly_target
  if not ft then return false end
  if (ft.hp_pct or 100) >= spec_kit.setting_number(context, "restoration_friendly_target_threshold", 90) then return false end
  if context.is_moving then return false end
  if context.player_control_locked then return false end
  if not state.healing_wave_ready then return false end
   if not (NS.spell_ready and NS.spell_ready(ACTION.HealingWave, ft.unit, { skip_range = true })) then return false end
   local mana_pct = state.mana_pct or context.mana_pct or 100
   local spell_id = choose_healing_wave(mana_pct)
   if gate_overheal and gate_overheal("HealingWave", ft.unit, 2.5, context.settings, spell_id) then return false end
  return true
  end, execute = function(context, state)
   local ft = state.friendly_target
   if not ft or not ft.unit then return false end
   local mana_pct = state.mana_pct or context.mana_pct or 100
   local spell_id = choose_healing_wave(mana_pct)
   local adjusted, penalty = PreemptiveHeal.get_penalty_adjusted_heal(spell_id, 2500)
   local rank_label = (mana_pct > 30) and "12" or ((mana_pct > 15) and "11" or "10")
   return NS.try_cast(spell_id, ft.unit, string.format("[RESTO] Healing Wave (friendly target) %.0f%% rank %s (penalty %.0f%%)", ft.hp_pct or 100, rank_label, (penalty or 1) * 100))
  end },
 { name = "ManaPotion",
  matches = function(context)
   if not context.in_combat then return false end
   if not spec_kit.setting_bool(context, "use_auto_potions", true) then return false end
   if not context.has_mana_potion then return false end
   if (context.mana_pct or 100) > 20 then return false end
   return true
  end,
  execute = function(context) return potion_helper.try_use_potion(context, potion_helper.MANA_POTION_IDS) end },
  { name = "Healthstone",
    matches = function(ctx, state)
      if not ctx.in_combat then return false end
      if (state.hp_pct or 100) > 28 then return false end
      if (state.healthstone_ready or 0) <= 0 then return false end
      return true
    end,
    execute = function(ctx)
      local id = first_ready_item(HEALTHSTONE_IDS)
      if id then NS.use_item_by_id(id, ctx.me) end
    end },
 -- Mana emergency: auto-attack only, all spells forbidden (Research: Mana < 5%)
 { name = "ManaEmergencyWand",
  matches = function(context, state)
   if not state.in_combat then return false end
   if not state.mana_emergency then return false end
   return true
  end,
  execute = function(context, state)
   local target = context.target
   if target and NS.start_attack then
    NS.start_attack()
   end
   return true -- Claim priority, block all other strategies
  end
 },
 { name = "WaterShield", matches = water_shield_matches, execute = function() return NS.try_cast(WATER_SHIELD_SPELL, NS.PLAYER_UNIT, "[RESTO] WaterShield") end },
 { name = "LightningShield", matches = lightning_shield_matches, execute = function() return NS.try_cast(LIGHTNING_SHIELD_SPELL, NS.PLAYER_UNIT, "[RESTO] LightningShield") end },
 { name = "EarthShieldTank", matches = earth_shield_tank_matches, execute = function(context, state)
  local tank = state and state.tank
  local tank_unit = tank and tank.unit
  if tank_unit then
   return NS.try_cast(ACTION.EarthShield, tank_unit, "[RESTO] EarthShieldTank")
  end
  return NS.try_cast(ACTION.EarthShield, NS.PLAYER_UNIT, "[RESTO] EarthShieldSelf")
 end },
 { name = "NaturesSwiftness", matches = natures_swiftness_matches, execute = function()
  return NS.try_cast(ACTION.NaturesSwiftness, NS.PLAYER_UNIT, "[RESTO] NaturesSwiftness")
 end },
 { name = "ManaTideTotem" },  -- DSL-substituted at runtime
 { name = "Bloodlust", matches = bloodlust_matches, execute = function()
  return NS.try_cast(ACTION.Bloodlust, NS.PLAYER_UNIT, "[RESTO] Bloodlust", { expected_cooldown = 600 })
 end },
 -- FriendlyTarget (B6): honor the player's manually-selected friendly target.

 { name = "HealingWay", matches = healing_way_matches, execute = healing_way_execute },
 { name = "PreemptiveChainHeal", matches = function(context, state)
  if not state.in_combat then return false end
  if context.is_moving then return false end
  if not state.chain_heal_ready then return false end
  local threshold = spec_kit.setting_number(context, "restoration_preemptive_threshold", PreemptiveHeal.DEFAULT_THRESHOLD)
  if not PreemptiveHeal.match(context, state, threshold, 2.5) then return false end
  return true
 end, execute = function(context, state)
  local target_entry = state._preemptive_target
  if not target_entry or not target_entry.unit then return false end
  return PreemptiveHeal.execute(context, state, ACTION.ChainHeal, string.format("[RESTO] Preemptive CH %.0f%%", target_entry.effective_hp or 0), { cast_time = 2.5, heal_size = 1800 })
 end },
  { name = "FSRPause",
   matches = function(context, state)
    if not FsrManager then return false end
    if not state.in_combat then return false end
    if not state.fsr_inside or (state.fsr_regen_delta or 0) <= 0 then return false end
    return FsrManager.should_pause_for_fsr(state, context)
   end,
    execute = function(_, state)
     return true
    end },
  { name = "ChainHeal", matches = chain_heal_matches, execute = chain_heal_execute },
  { name = "SmartHeal", matches = smart_heal_matches, execute = function(context, state)
  local heal = (context._shaman_heal or false) or Healing.select_heal(context, state, state.lowest)
  if not heal or not heal.spell then return false end
  if not state.lowest or not state.lowest.unit then return false end
  return NS.try_cast(heal.spell, state.lowest.unit, string.format("[RESTO] %s %.0f%%", heal.label, state.lowest.effective_hp or 0))
 end },
 { name = "Purge" },  -- DSL-substituted at runtime
 { name = "TremorTotem" },  -- DSL-substituted at runtime
 { name = "GroundingTotem" },  -- DSL-substituted at runtime
 { name = "StrengthOfEarthTotem", matches = totem_strength_matches, execute = function() return NS.try_cast(ACTION.StrengthOfEarthTotem, NS.PLAYER_UNIT, "[RESTO] StrengthOfEarthTotem") end },
 { name = "ManaSpringTotem", matches = totem_mana_spring_matches, execute = function() return NS.try_cast(ACTION.ManaSpringTotem, NS.PLAYER_UNIT, "[RESTO] ManaSpringTotem") end },
 { name = "GraceOfAirTotem", matches = totem_grace_air_matches, execute = function() return NS.try_cast(ACTION.GraceOfAirTotem, NS.PLAYER_UNIT, "[RESTO] GraceOfAirTotem") end },
 { name = "WindfuryTotem", matches = totem_windfury_matches, execute = function() return NS.try_cast(ACTION.WindfuryTotem, NS.PLAYER_UNIT, "[RESTO] WindfuryTotem") end },
 { name = "CurePoison" },  -- DSL-substituted at runtime
 { name = "CureDisease" },  -- DSL-substituted at runtime
 { name = "PoisonCleansingTotem", matches = poison_cleansing_totem_matches, execute = function() return NS.try_cast(ACTION.PoisonCleansingTotem, NS.PLAYER_UNIT, "[RESTO] PoisonCleansingTotem") end },
 { name = "DiseaseCleansingTotem", matches = disease_cleansing_totem_matches, execute = function() return NS.try_cast(ACTION.DiseaseCleansingTotem, NS.PLAYER_UNIT, "[RESTO] DiseaseCleansingTotem") end },
}

local idle_dps_strategies = {
 { name = "EarthShock", matches = earth_shock_matches, execute = function(context) return NS.try_cast(ACTION.EarthShock, context.target, "[RESTO] EarthShock", { expected_cooldown = 6 }) end },
 { name = "FlameShock", matches = flame_shock_matches, execute = function(context) return NS.try_cast(ACTION.FlameShock, context.target, "[RESTO] FlameShock", { expected_cooldown = 6 }) end },
 { name = "ChainLightning", matches = chain_lightning_matches, execute = function(context) return NS.try_cast(ACTION.ChainLightning, context.target, "[RESTO] ChainLightning", { expected_cooldown = 6 }) end },
 { name = "LightningBolt", matches = lightning_bolt_matches, execute = function(context) return NS.try_cast(ACTION.LightningBolt, context.target, "[RESTO] LightningBolt", { expected_cooldown = 2.5 }) end },
}

-- Merge idle DPS strategies into healing_strategies so they fire in the live rotation.
-- Earth Shock doubles as an interrupt (target casting check in earth_shock_matches).
for _, strategy in ipairs(idle_dps_strategies) do
 healing_strategies[#healing_strategies + 1] = strategy
end

-- ============================================================================
-- Declarative Strategy DSL definitions (sixth DSL adopter, first healer)
-- ============================================================================
-- These strategies are compiled from declarative definitions and replace the
-- imperative match functions in the strategies table above for the same names.
-- This proves the DSL generalizes beyond DPS/tank specs to healer mechanics:
-- dispel management (cleanse target + debuff checks), totem auto-management
-- (fear/CC/caster drops), PvP purge conditionals, and mana-conservation CD gating.
local DSL_DEFS = {
    {
        name = "ManaTideTotem",
        conditions = {
            { type = "setting", key = "use_cooldowns", default = true },
            { type = "in_combat" },
            { type = "custom", fn = function(context, state)
                local threshold = spec_kit.setting_number(context, "restoration_mana_tide_pct", 60)
                if (state.mana_pct or 100) > threshold then return false end
                return true
            end },
            { type = "custom", fn = function(context, state)
                if Healing.group_mana_avg then
                    local threshold = spec_kit.setting_number(context, "restoration_mana_tide_pct", 60)
                    local group_mana = Healing.group_mana_avg()
                    if group_mana and group_mana > threshold then return false end
                end
                return true
            end },
            { type = "custom", fn = function(context, state)
                if Healing.all_members_above_hp and not Healing.all_members_above_hp(80) then return false end
                return true
            end },
            { type = "custom", fn = function(context, state)
                local me = context.me or NS.GetPlayer()
                if not me or not NS.spell_ready(ACTION.ManaTideTotem, me, { skip_range = true }) then return false end
                return true
            end },
        },
        action = { type = "custom", fn = function()
            return NS.try_cast(ACTION.ManaTideTotem, NS.PLAYER_UNIT, "[RESTO] ManaTideTotem", { expected_cooldown = 300 })
        end },
    },
    {
        name = "Purge",
        conditions = {
            { type = "state", field = "purge_ready", op = "truthy" },
            { type = "custom", fn = function(context, state)
                if not context.target then return false end
                return true
            end },
            { type = "custom", fn = function(context, state)
                if not (context.is_pvp == true or context.purge_target == true) then return false end
                return true
            end },
        },
        action = { type = "custom", fn = function(context, state)
            return NS.try_cast(ACTION.Purge, context.target, "[RESTO] Purge")
        end },
    },
    {
        name = "TremorTotem",
        conditions = {
            { type = "state", field = "tremor_totem_ready", op = "truthy" },
            { type = "in_combat" },
            { type = "custom", fn = function(context, state)
                if not (context.fear_nearby or context.known_fear_boss or context.fear_on_tank or context.control_nearby or context.control_risk or false) then return false end
                return true
            end },
        },
        action = { type = "custom", fn = function()
            return NS.try_cast(ACTION.TremorTotem, NS.PLAYER_UNIT, "[RESTO] TremorTotem")
        end },
    },
    {
        name = "GroundingTotem",
        conditions = {
            { type = "state", field = "grounding_totem_ready", op = "truthy" },
            { type = "in_combat" },
            { type = "enemy_count", op = ">=", value = 1 },
            { type = "custom", fn = function(context, state)
                if not (context.is_pvp == true or context.target_casting == true) then return false end
                return true
            end },
        },
        action = { type = "custom", fn = function()
            return NS.try_cast(ACTION.GroundingTotem, NS.PLAYER_UNIT, "[RESTO] GroundingTotem")
        end },
    },
    {
        name = "CurePoison",
        conditions = {
            { type = "state", field = "cure_poison_ready", op = "truthy" },
            { type = "custom", fn = function(context, state)
                return true
            end },
            { type = "state", field = "mana_emergency", op = "falsy" },
            { type = "custom", fn = function(context, state)
                local dt = _get_cleanse_target(state)
                if not dt then return false end
                if not dt.has_poison then return false end
                return true
            end },
            { type = "custom", fn = function(context, state)
                if state.lowest and (state.lowest.effective_hp or 100) < 25 then return false end
                return true
            end },
        },
        action = { type = "custom", fn = function(context, state)
            local ct = state and state.cleanse_target
            local target = ct and ct.unit or NS.PLAYER_UNIT
            return NS.try_cast(ACTION.CurePoison, target, "[RESTO] CurePoison")
        end },
    },
    {
        name = "CureDisease",
        conditions = {
            { type = "state", field = "cure_disease_ready", op = "truthy" },
            { type = "custom", fn = function(context, state)
                return true
            end },
            { type = "state", field = "mana_emergency", op = "falsy" },
            { type = "custom", fn = function(context, state)
                local dt = _get_cleanse_target(state)
                if not dt then return false end
                if not dt.has_disease then return false end
                return true
            end },
            { type = "custom", fn = function(context, state)
                if state.lowest and (state.lowest.effective_hp or 100) < 25 then return false end
                return true
            end },
        },
        action = { type = "custom", fn = function(context, state)
            local ct = state and state.cleanse_target
            local target = ct and ct.unit or NS.PLAYER_UNIT
            return NS.try_cast(ACTION.CureDisease, target, "[RESTO] CureDisease")
        end },
    },
}

-- Compile declarative strategies, injecting build_state so unit tests that call
-- strategy.matches(context) without state get a freshly-built state.
local DSL_STRATEGIES = dsl.compile_strategies(DSL_DEFS, { get_state = build_state })

-- ============================================================================
-- DSL in-place substitution (preserves priority order)
-- ============================================================================
local DSL_BY_NAME = {}
for i = 1, #DSL_STRATEGIES do
    DSL_BY_NAME[DSL_STRATEGIES[i].name] = DSL_STRATEGIES[i]
end

for i = 1, #healing_strategies do
    local dsl_strategy = DSL_BY_NAME[healing_strategies[i].name]
    if dsl_strategy then
        healing_strategies[i] = dsl_strategy
    end
end

if NS.rotation_registry and NS.rotation_registry.register then
    NS.rotation_registry:register("restoration", healing_strategies, { get_state = build_state })
end
if NS.log then NS.log("Shaman restoration rotation registered") end
return { strategies = healing_strategies, build_state = build_state }
