-- Warrior menu schema.

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
                    { key = "use_defensives", type = "checkbox", label = "Defensives (auto-use)", default = true },
                    { key = "defensive_hp_threshold", type = "slider", label = "Defensive HP%", min = 0, max = 100, default = 30, description = "HP threshold to trigger defensive cooldowns" },
                    { key = "use_last_stand", type = "checkbox", label = "Last Stand", default = true },
                    { key = "use_shield_wall", type = "checkbox", label = "Shield Wall", default = true },
                    { key = "use_self_buffs", type = "checkbox", label = "Self Buffs", default = true },
                    { key = "use_battle_shout", type = "checkbox", label = "Battle Shout", default = true },
                    { key = "use_pvp_cc_gating", type = "checkbox", label = "PvP CC Gate (skip AoE near CC)", default = true, tooltip = "Skip Cleave/Whirlwind/Sweeping Strikes when a nearby enemy is Polymorphed/Sapped/etc." },
                    { key = "use_shield_slam_purge", type = "checkbox", label = "Shield Slam Purge (PvP)", default = true, tooltip = "Shield Slam dispels 1 magic buff on enemy players (BoP, PW:S, Ice Barrier, etc.). Requires Defensive Stance." },
                    { key = "shield_slam_purge_pvp_only", type = "checkbox", label = "Shield Slam Purge — Players Only", default = true, tooltip = "Only purge buffs from enemy players (safer for PvE dungeons with CC'd mobs)." },
                    { key = "pvp_kite_threshold", type = "slider", label = "PvP Kite HP", min = 20, max = 80, default = 50 },
                    { key = "aoe_threshold", type = "slider", label = "AoE Count", min = 2, max = 6, default = 3 },
                    { key = "prot_tab_targeting", type = "checkbox", label = "Multi-Target Taunt Cycling (Prot)", default = true, tooltip = "Tab-target enemies that lack aggro for Taunt/Mocking Blow cycling." },
                    { key = "prot_tab_range", type = "slider", label = "Tab Target Range (yd)", min = 10, max = 40, default = 20, tooltip = "Range in yards to scan for threat targets." },
                },
            },
            {
                header = "Advanced",
                settings = {
                    { key = "warrior_use_spell_reflection", type = "checkbox", label = "Spell Reflection", default = true },
                    { key = "warrior_reflect_pvp_only", type = "checkbox", label = "Spell Reflection PvP Only", default = true },
                    { key = "use_disarm", type = "checkbox", label = "Auto Disarm (PvP)", default = true, tooltip = "Disarm enemy melee players (Warrior/Rogue/Paladin/Shaman). Requires Defensive Stance." },
                    { key = "disarm_trigger", type = "dropdown", label = "Disarm Trigger", default = "on_burst", options = {
                            { text = "On Burst (target has priority buffs)", value = "on_burst" },
                            { text = "On Cooldown", value = "on_cooldown" },
                    }, tooltip = "on_burst: only disarm when enemy has priority buffs (Death Wish, Bloodlust, etc.). on_cooldown: disarm whenever available." },
                    { key = "disarm_pvp_only", type = "checkbox", label = "Disarm — Players Only", default = true, tooltip = "Only disarm enemy players (safer for PvE with CC'd mobs)." },
                    { key = "warrior_cancel_external_buff", type = "checkbox", label = "Cancel PW:S/BoP", default = false },
                    { key = "warrior_defensive_stance_pve", type = "checkbox", label = "Defensive Stance Outside PvP", default = false },
                    { key = "hs_trick", type = "checkbox", label = "HS Dequeue Trick", default = true, description = "Smart HS dequeue to avoid rage waste on missed attacks" },
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
