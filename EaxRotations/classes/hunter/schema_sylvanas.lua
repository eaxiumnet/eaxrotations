-- Hunter menu schema.

-- ============================================================================
-- What: Hunter menu schema for playstyle, rotation, and class settings
-- When: Loaded once to build the class settings UI
-- Why: Keeps Hunter options explicit and auditable in one place
-- Safety: Static data only; conservative defaults; no runtime casts or API calls
-- ============================================================================

return {
    {
        name = "General",
        sections = {
            {
                header = "Rotation",
                settings = {
                    { key = "playstyle", type = "dropdown", label = "Playstyle", default = "beast_mastery", options = {
                            { text = "Leveling", value = "leveling" },
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
                    { key = "mana_viper_start", type = "slider", label = "Viper On Mana (%)", min = 0, max = 100, default = 20 },
                    { key = "mana_viper_end", type = "slider", label = "Viper Off Mana (%)", min = 0, max = 100, default = 30 },
                },
            },
            {
                header = "Pet",
                settings = {
                    { key = "auto_mend_pet", type = "checkbox", label = "Mend Pet", default = true },
                    { key = "mend_pet_hp", type = "slider", label = "Mend Pet HP", min = 0, max = 100, default = 50 },
                    { key = "auto_revive_pet", type = "checkbox", label = "Revive Pet", default = true },
                    { key = "auto_call_pet", type = "checkbox", label = "Call Pet", default = true },
                    { key = "auto_hunters_mark", type = "checkbox", label = "Hunter's Mark", default = true },
                },
            },	            {
	                header = "Cooldowns",
	                settings = {
	                    { key = "use_readiness", type = "checkbox", label = "Readiness (reset CDs)", default = true },
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
    {
        name = "Leveling",
        sections = {
            {
                header = "Leveling Settings",
                settings = {
                    { key = "leveling_wand_threshold", type = "slider", label = "Wand Mana %", min = 0, max = 100, default = 30 },
                    { key = "leveling_mend_pet_hp", type = "slider", label = "Mend Pet HP %", min = 0, max = 100, default = 50 },
                },
            },
        },
    },
    {
        name = "Consumables",
        sections = {
            {
                header = "Auto Consumables",
                settings = {
                    { key = "use_auto_consumables", type = "checkbox", label = "Enable Auto Consumables", default = true },
                    { key = "use_flasks", type = "checkbox", label = "Use Flasks", default = false },
                    { key = "use_elixirs", type = "checkbox", label = "Use Elixirs", default = false },
                    { key = "use_food", type = "checkbox", label = "Use Food", default = false },
                    { key = "use_combat_potions", type = "checkbox", label = "Combat Potions", default = true },
                    { key = "use_weapon_buffs", type = "checkbox", label = "Weapon Buffs", default = false },
                    { key = "use_drums", type = "checkbox", label = "Drums", default = false },
                    { key = "use_healthstones", type = "checkbox", label = "Healthstones", default = true },
                    { key = "use_mana_potions", type = "checkbox", label = "Mana Potions", default = true },
                    { key = "mana_potion_threshold", type = "slider", label = "Mana Potion at %", min = 0, max = 100, default = 40 },
                    { key = "health_potion_threshold", type = "slider", label = "Health Potion at %", min = 0, max = 100, default = 35 },
                },
            },
        },
    },
}
