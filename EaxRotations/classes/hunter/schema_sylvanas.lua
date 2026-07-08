-- hunter/schema_sylvanas.lua — Hunter menu schema and settings defaults.
-- WHAT:  defines menu widgets (checkboxes, sliders, keybinds) for hunter specs.
-- WHEN:  loaded at addon init to register middleware menu entries.
-- WHY:   centralized menu definition prevents duplicate widget IDs.
-- SAFETY: nil-guarded menu references; default fallbacks for all settings.

-- Hunter menu schema.


local consumables = require("shared/schema_consumables_sylvanas")

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
                    { key = "use_cooldowns_on_boss_only", type = "checkbox", label = "Cooldowns on Bosses Only", default = false, tooltip = "Only use major offensive cooldowns (Bestial Wrath) on boss targets — skip on trash" },
                    { key = "use_interrupt", type = "checkbox", label = "Interrupts", default = true },
                    { key = "use_threat_drop", type = "checkbox", label = "Threat Drop", default = true },
                    { key = "aoe_threshold", type = "slider", label = "AoE Count", min = 2, max = 6, default = 3 },
                    { key = "use_adaptive_rotation", type = "checkbox", label = "Adaptive Rotation (wowsims DPS math)", default = false, tooltip = "Replace threshold-based shot selection with DPS-optimal math engine. Selects best shot per tick by computing expected damage of each option." },
                    { key = "mana_save", type = "slider", label = "Mana Save %", min = 0, max = 100, default = 30, tooltip = "Below this mana %, skip expensive shots (Multi-Shot, Arcane Shot)." },
                    { key = "arcane_shot_mana", type = "slider", label = "Arcane Shot Mana Floor %", min = 0, max = 100, default = 15, tooltip = "Minimum mana % to cast Arcane Shot." },
                    { key = "adaptive_exec_pad_ms", type = "slider", label = "Adaptive Exec Pad (ms)", min = 0, max = 250, default = 100, tooltip = "Extra delay added before each special shot to reduce auto-shot clipping. Higher = safer but lower DPS." },
                    { key = "weapon_speed", type = "slider", label = "Ranged Weapon Speed", min = 20, max = 40, default = 29, tooltip = "Your ranged weapon's base speed in tenths of seconds (e.g. 29 = 2.9s). Used for haste computation." },
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
                    { key = "use_snake_trap", type = "checkbox", label = "Snake Trap (AoE)", default = true, tooltip = "Places a Snake Trap that releases venomous snakes to attack the first enemy. 305 mana, 30s cd. Requires level 68." },
                },
            },
            {
                header = "Aspect Management",
                settings = {
                    { key = "hunter_auto_aspect", type = "checkbox", label = "Auto Aspect Switch", default = true, tooltip = "Auto-switch between Hawk (DPS), Viper (low mana), Cheetah (OOC)" },
                    { key = "aspect_hawk", type = "checkbox", label = "Aspect of the Hawk", default = true },
                    { key = "aspect_viper", type = "checkbox", label = "Aspect of the Viper", default = true },
                    { key = "mana_viper_start", type = "slider", label = "Viper On Mana (%)", min = 0, max = 100, default = 20 },
                    { key = "mana_viper_end", type = "slider", label = "Viper Off Mana (%)", min = 0, max = 100, default = 30 },
                    { key = "hunter_viper_mana_threshold", type = "slider", label = "Viper Mana Threshold (%)", min = 0, max = 100, default = 20 },
                },
            },
            {
                header = "Shot Weaving",
                settings = {
                    { key = "hunter_shot_timer_buffer", type = "slider", label = "Shot Timer Buffer (ms)", min = 0, max = 300, default = 150, tooltip = "Delay Steady Shot if auto-shot is within this buffer" },
                    { key = "hunter_melee_weave", type = "checkbox", label = "Melee Weave", default = true, tooltip = "Use Raptor Strike / Wing Clip when in melee range" },
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
            },
            {
                header = "Cooldowns",
                settings = {
                    { key = "use_rapid_fire", type = "checkbox", label = "Rapid Fire", default = true },
                    { key = "use_readiness", type = "checkbox", label = "Readiness (reset CDs)", default = true },
                },
            },
            {
                header = "Defensives",
                settings = {
                    { key = "healthstone_hp", type = "slider", label = "Healthstone / Potion HP", min = 0, max = 100, default = 0, tooltip = "Use healthstone or healing potion when HP drops below this threshold (0 = disabled)" },
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
        name = "Beast Mastery",
        sections = {
            {
                header = "Shot Weaving",
                settings = {
                    { key = "hunter_shot_timer_buffer", type = "slider", label = "Shot Timer Buffer (ms)", min = 0, max = 300, default = 150, tooltip = "Delay Steady Shot if auto-shot is within this buffer" },
                    { key = "hunter_melee_weave", type = "checkbox", label = "Melee Weave", default = true, tooltip = "Use Raptor Strike / Wing Clip when in melee range" },
                },
            },
        },
    },
    {
        name = "Marksmanship",
        sections = {
            {
                header = "Shot Weaving",
                settings = {
                    { key = "hunter_shot_timer_buffer", type = "slider", label = "Shot Timer Buffer (ms)", min = 0, max = 300, default = 150, tooltip = "Delay Steady Shot if auto-shot is within this buffer" },
                    { key = "hunter_melee_weave", type = "checkbox", label = "Melee Weave", default = true, tooltip = "Use Raptor Strike / Wing Clip when in melee range" },
                },
            },
        },
    },
    {
        name = "Survival",
        sections = {
            {
                header = "Shot Weaving",
                settings = {
                    { key = "hunter_shot_timer_buffer", type = "slider", label = "Shot Timer Buffer (ms)", min = 0, max = 300, default = 150, tooltip = "Delay Steady Shot if auto-shot is within this buffer" },
                    { key = "hunter_melee_weave", type = "checkbox", label = "Melee Weave", default = true, tooltip = "Use Raptor Strike / Wing Clip when in melee range" },
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
    require("shared/schema_autoloot_sylvanas").build_tab(),
    consumables.build_tab({ use_mana_potions = { default = true } }),
}
