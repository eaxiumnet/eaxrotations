-- ============================================================================
-- Priest Holy Rotation (strict local api/ production port)
-- ============================================================================
-- Readability notes:
--   What: Holy Priest priority list for emergency shields, HoTs, group healing, and direct heals.
--   When: dispatcher selects the Holy playstyle for a Priest healer.
--   Why: priorities mirror healer decision-making instead of pretending healing is a fixed rotation.
--   Safety: spell existence, mana, effective HP, and target validity are checked before casting.
local _G = _G
local NS = _G.EaxRotations
if not NS then return end

-- Decision notes:
--   Playstyle files are ordered priority lists: earlier strategies must be more urgent or more time-sensitive.
--   Matches functions explain when an action is allowed; execute functions only perform the already-gated cast.
--   Role logic follows TBC expectations and avoids post-TBC spells, speculative target swaps, and impossible casts.

local load_player = NS.GetPlayer()

local enums = require("common/enums")
if type(enums) ~= "table" or type(enums.class_id) ~= "table" then enums = { class_id = NS.CLASS_ID } end
if not load_player or load_player:get_class() ~= enums.class_id.PRIEST then return end

local SPELLS = NS.PriestSpells

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

local format = string.format
-- ipairs unused in holy (no ipairs iteration needed)
local tostring = tostring

-- ============================================================================
-- IMPORT SHARED RANK TABLES + UTILITIES (from class_sylvanas.lua)
-- class_sylvanas.lua loads at order=61, holy at order=66 — safe to import.
-- ============================================================================
local FLASH_HEAL_RANKS = NS.PriestFLASH_HEAL_RANKS
local GREATER_HEAL_RANKS = NS.PriestGREATER_HEAL_RANKS
local PRAYER_OF_HEALING_RANKS = NS.PriestPRAYER_OF_HEALING_RANKS
local BINDING_HEAL_RANKS = NS.PriestBINDING_HEAL_RANKS
local cast_best_heal_rank = NS.cast_best_heal_rank or function() return false end

local INNER_FOCUS_BUFF = 14751
local SURGE_OF_LIGHT_BUFF = { 33151, 33154 }
local HOLY_CONCENTRATION_BUFF = { 34753, 34754, 34859, 34860 }
-- RENEW_BUFF removed: unused (holy uses Healing.scan_healing_targets for buff tracking)
-- WEAKENED_SOUL_DEBUFF removed: unused (holy uses state.lowest.has_weakened_soul from Healing scan)
local SHADOW_WORD_PAIN_DEBUFF = { 589, 594, 970, 992, 2767, 10892, 10893, 25367, 25368 }
local HOLY_FIRE_DOT_DEBUFF = { 14914, 15262, 15263, 15264, 15265, 15266, 15267, 15261, 25384 }

-- [PRE-ALLOC] Heal rank option tables — created once at load time, not per-frame in execute().
-- Avoids Lua 5.1 GC pressure from repeated inline table creation in combat path.
local HOLY_OPTS_EMERGENCY_FH = { prioritize_speed = true, cast_time = 1.5, overheal_threshold = 1.4 }
local HOLY_OPTS_BH = { bh_coefficient = true, cast_time = 2.0, overheal_threshold = 1.3 }
local HOLY_OPTS_CLEARCAST_GH = { prioritize_efficiency = true, gh_coefficient = true, cast_time = 2.5, overheal_threshold = 1.3 }
local HOLY_OPTS_GH = { gh_coefficient = true, cast_time = 2.5, overheal_threshold = 1.3 }
local HOLY_OPTS_FH = { cast_time = 1.5, overheal_threshold = 1.3 }
local HOLY_OPTS_POH = { poh_coefficient = true, cast_time = 3.0, overheal_threshold = 1.3 }

local holy_state = {
    lowest = nil,
    lowest_hp = 100,
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
}
-- Shared helpers from core_sylvanas.lua
local try_cast, spell_exists, spell_ready, debuff_remains, health_pct, player_control_locked, has_player_buff = NS.import_helpers(
    "try_cast", "spell_exists", "spell_ready", "debuff_remains", "health_pct",
    "player_control_locked", "has_player_buff"
)
-- debuff_up removed: unused in holy (debuff_remains used instead for SWP/Holy Fire tracking)

-- is_same_unit removed: unused in holy (no unit comparison needed)

local function build_holy_state(context)
    local aoe_hp = context.settings.holy_aoe_hp or 80
    local lowest_entry = nil
    local tank_entry = nil
    local lowest_hp = 100
    local tank_hp = 100
    local damaged_count = 0

    local player = NS.GetPlayer()
    context.player_control_locked = player_control_locked()
    context.is_moving = context.is_moving or (player.is_moving and player:is_moving()) or false
    context.hp = health_pct(NS.PLAYER_UNIT)
    context.mana_pct = context.player_mana_pct or (player.mana_pct and player:mana_pct()) or 100

    if Healing.scan_healing_targets then
        local entries, count = Healing.scan_healing_targets()
        if entries and count and count > 0 then
            lowest_entry = entries[1]
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
    end

    holy_state.lowest = lowest_entry
    holy_state.lowest_hp = lowest_hp
    holy_state.tank = tank_entry
    holy_state.tank_hp = tank_hp
    holy_state.group_damaged_count = damaged_count
    holy_state.surge_of_light = has_player_buff(SURGE_OF_LIGHT_BUFF)
    holy_state.clearcasting = has_player_buff(HOLY_CONCENTRATION_BUFF)
    holy_state.pom_ready = spell_exists(SPELLS.PrayerofMending) and spell_ready(SPELLS.PrayerofMending, (tank_entry and tank_entry.unit) or NS.PLAYER_UNIT)
    holy_state.coh_ready = spell_exists(SPELLS.CircleofHealing) and spell_ready(SPELLS.CircleofHealing, (lowest_entry and lowest_entry.unit) or NS.PLAYER_UNIT)
    holy_state.has_inner_focus = has_player_buff(INNER_FOCUS_BUFF)
    holy_state.swp_remaining = context.target and debuff_remains(context.target, SHADOW_WORD_PAIN_DEBUFF) or 0
    holy_state.holy_fire_remaining = context.target and debuff_remains(context.target, HOLY_FIRE_DOT_DEBUFF) or 0

    return holy_state
end

local strategies = {
    {
        name = "EmergencyPWS",
        matches = function(context, state)
            if context.player_control_locked then return false end
            if context.settings.holy_use_pws == false then return false end
            if not state.lowest then return false end
            if state.lowest.effective_hp > (context.settings.holy_pws_hp or 30) then return false end
            if state.lowest.has_weakened_soul then return false end
            return spell_exists(SPELLS.PowerWordShield) and spell_ready(SPELLS.PowerWordShield, state.lowest.unit)
        end,
        execute = function(_, state)
            return try_cast(SPELLS.PowerWordShield, state.lowest.unit, format("[HOLY] Emergency PW:S %.0f%%", state.lowest.effective_hp or 0))
        end,
    },
    {
        name = "EmergencyFlashHeal",
        matches = function(context, state)
            if not context.in_combat then return false end
            if context.player_control_locked or context.is_moving then return false end
            if not state.lowest then return false end
            return state.lowest_hp < (context.settings.holy_emergency_hp or 30)
        end,
        execute = function(context, state)
            local target = state.lowest.unit
            local chosen_spell, spell_label = cast_best_heal_rank(FLASH_HEAL_RANKS, target, context, "Emergency FH", HOLY_OPTS_EMERGENCY_FH)
            if not chosen_spell then return false end
            return try_cast(chosen_spell, target, format("[HOLY] %s %.0f%%", spell_label, state.lowest.effective_hp or 0))
        end,
    },
    {
        name = "PrayerOfMending",
        matches = function(context, state)
            if context.player_control_locked then return false end
            if not state.pom_ready then return false end
            if not context.in_combat and context.settings.holy_prepull_pom == false then return false end
            return state.tank ~= nil or state.lowest ~= nil
        end,
        execute = function(_, state)
            local target = (state.tank and state.tank.unit) or (state.lowest and state.lowest.unit) or NS.PLAYER_UNIT
            local hp = (state.tank and state.tank.effective_hp) or (state.lowest and state.lowest.effective_hp) or 100
            return try_cast(SPELLS.PrayerofMending, target, format("[HOLY] Prayer of Mending %.0f%%", hp))
        end,
    },
    {
        name = "CircleOfHealing",
        matches = function(context, state)
            if not context.in_combat then return false end
            if context.player_control_locked then return false end
            if context.settings.holy_use_coh == false then return false end
            if not state.coh_ready then return false end
            return state.group_damaged_count >= (context.settings.holy_aoe_count or 3)
        end,
        execute = function(_, state)
            local target = (state.lowest and state.lowest.unit) or (state.tank and state.tank.unit) or NS.PLAYER_UNIT
            return try_cast(SPELLS.CircleofHealing, target, format("[HOLY] Circle of Healing count=%d", state.group_damaged_count or 0))
        end,
    },
    {
        name = "BindingHeal",
        matches = function(context, state)
            if not context.in_combat then return false end
            if context.player_control_locked or context.is_moving then return false end
            if context.settings.holy_use_binding_heal == false then return false end
            if context.hp > (context.settings.holy_binding_self_hp or 80) then return false end
            if not state.lowest or state.lowest.is_player then return false end
            return spell_exists(SPELLS.BindingHeal) and spell_ready(SPELLS.BindingHeal, state.lowest.unit)
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
            if context.settings.holy_use_poh == false then return false end
            return state.group_damaged_count >= (context.settings.holy_aoe_count or 3)
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
            if not state.lowest then return false end
            return state.lowest_hp < 95
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
            if context.settings.holy_use_inner_focus == false then return false end
            if state.has_inner_focus then return false end
            if not spell_exists(SPELLS.InnerFocus) or not spell_ready(SPELLS.InnerFocus, NS.PLAYER_UNIT) then return false end
            if not state.lowest then return false end
            return state.lowest_hp < (context.settings.holy_renew_hp or 90)
        end,
        execute = function()
            return try_cast(SPELLS.InnerFocus, NS.PLAYER_UNIT, "[HOLY] Inner Focus")
        end,
    },
    {
        name = "GreaterHeal",
        matches = function(context, state)
            if not context.in_combat then return false end
            if context.player_control_locked or context.is_moving then return false end
            if not state.lowest then return false end
            local flash_hp = context.settings.holy_flash_heal_hp or 50
            local renew_hp = context.settings.holy_renew_hp or 90
            return state.lowest_hp < renew_hp and state.lowest_hp >= flash_hp
        end,
        execute = function(context, state)
            local target = state.lowest.unit
            local chosen_spell, spell_label = cast_best_heal_rank(GREATER_HEAL_RANKS, target, context, "GH", HOLY_OPTS_GH)
            if not chosen_spell then return false end
            return try_cast(chosen_spell, target, format("[HOLY] %s %.0f%%", spell_label, state.lowest.effective_hp or 0))
        end,
    },
    {
        name = "FlashHeal",
        matches = function(context, state)
            if not context.in_combat then return false end
            if context.player_control_locked or context.is_moving then return false end
            if not state.lowest then return false end
            return state.lowest_hp < (context.settings.holy_flash_heal_hp or 50)
        end,
        execute = function(context, state)
            local target = state.lowest.unit
            local chosen_spell, spell_label = cast_best_heal_rank(FLASH_HEAL_RANKS, target, context, "FH", HOLY_OPTS_FH)
            if not chosen_spell then return false end
            return try_cast(chosen_spell, target, format("[HOLY] %s %.0f%%", spell_label, state.lowest.effective_hp or 0))
        end,
    },
    {
        name = "RenewTank",
        matches = function(context, state)
            if context.player_control_locked then return false end
            if not state.tank then return false end
            if not spell_exists(SPELLS.Renew) or not spell_ready(SPELLS.Renew, state.tank.unit) then return false end
            if not context.in_combat and context.settings.holy_prepull_renew == false then return false end
            if state.tank.has_renew then return false end

            local threshold = context.settings.holy_renew_hp or 90
            if state.tank.effective_hp > threshold and context.in_combat then
                return false
            end

            return true
        end,
        execute = function(_, state)
            return try_cast(SPELLS.Renew, state.tank.unit, format("[HOLY] Renew Tank %.0f%%", state.tank.effective_hp or 0))
        end,
    },
    {
        name = "RenewSpread",
        matches = function(context, state)
            if not context.in_combat then return false end
            if context.player_control_locked then return false end
            if not state.lowest then return false end
            if state.lowest.has_renew then return false end
            if not spell_exists(SPELLS.Renew) or not spell_ready(SPELLS.Renew, state.lowest.unit) then return false end
            return state.lowest_hp < (context.settings.holy_renew_hp or 90)
        end,
        execute = function(_, state)
            return try_cast(SPELLS.Renew, state.lowest.unit, format("[HOLY] Renew %.0f%%", state.lowest.effective_hp or 0))
        end,
    },
    {
        name = "SurgeOfLightSmite",
        matches = function(context, state)
            if not context.in_combat then return false end
            if context.player_control_locked then return false end
            if not state.surge_of_light then return false end
            if not context.has_valid_enemy_target then return false end
            if state.lowest_hp < (context.settings.holy_flash_heal_hp or 50) then return false end
            return spell_exists(SPELLS.Smite) and spell_ready(SPELLS.Smite, context.target)
        end,
        execute = function(context)
            return try_cast(SPELLS.Smite, context.target, "[HOLY] Surge of Light Smite")
        end,
    },
    {
        name = "IdleSWP",
        matches = function(context, state)
            if not context.in_combat then return false end
            if context.player_control_locked then return false end
            if not context.settings.holy_dps_when_idle then return false end
            if not context.has_valid_enemy_target then return false end
            if state.lowest_hp < (context.settings.holy_renew_hp or 90) then return false end
            if context.mana_pct < (context.settings.holy_dps_mana_floor or 70) then return false end
            if state.swp_remaining > 0 then return false end
            return spell_exists(SPELLS.ShadowWordPain) and spell_ready(SPELLS.ShadowWordPain, context.target)
        end,
        execute = function(context)
            return try_cast(SPELLS.ShadowWordPain, context.target, "[HOLY] Idle SW:P")
        end,
    },
    {
        name = "IdleHolyFire",
        matches = function(context, state)
            if not context.in_combat then return false end
            if context.player_control_locked or context.is_moving then return false end
            if not context.settings.holy_dps_when_idle then return false end
            if not context.has_valid_enemy_target then return false end
            if state.lowest_hp < (context.settings.holy_renew_hp or 90) then return false end
            if context.mana_pct < (context.settings.holy_dps_mana_floor or 70) then return false end
            if state.holy_fire_remaining > 0 then return false end
            return spell_exists(SPELLS.HolyFire) and spell_ready(SPELLS.HolyFire, context.target)
        end,
        execute = function(context)
            return try_cast(SPELLS.HolyFire, context.target, "[HOLY] Idle Holy Fire")
        end,
    },
    {
        name = "IdleSmite",
        matches = function(context, state)
            if not context.in_combat then return false end
            if context.player_control_locked or context.is_moving then return false end
            if not context.settings.holy_dps_when_idle then return false end
            if not context.has_valid_enemy_target then return false end
            if state.lowest_hp < (context.settings.holy_renew_hp or 90) then return false end
            if context.mana_pct < (context.settings.holy_dps_mana_floor or 70) then return false end
            return spell_exists(SPELLS.Smite) and spell_ready(SPELLS.Smite, context.target)
        end,
        execute = function(context)
            return try_cast(SPELLS.Smite, context.target, "[HOLY] Idle Smite")
        end,
    },
}

NS.rotation_registry:register("holy", strategies, {
    get_state = build_holy_state,
    format_context_log = function(_, state)
        return format(
            "lowest=%.0f tank=%.0f damaged=%d sol=%s clear=%s",
            state.lowest_hp or 100,
            state.tank_hp or 100,
            state.group_damaged_count or 0,
            tostring(state.surge_of_light),
            tostring(state.clearcasting)
        )
    end,
})

NS.log("Holy priest rotation registered")
return strategies
