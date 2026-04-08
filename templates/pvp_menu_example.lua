-- PvP Menu Integration Example for EAX Specs
-- This file demonstrates how to integrate pvp_menu_template into your spec's menu.lua
-- Copy the relevant sections into your actual menu.lua file

-- ============================================================================
-- STEP 1: At the top of your menu.lua, require the template
-- ============================================================================

local pvp_template = require("templates.pvp_menu_template")

-- ============================================================================
-- STEP 2: Merge PvP settings into your menu structure
-- ============================================================================

-- Example: Original menu structure (your existing menu.lua)
local menu = {
    header = "EAXWarriorFury",
    settings = {
        -- General Settings
        {
            key = "enabled",
            type = "checkbox",
            default = true,
            label = "Enable Rotation",
        },
        {
            key = "mode",
            type = "combobox",
            default = 1,
            options = {"Auto", "PvE", "PvP"},
            label = "Rotation Mode",
        },

        -- Combat Settings
        {
            key = "combat_header",
            type = "header",
            label = "Combat",
        },
        {
            key = "use_cooldowns",
            type = "checkbox",
            default = true,
            label = "Use Cooldowns",
        },

        -- Defensive Settings
        {
            key = "defensive_header",
            type = "header",
            label = "Defensive",
        },
        {
            key = "defensive_threshold",
            type = "slider",
            default = 40,
            min = 10,
            max = 100,
            label = "Defensive Threshold (%)",
        },

        -- ============================================================================
        -- STEP 3: Add PvP section by including the template settings
        -- ============================================================================

        -- PvP Header
        {
            key = "pvp_header",
            type = "header",
            label = pvp_template.header,
        },

        -- Insert all PvP settings from template
        -- Option A: Direct insertion (copy-paste the settings table)
        -- Option B: Programmatic merge (shown below)
    },
}

-- ============================================================================
-- STEP 4: Programmatic merge approach (recommended)
-- Add this after your menu definition
-- ============================================================================

-- Function to merge PvP settings into existing menu
function merge_pvp_settings(menu_table, pvp_template)
    -- Find where to insert (after defensive section, before first spell section)
    local insert_index = #menu_table.settings + 1

    -- Add PvP header
    table.insert(menu_table.settings, insert_index, {
        key = "pvp_header",
        type = "header",
        label = pvp_template.header,
    })
    insert_index = insert_index + 1

    -- Add all PvP settings
    for _, setting in ipairs(pvp_template.settings) do
        table.insert(menu_table.settings, insert_index, setting)
        insert_index = insert_index + 1
    end

    return menu_table
end

-- Apply the merge
menu = merge_pvp_settings(menu, pvp_template)

-- ============================================================================
-- STEP 5: Alternative - Manual integration (copy-paste approach)
-- ============================================================================

-- If you prefer manual control, copy these settings directly into your menu.lua:
--[[
    {
        key = "pvp_header",
        type = "header",
        label = "PvP",
    },
    {
        key = "pvp_enabled",
        type = "checkbox",
        default = true,
        label = "Enable PvP Mode",
        tooltip = "Enable PvP-specific logic. Auto-detected via BG/Arena/PvP flag.",
    },
    {
        key = "pvp_mode",
        type = "combobox",
        default = 1,
        options = {"Auto", "PvE Only", "PvP Only"},
        label = "PvP Mode Selection",
        tooltip = "Auto detects PvP context. Override here if needed.",
    },
    {
        key = "pvp_hamstring",
        type = "checkbox",
        default = true,
        label = "Maintain Hamstring",
        tooltip = "Keep Hamstring on enemy players. Skips immune targets.",
    },
    {
        key = "pvp_piercing_howl",
        type = "checkbox",
        default = true,
        label = "Piercing Howl (AoE Snare)",
        tooltip = "Use Piercing Howl when 2+ enemies lack a slow.",
    },
    {
        key = "pvp_rend_stealth",
        type = "checkbox",
        default = true,
        label = "Rend Anti-Stealth",
        tooltip = "Apply Rend to Rogues/Druids to prevent stealth.",
    },
    {
        key = "pvp_overpower_evasion",
        type = "checkbox",
        default = true,
        label = "Overpower vs Evasion",
        tooltip = "Prioritize Overpower against Evasion/Deterrence.",
    },
    {
        key = "pvp_disarm",
        type = "checkbox",
        default = true,
        label = "Auto Disarm",
        tooltip = "Disarm enemy melee players.",
    },
    {
        key = "pvp_disarm_trigger",
        type = "combobox",
        default = 1,
        options = {"On Cooldown", "On Enemy Burst"},
        label = "Disarm Trigger",
        tooltip = "When to use Disarm ability.",
    },
    {
        key = "pvp_interrupt_cc_fallback",
        type = "checkbox",
        default = true,
        label = "CC Interrupt Fallback",
        tooltip = "Use CC as interrupt backup when kick is on CD.",
    },
    {
        key = "pvp_def_stance_range",
        type = "checkbox",
        default = true,
        label = "Def Stance at Range",
        tooltip = "Auto-switch to Defensive Stance when out of melee.",
    },
    {
        key = "pvp_trinket_defensive",
        type = "checkbox",
        default = true,
        label = "PvP Trinket Defensive",
        tooltip = "Use PvP trinket for defensive dispels (CC removal).",
    },
    {
        key = "pvp_burst_threshold",
        type = "slider",
        default = 60,
        min = 10,
        max = 100,
        label = "Burst Threshold (%)",
        tooltip = "Target health % to trigger burst cooldowns.",
    },
    {
        key = "pvp_save_cooldowns",
        type = "checkbox",
        default = false,
        label = "Save Cooldowns vs Healers",
        tooltip = "Don't waste burst CDs on targets with strong healing.",
    },
    {
        key = "pvp_focus_healers",
        type = "checkbox",
        default = true,
        label = "Focus Healers",
        tooltip = "Prioritize healer targets in arena/BG.",
    },
    {
        key = "pvp_target_swapping",
        type = "checkbox",
        default = true,
        label = "Smart Target Swapping",
        tooltip = "Swap to low-health targets when current target is healed.",
    },
    {
        key = "pvp_auto_self_cast",
        type = "checkbox",
        default = true,
        label = "Auto Self-Cast",
        tooltip = "Auto-cast beneficial spells on self when no friendly target.",
    },
--]]

-- ============================================================================
-- STEP 6: Usage in main.lua - Detect PvP context
-- ============================================================================

--[[
-- At top of main.lua:
local pvp_template = require("templates.pvp_menu_template")

-- In your on_update or rotation function:
local function on_update()
    local me = core.object_manager.get_local_player()
    local target = core.object_manager.get_target()

    -- Detect PvP context
    local is_pvp, is_arena, is_battleground, target_is_player =
        pvp_template.detect_pvp_context(me, target)

    -- Build context table
    local context = {
        is_pvp = is_pvp,
        is_arena = is_arena,
        is_battleground = is_battleground,
        target_is_player = target_is_player,
    }

    -- Check if PvP mode is active
    if pvp_template.is_pvp_active(menu, context) then
        -- Run PvP rotation logic
        run_pvp_rotation(me, target, context)
    else
        -- Run PvE rotation logic
        run_pve_rotation(me, target)
    end
end
--]]

-- ============================================================================
-- STEP 7: Usage in main.lua - Check individual settings
-- ============================================================================

--[[
-- Check if specific PvP feature is enabled:
if pvp_template.is_enabled(menu, "pvp_hamstring") then
    -- Apply hamstring logic
end

-- Get slider value with default:
local burst_threshold = pvp_template.get_value(menu, "pvp_burst_threshold", 60)
if target:get_health_percentage() < burst_threshold then
    -- Use burst cooldowns
end

-- Check if target can stealth:
local target_class = target:get_class()
if pvp_template.can_stealth(target_class) and pvp_template.is_enabled(menu, "pvp_rend_stealth") then
    -- Apply Rend to prevent stealth
end
--]]

-- ============================================================================
-- STEP 8: Complete integration example for Warrior Fury
-- ============================================================================

local warrior_fury_menu = {
    header = "EAXWarriorFury",
    settings = {
        -- General
        {
            key = "enabled",
            type = "checkbox",
            default = true,
            label = "Enable Rotation",
        },
        {
            key = "mode",
            type = "combobox",
            default = 1,
            options = {"Auto", "PvE", "PvP"},
            label = "Rotation Mode",
        },

        -- Combat
        {
            key = "combat_header",
            type = "header",
            label = "Combat",
        },
        {
            key = "use_cooldowns",
            type = "checkbox",
            default = true,
            label = "Use Cooldowns",
        },
        {
            key = "use_aoe",
            type = "checkbox",
            default = true,
            label = "Use AoE Abilities",
        },

        -- Defensive
        {
            key = "defensive_header",
            type = "header",
            label = "Defensive",
        },
        {
            key = "defensive_threshold",
            type = "slider",
            default = 40,
            min = 10,
            max = 100,
            label = "Defensive Threshold (%)",
        },

        -- PvP (merged from template)
        {
            key = "pvp_header",
            type = "header",
            label = "PvP",
        },
        {
            key = "pvp_enabled",
            type = "checkbox",
            default = true,
            label = "Enable PvP Mode",
            tooltip = "Enable PvP-specific logic. Auto-detected via BG/Arena/PvP flag.",
        },
        {
            key = "pvp_mode",
            type = "combobox",
            default = 1,
            options = {"Auto", "PvE Only", "PvP Only"},
            label = "PvP Mode Selection",
            tooltip = "Auto detects PvP context. Override here if needed.",
        },
        {
            key = "pvp_hamstring",
            type = "checkbox",
            default = true,
            label = "Maintain Hamstring",
            tooltip = "Keep Hamstring on enemy players. Skips immune targets.",
        },
        {
            key = "pvp_piercing_howl",
            type = "checkbox",
            default = true,
            label = "Piercing Howl (AoE Snare)",
            tooltip = "Use Piercing Howl when 2+ enemies lack a slow.",
        },
        {
            key = "pvp_rend_stealth",
            type = "checkbox",
            default = true,
            label = "Rend Anti-Stealth",
            tooltip = "Apply Rend to Rogues/Druids to prevent stealth.",
        },
        {
            key = "pvp_overpower_evasion",
            type = "checkbox",
            default = true,
            label = "Overpower vs Evasion",
            tooltip = "Prioritize Overpower against Evasion/Deterrence.",
        },
        {
            key = "pvp_disarm",
            type = "checkbox",
            default = true,
            label = "Auto Disarm",
            tooltip = "Disarm enemy melee players.",
        },
        {
            key = "pvp_disarm_trigger",
            type = "combobox",
            default = 1,
            options = {"On Cooldown", "On Enemy Burst"},
            label = "Disarm Trigger",
            tooltip = "When to use Disarm ability.",
        },
        {
            key = "pvp_interrupt_cc_fallback",
            type = "checkbox",
            default = true,
            label = "CC Interrupt Fallback",
            tooltip = "Use CC as interrupt backup when kick is on CD.",
        },
        {
            key = "pvp_def_stance_range",
            type = "checkbox",
            default = true,
            label = "Def Stance at Range",
            tooltip = "Auto-switch to Defensive Stance when out of melee.",
        },
        {
            key = "pvp_trinket_defensive",
            type = "checkbox",
            default = true,
            label = "PvP Trinket Defensive",
            tooltip = "Use PvP trinket for defensive dispels (CC removal).",
        },
        {
            key = "pvp_burst_threshold",
            type = "slider",
            default = 60,
            min = 10,
            max = 100,
            label = "Burst Threshold (%)",
            tooltip = "Target health % to trigger burst cooldowns.",
        },
        {
            key = "pvp_save_cooldowns",
            type = "checkbox",
            default = false,
            label = "Save Cooldowns vs Healers",
            tooltip = "Don't waste burst CDs on targets with strong healing.",
        },
        {
            key = "pvp_focus_healers",
            type = "checkbox",
            default = true,
            label = "Focus Healers",
            tooltip = "Prioritize healer targets in arena/BG.",
        },
        {
            key = "pvp_target_swapping",
            type = "checkbox",
            default = true,
            label = "Smart Target Swapping",
            tooltip = "Swap to low-health targets when current target is healed.",
        },
        {
            key = "pvp_auto_self_cast",
            type = "checkbox",
            default = true,
            label = "Auto Self-Cast",
            tooltip = "Auto-cast beneficial spells on self when no friendly target.",
        },
    },
}

-- Return the example menu
return warrior_fury_menu
