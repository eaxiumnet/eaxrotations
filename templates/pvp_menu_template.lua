-- PvP Mode Menu Template for EAX Rotations
-- Based on legacy warrior PvP system
-- Usage: Merge this into your spec's menu.lua tree structure
-- Version: 1.0.0

local pvp_menu_template = {
    header = "PvP",
    settings = {
        -- General
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
            default = 1,  -- 1=Auto, 2=PvE, 3=PvP
            options = {"Auto", "PvE Only", "PvP Only"},
            label = "PvP Mode Selection",
            tooltip = "Auto detects PvP context. Override here if needed.",
        },

        -- Offensive
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

        -- CC & Control
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
            default = 1,  -- 1=On Cooldown, 2=On Burst
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

        -- Defensive
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

        -- Burst & Cooldowns
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

        -- Targeting
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

        -- Utility
        {
            key = "pvp_auto_self_cast",
            type = "checkbox",
            default = true,
            label = "Auto Self-Cast",
            tooltip = "Auto-cast beneficial spells on self when no friendly target.",
        },
    },
}

-- Cached API references for performance
local _get_local_player = core.object_manager.get_local_player
local _is_in_instance = core.game_state.is_in_instance
local _get_unit_type = core.object_manager.get_unit_type
local _is_pvp_flagged = core.game_state.is_pvp_flagged

-- Helper function to detect PvP context
-- Returns: is_pvp, is_arena, is_battleground, target_is_player
function pvp_menu_template.detect_pvp_context(me, target)
    me = me or _get_local_player()
    if not me then
        return false, false, false, false
    end

    local is_battleground = false
    local is_arena = false
    local is_pvp = false
    local target_is_player = false

    -- Check instance type for BG/Arena
    if _is_in_instance then
        local instance_type = _is_in_instance()
        if instance_type then
            is_battleground = (instance_type == "battleground")
            is_arena = (instance_type == "arena")
        end
    end

    -- Check PvP flag status
    if _is_pvp_flagged then
        is_pvp = _is_pvp_flagged() or false
    end

    -- Check target type
    if target and _get_unit_type then
        local unit_type = _get_unit_type(target)
        target_is_player = (unit_type == "player")
    end

    -- Combined PvP detection
    is_pvp = is_pvp or is_battleground or is_arena

    return is_pvp, is_arena, is_battleground, target_is_player
end

-- Helper to check if PvP mode is active
-- Usage: if pvp_menu_template.is_pvp_active(menu, context) then ... end
function pvp_menu_template.is_pvp_active(menu, context)
    -- Check if PvP is enabled at all
    local enabled = (menu.pvp_enabled and menu.pvp_enabled:get())
    if enabled == false then
        return false
    end

    -- Check mode selection
    local mode = (menu.pvp_mode and menu.pvp_mode:get()) or 1
    if mode == 2 then return false end  -- PvE only
    if mode == 3 then return true end   -- PvP only

    -- Auto mode - use context
    return context.is_pvp or false
end

-- Helper to check if a specific PvP setting is enabled
-- Usage: if pvp_menu_template.is_enabled(menu, "pvp_hamstring") then ... end
function pvp_menu_template.is_enabled(menu, setting_key)
    if not menu then return false end
    local setting = menu[setting_key]
    if not setting then return false end
    local value = setting:get()
    return value == true or value == 1
end

-- Helper to get slider value with default
-- Usage: local threshold = pvp_menu_template.get_value(menu, "pvp_burst_threshold", 60)
function pvp_menu_template.get_value(menu, setting_key, default_value)
    if not menu then return default_value end
    local setting = menu[setting_key]
    if not setting then return default_value end
    local value = setting:get()
    if value == nil then return default_value end
    return value
end

-- Predefined class detection for anti-stealth logic
pvp_menu_template.STEALTH_CLASSES = {
    ["ROGUE"] = true,
    ["DRUID"] = true,
}

-- Predefined healer specs for focus targeting
pvp_menu_template.HEALER_SPECS = {
    ["PRIEST_HOLY"] = true,
    ["PRIEST_DISCIPLINE"] = true,
    ["PALADIN_HOLY"] = true,
    ["SHAMAN_RESTORATION"] = true,
    ["DRUID_RESTORATION"] = true,
}

-- Helper to check if target class can stealth
function pvp_menu_template.can_stealth(class_name)
    return pvp_menu_template.STEALTH_CLASSES[class_name] or false
end

-- Helper to check if target spec is a healer
function pvp_menu_template.is_healer_spec(spec_name)
    return pvp_menu_template.HEALER_SPECS[spec_name] or false
end

return pvp_menu_template
