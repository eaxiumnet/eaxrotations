-- priest/schema_sylvanas.lua — Priest menu schema and settings defaults.
-- WHAT:  defines menu widgets (checkboxes, sliders, keybinds) for priest specs.
-- WHEN:  loaded at addon init to register middleware menu entries.
-- WHY:   centralized menu definition prevents duplicate widget IDs.
-- SAFETY: nil-guarded menu references; default fallbacks for all settings.

-- Priest menu schema.

local consumables = require("shared/schema_consumables_sylvanas")

return {
    {
        name = "General",
        sections = {
            {
                header = "Rotation",
                settings = {
                    { key = "playstyle", type = "dropdown", label = "Playstyle", default = "discipline", options = {
                            { text = "Leveling", value = "leveling" },
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
                    { key = "use_symbol_of_hope", type = "checkbox", label = "Symbol of Hope (Party Mana)", default = true, tooltip = "Buffs party members with 33 mana every 5 sec for 15 sec. 15 mana cost, 5 min cooldown. Requires group/party." },
                    { key = "pws_hp", type = "slider", label = "PW:Shield HP Threshold", min = 0, max = 100, default = 0, tooltip = "Self-cast PW:Shield when HP drops below this in combat (0 = disabled)" },
                    { key = "auto_inner_fire", type = "checkbox", label = "Inner Fire (OOC)", default = true },
                    { key = "auto_fortitude", type = "checkbox", label = "Fortitude (OOC)", default = true },
                    { key = "use_offensive_dispel", type = "checkbox", label = "Offensive Dispel", default = true, tooltip = "Dispel target magic buffs (Bloodlust, PW:S, Ice Barrier, etc.) â€” auto-targets highest priority enemy" },
                    { key = "offensive_dispel_mana_floor", type = "slider", label = "Offensive Dispel Mana Floor", min = 10, max = 60, default = 30 },
                    { key = "use_mass_dispel", type = "checkbox", label = "Mass Dispel", default = false, tooltip = "AoE dispel all friendlies within 15yd; 100 mana cost, no CD" },
                    { key = "mass_dispel_mana_floor", type = "slider", label = "Mass Dispel Mana Floor", min = 10, max = 80, default = 50 },
                    { key = "use_mana_burn", type = "checkbox", label = "Mana Burn", default = true, tooltip = "Burn enemy mana (caster classes, healers) to deny casts" },
                    { key = "mana_burn_mana_floor", type = "slider", label = "Mana Burn Mana Floor", min = 10, max = 60, default = 40 },
                },
            },
        },
    },
    {
        name = "Discipline",
        sections = {
            {
                header = "Healing Priority",
                settings = {
                    { key = "discipline_pws_hp", type = "slider", label = "PW:S HP Threshold (%)", min = 10, max = 60, default = 35 },
                    { key = "discipline_flash_hp", type = "slider", label = "Flash Heal HP (%)", min = 20, max = 80, default = 55 },
                    { key = "discipline_greater_heal_hp", type = "slider", label = "Greater Heal HP (%)", min = 30, max = 95, default = 82 },
                    { key = "discipline_renew_hp", type = "slider", label = "Renew HP (%)", min = 50, max = 100, default = 90 },
                },
            },
            {
                header = "Smart Casting",
                settings = {
                    { key = "stopcast_enabled", type = "checkbox", label = "Smart Stop-Cast", default = true, tooltip = "Cancel in-flight heals if target recovers above threshold during cast" },
                    { key = "stopcast_threshold", type = "slider", label = "Stop-Cast Threshold (%)", min = 80, max = 100, default = 95, tooltip = "Cancel cast if target would end above this HP%" },
                    { key = "tank_hp_bias", type = "slider", label = "Tank HP Bias (%)", min = 0, max = 30, default = 15, tooltip = "Treat tanks as if they have this much less HP for triage scoring" },
                    { key = "heal_pets", type = "checkbox", label = "Heal Pets", default = true, tooltip = "Include Hunter/Warlock pets in healing target scan" },
                    { key = "pet_weight", type = "slider", label = "Pet Triage Weight", min = 0.1, max = 1.0, default = 0.6, tooltip = "Lower = pets are less urgent than players" },
                    { key = "fsr_enabled", type = "checkbox", label = "FSR Pause", default = true },
                    { key = "fsr_mana_threshold", type = "slider", label = "FSR Mana Threshold (%)", min = 10, max = 60, default = 35 },
                    { key = "fsr_emergency_hp", type = "slider", label = "FSR Emergency HP (%)", min = 10, max = 60, default = 40 },
                    { key = "fsr_max_pause_seconds", type = "slider", label = "FSR Max Pause (s)", min = 0, max = 5, default = 2 },
                },
            },
            {
                header = "Cooldowns",
                settings = {
                    { key = "discipline_pain_suppression_hp", type = "slider", label = "Pain Suppression HP (%)", min = 10, max = 50, default = 25 },
                    { key = "discipline_use_power_infusion", type = "checkbox", label = "Power Infusion", default = true },
                    { key = "discipline_pi_safety_hp", type = "slider", label = "PI Safety HP (%)", min = 40, max = 100, default = 80 },
                    { key = "discipline_use_inner_focus", type = "checkbox", label = "Inner Focus", default = true },
                    { key = "discipline_if_hp", type = "slider", label = "Inner Focus HP (%)", min = 30, max = 90, default = 65 },
                },
            },
            {
                header = "AoE Healing",
                settings = {
                    { key = "discipline_aoe_hp", type = "slider", label = "AoE HP Threshold (%)", min = 50, max = 100, default = 85 },
                },
            },
            {
                header = "DPS When Idle",
                settings = {
                    { key = "discipline_dps_when_idle", type = "checkbox", label = "DPS When Idle", default = false },
                    { key = "discipline_dps_mana_floor", type = "slider", label = "DPS Mana Floor (%)", min = 10, max = 70, default = 35 },
                    { key = "discipline_idle_hp", type = "slider", label = "Idle DPS Group Safe HP (%)", min = 50, max = 100, default = 92 },
                },
            },
            {
                header = "Shield Targeting",
                settings = {
                    { key = "disc_shield_tank_only", type = "checkbox", label = "Shield Tank Only", default = false, tooltip = "Only cast Power Word: Shield on the tank. Disable to shield any injured party member." },
                },
            },
            {
                header = "Pre-Pull",
                settings = {
                    { key = "disc_prepull_pom", type = "checkbox", label = "Pre-Pull Prayer of Mending", default = true },
                },
            },
            {
                header = "Self Survival",
                settings = {
                    { key = "discipline_healthstone_hp", type = "slider", label = "Healthstone HP (%)", min = 10, max = 60, default = 35 },
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
                    { key = "leveling_heal_hp", type = "slider", label = "Heal HP %", min = 0, max = 100, default = 50 },
                    { key = "leveling_use_desperate_prayer", type = "checkbox", label = "Desperate Prayer (panic button)", default = true, tooltip = "Self-heal when HP drops below threshold. Race-gated (Human/Dwarf/Draenei/Dark Iron all learn at L10-66)." },
                    { key = "leveling_desp_prayer_hp", type = "slider", label = "Desperate Prayer HP %", min = 5, max = 60, default = 35 },
                },
            },
        },
    },
    {
        name = "Holy",
        sections = {
            {
                header = "Healing Priority",
                settings = {
                    { key = "holy_use_pws", type = "checkbox", label = "Power Word: Shield", default = true },
                    { key = "holy_pws_hp", type = "slider", label = "PW:S HP Threshold (%)", min = 10, max = 60, default = 30 },
                    { key = "holy_emergency_hp", type = "slider", label = "Emergency Heal HP (%)", min = 10, max = 60, default = 30 },
                    { key = "holy_flash_heal_hp", type = "slider", label = "Flash Heal HP (%)", min = 20, max = 80, default = 50 },
                    { key = "holy_renew_hp", type = "slider", label = "Renew HP (%)", min = 50, max = 100, default = 90 },
                },
            },
            {
                header = "Smart Casting",
                settings = {
                    { key = "stopcast_enabled", type = "checkbox", label = "Smart Stop-Cast", default = true, tooltip = "Cancel in-flight heals if target recovers above threshold during cast" },
                    { key = "stopcast_threshold", type = "slider", label = "Stop-Cast Threshold (%)", min = 80, max = 100, default = 95, tooltip = "Cancel cast if target would end above this HP%" },
                    { key = "tank_hp_bias", type = "slider", label = "Tank HP Bias (%)", min = 0, max = 30, default = 15, tooltip = "Treat tanks as if they have this much less HP for triage scoring" },
                    { key = "heal_pets", type = "checkbox", label = "Heal Pets", default = true, tooltip = "Include Hunter/Warlock pets in healing target scan" },
                    { key = "pet_weight", type = "slider", label = "Pet Triage Weight", min = 0.1, max = 1.0, default = 0.6, tooltip = "Lower = pets are less urgent than players" },
                    { key = "fsr_enabled", type = "checkbox", label = "Enable FSR Pause", default = true },
                    { key = "fsr_mana_threshold", type = "slider", label = "FSR Mana Threshold (%)", min = 5, max = 60, default = 35 },
                    { key = "fsr_emergency_hp", type = "slider", label = "FSR Emergency HP (%)", min = 10, max = 80, default = 40 },
                    { key = "fsr_max_pause_seconds", type = "slider", label = "FSR Max Pause Seconds", min = 0, max = 5, default = 2 },
                },
            },
            {
                header = "AoE Healing",
                settings = {
                    { key = "holy_use_coh", type = "checkbox", label = "Circle of Healing", default = true },
                    { key = "holy_use_poh", type = "checkbox", label = "Prayer of Healing", default = true },
                    { key = "holy_aoe_count", type = "slider", label = "AoE Target Count", min = 2, max = 6, default = 3 },
                    { key = "holy_aoe_hp", type = "slider", label = "AoE HP Threshold (%)", min = 50, max = 100, default = 80 },
                },
            },
            {
                header = "Cooldowns & Utility",
                settings = {
                    { key = "holy_use_lightwell", type = "checkbox", label = "Lightwell", default = false },
                    { key = "holy_use_inner_focus", type = "checkbox", label = "Inner Focus", default = true },
                    { key = "holy_use_binding_heal", type = "checkbox", label = "Binding Heal", default = true },
                    { key = "holy_binding_self_hp", type = "slider", label = "Binding Heal Self HP (%)", min = 20, max = 100, default = 80 },
                    { key = "holy_use_desperate_prayer", type = "checkbox", label = "Desperate Prayer", default = true },
                    { key = "holy_desp_prayer_hp", type = "slider", label = "Desperate Prayer HP (%)", min = 10, max = 60, default = 30 },
                    { key = "holy_healthstone_hp", type = "slider", label = "Healthstone HP (%)", min = 10, max = 60, default = 35 },
                },
            },
            {
                header = "Pre-Pull & Idle",
                settings = {
                    { key = "holy_prepull_pom", type = "checkbox", label = "Pre-Pull PoM", default = true },
                    { key = "holy_prepull_renew", type = "checkbox", label = "Pre-Pull Renew", default = true },
                    { key = "holy_dps_when_idle", type = "checkbox", label = "DPS When Idle", default = false },
                    { key = "holy_dps_mana_floor", type = "slider", label = "DPS Mana Floor (%)", min = 10, max = 90, default = 70 },
                },
            },
            {
                header = "Mana Conservation",
                settings = {
                    { key = "holy_gh_mana_floor", type = "slider", label = "GH Mana Floor (%)", min = 10, max = 50, default = 30 },
                    { key = "holy_fh_mana_floor", type = "slider", label = "FH Mana Floor (%)", min = 5, max = 40, default = 15 },
                },
            },
        },
    },
    {
        name = "Shadow",
        sections = {
            {
                header = "Combat",
                settings = {
                    { key = "shadow_combat_mode", type = "dropdown", label = "Combat Mode", default = "auto", options = {
                        { text = "Auto", value = "auto" },
                        { text = "Single Target", value = "st" },
                        { text = "Cleave", value = "cleave" },
                        { text = "AoE", value = "aoe" },
                    } },
                    { key = "shadow_multidot_mode", type = "dropdown", label = "Multi-DoT Mode", default = 1, options = {
                        { text = "Off", value = 1 },
                        { text = "Near Target Only", value = 2 },
                        { text = "All in Range", value = 3 },
                    } },
                    { key = "shadow_multidot_max_targets", type = "slider", label = "Multi-DoT Max Targets", min = 2, max = 5, default = 3 },
                    { key = "shadow_multi_dot_range", type = "slider", label = "Multi-DoT Range", min = 10, max = 40, default = 30 },
                    { key = "shadow_multi_dot_targets", type = "slider", label = "Multi-DoT Targets", min = 2, max = 6, default = 3 },
                },
            },
            {
                header = "DoT Refresh",
                settings = {
                    { key = "shadow_vt_refresh_window", type = "slider", label = "VT Refresh Window (s)", min = 0.5, max = 3.0, default = 1.5 },
                    { key = "shadow_swp_refresh_window", type = "slider", label = "SW:P Refresh Window (s)", min = 0.5, max = 3.0, default = 1.5 },
                    { key = "shadow_dp_refresh_window", type = "slider", label = "DP Refresh Window (s)", min = 1, max = 6, default = 3 },
                    { key = "shadow_dot_ttd_threshold", type = "slider", label = "DoT TTD Threshold (%)", min = 0, max = 100, default = 50, tooltip = "Skip DoT reapplication if target dies before this % of DoT duration" },
                },
            },
            {
                header = "Mana Conservation",
                settings = {
                    { key = "shadow_mb_mana_floor", type = "slider", label = "MB Mana Floor (%)", min = 10, max = 50, default = 30 },
                    { key = "shadow_conserve_mana_floor", type = "slider", label = "Conserve Mana Floor (%)", min = 5, max = 30, default = 15 },
                    { key = "shadow_if_mb_combo", type = "checkbox", label = "Inner Focus + Mind Blast Combo", default = true, tooltip = "Hold Inner Focus for Mind Blast; if MB on long CD, use IF on next best spell" },
                },
            },
            {
                header = "Self Survival",
                settings = {
                    { key = "shadow_swd_safety_hp", type = "slider", label = "SW:D Min Self HP %", min = 20, max = 100, default = 80 },
                    { key = "shadow_shield_hp", type = "slider", label = "PW:Shield HP %", min = 0, max = 80, default = 35 },
                    { key = "shadow_flash_heal_hp", type = "slider", label = "Flash Heal HP %", min = 0, max = 80, default = 25 },
                },
            },
            {
                header = "Threat & Safety",
                settings = {
                    { key = "shadow_threat_safe", type = "checkbox", label = "Threat Safety Gate", default = true },
                },
            },
            {
                header = "Utility",
                settings = {
                    { key = "shadow_use_inner_fire", type = "checkbox", label = "Auto Inner Fire", default = true },
                    { key = "shadow_mounted_bail", type = "checkbox", label = "Mounted Bail", default = true },
                },
            },
        },
    },
    {
        name = "Smite",
        sections = {
            {
                header = "DPS Priority",
                settings = {
                    { key = "smite_holy_fire_weave", type = "checkbox", label = "Holy Fire Weave Mode", default = true },
                    { key = "smite_use_inner_focus", type = "checkbox", label = "Inner Focus", default = true },
                    { key = "smite_use_starshards", type = "checkbox", label = "Starshards (NE)", default = true },
                    { key = "smite_use_devouring_plague", type = "checkbox", label = "Devouring Plague (UD)", default = true },
                    { key = "smite_use_power_infusion", type = "checkbox", label = "Power Infusion", default = true },
                },
            },
            {
                header = "Optional Shadow Spells",
                settings = {
                    { key = "smite_use_mb", type = "checkbox", label = "Mind Blast", default = false },
                    { key = "smite_use_swd", type = "checkbox", label = "Shadow Word: Death", default = false },
                    { key = "smite_swd_hp", type = "slider", label = "SW:D Min Self HP (%)", min = 20, max = 100, default = 40 },
                },
            },
            {
                header = "Mana Conservation",
                settings = {
                    { key = "smite_mana_floor", type = "slider", label = "Mana Low Floor (%)", min = 10, max = 60, default = 30 },
                    { key = "smite_conserve_mana_floor", type = "slider", label = "Spell Cut Floor (%)", min = 5, max = 30, default = 15 },
                    { key = "smite_wand_floor", type = "slider", label = "Wand-Only Floor (%)", min = 1, max = 20, default = 5 },
                    { key = "smite_use_shadowfiend", type = "checkbox", label = "Shadowfiend", default = true },
                    { key = "smite_shadowfiend_mana", type = "slider", label = "Shadowfiend Mana (%)", min = 10, max = 70, default = 35 },
                },
            },
            {
                header = "Solo & Survival",
                settings = {
                    { key = "smite_solo_pws_hp", type = "slider", label = "PW:S HP Threshold (%)", min = 10, max = 90, default = 55 },
                    { key = "smite_solo_renew_hp", type = "slider", label = "Renew HP Threshold (%)", min = 20, max = 100, default = 72 },
                    { key = "smite_solo_scream_hp", type = "slider", label = "Scream HP Threshold (%)", min = 10, max = 90, default = 75 },
                    { key = "smite_solo_scream_enemies", type = "slider", label = "Scream Min Enemies", min = 1, max = 6, default = 2 },
                    { key = "smite_pvp_scream_hp", type = "slider", label = "PvP Scream HP (%)", min = 10, max = 90, default = 65 },
                    { key = "smite_group_safe_hp", type = "slider", label = "Group Safe HP (%)", min = 50, max = 100, default = 80 },
                },
            },
            {
                header = "Threat & Safety",
                settings = {
                    { key = "smite_threat_safe", type = "checkbox", label = "Threat Safety Gate", default = true },
                },
            },
        },
    },
    require("shared/schema_autoloot_sylvanas").build_tab(),
    consumables.build_tab({ use_mana_potions = { default = true } }),
}
