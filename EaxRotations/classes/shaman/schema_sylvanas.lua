-- Readability notes:
--   What: Shaman menu schema.
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
                    { key = "playstyle", type = "dropdown", label = "Playstyle", default = "elemental", options = {
                            { text = "Elemental", value = "elemental" },
                            { text = "Enhancement", value = "enhancement" },
                            { text = "Restoration", value = "restoration" },
                    } },
                    { key = "use_cooldowns", type = "checkbox", label = "Cooldowns", default = true },
                    { key = "use_interrupt", type = "checkbox", label = "Interrupts", default = true },
                    { key = "use_threat_drop", type = "checkbox", label = "Threat Drop", default = true },
                    { key = "aoe_threshold", type = "slider", label = "AoE Count", min = 2, max = 6, default = 3 },
                    { key = "enhancement_manage_totems", type = "checkbox", label = "Enhancement Totems", default = false },
                    { key = "enhancement_totem_twisting", type = "checkbox", label = "Enhancement Totem Twisting", default = false },
                },
            },
            {
                header = "Utility",
                settings = {
                    { key = "use_auto_tremor_totem", type = "checkbox", label = "Auto Tremor Totem", default = true },
                    { key = "use_purge", type = "checkbox", label = "Purge Dispel", default = true },
                    { key = "purge_pvp_only", type = "checkbox", label = "Purge PvP Only", default = false },
                    { key = "purge_min_mana_pct", type = "slider", label = "Purge Min Mana (%)", min = 10, max = 50, default = 20 },
                    { key = "use_self_dispel", type = "checkbox", label = "Self Dispel (Poison/Disease)", default = true },
                    { key = "dispel_min_mana_pct", type = "slider", label = "Dispel Min Mana (%)", min = 10, max = 50, default = 20 },
                },
            },
        },
    },
}
