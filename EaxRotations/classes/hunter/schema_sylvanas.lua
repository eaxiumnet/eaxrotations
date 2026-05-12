-- Readability notes:
--   What: Hunter menu schema.
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
                    { key = "playstyle", type = "dropdown", label = "Playstyle", default = "beast_mastery", options = {
                            { text = "Beast Mastery", value = "beast_mastery" },
                            { text = "Marksmanship", value = "marksmanship" },
                            { text = "Survival", value = "survival" },
                    } },
                    { key = "use_cooldowns", type = "checkbox", label = "Cooldowns", default = true },
                    { key = "use_interrupt", type = "checkbox", label = "Interrupts", default = true },
                    { key = "use_threat_drop", type = "checkbox", label = "Threat Drop", default = true },
                    { key = "aoe_threshold", type = "slider", label = "AoE Count", min = 2, max = 6, default = 3 },
                },
            },
            {
                header = "Viper Sting",
                settings = {
                    { key = "use_viper_sting_pve", type = "checkbox", label = "Viper Sting (PvE Mana Drain)", default = false },
                    { key = "use_viper_sting_pvp", type = "checkbox", label = "Viper Sting (PvP)", default = true },
                    { key = "viper_sting_hp_threshold", type = "slider", label = "Viper Sting HP Threshold", min = 10, max = 100, default = 30 },
                    { key = "viper_sting_priest", type = "checkbox", label = "Viper Sting: Priests", default = true },
                    { key = "viper_sting_paladin", type = "checkbox", label = "Viper Sting: Paladins", default = true },
                    { key = "viper_sting_shaman", type = "checkbox", label = "Viper Sting: Shamans", default = true },
                    { key = "viper_sting_druid", type = "checkbox", label = "Viper Sting: Druids", default = true },
                    { key = "viper_sting_mage", type = "checkbox", label = "Viper Sting: Mages", default = true },
                    { key = "viper_sting_warlock", type = "checkbox", label = "Viper Sting: Warlocks", default = true },
                },
            },
            {
                header = "Traps",
                settings = {
                    { key = "freezing_trap_pve", type = "checkbox", label = "Freezing Trap on Adds", default = true },
                },
            },
            {
                header = "Aspect Management",
                settings = {
                    { key = "aspect_hawk", type = "checkbox", label = "Aspect of the Hawk", default = true },
                    { key = "aspect_viper", type = "checkbox", label = "Aspect of the Viper", default = true },
                    { key = "mana_viper_start", type = "slider", label = "Viper On Mana (%)", min = 0, max = 100, default = 10 },
                    { key = "mana_viper_end", type = "slider", label = "Viper Off Mana (%)", min = 0, max = 100, default = 30 },
                },
            },
            {
                header = "Utility",
                settings = {
                    { key = "use_misdirection", type = "checkbox", label = "Misdirection", default = true },
                    { key = "misdirection_pull_window", type = "slider", label = "Misdirection Window (s)", min = 1, max = 10, default = 6 },
                    { key = "misdirection_on_focus", type = "checkbox", label = "Misdirection on Focus", default = true },
                },
            },
        },
    },
}
