-- healing_sylvanas.lua — Shaman Healing Utilities for Restoration.
-- WHAT:  party/raid scanning, ChainHeal/LHW/HW selection, and overheal gating.
-- WHEN:  loaded by restoration_sylvanas.lua during addon load.
-- WHY:   centralizes healing target selection and predictive overheal logic.
-- SAFETY: NS guard at load; predictive_overheal passes spell_id for downrank penalty;
--          _spell_id() helper handles production + test-stub compatibility.

-- ============================================================================
-- Shaman Healing Utilities (EaxRotations)
-- Party/raid scanning and healing utilities for Restoration Shaman
local _G = _G
local NS = _G.EaxRotations
if not NS then
    if type(core) == "table" and type(core.log_error) == "function" then
        core.log_error("[EaxRotations ERROR] Core module not loaded!")
    else
        print("[EaxRotations ERROR] Core module not loaded!")
    end
    return nil
end

local _ok_enums, enums = pcall(require, "common/enums")
if not _ok_enums or type(enums) ~= "table" or type(enums.class_id) ~= "table" then enums = { class_id = NS.CLASS_ID } end
local load_player = NS.GetPlayer and NS.GetPlayer()
local ok_cls, cls_id = pcall(function() return load_player and load_player:get_class() end)
if not ok_cls or cls_id ~= enums.class_id.SHAMAN then return nil end

-- Dispel type detection: uses NS.has_dispel_type_debuff() which scans
-- the unit's debuff cache for aura.dispel_type/aura.buff_type fields.
-- This is the correct API approach -- whitelists can never be complete.
-- Shaman dispels: Poison (Cure Toxins), Disease (Cure Disease)
local has_dispel_type_debuff = NS.has_dispel_type_debuff or function() return false end

local healing_targets = {}
local healing_targets_count = 0
-- Per-frame cache: prevents multiple rescans when multiple query
-- functions (get_tank_target, get_lowest_hp_target, etc.) all call
-- scan_healing_targets() independently in the same tick.
local scan_frame = 0
local math_floor = math.floor

NS.ShamanHealing = {}

-- Import shared helpers from core_sylvanas.lua
local health_pct, mana_pct, buff_remains = NS.import_helpers("health_pct", "mana_pct", "buff_remains")

-- Shared query functions from core_sylvanas.lua
local is_in_raid = NS.is_in_raid or function() return false end
local is_in_party = NS.is_in_party or function() return false end
local has_healing_reduction_debuff = NS.has_healing_reduction_debuff or function() return false end

local build_healing_entries = NS.build_healing_entries or function() return 0 end
local healing_get_tank = NS.healing_get_tank or function() return nil end
local healing_get_lowest_hp = NS.healing_get_lowest_hp or function() return nil end
local healing_all_above_hp = NS.healing_all_above_hp or function() return false end
local healing_get_cleanse_target = NS.healing_get_cleanse_target or function() return nil end
local healing_count_below_hp = NS.healing_count_below_hp or function() return 0 end

-- Reference Shaman class spells for select_heal
local SHAMAN_SPELLS = NS.ShamanSpells or {}

-- ============================================================================
-- HEALING TARGET SCANNER
-- ============================================================================
local function scan_healing_targets()
    -- Per-frame cache guard: only scan once per frame to avoid redundant
    -- build_healing_entries calls from multiple query functions.
    local current_frame = math_floor(NS.game_time_ms() / (1000 / 60))
    if current_frame > 0 and current_frame == scan_frame then
        return healing_targets, healing_targets_count
    end
    scan_frame = current_frame

    healing_targets_count = build_healing_entries(healing_targets, function(entry, unit)
        -- Dispel tracking (Poison + Disease for Shaman)
        entry.has_poison = false
        entry.has_disease = false

        entry.has_poison = has_dispel_type_debuff(unit, "Poison")
        entry.has_disease = has_dispel_type_debuff(unit, "Disease")

        entry.needs_cleanse = entry.has_poison or entry.has_disease

        entry.deficit = entry.max_hp - entry.current_hp
        -- incoming_dps is now populated by core_sylvanas.lua build_healing_entries via EMA tracker
        entry.has_healing_reduction = has_healing_reduction_debuff(unit)
    end)

    return healing_targets, healing_targets_count
end

NS.ShamanHealing.scan_healing_targets = scan_healing_targets

-- ============================================================================
-- TARGET QUERY FUNCTIONS
-- ============================================================================
local function get_tank_target()
    scan_healing_targets()
    return healing_get_tank(healing_targets, healing_targets_count)
end

NS.ShamanHealing.get_tank_target = get_tank_target

local function get_lowest_hp_target(threshold)
    threshold = threshold or 100
    scan_healing_targets()
    return healing_get_lowest_hp(healing_targets, healing_targets_count, threshold)
end

NS.ShamanHealing.get_lowest_hp_target = get_lowest_hp_target

local function all_members_above_hp(threshold)
    scan_healing_targets()
    return healing_all_above_hp(healing_targets, healing_targets_count, threshold)
end

NS.ShamanHealing.all_members_above_hp = all_members_above_hp

local function get_cleanse_target()
    scan_healing_targets()
    return healing_get_cleanse_target(healing_targets, healing_targets_count)
end

NS.ShamanHealing.get_cleanse_target = get_cleanse_target

-- ============================================================================
-- select_heal: Smart spell selection based on HP thresholds
--
-- Uses state.natures_swiftness_active to determine whether Nature's Swiftness
-- is already active for the emergency (< 30% HP) Healing Wave combo.
--
-- Returns: { spell, label, spell_type } or nil
--   spell:      spell object to cast, or nil if a non-cast action is needed
--   label:      human-readable label for logging
--   spell_type: type identifier for the rotation engine
-- ============================================================================
local function entry_hp(entry)
    if entry and type(entry.effective_hp) == "number" then return entry.effective_hp end
    if entry and type(entry.hp) == "number" then return entry.hp end
    return 100
end

-- Safe spell-ID extraction: handles production spell_action objects (with :id())
-- and test stubs that return raw numbers or plain tables.
local function _spell_id(spell_obj)
    if type(spell_obj) == "number" then return spell_obj end
    if type(spell_obj) == "table" and type(spell_obj.id) == "function" then return spell_obj:id() end
    return nil
end

local function predictive_overheal(spell_key, entry, cast_time, settings, emergency_hp, spell_id)
    if not entry or not entry.unit then return false end
    if entry_hp(entry) <= (emergency_hp or 30) then return false end
    if (entry.time_to_die or 999) <= cast_time then return false end
    if NS.HealerDeficit and NS.HealerDeficit.gate_spell_overheal then
        return NS.HealerDeficit.gate_spell_overheal(spell_key, entry.unit, cast_time, settings, spell_id)
    end
    return NS.gate_overheal and NS.gate_overheal(spell_key, entry.unit, cast_time, settings, spell_id) or false
end

local function chain_heal_overheal(entry, settings)
    if not entry or not entry.unit then return false end
    if entry_hp(entry) <= 35 then return false end
    if (entry.time_to_die or 999) <= 2.5 then return false end
    if NS.HealerDeficit and NS.HealerDeficit.heal_would_overheal then
        return NS.HealerDeficit.heal_would_overheal(entry.unit, 1800, 2.5, settings)
    end
    return predictive_overheal("ChainHeal", entry, 2.5, settings, 35, _spell_id(SHAMAN_SPELLS.ChainHeal))
end

local heal_result = { spell = nil, label = "", spell_type = "" }

local function select_heal(context, state, target, options)
    if not context or not target then return nil end
    if context.is_moving then return nil end

    local deficit = target.effective_deficit or target.deficit or 0
    if deficit <= 0 then return nil end

    local hp = entry_hp(target)

    -- Emergency: HP < 30% -- Nature's Swiftness + Healing Wave
    if hp < 30 then
        local ns_active = state and state.natures_swiftness_active
        if ns_active then
            -- NS is already active, cast Healing Wave
            heal_result.spell = SHAMAN_SPELLS.HealingWave or nil
            heal_result.label = "NS + HW"
            heal_result.spell_type = "NS_HealingWave"
        else
            -- Need to activate Nature's Swiftness first
            heal_result.spell = nil
            heal_result.label = "NS Emergency"
            heal_result.spell_type = "NaturesSwiftness"
        end
        return heal_result
    end

    -- Low HP: < 50% -- Lesser Healing Wave (fast cast, efficient)
    if hp < 50 then
        -- Predictive overheal gate: skip LHW if predicted deficit is small
        if predictive_overheal("LesserHealingWave", target, 1.5, context.settings, 30, _spell_id(SHAMAN_SPELLS.LesserHealingWave)) then return nil end
        heal_result.spell = SHAMAN_SPELLS.LesserHealingWave or nil
        heal_result.label = "LHW"
        heal_result.spell_type = "LesserHealingWave"
        return heal_result
    end

    -- Medium HP: < 70% -- Healing Wave (slow, mana efficient)
    if hp < 70 then
        -- Predictive overheal gate: skip slow HW cast if deficit is too small
        if predictive_overheal("HealingWave", target, 2.5, context.settings, 35, _spell_id(SHAMAN_SPELLS.HealingWave)) then return nil end
        heal_result.spell = SHAMAN_SPELLS.HealingWave or nil
        heal_result.label = "HW"
        heal_result.spell_type = "HealingWave"
        return heal_result
    end

    -- Moderate HP: < 90% -- Chain Heal (if 2+ injured nearby)
    if hp < 90 then
        -- Ensure we have scanned targets for the count check
        scan_healing_targets()
        local nearby_injured = healing_count_below_hp(healing_targets, healing_targets_count, 95)
        if nearby_injured >= 2 then
            if chain_heal_overheal(target, context.settings) then return nil end
            heal_result.spell = SHAMAN_SPELLS.ChainHeal or nil
            heal_result.label = "CH"
            heal_result.spell_type = "ChainHeal"
            return heal_result
        end
    end

    -- No suitable heal found (Riptide does not exist in TBC)
    return nil
end

NS.ShamanHealing.select_heal = select_heal

-- ============================================================================
-- NAMESPACE EXPORTS
-- ============================================================================
NS.ShamanHealing.is_in_raid = is_in_raid
NS.ShamanHealing.is_in_party = is_in_party

local spec_kit = require("shared/spec_kit_sylvanas")
local potion_helper = require("shared/potion_helper_sylvanas")
local define = spec_kit.define_action_for_class(SHAMAN_SPELLS)

local ACTION = {
    HealingWave       = define("HealingWave",       { 25396, 25391, 25357, 10468, 10467, 10466, 8005, 959, 547, 332, 331 }, "HealingWave"),
    LesserHealingWave = define("LesserHealingWave", { 25420, 10468, 10467, 10466, 8010, 8005, 8004 }, "LesserHealingWave"),
    ChainHeal         = define("ChainHeal",         { 25423, 25422, 10623, 10622, 1064 }, "ChainHeal"),
    EarthShield       = define("EarthShield",       { 32594, 32593, 974 }, "EarthShield"),
    WaterShield       = define("WaterShield",       { 33736, 24398 }, "WaterShield"),
    NaturesSwiftness  = define("NaturesSwiftness",  { 16188 }, "NaturesSwiftness"),
    CurePoison        = define("CurePoison",        { 526 }, "CurePoison"),
    CureDisease       = define("CureDisease",       { 2870 }, "CureDisease"),
    ManaTideTotem     = define("ManaTideTotem",     { 16190 }, "ManaTideTotem"),
    ManaSpringTotem   = define("ManaSpringTotem",   { 25570, 10497, 10496, 10495, 5675 }, "ManaSpringTotem"),
}

local WATER_SHIELD_BUFF = { 33736, 24398 }
local EARTH_SHIELD_BUFF = { 32594, 32593, 974 }
local NS_BUFF = { 16188 }
local HEALTHSTONE_IDS = { 22105, 22104, 22103, 19013, 19012, 19011, 5512 }

local EMERGENCY_HP = 30
local LHW_HP = 50
local HW_HP = 70
local CH_HP = 90

local HEAL_SCHEMA = { hp_pct = 100, mana_pct = 100, lowest_hp = 100 }

local heal_state = {
    lowest = nil,
    tank = nil,
    cleanse_target = nil,
    mana_pct = 100,
    hp_pct = 100,
    lowest_hp = 100,
    ns_active = false,
    ns_ready = false,
    hw_ready = false,
    lhw_ready = false,
    ch_ready = false,
    es_ready = false,
    ws_ready = false,
    cure_poison_ready = false,
    cure_disease_ready = false,
    mana_tide_ready = false,
    mana_spring_ready = false,
    has_water_shield = false,
    tank_has_earth_shield = false,
    healthstone_id = nil,
    injured_count = 0,
    in_combat = false,
    is_group = false,
    is_raid = false,
    is_solo = false,
    is_pvp = false,
    is_leveling = false,
}

local function first_ready_item(ids)
    if not NS.is_item_ready then return nil end
    for i = 1, #ids do
        if NS.is_item_ready(ids[i]) then return ids[i] end
    end
    return nil
end

local function gate_overheal(spell_key, unit, cast_time, settings, spell_id)
    if NS.HealerDeficit and NS.HealerDeficit.gate_spell_overheal then
        return NS.HealerDeficit.gate_spell_overheal(spell_key, unit, cast_time, settings, spell_id)
    end
    return NS.gate_overheal and NS.gate_overheal(spell_key, unit, cast_time, settings, spell_id) or false
end

local function build_state(context)
    context = context or {}
    local me = context.me or (NS.GetPlayer and NS.GetPlayer()) or NS.PLAYER_UNIT

    heal_state.in_combat = context.in_combat == true
    heal_state.is_group = context.is_group == true
    heal_state.is_raid = context.is_raid == true
    heal_state.is_solo = context.is_solo == true
    heal_state.is_pvp = context.is_pvp == true or context.is_arena == true or context.is_battleground == true
    heal_state.is_leveling = context.is_leveling == true
    heal_state.mana_pct = context.mana_pct or (me and NS.mana_pct and NS.mana_pct(me)) or 100
    heal_state.hp_pct = context.hp or context.hp_pct or (me and NS.unit_health_pct and NS.unit_health_pct(me)) or 100

    scan_healing_targets()
    heal_state.lowest = get_lowest_hp_target(CH_HP)
    heal_state.tank = get_tank_target()
    heal_state.cleanse_target = get_cleanse_target()
    heal_state.injured_count = healing_count_below_hp(healing_targets, healing_targets_count, 95)

    if context.friendly_target and context.friendly_target_hp then
        local ft_hp = context.friendly_target_hp or 100
        if ft_hp < entry_hp(heal_state.lowest) then
            heal_state.lowest = {
                unit = context.friendly_target,
                effective_hp = ft_hp,
                hp = ft_hp,
                deficit = context.friendly_target_deficit or 0,
            }
        end
    end

    local target = heal_state.lowest and heal_state.lowest.unit
    local tank_unit = heal_state.tank and heal_state.tank.unit
    heal_state.ns_active = me and NS.buff_up and NS.buff_up(me, NS_BUFF) or false
    heal_state.ns_ready = NS.spell_ready and NS.spell_ready(ACTION.NaturesSwiftness, me, { skip_range = true, expected_cooldown = 180 }) or false
    heal_state.hw_ready = target and NS.spell_ready and NS.spell_ready(ACTION.HealingWave, target) or false
    heal_state.lhw_ready = target and NS.spell_ready and NS.spell_ready(ACTION.LesserHealingWave, target) or false
    heal_state.ch_ready = target and NS.spell_ready and NS.spell_ready(ACTION.ChainHeal, target) or false
    heal_state.es_ready = tank_unit and NS.spell_ready and NS.spell_ready(ACTION.EarthShield, tank_unit) or false
    heal_state.ws_ready = NS.spell_ready and NS.spell_ready(ACTION.WaterShield, me, { skip_range = true }) or false
    heal_state.cure_poison_ready = NS.spell_ready and NS.spell_ready(ACTION.CurePoison, me, { skip_range = true }) or false
    heal_state.cure_disease_ready = NS.spell_ready and NS.spell_ready(ACTION.CureDisease, me, { skip_range = true }) or false
    heal_state.mana_tide_ready = NS.spell_ready and NS.spell_ready(ACTION.ManaTideTotem, me, { skip_range = true, expected_cooldown = 300 }) or false
    heal_state.mana_spring_ready = NS.spell_ready and NS.spell_ready(ACTION.ManaSpringTotem, me, { skip_range = true }) or false
    heal_state.has_water_shield = me and NS.buff_up and NS.buff_up(me, WATER_SHIELD_BUFF) or false
    heal_state.tank_has_earth_shield = tank_unit and NS.buff_up and NS.buff_up(tank_unit, EARTH_SHIELD_BUFF) or false
    heal_state.healthstone_id = first_ready_item(HEALTHSTONE_IDS)
    heal_state.lowest_hp = entry_hp(heal_state.lowest)

    return spec_kit.safe_state(heal_state, HEAL_SCHEMA)
end

local function cast_on(spell, unit, reason, opts)
    if not unit then return false end
    return NS.try_cast and NS.try_cast(spell, unit, reason, opts) or false
end

local function natures_swiftness_matches(context, state)
    if not state.ns_ready then return false end
    if state.ns_active then return false end
    if (state.lowest_hp or 100) > EMERGENCY_HP then return false end
    return true
end

local function ns_healing_wave_matches(context, state)
    if not state.ns_active then return false end
    if not state.hw_ready then return false end
    if (state.lowest_hp or 100) > EMERGENCY_HP then return false end
    return true
end

local function lesser_healing_wave_matches(context, state)
    if context.is_moving then return false end
    if not state.lhw_ready then return false end
    local target = state.lowest
    if not target or not target.unit then return false end
    local hp = entry_hp(target)
    if hp >= LHW_HP then return false end
    if gate_overheal("LesserHealingWave", target.unit, 1.5, context.settings) then return false end
    return true
end

local function healing_wave_matches(context, state)
    if context.is_moving then return false end
    if not state.hw_ready then return false end
    local target = state.lowest
    if not target or not target.unit then return false end
    local hp = entry_hp(target)
    if hp >= HW_HP or hp < LHW_HP then return false end
    if gate_overheal("HealingWave", target.unit, 2.5, context.settings) then return false end
    return true
end

local function chain_heal_matches(context, state)
    if context.is_moving then return false end
    if not state.ch_ready then return false end
    local target = state.lowest
    if not target or not target.unit then return false end
    if (entry_hp(target) or 100) >= CH_HP then return false end
    local group_aware = spec_kit.setting_bool(context, "shaman_group_aware_utility", true)
    if (state.injured_count or 0) < 2 and not (group_aware and context.is_raid) then return false end
    if gate_overheal("ChainHeal", target.unit, 2.5, context.settings) then return false end
    return true
end

local function earth_shield_matches(context, state)
    if not state.es_ready then return false end
    if state.tank_has_earth_shield then return false end
    if not state.tank or not state.tank.unit then return false end
    return true
end

local function water_shield_matches(context, state)
    if state.has_water_shield then return false end
    if not state.ws_ready then return false end
    return true
end

local function cure_poison_matches(context, state)
    if not state.cure_poison_ready then return false end
    local ct = state.cleanse_target
    if not ct or not ct.unit then return false end
    if not ct.has_poison then return false end
    return true
end

local function cure_disease_matches(context, state)
    if not state.cure_disease_ready then return false end
    local ct = state.cleanse_target
    if not ct or not ct.unit then return false end
    if not ct.has_disease then return false end
    return true
end

local function mana_tide_matches(context, state)
    if not context.in_combat then return false end
    if not state.mana_tide_ready then return false end
    if (state.mana_pct or 100) > 35 then return false end
    local group_aware = spec_kit.setting_bool(context, "shaman_group_aware_utility", true)
    if group_aware and not (context.is_group or context.is_raid) then return false end
    return true
end

local function mana_spring_matches(context, state)
    if context.in_combat then return false end
    if not state.mana_spring_ready then return false end
    return true
end

local function mana_potion_matches(context, state)
    if not context.in_combat then return false end
    if (state.mana_pct or 100) > 22 then return false end
    if not potion_helper or not potion_helper.try_use_potion then return false end
    return true
end

local function healthstone_matches(context, state)
    if not context.in_combat then return false end
    if (state.hp_pct or 100) > 35 then return false end
    if not state.healthstone_id then return false end
    return true
end

local strategies = {
    { name = "NaturesSwiftness", matches = natures_swiftness_matches,
      execute = function(context, state)
          local me = context.me or NS.PLAYER_UNIT
          return cast_on(ACTION.NaturesSwiftness, me, "[HEAL] Nature's Swiftness", { skip_range = true, expected_cooldown = 180 })
      end },
    { name = "NSHealingWave", matches = ns_healing_wave_matches,
      execute = function(context, state)
          return cast_on(ACTION.HealingWave, state.lowest.unit, "[HEAL] NS + Healing Wave")
      end },
    { name = "LesserHealingWave", matches = lesser_healing_wave_matches,
      execute = function(context, state)
          return cast_on(ACTION.LesserHealingWave, state.lowest.unit, "[HEAL] Lesser Healing Wave")
      end },
    { name = "HealingWave", matches = healing_wave_matches,
      execute = function(context, state)
          return cast_on(ACTION.HealingWave, state.lowest.unit, "[HEAL] Healing Wave")
      end },
    { name = "ChainHeal", matches = chain_heal_matches,
      execute = function(context, state)
          return cast_on(ACTION.ChainHeal, state.lowest.unit, "[HEAL] Chain Heal")
      end },
    { name = "EarthShield", matches = earth_shield_matches,
      execute = function(context, state)
          return cast_on(ACTION.EarthShield, state.tank.unit, "[HEAL] Earth Shield")
      end },
    { name = "WaterShield", matches = water_shield_matches,
      execute = function(context, state)
          local me = context.me or NS.PLAYER_UNIT
          return cast_on(ACTION.WaterShield, me, "[HEAL] Water Shield", { skip_range = true })
      end },
    { name = "CurePoison", matches = cure_poison_matches,
      execute = function(context, state)
          return cast_on(ACTION.CurePoison, state.cleanse_target.unit, "[HEAL] Cure Poison")
      end },
    { name = "CureDisease", matches = cure_disease_matches,
      execute = function(context, state)
          return cast_on(ACTION.CureDisease, state.cleanse_target.unit, "[HEAL] Cure Disease")
      end },
    { name = "ManaTideTotem", matches = mana_tide_matches,
      execute = function(context, state)
          local me = context.me or NS.PLAYER_UNIT
          return cast_on(ACTION.ManaTideTotem, me, "[HEAL] Mana Tide Totem", { skip_range = true, expected_cooldown = 300 })
      end },
    { name = "ManaSpringTotem", matches = mana_spring_matches,
      execute = function(context, state)
          local me = context.me or NS.PLAYER_UNIT
          return cast_on(ACTION.ManaSpringTotem, me, "[HEAL] Mana Spring Totem", { skip_range = true })
      end },
    { name = "ManaPotion", matches = mana_potion_matches,
      execute = function(context, state)
          return potion_helper.try_use_potion(context, potion_helper.MANA_POTION_IDS or {}) == true
      end },
    { name = "Healthstone", matches = healthstone_matches,
      execute = function(context, state)
          if state.healthstone_id and NS.use_item_by_id then
              return NS.use_item_by_id(state.healthstone_id) == true
          end
          return false
      end },
}

if NS.rotation_registry and NS.rotation_registry.register then
    NS.rotation_registry:register("healing", strategies, { get_state = build_state })
end
if NS.log then NS.log("Shaman healing rotation registered") end

NS.ShamanHealing.strategies = strategies
NS.ShamanHealing.build_state = build_state

return NS.ShamanHealing
