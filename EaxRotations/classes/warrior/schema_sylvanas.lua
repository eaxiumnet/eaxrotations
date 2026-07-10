-- warrior/schema_sylvanas.lua — Warrior menu schema and settings defaults.
-- WHAT:  defines menu widgets (checkboxes, sliders, keybinds) for warrior specs.
-- WHEN:  loaded at addon init to register middleware menu entries.
-- WHY:   centralized menu definition prevents duplicate widget IDs.
-- SAFETY: nil-guarded menu references; default fallbacks for all settings.

-- Warrior menu schema.

local consumables = require("shared/schema_consumables_sylvanas")

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
                    { key = "use_cooldowns_on_boss_only", type = "checkbox", label = "Cooldowns on Bosses Only", default = false, tooltip = "Only use major offensive cooldowns (Death Wish, Recklessness) on boss targets — skip on trash" },
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
                    { key = "warrior_use_intervene", type = "checkbox", label = "Intervene (Prot)", default = true, tooltip = "Charge to a party member to intercept the next attack against them. 10 rage, 30s cd, 25yd range." },
                    { key = "warrior_intervene_pvp_only", type = "checkbox", label = "Intervene PvP Only", default = true, tooltip = "Only use Intervene in PvP to avoid wasting rage in PvE." },
                    { key = "warrior_intervene_hp_threshold", type = "slider", label = "Intervene Party HP%", min = 0, max = 100, default = 60, tooltip = "Party member HP threshold to trigger Intervene." },
                    { key = "use_disarm", type = "checkbox", label = "Auto Disarm (PvP)", default = true, tooltip = "Disarm enemy melee players (Warrior/Rogue/Paladin/Shaman). Requires Defensive Stance." },
                    { key = "disarm_trigger", type = "dropdown", label = "Disarm Trigger", default = "on_burst", options = {
                            { text = "On Burst (target has priority buffs)", value = "on_burst" },
                            { text = "On Cooldown", value = "on_cooldown" },
                    }, tooltip = "on_burst: only disarm when enemy has priority buffs (Death Wish, Bloodlust, etc.). on_cooldown: disarm whenever available." },
                    { key = "disarm_pvp_only", type = "checkbox", label = "Disarm — Players Only", default = true, tooltip = "Only disarm enemy players (safer for PvE with CC'd mobs)." },
                    { key = "warrior_cancel_external_buff", type = "checkbox", label = "Cancel PW:S/BoP", default = false },
                    { key = "warrior_defensive_stance_pve", type = "checkbox", label = "Defensive Stance Outside PvP", default = false },
                    { key = "hs_trick", type = "checkbox", label = "HS Dequeue Trick", default = true, description = "Smart HS dequeue to avoid rage waste on missed attacks" },
                    { key = "prot_swing_timer", type = "checkbox", label = "Swing Timer HS/Cleave", default = true, description = "Avoid Heroic Strike / Cleave within 0.3s of a melee swing to prevent clipping auto-attacks" },
                    { key = "fury_swing_desync", type = "checkbox", label = "Swing Desync (Fury DW)", default = false, description = "Inject Slam to desync MH/OH swing timers for smoother rage gen" },
                    { key = "fury_use_hamstring", type = "checkbox", label = "Hamstring Weave (Fury)", default = false, description = "Weave Hamstring at high rage for Sword Spec procs" },
                    { key = "fury_hamstring_rage", type = "slider", label = "Hamstring Weave Rage Min", min = 30, max = 100, default = 50, description = "Minimum rage to begin Hamstring Sword Spec weave" },
                    { key = "fury_ww_prio_count", type = "slider", label = "WW Priority Over BT", min = 0, max = 5, default = 2, description = "Enemy count threshold: yield Bloodthirst to Whirlwind above this (0=disabled)" },
                    { key = "kebab_general_use", type = "checkbox", label = "Kebab General Use", default = false, description = "Enable general-use Kebab mode (less pooling)" },
                    { key = "kebab_use_sweeping_strikes", type = "checkbox", label = "Kebab Use Sweeping Strikes", default = true },
                    { key = "kebab_use_whirlwind", type = "checkbox", label = "Kebab Use Whirlwind", default = true },
                    { key = "kebab_execute_phase", type = "checkbox", label = "Kebab Execute Phase", default = true },
                    { key = "kebab_use_ww_execute", type = "checkbox", label = "Kebab WW in Execute", default = true },
                    { key = "kebab_use_ms_execute", type = "checkbox", label = "Kebab MS in Execute", default = true },
                    { key = "kebab_use_overpower", type = "checkbox", label = "Kebab Use Overpower", default = true },
                    { key = "kebab_hs_during_execute", type = "checkbox", label = "Kebab HS During Execute", default = true },
                    { key = "kebab_hs_rage_threshold", type = "slider", label = "Kebab HS Rage Threshold", min = 0, max = 100, default = 40 },
                    { key = "kebab_force_dw_priority", type = "checkbox", label = "Kebab Force DW Priority", default = false },
                    { key = "auto_shout", type = "checkbox", label = "Kebab Auto Shout", default = true },
                    { key = "shout_type", type = "dropdown", label = "Kebab Shout Type", default = "battle", options = { { text = "Battle", value = "battle" }, { text = "Commanding", value = "commanding" } } },
                    { key = "sunder_armor_mode", type = "dropdown", label = "Kebab Sunder Mode", default = "none", options = { { text = "None", value = "none" }, { text = "Auto", value = "auto" } } },
                    { key = "maintain_thunder_clap", type = "checkbox", label = "Kebab Maintain Thunder Clap", default = true },
                    { key = "maintain_demo_shout", type = "checkbox", label = "Kebab Maintain Demo Shout", default = true },
                },
            },
            {
                header = "Threat & Combat Mode",
                settings = {
                    { key = "snap_threat_enabled", type = "checkbox", label = "Snap Threat on Combat Start", default = true, tooltip = "Fire Shield Slam immediately when entering combat to establish threat" },
                    { key = "combat_mode", type = "dropdown", label = "Combat Mode", default = "auto", options = {
                        { text = "Auto", value = "auto" },
                        { text = "Single Target", value = "single" },
                        { text = "AoE", value = "aoe" },
                    }, tooltip = "Force rotation mode: Auto uses enemy count, ST/AoE override" },
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
    require("shared/schema_autoloot_sylvanas").build_tab(),
    consumables.build_tab(),
}
