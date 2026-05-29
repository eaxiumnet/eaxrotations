-- ============================================================================
-- Shaman Healing Utilities (EaxRotations)
-- Party/raid scanning and healing utilities for Restoration Shaman
local _G = _G
local NS = _G.EaxRotations
if not NS then
    print("[EaxRotations ERROR] Core module not loaded!")
    return nil
end

local _ok_enums, enums = pcall(require, "common/enums")
if not _ok_enums or type(enums) ~= "table" or type(enums.class_id) ~= "table" then enums = { class_id = NS.CLASS_ID } end
local load_player = NS.GetPlayer()
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

local function predictive_overheal(spell_key, entry, cast_time, settings, emergency_hp)
    if not entry or not entry.unit then return false end
    if entry_hp(entry) <= (emergency_hp or 30) then return false end
    if (entry.time_to_die or 999) <= cast_time then return false end
    if NS.HealerDeficit and NS.HealerDeficit.gate_spell_overheal then
        return NS.HealerDeficit.gate_spell_overheal(spell_key, entry.unit, cast_time, settings)
    end
    return NS.gate_overheal and NS.gate_overheal(spell_key, entry.unit, cast_time, settings) or false
end

local function chain_heal_overheal(entry, settings)
    if not entry or not entry.unit then return false end
    if entry_hp(entry) <= 35 then return false end
    if (entry.time_to_die or 999) <= 2.5 then return false end
    if NS.HealerDeficit and NS.HealerDeficit.heal_would_overheal then
        return NS.HealerDeficit.heal_would_overheal(entry.unit, 1800, 2.5, settings)
    end
    return predictive_overheal("ChainHeal", entry, 2.5, settings, 35)
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
        if NS.gate_overheal("LesserHealingWave", target.unit, 1.5, context.settings) then return nil end
        heal_result.spell = SHAMAN_SPELLS.LesserHealingWave or nil
        heal_result.label = "LHW"
        heal_result.spell_type = "LesserHealingWave"
        return heal_result
    end

    -- Medium HP: < 70% -- Healing Wave (slow, mana efficient)
    if hp < 70 then
        -- Predictive overheal gate: skip slow HW cast if deficit is too small
        if NS.gate_overheal("HealingWave", target.unit, 2.5, context.settings) then return nil end
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

NS.log("Shaman healing utilities loaded")
return NS.ShamanHealing
