-- resto_sylvanas.lua -- Druid Restoration healing for TBC Anniversary (2.5.5).
-- WHAT: HoT-based healer (Lifebloom 3-stack rolling, Rejuvenation, Regrowth, Swiftmend).
-- WHEN: combat or pre-combat, with valid friendly targets.
-- WHY:   mirrors TBC resto druid consensus from wowsims (no APL), Icy Veins, Wowhead: Lifebloom 3-stack rolling + Swiftmend burst + Rejuv + Regrowth spot + downrank for mana.
-- SAFETY: Pattern 14 eliminated via spec_kit.safe_state(); FSRPause simplified delegate on state.in_combat/lowest_hp_pct/fsr_* (early hoist + schema); no manual nil-guards; no on_update() allocs.
local NS = _G.EaxRotations
if not NS then return nil end
local SPELLS = NS.DruidSpells or {}
local spec_kit = require("shared/spec_kit_sylvanas")
local potion_helper = require("shared/potion_helper_sylvanas")
local Healing = NS.DruidHealing or require("classes/druid/healing_sylvanas")
-- Preemptive heal module (Sonah-style predictive healing)
local PreemptiveHeal = require("shared/preemptive_heal_sylvanas")
local FsrManager = require("shared/fsr_manager_sylvanas")
local _data_ok, TBC = pcall(require, "shared/tbc_data_sylvanas")
if not _data_ok or type(TBC) ~= "table" then TBC = { ITEMS = { potions = {} } } end
local TBC_POTIONS = (TBC.ITEMS and TBC.ITEMS.potions) or {}

local PLAYER_UNIT = NS.PLAYER_UNIT
local STANCE_CASTER = 0
local STANCE_BEAR = 1
local STANCE_CAT = 3
local STANCE_TRAVEL = 4
local STANCE_TREE = 5

local LIFEBLOOM_BUFF = 33763
local REJUVENATION_BUFF = { 26982, 26981, 25299, 9841, 9840, 9839, 8910, 3627, 2091, 2090, 1430, 1058, 774 }
local REGROWTH_BUFF = { 26980, 9858, 9857, 9856, 9750, 8941, 8940, 8939, 8938, 8936 }
local NATURES_SWIFTNESS_BUFF = 17116
local TREE_OF_LIFE_BUFF = 33891
local NATURES_GRASP_BUFF = { 27009, 16813, 16812, 16811, 16810, 16689 }
local ABOLISH_POISON_BUFF = { 2893 }
local MOONFIRE_DEBUFF = { 26988, 26987, 9835, 9834, 9833, 8929, 8928, 8927, 8926, 8925, 8924, 8921 }
local INSECT_SWARM_DEBUFF = { 27013, 24977, 24976, 24975, 24974, 5570 }

local SWIFTMEND_EXPECTED_CD = 15
local NATURES_SWIFTNESS_EXPECTED_CD = 180
local INNERVATE_EXPECTED_CD = 360
local TRANQUILITY_EXPECTED_CD = 600
local BARKSKIN_EXPECTED_CD = 60
local REBIRTH_EXPECTED_CD = 1200
local LIFEBLOOM_REFRESH = 2.5
local LIFEBLOOM_BLOOM_SOON = 1.2
local REJUVENATION_REFRESH = 3.0
local REGROWTH_REFRESH = 4.0
local TREE_AURA_RANGE = 45
local MANA_LOW_FOR_BLOOM = 22
local MANA_CONSERVE_PCT = 30
local MANA_EMERGENCY_PCT = 15
local MANA_CRITICAL_PCT = 5
local HEALTHSTONE_IDS = { 22105, 22104, 22103, 19013, 19012, 19011, 5512 }
local function first_ready_item(item_ids)
    if not NS.is_item_ready then return 0 end
    for i = 1, #item_ids do
        local item_id = item_ids[i]
        if NS.is_item_ready(item_id) then return item_id end
    end
    return 0
end
local FULL_TARGET_HP = 96
local TANK_REJUV_HP = 92
local RAID_REJUV_HP = 88
local REGROWTH_SPOT_HP = 62
local HEALING_TOUCH_HP = 42
local DOWNRANK_HT_HP = 72
local DOWNRANK_REGROWTH_HP = 75

local HEALING_TOUCH_MAX = 26979
local HEALING_TOUCH_CONSERVE = 26978
local HEALING_TOUCH_EFFICIENT = 25297
local REGROWTH_MAX = 26980
local REGROWTH_CONSERVE = 9858
local REGROWTH_EFFICIENT = 9857
local CLEARCASTING_BUFF = 16870
local MOVING_HOT_HP = 90
local PVP_MELEE_RANGE = 8
local REPOSITION_RANGE = 28

-- Centralized spell resolver via spec_kit (rank IDs from class_sylvanas.lua).
local define = spec_kit.define_action_for_class(SPELLS)
local ACTION = {
    AbolishPoison     = define("AbolishPoison",     { 2893 }, "AbolishPoison"),
    Barkskin          = define("Barkskin",          { 22812 }, "Barkskin"),
    BearForm          = define("BearForm",          { 9634, 5487 }, "BearForm"),
    CatForm           = define("CatForm",           { 768 }, "CatForm"),
    Cyclone           = define("Cyclone",           { 33786 }, "Cyclone"),
    EntanglingRoots   = define("EntanglingRoots",   { 26989, 9853, 9852, 5196, 5195, 1062, 339 }, "EntanglingRoots"),
    HealingTouch      = define("HealingTouch",      { 26979, 26978, 25297, 9889, 9888, 9758, 8903, 6778, 5189, 5188, 5187, 5186, 5185 }, "HealingTouch"),
    HealingTouchRank4 = define("HealingTouchRank4", { 5189 }, "HealingTouchRank4"),
    InsectSwarm       = define("InsectSwarm",       { 27013, 24977, 24976, 24975, 24974, 5570 }, "InsectSwarm"),
    Innervate         = define("Innervate",         { 29166 }, "Innervate"),
    Lifebloom         = define("Lifebloom",         { 33763 }, "Lifebloom"),
    Moonfire          = define("Moonfire",          { 26988, 26987, 9835, 9834, 9833, 8929, 8928, 8927, 8926, 8925, 8924, 8921 }, "Moonfire"),
    NaturesGrasp      = define("NaturesGrasp",      { 27009, 17329, 16813, 16812, 16811, 16810, 16689 }, "NaturesGrasp"),
    NaturesSwiftness  = define("NaturesSwiftness",  { 17116 }, "NaturesSwiftness"),
    Rebirth           = define("Rebirth",           { 26994, 20484 }, "Rebirth"),
    Regrowth          = define("Regrowth",          { 26980, 9858, 9857, 9856, 9750, 8941, 8940, 8939, 8938, 8936 }, "Regrowth"),
    Rejuvenation      = define("Rejuvenation",      { 26982, 26981, 25299, 9841, 9840, 9839, 8910, 3627, 2091, 2090, 1430, 1058, 774 }, "Rejuvenation"),
    RemoveCurse       = define("RemoveCurse",       { 2782 }, "RemoveCurse"),
    Swiftmend         = define("Swiftmend",         { 18562 }, "Swiftmend"),
    Tranquility       = define("Tranquility",       { 26983, 9863, 9862, 8918, 740 }, "Tranquility"),
    TravelForm        = define("TravelForm",        { 783 }, "TravelForm"),
    TreeOfLifeForm    = define("TreeOfLifeForm",    { 33891 }, "TreeOfLifeForm"),
    Wrath             = define("Wrath",             { 26985, 26984, 9912, 8905, 6780, 5180, 5179, 5178, 5177, 5176 }, "Wrath"),
}

local HEALER_CLASS_IDS = { [2] = true, [5] = true, [7] = true, [11] = true }

local SKIP_RANGE = { skip_range = true }
local BARKSKIN_OPTS = { skip_range = true, expected_cooldown = BARKSKIN_EXPECTED_CD }
local SWIFTMEND_OPTS = { expected_cooldown = SWIFTMEND_EXPECTED_CD }
local NS_OPTS = { skip_range = true, expected_cooldown = NATURES_SWIFTNESS_EXPECTED_CD }
local INNERVATE_OPTS = { expected_cooldown = INNERVATE_EXPECTED_CD }
local TRANQUILITY_OPTS = { skip_range = true, expected_cooldown = TRANQUILITY_EXPECTED_CD }
local TREE_OPTS = { skip_range = true }

-- Schema for safe_state (Pattern 14 nil-guard elimination).
local RESTO_SCHEMA = {
    mana_pct = 100,
    hp_pct = 100,
    moonfire_remains = 0,
    insect_swarm_remains = 0,
    tranquility_count = 0,
    tree_aura_count = 0,
    melee_pressure_count = 0,
    has_natures_swiftness = false,
    has_clearcasting = false,
    in_tree = false,
    in_caster = false,
    can_tree = false,
    should_dance_caster = false,
    should_move_form = false,
    friendly_target_ready = false,
    mana_conserve = false,
    mana_emergency = false,
    mana_critical = false,
    is_group = false,
    in_combat = false,
    lowest_hp_pct = 100,

    -- FSR state (Five-Second Rule)
    fsr_inside = false, fsr_seconds = 0, fsr_regen_delta = 0,
}

local resto_state = {
 entries = nil,
 count = 0,
 tank = nil,
 lowest = nil,
 lowest_tank = nil,
 lowest_healer = nil,
 lowest_dps = nil,
 swiftmend_target = nil,
 ns_target = nil,
 ht_target = nil,
 regrowth_target = nil,
 rejuv_target = nil,
 lifebloom_tank = nil,
 lifebloom_raid = nil,
 lifebloom_raid2 = nil,
 lifebloom_refresh = nil,
 lifebloom_bloom = nil,
 innervate_target = nil,
 cursed_target = nil,
 poison_target = nil,
 tranquility_count = 0,
 tranquility_best_target = nil,
 tree_aura_count = 0,
 melee_pressure_count = 0,
 melee_target = nil,
 enemy_healer = nil,
 root_target = nil,
 has_natures_swiftness = false,
 in_tree = false,
 in_caster = false,
 can_tree = false,
 should_dance_caster = false,
 should_move_form = false,
 tree_dance_cooldown = 0,
 moonfire_remains = 0,
 insect_swarm_remains = 0,
 friendly_target = nil,
 friendly_target_ready = false,
 in_combat = false,
 lowest_hp_pct = 100,
}



local function has_hot_for_swiftmend(entry)
 if not entry or not entry.unit then return false end
 return entry.has_rejuvenation or entry.has_regrowth or NS.buff_up(entry.unit, REJUVENATION_BUFF) or NS.buff_up(entry.unit, REGROWTH_BUFF)
end

local function effective_hp(entry)
 return entry and (entry.effective_hp or entry.hp or 100) or 100
end

local function effective_deficit(entry)
 if not entry then return 0 end
 return entry.effective_deficit or entry.deficit or 0
end

local function predictive_overheal(spell_key, entry, cast_time, settings, emergency_hp)
 if not entry or not entry.unit then return false end
 if effective_hp(entry) <= (emergency_hp or 30) then return false end
 if (entry.time_to_die or 999) <= cast_time then return false end
 if NS.HealerDeficit and NS.HealerDeficit.gate_spell_overheal then
  return NS.HealerDeficit.gate_spell_overheal(spell_key, entry.unit, cast_time, settings)
 end
 return NS.gate_overheal and NS.gate_overheal(spell_key, entry.unit, cast_time, settings) or false
end

local function downrank_ht_overheal(entry, settings)
 if not entry or not entry.unit then return false end
 if effective_hp(entry) <= 35 then return false end
 if (entry.time_to_die or 999) <= 2.5 then return false end
 if NS.HealerDeficit and NS.HealerDeficit.heal_would_overheal then
  return NS.HealerDeficit.heal_would_overheal(entry.unit, 700, 2.5, settings)
 end
 return predictive_overheal("HealingTouch", entry, 2.5, settings, 35)
end

local function downrank_regrowth_overheal(entry, settings)
 if not entry or not entry.unit then return false end
 if effective_hp(entry) <= 40 then return false end
 if (entry.time_to_die or 999) <= 3 then return false end
 return predictive_overheal("Regrowth", entry, 2.0, settings, 40)
end



local function unit_class_id(unit)
 if not unit or not NS.safe_field then return nil end
 local getter = NS.safe_field(unit, "get_class")
 if not getter then return nil end
 local ok, value = pcall(getter, unit)
 return ok and type(value) == "number" and value or nil
end

local function is_healer_entry(entry)
 local class_id = entry and unit_class_id(entry.unit) or nil
 return class_id and HEALER_CLASS_IDS[class_id] == true
end

local function choose_better(current, candidate)
 if not candidate then return current end
 if not current then return candidate end
 local cand_hp = effective_hp(candidate)
 local current_hp = effective_hp(current)
 if cand_hp < current_hp then return candidate end
 if cand_hp == current_hp and effective_deficit(candidate) > effective_deficit(current) then return candidate end
 return current
end

local function entry_can_receive_lifebloom(entry, context)
 if not entry or not entry.unit then return false end
 if context.mana_pct and context.mana_pct <= MANA_LOW_FOR_BLOOM then return false end
 if effective_hp(entry) >= FULL_TARGET_HP and (entry.lifebloom_stacks or 0) > 0 then return false end
 return true
end

local function needs_lifebloom_refresh(entry, context, wanted_stacks)
 if not entry_can_receive_lifebloom(entry, context) then return false end
 local stacks = entry.lifebloom_stacks or 0
 local remains = entry.lifebloom_remains or NS.buff_remains(entry.unit, LIFEBLOOM_BUFF) or 0
 if stacks <= 0 then return true end
 if stacks < wanted_stacks and remains > LIFEBLOOM_BLOOM_SOON then return true end
 if remains <= 0 or remains > LIFEBLOOM_REFRESH then return false end
 -- Tick-cadence-aware refresh: if HotTickTracker is available, check if next tick
 -- is imminent. Refreshing right before a tick clips it; wait until after the tick.
 if NS.HotTickTracker and type(NS.HotTickTracker.next_tick_in) == "function" then
  local ok, tick_in = pcall(NS.HotTickTracker.next_tick_in, NS.HotTickTracker, entry.unit, "lifebloom")
  if ok and type(tick_in) == "number" and tick_in >= 0 and tick_in < 0.5 then
   -- Next tick is within 0.5s — wait for it to land before refreshing
   return false
  end
 end
 return true
end

local function should_let_lifebloom_bloom(entry, context)
 if not entry or not entry.unit then return false end
 local stacks = entry.lifebloom_stacks or 0
 if stacks <= 0 then return false end
 local remains = entry.lifebloom_remains or 0
 if remains <= 0 or remains > LIFEBLOOM_BLOOM_SOON then return false end
 local mana = context.mana_pct or context.player_mana_pct or 100
 return mana <= MANA_LOW_FOR_BLOOM or effective_hp(entry) >= FULL_TARGET_HP
end

local function needs_rejuvenation(entry, threshold)
 if not entry or not entry.unit then return false end
 if effective_hp(entry) > threshold then return false end
 local remains = NS.buff_remains(entry.unit, REJUVENATION_BUFF) or 0
 if not entry.has_rejuvenation or remains <= 0 then return true end
 if remains > REJUVENATION_REFRESH then return false end
 -- Tick-cadence-aware refresh via HotTickTracker
 if NS.HotTickTracker and type(NS.HotTickTracker.next_tick_in) == "function" then
  local ok, tick_in = pcall(NS.HotTickTracker.next_tick_in, NS.HotTickTracker, entry.unit, "rejuvenation")
  if ok and type(tick_in) == "number" and tick_in >= 0 and tick_in < 0.5 then
   return false -- wait for tick to land
  end
 end
 return true
end

local function needs_regrowth(entry)
 if not entry or not entry.unit then return false end
 if effective_hp(entry) > REGROWTH_SPOT_HP then return false end
 local remains = NS.buff_remains(entry.unit, REGROWTH_BUFF) or 0
 if not entry.has_regrowth or remains <= 0 then return true end
 if remains > REGROWTH_REFRESH then return false end
 -- Tick-cadence-aware refresh via HotTickTracker
 if NS.HotTickTracker and type(NS.HotTickTracker.next_tick_in) == "function" then
  local ok, tick_in = pcall(NS.HotTickTracker.next_tick_in, NS.HotTickTracker, entry.unit, "regrowth")
  if ok and type(tick_in) == "number" and tick_in >= 0 and tick_in < 0.5 then
   return false -- wait for tick to land
  end
 end
 return true
end

local function count_tree_aura_targets(entries, count)
 local aura_count = 0
 for i = 1, count do
  local entry = entries[i]
  local distance = entry and entry.unit and NS.unit_distance and NS.unit_distance(entry.unit) or 0
  if entry and entry.unit and distance <= TREE_AURA_RANGE then
   aura_count = aura_count + 1
  end
 end
 return aura_count
end

local function scan_pvp_pressure(context, state)
 if not context or not context.me then return end
 state.melee_pressure_count = 0
 state.melee_target = nil
 state.enemy_healer = nil
 state.root_target = nil
 local enemies = NS.GetEnemiesInRange and NS.GetEnemiesInRange(40) or nil
 local enemy_count = type(enemies) == "table" and (enemies.n or #enemies) or 0
 for i = 1, enemy_count do
  local enemy = enemies[i]
  if enemy and NS.unit_alive(enemy) then
   local distance = NS.unit_distance and NS.unit_distance(enemy, context.me) or 999
   if distance <= PVP_MELEE_RANGE and NS.is_melee_target and NS.is_melee_target(enemy, context.me) then
    state.melee_pressure_count = state.melee_pressure_count + 1
    if not state.melee_target then state.melee_target = enemy end
    if not state.root_target then state.root_target = enemy end
   end
   if not state.enemy_healer and HEALER_CLASS_IDS[unit_class_id(enemy) or 0] and distance <= 30 then
    state.enemy_healer = enemy
   end
  end
 end
end

local function find_priority_innervate(entries, count, context)
 -- Prefer other healers at low mana before self
 local healer_mana_floor = spec_kit.setting_number(context, "resto_innervate_mana", 30)
 for i = 1, count do
  local entry = entries[i]
  local mana = entry and entry.unit and NS.mana_pct and NS.mana_pct(entry.unit) or 100
  local is_self = entry and entry.unit and NS.same_unit and NS.same_unit(entry.unit, context.me)
  if entry and entry.unit and is_healer_entry(entry) and not is_self and mana <= (healer_mana_floor + 5) then
   return entry.unit
  end
 end
 -- Fall back to self if own mana is critically low
 if (context.mana_pct or 100) <= spec_kit.setting_number(context, "resto_innervate_mana", 30) then
  return context.me or NS.GetPlayer()
 end
 return nil
end

local function choose_swiftmend_prefer_rejuv(first, second)
 if not second then return first end
 if not first then return second end
 local first_hp = effective_hp(first)
 local second_hp = effective_hp(second)
 if math.abs(first_hp - second_hp) <= 8 then
  -- Prefer Rejuv-only over Regrowth (preserves Regrowth's direct+HoT)
  local first_rejuv_only = first.has_rejuvenation and not first.has_regrowth
  local second_rejuv_only = second.has_rejuvenation and not second.has_regrowth
  if first_rejuv_only and not second_rejuv_only then return first end
  if second_rejuv_only and not first_rejuv_only then return second end
  -- Prefer HoT that is about to expire (consume before clipping — HealIQ approach)
  local first_remains = NS.buff_remains(first.unit, REJUVENATION_BUFF) or 999
  local second_remains = NS.buff_remains(second.unit, REJUVENATION_BUFF) or 999
  if first_remains < 2.0 and second_remains > 3.0 then return first end
  if second_remains < 2.0 and first_remains > 3.0 then return second end
 end
 return choose_better(first, second)
end

local function choose_swiftmend_target(entries, count, threshold)
 local tank_candidate, healer_candidate, dps_candidate = nil, nil, nil
 for i = 1, count do
  local entry = entries[i]
  if entry and effective_hp(entry) <= threshold and has_hot_for_swiftmend(entry) then
   if entry.is_tank then tank_candidate = choose_swiftmend_prefer_rejuv(tank_candidate, entry)
   elseif is_healer_entry(entry) then healer_candidate = choose_swiftmend_prefer_rejuv(healer_candidate, entry)
   else dps_candidate = choose_swiftmend_prefer_rejuv(dps_candidate, entry) end
  end
 end
 return tank_candidate or healer_candidate or dps_candidate
end

local function build_state(context)
 local entries, count = Healing.scan_healing_targets()
 local lifebloom_targets = spec_kit.setting_number(context, "resto_lifebloom_targets", 3)
 if lifebloom_targets < 1 then lifebloom_targets = 1 elseif lifebloom_targets > 3 then lifebloom_targets = 3 end

 resto_state.entries = entries
 resto_state.count = count
 resto_state.tank = NS.healing_get_tank and NS.healing_get_tank(entries, count) or nil
 resto_state.lowest = NS.healing_get_lowest_hp and NS.healing_get_lowest_hp(entries, count, 100) or nil
 resto_state.lowest_tank = nil
 resto_state.lowest_healer = nil
 resto_state.lowest_dps = nil
 -- early hoist for FSR manager (in_combat, lowest_hp_pct; Pattern 14, before loops/returns; mana later)
 resto_state.in_combat = context.in_combat or false
 local _lowest = resto_state.lowest
 resto_state.lowest_hp_pct = _lowest and (_lowest.effective_hp or _lowest.hp or 100) or 100
 resto_state.swiftmend_target = nil
 resto_state.ns_target = nil
 resto_state.ht_target = nil
 resto_state.regrowth_target = nil
 resto_state.rejuv_target = nil
 resto_state.lifebloom_tank = nil
 resto_state.lifebloom_raid = nil
 resto_state.lifebloom_raid2 = nil
 resto_state.lifebloom_refresh = nil
 resto_state.lifebloom_bloom = nil
 resto_state.innervate_target = nil
 resto_state.cursed_target = nil
 resto_state.poison_target = nil
 resto_state.tranquility_count = 0
 resto_state.in_tree = context.stance == STANCE_TREE
 resto_state.in_caster = not context.stance or context.stance == STANCE_CASTER
 -- Broken-API guard: skip aura checks if API is unhealthy (prevents crash loops on private servers)
 local skip_aura = NS.broken_api_throttled and NS.broken_api_throttled(17116, 3.0) or false
 if not skip_aura then
  resto_state.tree_aura_count = count_tree_aura_targets(entries, count)
  resto_state.in_tree = context.stance == STANCE_TREE or NS.has_player_buff(TREE_OF_LIFE_BUFF)
  resto_state.has_natures_swiftness = NS.has_player_buff(NATURES_SWIFTNESS_BUFF)
  resto_state.has_clearcasting = NS.has_player_buff(CLEARCASTING_BUFF)
  resto_state.moonfire_remains = context.target and NS.debuff_remains(context.target, MOONFIRE_DEBUFF) or 0
  resto_state.insect_swarm_remains = context.target and NS.debuff_remains(context.target, INSECT_SWARM_DEBUFF) or 0
 end
 -- Tree of Life talent detection
 if NS.spell_book and NS.spell_book.is_spell_learned then
  resto_state.can_tree = NS.spell_book.is_spell_learned(33891) == true
 elseif NS.spell_exists then
  resto_state.can_tree = NS.spell_exists(ACTION.TreeOfLifeForm) == true
 end
 -- Wire NS.Triage for intelligent target ranking (if available)
 if NS.Triage and NS.Triage.rank and count > 0 then
  local ranked = NS.Triage.rank(entries, count, context.settings)
  if ranked and ranked[1] then
   resto_state.lowest = ranked[1]
  end
 end
 -- Wire NS.AoEHeal for Tranquility cluster targeting (if available)
 if NS.AoEHeal and NS.AoEHeal.best_target and count > 0 then
  local best_cluster, cluster_count = NS.AoEHeal.best_target(entries, count, 40, 3)
  if best_cluster and cluster_count >= 3 then
   resto_state.tranquility_best_target = best_cluster
   if cluster_count > resto_state.tranquility_count then
    resto_state.tranquility_count = cluster_count
   end
  else
   resto_state.tranquility_best_target = nil
  end
 else
  resto_state.tranquility_best_target = nil
 end
 resto_state.is_group = context.is_group or false
 resto_state.mana_pct = context.mana_pct or context.player_mana_pct or 100
 local mana_conserve_pct = spec_kit.setting_number(context, "resto_mana_conserve_pct", MANA_CONSERVE_PCT)
 local mana_emergency_pct = spec_kit.setting_number(context, "resto_mana_emergency_pct", MANA_EMERGENCY_PCT)
 local mana_critical_pct = spec_kit.setting_number(context, "resto_mana_critical_pct", MANA_CRITICAL_PCT)
 resto_state.mana_conserve = resto_state.mana_pct <= mana_conserve_pct
 resto_state.mana_emergency = resto_state.mana_pct <= mana_emergency_pct
 resto_state.mana_critical = resto_state.mana_pct <= mana_critical_pct

 local swiftmend_hp = spec_kit.setting_number(context, "resto_swiftmend_hp", 50)
 local ns_hp = spec_kit.setting_number(context, "resto_ns_hp", 30)
 local tranquility_hp = spec_kit.setting_number(context, "resto_tranquility_hp", 25)
 local auto_dispel = spec_kit.setting_bool(context, "resto_auto_dispel", true)
 local tank_rejuv_hp = spec_kit.setting_number(context, "resto_rejuv_hp_tank", TANK_REJUV_HP)
 local raid_rejuv_hp = spec_kit.setting_number(context, "resto_rejuv_hp_raid", RAID_REJUV_HP)

 for i = 1, count do
  local entry = entries[i]
  if entry and entry.unit then
   local hp = effective_hp(entry)
   if entry.is_tank then resto_state.lowest_tank = choose_better(resto_state.lowest_tank, entry)
   elseif is_healer_entry(entry) then resto_state.lowest_healer = choose_better(resto_state.lowest_healer, entry)
   else resto_state.lowest_dps = choose_better(resto_state.lowest_dps, entry) end
   if hp <= tranquility_hp then resto_state.tranquility_count = resto_state.tranquility_count + 1 end
   if hp <= ns_hp then resto_state.ns_target = choose_better(resto_state.ns_target, entry) end
   if hp <= HEALING_TOUCH_HP and not predictive_overheal("HealingTouch", entry, 2.5, context.settings, 25) then resto_state.ht_target = choose_better(resto_state.ht_target, entry) end
   if needs_regrowth(entry) and not predictive_overheal("Regrowth", entry, 2.0, context.settings, 35) then resto_state.regrowth_target = choose_better(resto_state.regrowth_target, entry) end
   if needs_rejuvenation(entry, entry.is_tank and tank_rejuv_hp or raid_rejuv_hp) then resto_state.rejuv_target = choose_better(resto_state.rejuv_target, entry) end
   if should_let_lifebloom_bloom(entry, context) then resto_state.lifebloom_bloom = choose_better(resto_state.lifebloom_bloom, entry) end
   if auto_dispel and not resto_state.cursed_target and NS.has_dispel_type_debuff and NS.has_dispel_type_debuff(entry.unit, "Curse") then resto_state.cursed_target = entry end
   if auto_dispel and not resto_state.poison_target and NS.has_dispel_type_debuff and NS.has_dispel_type_debuff(entry.unit, "Poison") and not NS.buff_up(entry.unit, ABOLISH_POISON_BUFF) then resto_state.poison_target = entry end
  end
 end

 if resto_state.tank and needs_lifebloom_refresh(resto_state.tank, context, 3) and not should_let_lifebloom_bloom(resto_state.tank, context) then
  resto_state.lifebloom_tank = resto_state.tank
  resto_state.lifebloom_refresh = resto_state.tank
 end
 if lifebloom_targets > 1 then
  for i = 1, count do
   local entry = entries[i]
   if entry and entry ~= resto_state.tank and needs_lifebloom_refresh(entry, context, 1) and effective_hp(entry) <= 88 then
    if not resto_state.lifebloom_raid then
     resto_state.lifebloom_raid = entry
    elseif lifebloom_targets > 2 and entry ~= resto_state.lifebloom_raid then
     resto_state.lifebloom_raid2 = entry
     break
    end
   end
  end
 end

 resto_state.swiftmend_target = choose_swiftmend_target(entries, count, swiftmend_hp)
 resto_state.innervate_target = find_priority_innervate(entries, count, context)
 if context.is_moving and not context.in_combat and (context.target_distance or 0) >= REPOSITION_RANGE then resto_state.should_move_form = true end
 scan_pvp_pressure(context, resto_state)
 if resto_state.in_tree and (resto_state.ns_target or resto_state.ht_target or resto_state.enemy_healer or resto_state.root_target) then resto_state.should_dance_caster = true end
 local ft = NS.get_friendly_target_entry and NS.get_friendly_target_entry(context)
 resto_state.friendly_target = ft
 resto_state.friendly_target_ready = ft ~= nil

 -- parity: Smart Stop-Cast — cancel overhealing casts mid-flight
 local me = context.me or NS.GetPlayer and NS.GetPlayer() or nil
 if me and NS.StopCast and type(NS.StopCast.update) == "function" then
  NS.StopCast.update(me, context.settings)
 end

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

local function solo_damage_enabled(context, state)
 if not context or not context.has_valid_enemy_target then return false end
 if not (context.is_solo == true or context.is_leveling == true or spec_kit.setting_bool(context, "resto_dps_when_idle", false)) then return false end
 if context.is_moving and not NS.spell_ready(ACTION.Moonfire, context.target) then return false end
 if state and state.lowest and effective_hp(state.lowest) < spec_kit.setting_number(context, "resto_idle_hp", 88) then return false end
 if (context.mana_pct or 100) < spec_kit.setting_number(context, "resto_dps_mana_floor", 35) then return false end
 if state and state.in_tree then return false end
 return true
end

-- ============================================================================
-- Strategy coverage map
-- ============================================================================
-- [01-03] Personal survival and PvP melee pressure responses.
-- [04-05] Automatic TBC dispels for Curse and Poison when enabled.
-- [06-08] Mana recovery with potion floor, self Innervate, and healer Innervate.
-- [09] Rebirth battle rez when a dead ally can be returned.
-- [10-12] Swiftmend and Nature's Swiftness triage before hard casts.
-- [12] Tranquility only when multiple allies are critical and threat is safe.
-- [13] Tree form dancing for non-HoT emergency spells.
-- [14-15] Direct healing: max Healing Touch and Regrowth spot healing.
-- [16] Explicit Lifebloom bloom allowance by returning false and continuing.
-- [17-20] Lifebloom rolling on tank plus up to two raid priority targets.
-- [21-23] Movement-safe instant HoTs.
-- [24] Mana-conservative downranked Healing Touch.
-- [25] Tree of Life maintenance when aura value exists and talent is present.
-- [26-27] Light PvP control using only TBC-era Cyclone and Entangling Roots.
-- [28-29] Movement form support for repositioning.
-- [30] Fallback direct heal when all higher-value options are unavailable.
local function BarkskinSelfPreservation_matches(context) return (context.hp or 100) <= spec_kit.setting_number(context, "barkskin_hp", 55) and NS.spell_ready(ACTION.Barkskin, PLAYER_UNIT, BARKSKIN_OPTS) end
local function BarkskinSelfPreservation_execute() return NS.try_cast(ACTION.Barkskin, PLAYER_UNIT, "[RESTO] Barkskin self", BARKSKIN_OPTS) end

local function BearFormFocusedByMelee_matches(context, state) return context.is_pvp and (context.hp or 100) <= 35 and state.melee_pressure_count > 0 and context.stance ~= STANCE_BEAR and NS.spell_ready(ACTION.BearForm, PLAYER_UNIT, SKIP_RANGE) end
local function BearFormFocusedByMelee_execute() return NS.try_cast(ACTION.BearForm, PLAYER_UNIT, "[RESTO] Bear Form under melee focus", SKIP_RANGE) end

local function NaturesGraspMelee_matches(context, state) return context.is_pvp and state.melee_pressure_count > 0 and not NS.has_player_buff(NATURES_GRASP_BUFF) and NS.spell_ready(ACTION.NaturesGrasp, PLAYER_UNIT, SKIP_RANGE) end
local function NaturesGraspMelee_execute() return NS.try_cast(ACTION.NaturesGrasp, PLAYER_UNIT, "[RESTO] Nature's Grasp melee peel", SKIP_RANGE) end

local function InnervateSelf_matches(context, state) return state.innervate_target and NS.same_unit(state.innervate_target, context.me) and NS.spell_ready(ACTION.Innervate, state.innervate_target, INNERVATE_OPTS) end
local function InnervateSelf_execute(_, state) return NS.try_cast(ACTION.Innervate, state.innervate_target, "[RESTO] Innervate self", INNERVATE_OPTS) end

local function InnervateHealer_matches(context, state) return state.innervate_target and not NS.same_unit(state.innervate_target, context.me) and NS.spell_ready(ACTION.Innervate, state.innervate_target, INNERVATE_OPTS) end
local function InnervateHealer_execute(_, state) return NS.try_cast(ACTION.Innervate, state.innervate_target, "[RESTO] Innervate healer", INNERVATE_OPTS) end

local function RebirthBattleRez_matches(context) return context.in_combat and (NS.is_in_party and NS.is_in_party() or NS.is_in_raid and NS.is_in_raid()) and NS.spell_ready(ACTION.Rebirth, PLAYER_UNIT, { skip_range = true, expected_cooldown = REBIRTH_EXPECTED_CD }) end
local function RebirthBattleRez_execute() return NS.try_cast(ACTION.Rebirth, PLAYER_UNIT, "[RESTO] Rebirth battle rez", { skip_range = true, expected_cooldown = REBIRTH_EXPECTED_CD }) end

local function SwiftmendEmergency_matches(_, state) return state.swiftmend_target and NS.spell_ready(ACTION.Swiftmend, state.swiftmend_target.unit, SWIFTMEND_OPTS) end
local function SwiftmendEmergency_execute(_, state) return NS.try_cast(ACTION.Swiftmend, state.swiftmend_target.unit, "[RESTO] Swiftmend triage") end

local function NaturesSwiftness_matches(_, state) return state.ns_target and not state.has_natures_swiftness and (state.ns_target.time_to_die or 999) <= 3.5 and NS.spell_ready(ACTION.NaturesSwiftness, PLAYER_UNIT, NS_OPTS) end
local function NaturesSwiftness_execute() return NS.try_cast(ACTION.NaturesSwiftness, PLAYER_UNIT, "[RESTO] Nature's Swiftness", NS_OPTS) end

local function NaturesSwiftnessHealingTouch_matches(context, state) return state.ns_target and state.has_natures_swiftness and NS.spell_ready(ACTION.HealingTouch, state.ns_target.unit) and not predictive_overheal("HealingTouch", state.ns_target, 1.5, context.settings, 25) end
local function NaturesSwiftnessHealingTouch_execute(_, state) return NS.try_cast(ACTION.HealingTouch, state.ns_target.unit, "[RESTO] NS Healing Touch") end

local function TranquilityEmergency_matches(context, state) local needed = spec_kit.setting_number(context, "resto_tranquility_count", 3); if state.tranquility_count < needed then return false end; if NS.threat_status and NS.threat_status(context.me, context.target) >= 2 then return false end; return NS.spell_ready(ACTION.Tranquility, PLAYER_UNIT, TRANQUILITY_OPTS) end
local function TranquilityEmergency_execute() return NS.try_cast(ACTION.Tranquility, PLAYER_UNIT, "[RESTO] Tranquility emergency", TRANQUILITY_OPTS) end

local function LeaveTreeForDirectHeal_matches(_, state) return state.should_dance_caster and state.in_tree and NS.spell_ready(ACTION.TreeOfLifeForm, PLAYER_UNIT, TREE_OPTS) end
local function LeaveTreeForDirectHeal_execute(_, state) state.should_dance_caster = false return NS.try_cast(ACTION.TreeOfLifeForm, PLAYER_UNIT, "[RESTO] Leave Tree for direct spell", TREE_OPTS) end

local function SecondRaidLifebloomCoverage_matches(_, state) return state.lifebloom_raid2 and NS.spell_ready(ACTION.Lifebloom, state.lifebloom_raid2.unit) end
local function SecondRaidLifebloomCoverage_execute(_, state) return NS.try_cast(ACTION.Lifebloom, state.lifebloom_raid2.unit, "[RESTO] Second raid Lifebloom coverage") end

local function MovingLifebloom_matches(context, state) return context.is_moving and state.lowest and effective_hp(state.lowest) <= MOVING_HOT_HP and NS.spell_ready(ACTION.Lifebloom, state.lowest.unit) end
local function MovingLifebloom_execute(_, state) return NS.try_cast(ACTION.Lifebloom, state.lowest.unit, "[RESTO] Moving Lifebloom") end

local function MovingRejuvenation_matches(context, state) return context.is_moving and state.rejuv_target and not state.mana_emergency and NS.spell_ready(ACTION.Rejuvenation, state.rejuv_target.unit) end
local function MovingRejuvenation_execute(_, state) return NS.try_cast(ACTION.Rejuvenation, state.rejuv_target.unit, "[RESTO] Moving Rejuvenation") end

local function PriorityRejuvenation_matches(_, state) return state.rejuv_target and not state.mana_emergency and NS.spell_ready(ACTION.Rejuvenation, state.rejuv_target.unit) end
local function PriorityRejuvenation_execute(_, state) return NS.try_cast(ACTION.Rejuvenation, state.rejuv_target.unit, "[RESTO] Priority Rejuvenation") end

local function CycloneEnemyHealer_matches(context, state) return context.is_pvp and state.enemy_healer and NS.try_interrupt and NS.try_interrupt(state.enemy_healer) and NS.spell_ready(ACTION.Cyclone, state.enemy_healer) end
local function CycloneEnemyHealer_execute(_, state) return NS.try_cast(ACTION.Cyclone, state.enemy_healer, "[RESTO] Cyclone enemy healer") end

local function EntanglingRootsMelee_matches(context, state) return context.is_pvp and state.root_target and not context.is_moving and NS.spell_ready(ACTION.EntanglingRoots, state.root_target) end
local function EntanglingRootsMelee_execute(_, state) return NS.try_cast(ACTION.EntanglingRoots, state.root_target, "[RESTO] Entangling Roots melee") end

local function SoloMoonfire_matches(context, state) return solo_damage_enabled(context, state) and not state.mana_emergency and state.moonfire_remains <= 3 and NS.spell_ready(ACTION.Moonfire, context.target) end
local function SoloMoonfire_execute(context) return NS.try_cast(ACTION.Moonfire, context.target, "[RESTO] Solo Moonfire") end

local function SoloInsectSwarm_matches(context, state) return solo_damage_enabled(context, state) and not context.is_moving and not state.mana_emergency and state.insect_swarm_remains <= 3 and NS.spell_ready(ACTION.InsectSwarm, context.target) end
local function SoloInsectSwarm_execute(context) return NS.try_cast(ACTION.InsectSwarm, context.target, "[RESTO] Solo Insect Swarm") end

local function SoloWrath_matches(context, state) return solo_damage_enabled(context, state) and not context.is_moving and not state.mana_emergency and NS.spell_ready(ACTION.Wrath, context.target) end
local function SoloWrath_execute(context) return NS.try_cast(ACTION.Wrath, context.target, "[RESTO] Solo Wrath") end

local function TravelFormReposition_matches(context, state) return state.should_move_form and context.stance ~= STANCE_TRAVEL and context.stance ~= STANCE_CAT and NS.spell_ready(ACTION.TravelForm, PLAYER_UNIT, SKIP_RANGE) end
local function TravelFormReposition_execute() return NS.try_cast(ACTION.TravelForm, PLAYER_UNIT, "[RESTO] Travel Form reposition", SKIP_RANGE) end

local function CatFormRepositionFallback_matches(context, state) return state.should_move_form and context.stance ~= STANCE_CAT and NS.spell_ready(ACTION.CatForm, PLAYER_UNIT, SKIP_RANGE) end
local function CatFormRepositionFallback_execute() return NS.try_cast(ACTION.CatForm, PLAYER_UNIT, "[RESTO] Cat Form reposition", SKIP_RANGE) end

local strategies = {
 -- FriendlyTarget (Step 0): honor the player's manually-selected friendly target.
 -- TOP priority: works in and out of combat. Threshold-gated so full-health
 -- targets are ignored. State is populated in build_state().
 { name = "FriendlyTarget", matches = function(context, state)
  if not state.friendly_target_ready then return false end
  local ft = state.friendly_target
  if not ft then return false end
  if (ft.hp_pct or 100) >= spec_kit.setting_number(context, "resto_friendly_target_threshold", 90) then return false end
  if context.is_moving then return false end
  if context.player_control_locked then return false end
  if not NS.spell_ready(ACTION.Regrowth, ft.unit) then return false end
  if predictive_overheal("Regrowth", ft, 2.0, context.settings, 35) then return false end
  return true
 end, execute = function(context, state)
  local ft = state.friendly_target
  if not ft or not ft.unit then return false end
  return NS.try_cast(ACTION.Regrowth, ft.unit, string.format("[RESTO] Regrowth (friendly target) %.0f%%", effective_hp(ft)))
 end },
 { name = "Healthstone",
   matches = function(context, state)
       if not context.in_combat then return false end
       if (context.hp or 100) > 28 then return false end
       return (state.healthstone_ready or 0) > 0
   end,
   execute = function(context)
       local item_id = first_ready_item(HEALTHSTONE_IDS)
       if item_id > 0 and NS.use_item_by_id then
           return NS.use_item_by_id(item_id, context.me) and true or false
       end
       return false
   end,
 },
  { name = "BarkskinSelfPreservation", matches = BarkskinSelfPreservation_matches, execute = BarkskinSelfPreservation_execute },
  { name = "BearFormFocusedByMelee", matches = BearFormFocusedByMelee_matches, execute = BearFormFocusedByMelee_execute },
  { name = "NaturesGraspMelee", matches = NaturesGraspMelee_matches, execute = NaturesGraspMelee_execute },
 { name = "RemoveCurse", matches = function(context, state)
   if NS.broken_api_throttled and NS.broken_api_throttled(ACTION.RemoveCurse, 3.0) then return false end
   if context and (context.control_risk or context.is_group) and state.cursed_target then return true end
   return state.cursed_target and NS.spell_ready(ACTION.RemoveCurse, state.cursed_target.unit)
  end, execute = function(_, state) return NS.try_cast(ACTION.RemoveCurse, state.cursed_target.unit, "[RESTO] Remove Curse") end },
 { name = "AbolishPoison", matches = function(context, state)
   if NS.broken_api_throttled and NS.broken_api_throttled(ACTION.AbolishPoison, 3.0) then return false end
   if context and (context.control_risk or context.is_group) and state.poison_target then return true end
   return state.poison_target and NS.spell_ready(ACTION.AbolishPoison, state.poison_target.unit)
  end, execute = function(_, state) return NS.try_cast(ACTION.AbolishPoison, state.poison_target.unit, "[RESTO] Abolish Poison") end },
 { name = "ManaPotionFloor", matches = function(_, s) return (s.mana_pct or 100) <= 18 end, execute = function(context) return potion_helper.try_use_potion(context, potion_helper.MANA_POTION_IDS) end },
  { name = "InnervateSelf", matches = InnervateSelf_matches, execute = InnervateSelf_execute },
  { name = "InnervateHealer", matches = InnervateHealer_matches, execute = InnervateHealer_execute },
  { name = "RebirthBattleRez", matches = RebirthBattleRez_matches, execute = RebirthBattleRez_execute },
  { name = "SwiftmendEmergency", matches = SwiftmendEmergency_matches, execute = SwiftmendEmergency_execute },
 { name = "PreemptiveRegrowth", matches = function(context, state)
  if not context.in_combat then return false end
  if context.is_moving then return false end
  local threshold = spec_kit.setting_number(context, "resto_preemptive_threshold", PreemptiveHeal.DEFAULT_THRESHOLD)
  if not PreemptiveHeal.match(context, state, threshold, 2.0) then return false end
  if not NS.spell_ready(ACTION.Regrowth, state._preemptive_target.unit) then return false end
  return true
 end, execute = function(context, state)
  local target_entry = state._preemptive_target
  if not target_entry or not target_entry.unit then return false end
  return PreemptiveHeal.execute(context, state, ACTION.Regrowth, string.format("[RESTO] Preemptive Regrowth %.0f%%", target_entry.effective_hp or 0), { cast_time = 2.0, heal_size = 1500 })
 end },
  { name = "NaturesSwiftness", matches = NaturesSwiftness_matches, execute = NaturesSwiftness_execute },
  { name = "NaturesSwiftnessHealingTouch", matches = NaturesSwiftnessHealingTouch_matches, execute = NaturesSwiftnessHealingTouch_execute },
  { name = "TranquilityEmergency", matches = TranquilityEmergency_matches, execute = TranquilityEmergency_execute },
  { name = "LeaveTreeForDirectHeal", matches = LeaveTreeForDirectHeal_matches, execute = LeaveTreeForDirectHeal_execute },
 { name = "HealingTouchMaxEmergency", matches = function(context, state)
  if context.is_moving or not state.ht_target then return false end
  if not NS.spell_ready(ACTION.HealingTouch, state.ht_target.unit) then return false end
  if predictive_overheal("HealingTouch", state.ht_target, 2.5, context.settings, 25) then return false end
  return true
  end, execute = function(_, state) return NS.try_cast(ACTION.HealingTouch, state.ht_target.unit, "[RESTO] Healing Touch emergency") end },

  -- FSRPause after emergencies (Preemptive/NS/Swiftmend/Tranquility/LeaveTree/HTMax) before fillers (Regrowth/Lifebloom/Rejuv/Downrank etc.)
  { name = "FSRPause",
   matches = function(context, state)
    if not FsrManager then return false end
    if not state.in_combat then return false end
    if not state.fsr_inside or (state.fsr_regen_delta or 0) <= 0 then return false end
    return FsrManager.should_pause_for_fsr(state, context)
   end,
   execute = function(_, state)
    return true
   end,
  },

 { name = "RegrowthSpotHeal", matches = function(context, state)
  if context.is_moving or not state.regrowth_target or state.mana_conserve then return false end
  if not NS.spell_ready(ACTION.Regrowth, state.regrowth_target.unit) then return false end
  if predictive_overheal("Regrowth", state.regrowth_target, 2.0, context.settings, 35) then return false end
  return true
 end, execute = function(context, state)
  local mana = context.mana_pct or 100
  local spell = ACTION.Regrowth
  local label = "Regrowth spot heal"
  if mana < 25 then
   spell = REGROWTH_EFFICIENT
   label = "Downrank Regrowth (efficient)"
  elseif mana < 45 then
   spell = REGROWTH_CONSERVE
   label = "Downrank Regrowth (conserve)"
  end
  return NS.try_cast(spell, state.regrowth_target.unit, "[RESTO] " .. label)
 end },
 { name = "LifebloomLetBloom", matches = function(_, state) return state.lifebloom_bloom ~= nil end, execute = function() return false end },
 { name = "TankLifebloomStack", matches = function(_, state) return state.lifebloom_tank and NS.spell_ready(ACTION.Lifebloom, state.lifebloom_tank.unit) end, execute = function(_, state) return NS.try_cast(ACTION.Lifebloom, state.lifebloom_tank.unit, "[RESTO] Tank Lifebloom roll") end },
 { name = "ClearcastRegrowth", matches = function(context, state)
  if not state.has_clearcasting or not state.regrowth_target then return false end
  if not NS.spell_ready(ACTION.Regrowth, state.regrowth_target.unit) then return false end
  if predictive_overheal("Regrowth", state.regrowth_target, 2.0, context.settings, 35) then return false end
  return true
 end, execute = function(_, state) return NS.try_cast(ACTION.Regrowth, state.regrowth_target.unit, "[RESTO] Clearcast Regrowth") end },
 { name = "RaidLifebloomCoverage", matches = function(_, state) return state.lifebloom_raid and NS.spell_ready(ACTION.Lifebloom, state.lifebloom_raid.unit) end, execute = function(_, state) return NS.try_cast(ACTION.Lifebloom, state.lifebloom_raid.unit, "[RESTO] Raid Lifebloom coverage") end },
  { name = "SecondRaidLifebloomCoverage", matches = SecondRaidLifebloomCoverage_matches, execute = SecondRaidLifebloomCoverage_execute },
  { name = "MovingLifebloom", matches = MovingLifebloom_matches, execute = MovingLifebloom_execute },
  { name = "MovingRejuvenation", matches = MovingRejuvenation_matches, execute = MovingRejuvenation_execute },
  { name = "PriorityRejuvenation", matches = PriorityRejuvenation_matches, execute = PriorityRejuvenation_execute },
 { name = "DownrankHealingTouch", matches = function(context, state)
  if context.is_moving or not state.lowest then return false end
  if effective_hp(state.lowest) > DOWNRANK_HT_HP then return false end
  if (context.mana_pct or 100) > 45 then return false end
  if not NS.spell_ready(ACTION.HealingTouchRank4, state.lowest.unit) then return false end
  if downrank_ht_overheal(state.lowest, context.settings) then return false end
  return true
  end, execute = function(context, state)
   local mana_pct = context.mana_pct or 100
   local spell_id
   if mana_pct > 30 then
    spell_id = HEALING_TOUCH_MAX
   elseif mana_pct > 15 then
    spell_id = HEALING_TOUCH_CONSERVE
   else
    spell_id = HEALING_TOUCH_EFFICIENT
   end
   local adjusted, penalty = PreemptiveHeal.get_penalty_adjusted_heal(spell_id, 3000)
   return NS.try_cast(spell_id, state.lowest.unit, string.format("[RESTO] Downrank Healing Touch rank %s (penalty %.0f%%)", mana_pct > 30 and "13" or (mana_pct > 15 and "12" or "11"), (penalty or 1) * 100))
  end },
 { name = "TreeOfLifeMaintain", matches = function(_, state) return state.can_tree and not state.in_tree and state.tree_aura_count >= 2 end, execute = function() return NS.try_cast(ACTION.TreeOfLifeForm, PLAYER_UNIT, "[RESTO] Tree of Life aura", TREE_OPTS) end },
  { name = "CycloneEnemyHealer", matches = CycloneEnemyHealer_matches, execute = CycloneEnemyHealer_execute },
  { name = "EntanglingRootsMelee", matches = EntanglingRootsMelee_matches, execute = EntanglingRootsMelee_execute },
  { name = "SoloMoonfire", matches = SoloMoonfire_matches, execute = SoloMoonfire_execute },
  { name = "SoloInsectSwarm", matches = SoloInsectSwarm_matches, execute = SoloInsectSwarm_execute },
  { name = "SoloWrath", matches = SoloWrath_matches, execute = SoloWrath_execute },
  { name = "TravelFormReposition", matches = TravelFormReposition_matches, execute = TravelFormReposition_execute },
  { name = "CatFormRepositionFallback", matches = CatFormRepositionFallback_matches, execute = CatFormRepositionFallback_execute },
 { name = "FallbackHealingTouch", matches = function(context, state)
  if context.is_moving or not state.lowest then return false end
  if effective_hp(state.lowest) > 80 then return false end
  if not NS.spell_ready(ACTION.HealingTouch, state.lowest.unit) then return false end
  if predictive_overheal("HealingTouch", state.lowest, 2.5, context.settings, 35) then return false end
  return true
 end, execute = function(_, state) return NS.try_cast(ACTION.HealingTouch, state.lowest.unit, "[RESTO] Healing Touch fallback") end },
}

local module = { strategies = strategies, build_state = build_state }
if NS.rotation_registry and NS.rotation_registry.register then
    NS.rotation_registry:register("resto", strategies, { get_state = build_state })
end
if NS.log then NS.log("Druid resto rotation registered") end
return module