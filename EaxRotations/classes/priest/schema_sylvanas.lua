-- Readability notes:
--   What: Priest menu schema.
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
                    { key = "playstyle", type = "dropdown", label = "Playstyle", default = "discipline", options = {
                            { text = "Discipline", value = "discipline" },
                            { text = "Holy", value = "holy" },
                            { text = "Shadow", value = "shadow" },
                            { text = "Smite", value = "smite" },
                    } },
                    { key = "use_cooldowns", type = "checkbox", label = "Cooldowns", default = true },
                    { key = "use_interrupt", type = "checkbox", label = "Interrupts", default = true },
                    { key = "use_threat_drop", type = "checkbox", label = "Threat Drop", default = true },
                    { key = "use_pvp_defensives", type = "checkbox", label = "PvP Defensives", default = true },
                    { key = "pvp_kite_threshold", type = "slider", label = "PvP Kite HP", min = 20, max = 80, default = 50 },
                    { key = "aoe_threshold", type = "slider", label = "AoE Count", min = 2, max = 6, default = 3 },
                },
            },
            {
                header = "Utility",
                settings = {
                    { key = "use_party_dispel", type = "checkbox", label = "Party Dispel", default = true },
                    { key = "party_dispel_mana_floor", type = "slider", label = "Dispel Mana Floor (%)", min = 10, max = 50, default = 30 },
                    { key = "use_self_dispel", type = "checkbox", label = "Self Dispel", default = true },
                    { key = "use_shadowfiend", type = "checkbox", label = "Shadowfiend", default = true },
                    { key = "shadowfiend_mana_threshold", type = "slider", label = "Shadowfiend Mana", min = 10, max = 60, default = 30 },
                    { key = "use_enhanced_fade", type = "checkbox", label = "Enhanced Fade", default = true },
                },
            },
        },
    },
}
