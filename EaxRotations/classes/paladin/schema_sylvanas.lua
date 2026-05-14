-- Readability notes:
--   What: Paladin menu schema.
--   When: main.lua renders class settings.
--   Why: user controls are declarative and easy to audit.
--   Safety: all settings have defaults; missing widgets are handled by main.lua guards.
--   Performance: this file returns static data; widgets are built once by main.lua.

-- Decision notes:
--   Schema files are data-only so menu construction can happen once in main.lua.
--   Defaults stay conservative; unsafe automation should require an explicit user setting.
--   Keys should stay stable because users may have saved profiles using these exact identifiers.
return {
    {
        name = "General",
        sections = {
            {
                header = "Rotation",
                settings = {
                    { key = "playstyle", type = "dropdown", label = "Playstyle", default = "holy", options = {
                            { text = "Holy", value = "holy" },
                            { text = "Protection", value = "protection" },
                            { text = "Retribution", value = "retribution" },
                    } },
                    { key = "use_cooldowns", type = "checkbox", label = "Cooldowns", default = true },
                    { key = "seal_twisting", type = "checkbox", label = "Seal Twisting", default = true },
                    { key = "use_interrupt", type = "checkbox", label = "Interrupts", default = true },
                    { key = "use_threat_drop", type = "checkbox", label = "Threat Drop", default = true },
                    { key = "aoe_threshold", type = "slider", label = "AoE Count", min = 2, max = 6, default = 3 },
                },
            },
            {
                header = "Blessing Refresh",
                settings = {
                    { key = "holy_refresh_enabled", type = "checkbox", label = "Combat Refresh", default = true, tooltip = "Refresh Wisdom and Kings in combat when duration is low" },
                    { key = "holy_refresh_threshold", type = "slider", label = "Refresh When < (sec)", min = 30, max = 300, default = 120, tooltip = "Refresh blessings when remaining time drops below this" },
                    { key = "holy_refresh_mana", type = "slider", label = "Min Mana %", min = 0, max = 100, default = 30, tooltip = "Only refresh blessings when mana is above this threshold" },
                },
            },
        },
    },
}
