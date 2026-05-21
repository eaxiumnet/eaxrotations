-- Warrior menu schema.
-- ============================================================================
-- What: TBC Warrior settings schema for rotations, PvP defensives, tactician weaving, and leveling
-- When: Load time
-- Why: Defines the user-facing controls consumed by all warrior playstyles
-- Safety: Conservative defaults; explicit toggles keep risky automation opt-in
-- ============================================================================

return {
    {
        name = "General",
        sections = {
            {
                header = "Rotation",
                settings = {
                    { key = "playstyle", type = "dropdown", label = "Playstyle", default = "arms", options = {
                            { text = "Leveling", value = "leveling" },
                            { text = "Arms", value = "arms" },
                            { text = "Fury", value = "fury" },
                            { text = "Kebab", value = "kebab" },
                            { text = "Protection", value = "protection" },
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
                header = "Advanced",
                settings = {
                    { key = "warrior_use_spell_reflection", type = "checkbox", label = "Spell Reflection", default = true },
                    { key = "warrior_reflect_pvp_only", type = "checkbox", label = "Spell Reflection PvP Only", default = true },
                    { key = "warrior_cancel_external_buff", type = "checkbox", label = "Cancel PW:S/BoP", default = false },
                    { key = "warrior_defensive_stance_pve", type = "checkbox", label = "Defensive Stance Outside PvP", default = false },
                },
            },
            {
                header = "Tactician (Arms)",
                settings = {
                    { key = "hamstring_tactician_weave", type = "checkbox", label = "Hamstring Tactician Weave", default = true, description = "Spam Hamstring when MS on CD to fish for Tactician procs (~5% DPS gain)" },
                    { key = "hamstring_weave_rage", type = "slider", label = "Hamstring Weave Rage Min", min = 40, max = 80, default = 55, description = "Minimum rage to begin Hamstring Tactician spam" },
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
                    { key = "leveling_use_execute", type = "checkbox", label = "Use Execute", default = true },
                    { key = "leveling_use_rend", type = "checkbox", label = "Use Rend", default = true },
                    { key = "leveling_use_thunder_clap", type = "checkbox", label = "Use Thunder Clap", default = true },
                    { key = "leveling_exec_hp", type = "slider", label = "Execute HP %", min = 0, max = 100, default = 20 },
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
                    { key = "use_mana_potions", type = "checkbox", label = "Mana Potions", default = false },
                    { key = "mana_potion_threshold", type = "slider", label = "Mana Potion at %", min = 0, max = 100, default = 40 },
                    { key = "health_potion_threshold", type = "slider", label = "Health Potion at %", min = 0, max = 100, default = 35 },
                },
            },
        },
    },
}
