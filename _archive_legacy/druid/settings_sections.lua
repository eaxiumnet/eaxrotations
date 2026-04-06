-- =============================================================================
-- SETTINGS SECTIONS - Flux AIO Common Schema Sections
-- Converted from flux/rotation/source/aio/common.lua
-- Shared section factories used by all class schemas to avoid duplication
-- =============================================================================

local SettingsSections = {}

-- =============================================================================
-- DASHBOARD SECTION
-- =============================================================================
SettingsSections.dashboard = function()
    return {
        category = "Dashboard",
        settings = {
            {
                key = "dashboard.show",
                type = "checkbox",
                default = false,
                label = "Show Dashboard",
                tooltip = "Display the combat dashboard overlay (/flux status).",
            },
        }
    }
end

-- =============================================================================
-- BURST CONDITIONS SECTION
-- =============================================================================
SettingsSections.burst = function()
    return {
        category = "Burst Conditions",
        description = "When to automatically use burst cooldowns.",
        settings = {
            {
                key = "burst.on_bloodlust",
                type = "checkbox",
                default = false,
                label = "During Bloodlust/Heroism",
                tooltip = "Auto-burst when Bloodlust or Heroism buff is detected.",
            },
            {
                key = "burst.on_pull",
                type = "checkbox",
                default = false,
                label = "On Pull (first 5s)",
                tooltip = "Auto-burst within the first 5 seconds of combat.",
            },
            {
                key = "burst.on_execute",
                type = "checkbox",
                default = false,
                label = "Execute Phase (<20% HP)",
                tooltip = "Auto-burst when target is below 20% health.",
            },
            {
                key = "burst.in_combat",
                type = "checkbox",
                default = false,
                label = "Always in Combat",
                tooltip = "Always auto-burst when in combat with a valid target (most aggressive).",
            },
        }
    }
end

-- =============================================================================
-- DEBUG SECTION
-- =============================================================================
SettingsSections.debug = function()
    return {
        category = "Debug",
        settings = {
            {
                key = "debug.mode",
                type = "checkbox",
                default = true,
                label = "Debug Mode",
                tooltip = "Print rotation debug messages.",
            },
            {
                key = "debug.system",
                type = "checkbox",
                default = false,
                label = "Debug System (Advanced)",
                tooltip = "Print system debug messages (middleware, strategies).",
            },
            {
                key = "debug.log_context",
                type = "checkbox",
                default = false,
                label = "Log Context",
                tooltip = "Print full context state to debug log every 2s during combat.",
            },
        }
    }
end

-- =============================================================================
-- TRINKETS & RACIAL SECTION
-- =============================================================================
SettingsSections.trinkets = function(racial_tooltip)
    return {
        category = "Trinkets & Racial",
        settings = {
            {
                key = "trinkets.slot1_mode",
                type = "dropdown",
                default = "off",
                label = "Trinket 1",
                tooltip = "Off = never use. Offensive = fires during burst. Defensive = fires during def.",
                options = {
                    { value = "off", text = "Off" },
                    { value = "offensive", text = "Offensive (Burst)" },
                    { value = "defensive", text = "Defensive" },
                },
            },
            {
                key = "trinkets.slot2_mode",
                type = "dropdown",
                default = "off",
                label = "Trinket 2",
                tooltip = "Off = never use. Offensive = fires during burst. Defensive = fires during def.",
                options = {
                    { value = "off", text = "Off" },
                    { value = "offensive", text = "Offensive (Burst)" },
                    { value = "defensive", text = "Defensive" },
                },
            },
            {
                key = "trinkets.use_racial",
                type = "checkbox",
                default = true,
                label = "Use Racial",
                tooltip = racial_tooltip or "Use racial ability during combat.",
            },
        }
    }
end

-- =============================================================================
-- UTILITY FUNCTIONS
-- =============================================================================

---Get all common sections as a flat settings table for SettingsBridge
---@return table flat_settings Table of key -> setting_definition
function SettingsSections.get_all_flat()
    local flat = {}
    
    local sections = {
        SettingsSections.dashboard(),
        SettingsSections.burst(),
        SettingsSections.debug(),
        SettingsSections.trinkets(),
    }
    
    for _, section in ipairs(sections) do
        for _, setting in ipairs(section.settings) do
            flat[setting.key] = setting
        end
    end
    
    return flat
end

---Get default values for all common settings
---@return table defaults Table of key -> default_value
function SettingsSections.get_all_defaults()
    local defaults = {}
    
    local sections = {
        SettingsSections.dashboard(),
        SettingsSections.burst(),
        SettingsSections.debug(),
        SettingsSections.trinkets(),
    }
    
    for _, section in ipairs(sections) do
        for _, setting in ipairs(section.settings) do
            defaults[setting.key] = setting.default
        end
    end
    
    return defaults
end

-- =============================================================================
-- EXPORT
-- =============================================================================

return SettingsSections


