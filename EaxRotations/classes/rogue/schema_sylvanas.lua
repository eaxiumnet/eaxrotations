-- Readability notes:
--   What: Rogue menu schema.
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
                    { key = "playstyle", type = "dropdown", label = "Playstyle", default = "combat", options = {
                            { text = "Assassination", value = "assassination" },
                            { text = "Combat", value = "combat" },
                            { text = "Subtlety", value = "subtlety" },
                    } },
                    { key = "use_cooldowns", type = "checkbox", label = "Cooldowns", default = true },
                    { key = "use_interrupt", type = "checkbox", label = "Interrupts", default = true },
                    { key = "use_threat_drop", type = "checkbox", label = "Threat Drop", default = true },
                    { key = "aoe_threshold", type = "slider", label = "AoE Count", min = 2, max = 6, default = 3 },
                },
            },
            {
                header = "Emergency Toolkit",
                settings = {
                    { key = "rogue_use_evasion", type = "checkbox", label = "Evasion", default = true },
                    { key = "rogue_evasion_hp", type = "slider", label = "Evasion HP", min = 10, max = 50, default = 35 },
                    { key = "rogue_use_cloak", type = "checkbox", label = "Cloak of Shadows", default = true },
                    { key = "rogue_cloak_hp", type = "slider", label = "Cloak HP", min = 20, max = 60, default = 45 },
                    { key = "rogue_use_vanish_defensive", type = "checkbox", label = "Vanish (Emergency)", default = false },
                    { key = "rogue_vanish_hp", type = "slider", label = "Vanish HP", min = 10, max = 40, default = 20 },
                },
            },
        },
    },
}
