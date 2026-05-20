-- runtime module.

-- ============================================================================
-- EaxRotations - Project Sylvanas API
-- Build Configuration for api/ native API layer
-- ============================================================================

-- This file documents the load order for the Project Sylvanas API build.

-- IMPORTANT: Load order is critical - dependencies must load before dependents

-- [#16] SYLVANAS_API_LOAD_ORDER converted from live Lua table to block comment.
-- The actual load order is determined by main.lua require() calls, NOT by this table.
-- Keeping it as live Lua code in _G wasted memory for a table that was never iterated
-- or used programmatically. The comment below preserves the documentation.
--[[
    -- ============================================================================
    -- TIER 1: Core API Layer (from api/ folder)
    -- These are provided by the native runtime, NOT part of this addon
    -- ============================================================================
    -- api/core.lua              -- Native host API (provided by runtime)
    -- api/game_object.lua       -- Base object API (provided by runtime)
    -- api/menu.lua              -- Menu/widget API (provided by runtime)
    -- api/common/izi_sdk.lua    -- High-level SDK (provided by runtime)
    -- (Project Sylvanas does not expose rotation_api; EaxRotations uses local state.)

    -- ============================================================================
    -- TIER 2: Framework Core (Project Sylvanas API)
    -- Core framework files
    --
    -- IMPORTANT: The 'order' values below are for DOCUMENTATION ONLY.
    -- The actual load order is determined by main.lua require() calls.
    -- core_sylvanas MUST load first because it creates _G.EaxRotations.
    -- Do NOT reorder require() calls in main.lua to match these numbers.
    -- ============================================================================
    { file = "core_sylvanas.lua",     order = 10, description = "Core framework using api/ (MUST load first in main.lua)" },
    { file = "helpers_sylvanas.lua",   order = 10.5, description = "Shared helper import module (NS.import_helpers)" },
    { file = "explain_helpers_sylvanas.lua", order = 10.7, description = "Universal explain system (NS.explain_spell_gates, NS.explain_context_gates)" },
    { file = "optimizer.lua",         order = 11, description = "DecisionCache memoization layer" },
    { file = "shared/combat_log_parser_sylvanas.lua", order = 12, description = "CLEU-based damage/healing tracking with ring buffer" },
    { file = "dashboard_sylvanas.lua",   order = 13, description = "Combat overlay with resource bars" },
    { file = "debug_log_sylvanas.lua",  order = 14, description = "Debug log frame and diagnostics" },
    { file = "api_probe_sylvanas.lua",    order = 14.5, description = "API probe diagnostic (pcall-tests all API functions)" },
    { file = "sim_constants_sylvanas.lua", order = 15, description = "Sim-derived stat constants and combat table values" },
    { file = "gear_sets_sylvanas.lua",     order = 15.5, description = "TBC set item IDs and set-bonus spell IDs" },
    { file = "shared/mf_tick_compute_sylvanas.lua",   order = 16, description = "Shared MF tick computation (pure function, no NS deps, testable)" },
    { file = "shared/execute_phase_sylvanas.lua",    order = 17, description = "Shared execute phase / low-HP target gating (pure function, no NS deps, testable)" },
    { file = "shared/dot_refresh_sylvanas.lua",       order = 18, description = "Shared DoT refresh logic: APL haste-aware formula (pure function, no NS deps, testable)" },
    { file = "shared/force_command_sylvanas.lua",      order = 18.1, description = "Force command system for manual override keybinds" },
    { file = "shared/auto_tremor_sylvanas.lua",        order = 18.2, description = "Auto Tremor Totem for fear-casting bosses" },
    { file = "shared/purge_manager_sylvanas.lua",       order = 18.3, description = "Shaman purge dispel for enemy magic buffs" },
    { file = "shared/notification_sylvanas.lua",        order = 18.4, description = "Center-screen notifications for rotation events" },
    { file = "shared/aspect_manager_sylvanas.lua",       order = 18.5, description = "Hunter aspect manager for Viper/Hawk swapping" },
    
    -- ============================================================================
    -- TIER 2-4 FEATURES (Gap Analysis Implementation)
    -- ============================================================================
    -- PvP Core Foundation
    { file = "shared/dr_tracker_sylvanas.lua",           order = 18.6, description = "Diminishing Returns tracker for arena" },
    { file = "shared/enemy_cd_tracker_sylvanas.lua",      order = 18.7, description = "Enemy cooldown tracking" },
    { file = "shared/arena_priority_sylvanas.lua",      order = 18.8, description = "Arena target priority system" },
    { file = "shared/pvp_burst_window_sylvanas.lua",     order = 18.9, description = "PvP burst window scoring" },
    
    -- Rotation Infrastructure
    { file = "shared/strategy_factory_sylvanas.lua",     order = 19.1, description = "Strategy factory for reduced boilerplate" },
    { file = "shared/custom_rotation_sylvanas.lua",       order = 19.2, description = "Custom rotation engine" },
    
    -- Settings & Profiles
    { file = "shared/profile_manager_sylvanas.lua",      order = 19.3, description = "Profile save/load system" },
    
    -- Metrics, Gear, Swing
    { file = "shared/combat_stats_sylvanas.lua",         order = 19.4, description = "Combat statistics tracking" },
    { file = "shared/gear_score_sylvanas.lua",            order = 19.5, description = "Gear score calculator" },
    { file = "shared/swing_timer_sylvanas.lua",           order = 19.6, description = "Enhanced swing timer" },
    { file = "shared/weapon_imbue_sylvanas.lua",          order = 19.7, description = "Weapon imbue management" },
    
    -- UX/Optimization
    { file = "shared/spell_validation_sylvanas.lua",      order = 19.8, description = "Spell validation on load" },
    { file = "shared/talent_inference_sylvanas.lua",    order = 19.9, description = "Talent inference from spells" },
    { file = "shared/idle_suggestion_sylvanas.lua",      order = 20.0, description = "Idle action suggestions" },
    { file = "shared/benchmarks_sylvanas.lua",            order = 20.1, description = "Performance benchmarks" },
    
    { file = "main_sylvanas.lua",                     order = 21, description = "Reusable rotation dispatcher loaded before class registration in main.lua" },

    -- ============================================================================
    -- TIER 3: Class Modules (converted to api/ pattern)
    -- Each class has: schema -> class -> middleware -> playstyles
    -- ============================================================================
    -- DRUID
    { file = "classes/druid/schema_sylvanas.lua",      order = 20, class = "druid" },
    { file = "classes/druid/class_sylvanas.lua",       order = 21, class = "druid" },
    { file = "classes/druid/middleware_sylvanas.lua",  order = 22, class = "druid" },
    { file = "classes/druid/healing_sylvanas.lua",     order = 23, class = "druid" },
    { file = "classes/druid/cat_sylvanas.lua",         order = 24, class = "druid" },
    { file = "classes/druid/bear_sylvanas.lua",        order = 25, class = "druid" },
    { file = "classes/druid/balance_sylvanas.lua",     order = 26, class = "druid" },
    { file = "classes/druid/resto_sylvanas.lua",       order = 27, class = "druid" },
    { file = "classes/druid/caster_sylvanas.lua",      order = 28, class = "druid" },

    -- HUNTER
    { file = "classes/hunter/schema_sylvanas.lua",      order = 30, class = "hunter" },
    { file = "classes/hunter/class_sylvanas.lua",       order = 31, class = "hunter" },
    { file = "classes/hunter/middleware_sylvanas.lua",  order = 32, class = "hunter" },
    { file = "classes/hunter/cliptracker_sylvanas.lua", order = 33, class = "hunter" },
    { file = "classes/hunter/debugui_sylvanas.lua",    order = 33, class = "hunter" },
    { file = "classes/hunter/beast_mastery_sylvanas.lua", order = 34, class = "hunter" },
    { file = "classes/hunter/marksmanship_sylvanas.lua",  order = 35, class = "hunter" },
    { file = "classes/hunter/survival_sylvanas.lua",      order = 36, class = "hunter" },

    -- MAGE
    { file = "classes/mage/schema_sylvanas.lua",      order = 40, class = "mage" },
    { file = "classes/mage/class_sylvanas.lua",       order = 41, class = "mage" },
    { file = "classes/mage/middleware_sylvanas.lua",  order = 42, class = "mage" },
    { file = "classes/mage/arcane_sylvanas.lua",      order = 43, class = "mage" },
    { file = "classes/mage/fire_sylvanas.lua",        order = 44, class = "mage" },
    { file = "classes/mage/frost_sylvanas.lua",       order = 45, class = "mage" },

    -- PALADIN
    { file = "classes/paladin/schema_sylvanas.lua",       order = 50, class = "paladin" },
    { file = "classes/paladin/class_sylvanas.lua",        order = 51, class = "paladin" },
    { file = "classes/paladin/middleware_sylvanas.lua",   order = 52, class = "paladin" },
    { file = "classes/paladin/healing_sylvanas.lua",      order = 53, class = "paladin" },
    { file = "classes/paladin/retribution_sylvanas.lua",  order = 54, class = "paladin" },
    { file = "classes/paladin/protection_sylvanas.lua",   order = 55, class = "paladin" },
    { file = "classes/paladin/holy_sylvanas.lua",         order = 56, class = "paladin" },

    -- PRIEST
    { file = "classes/priest/schema_sylvanas.lua",       order = 60, class = "priest" },
    { file = "classes/priest/class_sylvanas.lua",        order = 61, class = "priest" },
    { file = "classes/priest/middleware_sylvanas.lua",   order = 62, class = "priest" },
    { file = "classes/priest/healing_sylvanas.lua",      order = 63, class = "priest" },
    { file = "classes/priest/shadow_sylvanas.lua",       order = 64, class = "priest" },
    { file = "classes/priest/discipline_sylvanas.lua",   order = 65, class = "priest" },
    { file = "classes/priest/holy_sylvanas.lua",         order = 66, class = "priest" },
    { file = "classes/priest/smite_sylvanas.lua",       order = 67, class = "priest" },

    -- ROGUE
    { file = "classes/rogue/schema_sylvanas.lua",        order = 70, class = "rogue" },
    { file = "classes/rogue/class_sylvanas.lua",         order = 71, class = "rogue" },
    { file = "classes/rogue/middleware_sylvanas.lua",    order = 72, class = "rogue" },
    { file = "classes/rogue/assassination_sylvanas.lua", order = 73, class = "rogue" },
    { file = "classes/rogue/combat_sylvanas.lua",        order = 74, class = "rogue" },
    { file = "classes/rogue/subtlety_sylvanas.lua",      order = 75, class = "rogue" },

    -- SHAMAN
    { file = "classes/shaman/schema_sylvanas.lua",       order = 80, class = "shaman" },
    { file = "classes/shaman/class_sylvanas.lua",        order = 81, class = "shaman" },
    { file = "classes/shaman/middleware_sylvanas.lua",   order = 82, class = "shaman" },
    { file = "classes/shaman/healing_sylvanas.lua",      order = 83, class = "shaman" },
    { file = "classes/shaman/elemental_sylvanas.lua",    order = 84, class = "shaman" },
    { file = "classes/shaman/enhancement_sylvanas.lua",  order = 85, class = "shaman" },
    { file = "classes/shaman/restoration_sylvanas.lua",  order = 86, class = "shaman" },

    -- WARLOCK
    { file = "classes/warlock/schema_sylvanas.lua",      order = 90, class = "warlock" },
    { file = "classes/warlock/class_sylvanas.lua",      order = 91, class = "warlock" },
    { file = "classes/warlock/middleware_sylvanas.lua",  order = 92, class = "warlock" },
    { file = "classes/warlock/affliction_sylvanas.lua",  order = 93, class = "warlock" },
    { file = "classes/warlock/demonology_sylvanas.lua",  order = 94, class = "warlock" },
    { file = "classes/warlock/destruction_sylvanas.lua", order = 95, class = "warlock" },

    -- WARRIOR
    { file = "classes/warrior/schema_sylvanas.lua",      order = 100, class = "warrior" },
    { file = "classes/warrior/class_sylvanas.lua",       order = 101, class = "warrior" },
    { file = "classes/warrior/middleware_sylvanas.lua",  order = 102, class = "warrior" },
    { file = "classes/warrior/arms_sylvanas.lua",        order = 103, class = "warrior" },
    { file = "classes/warrior/kebab_sylvanas.lua",       order = 103.5, class = "warrior" },
    { file = "classes/warrior/fury_sylvanas.lua",        order = 104, class = "warrior" },
    { file = "classes/warrior/protection_sylvanas.lua",  order = 105, class = "warrior" },

--]]

-- ============================================================================
-- FILE NAMING CONVENTION
-- ============================================================================
-- API Edition files use "_sylvanas" suffix
-- During transition period, both may exist. Eventually the _sylvanas files
-- will replace the originals.

-- ============================================================================
-- MIGRATION STATUS
-- ============================================================================
-- luacheck: ignore 221 SYLVANAS_MIGRATION_STATUS
SYLVANAS_MIGRATION_STATUS = {
    framework = {
        core_sylvanas = "COMPLETED",
        main_sylvanas = "COMPLETED",
        optimizer = "TRIMMED", -- Removed dead RotationIR, EventScheduler, CombatForecast, Profiler; kept DecisionCache only
        explain_helpers_sylvanas = "COMPLETED",
        api_probe_sylvanas = "COMPLETED",
        dashboard_sylvanas = "COMPLETED",
        debug_log_sylvanas = "COMPLETED",
    },
    classes = {
        druid = { all = "COMPLETED" },
        hunter = { all = "COMPLETED" },
        mage = { all = "COMPLETED" },
        paladin = { all = "COMPLETED" },
        priest = { all = "COMPLETED" },
        rogue = { all = "COMPLETED" },
        shaman = { all = "COMPLETED" },
        warlock = { all = "COMPLETED" },
        warrior = { all = "COMPLETED" },
    }
}

-- ============================================================================
-- API BOUNDARY NOTES
-- ============================================================================
--[[

EaxRotations class modules should consume the project-owned NS.* boundary.
Raw Project Sylvanas helpers belong in core_sylvanas.lua or focused shared
wrappers, not scattered through class/spec files.

-- Additional izi_sdk methods available:
unit:time_to_die()           -> TTD prediction
unit:distance()              -> Distance to target
unit:is_casting()            -> Cast state
unit:is_channeling()         -> Channel state
unit:buff_remains(id)        -> Buff duration
unit:debuff_remains(id)      -> Debuff duration
unit:combo_points_current()  -> Combo points

--]]

NS.log("API Load Order Configuration loaded")
NS.log("EaxRotations load-order metadata loaded")
