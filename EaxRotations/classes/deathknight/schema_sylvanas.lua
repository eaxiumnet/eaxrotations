-- deathknight/schema_sylvanas.lua — Death Knight menu schema and settings defaults.
-- WHAT:  defines menu widgets for death knight specs.
-- WHEN:  loaded at addon init when NS.is_wotlk() is true.
-- WHY:   centralized menu definition prevents duplicate widget IDs.
-- SAFETY: nil-guarded menu references; default fallbacks for all settings.

local consumables = require("shared/schema_consumables_sylvanas")

return {
    {
        name = "General",
        sections = {
            {
                header = "Rotation",
                settings = {
                    { key = "playstyle", type = "dropdown", label = "Playstyle", default = "blood", options = {
                            { text = "Leveling", value = "leveling" },
                            { text = "Blood", value = "blood" },
                            { text = "Frost", value = "frost" },
                            { text = "Unholy", value = "unholy" },
                    } },
                    { key = "use_cooldowns", type = "checkbox", label = "Cooldowns", default = true },
                    { key = "use_interrupt", type = "checkbox", label = "Interrupts", default = true },
                    { key = "use_threat_drop", type = "checkbox", label = "Threat Drop", default = true },
                    { key = "use_defensives", type = "checkbox", label = "Defensives (auto-use)", default = true },
                    { key = "defensive_hp_threshold", type = "slider", label = "Defensive HP%", min = 0, max = 100, default = 35 },
                    { key = "aoe_threshold", type = "slider", label = "AoE Count", min = 2, max = 6, default = 3 },
                },
            },
            {
                header = "Advanced",
                settings = {
                    { key = "dk_use_death_grip", type = "checkbox", label = "Death Grip", default = true },
                    { key = "dk_use_anti_magic_shell", type = "checkbox", label = "Anti-Magic Shell", default = true },
                    { key = "dk_use_bone_shield", type = "checkbox", label = "Bone Shield", default = true },
                    { key = "dk_use_horn_of_winter", type = "checkbox", label = "Horn of Winter", default = true },
                },
            },
        },
    },
    {
        name = "Leveling",
        sections = {
            {
                header = "Leveling Settings",
                settings = {
                    { key = "leveling_use_icy_touch", type = "checkbox", label = "Use Icy Touch", default = true },
                    { key = "leveling_use_plague_strike", type = "checkbox", label = "Use Plague Strike", default = true },
                    { key = "leveling_use_death_strike", type = "checkbox", label = "Use Death Strike", default = true },
                    { key = "leveling_use_heart_strike", type = "checkbox", label = "Use Heart Strike", default = true },
                },
            },
        },
    },
    require("shared/schema_autoloot_sylvanas").build_tab(),
    consumables.build_tab(),
}
