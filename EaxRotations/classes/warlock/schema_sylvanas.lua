-- Readability notes:
--   What: Warlock menu schema.
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
                    { key = "playstyle", type = "dropdown", label = "Playstyle", default = "affliction", options = {
                            { text = "Affliction", value = "affliction" },
                            { text = "Demonology", value = "demonology" },
                            { text = "Destruction", value = "destruction" },
                    } },
                    { key = "use_cooldowns", type = "checkbox", label = "Cooldowns", default = true },
                    { key = "use_interrupt", type = "checkbox", label = "Interrupts", default = true },
                    { key = "use_threat_drop", type = "checkbox", label = "Threat Drop", default = true },
                    { key = "use_pvp_defensives", type = "checkbox", label = "PvP Defensives", default = true },
                    { key = "pvp_kite_threshold", type = "slider", label = "PvP Kite HP", min = 20, max = 80, default = 50 },
                    { key = "aoe_threshold", type = "slider", label = "AoE Count", min = 2, max = 6, default = 3 },
                },
            },
        },
    },
}
