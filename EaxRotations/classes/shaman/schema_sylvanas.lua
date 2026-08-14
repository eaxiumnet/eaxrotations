-- shaman/schema_sylvanas.lua — Shaman menu schema and settings defaults.
-- WHAT:  defines menu widgets (checkboxes, sliders, keybinds) for shaman specs.
-- WHEN:  loaded at addon init to register middleware menu entries.
-- WHY:   centralized menu definition prevents duplicate widget IDs.
-- SAFETY: nil-guarded menu references; default fallbacks for all settings.

-- Shaman menu schema.

local consumables = require("shared/schema_consumables_sylvanas")

return {
    {
        name = "General",
        sections = {
            {
                header = "Rotation",
                settings = {
                    { key = "playstyle", type = "dropdown", label = "Playstyle", default = "elemental", options = {
                            { text = "Leveling", value = "leveling" },
                            { text = "Elemental", value = "elemental" },
                            { text = "Enhancement", value = "enhancement" },
                            { text = "Restoration", value = "restoration" },
                    } },
                    { key = "use_cooldowns", type = "checkbox", label = "Cooldowns", default = true },
                    { key = "use_cooldowns_on_boss_only", type = "checkbox", label = "Cooldowns on Bosses Only", default = false, tooltip = "Only use major offensive cooldowns (Bloodlust/Heroism, Shamanistic Rage) on boss targets — skip on trash" },
                    { key = "use_interrupt", type = "checkbox", label = "Interrupts", default = true },
                    { key = "use_threat_drop", type = "checkbox", label = "Threat Drop", default = true },
                    { key = "aoe_threshold", type = "slider", label = "AoE Count", min = 2, max = 6, default = 3 },
                    { key = "use_ooc_buffs", type = "checkbox", label = "OOC Buffs", default = true },
                    { key = "auto_lightning_shield", type = "checkbox", label = "Lightning Shield (OOC)", default = true, tooltip = "Maintain Lightning Shield out of combat" },
                    { key = "use_bloodlust", type = "checkbox", label = "Bloodlust", default = true },
                    { key = "self_heal_hp", type = "slider", label = "Self-Heal HP Threshold", min = 0, max = 100, default = 0, tooltip = "Cast Lesser Healing Wave on self when HP drops below this (0 = disabled)" },
                },
            },
            {
                header = "Enhancement � Combat & Rotation",
                settings = {
                    { key = "enhancement_combat_mode", type = "dropdown", label = "Combat Mode", default = "auto", options = {
                        { text = "Auto", value = "auto" },
                        { text = "Single Target", value = "single" },
                        { text = "AoE", value = "aoe" },
                    } },
                    { key = "enhancement_earth_shock_mode", type = "dropdown", label = "Earth Shock Mode", default = "interrupts", options = {
                        { text = "None", value = "none" },
                        { text = "DPS", value = "dps" },
                        { text = "Interrupts", value = "interrupts" },
                    } },
                    { key = "enhancement_shield_type", type = "dropdown", label = "Shield Type", default = "auto", options = {
                        { text = "Lightning Shield", value = "lightning" },
                        { text = "Water Shield", value = "water" },
                        { text = "Auto", value = "auto" },
                    } },
                    { key = "enhancement_manage_totems", type = "checkbox", label = "Manage Totems", default = true },
                    { key = "enhancement_totem_twisting", type = "checkbox", label = "WF + GoA Twisting", default = true },
                    { key = "enhancement_twist_mana_threshold", type = "slider", label = "Totem Twist Min Mana %", min = 0, max = 100, default = 40, tooltip = "Only attempt totem twisting when mana is above this threshold" },
                    { key = "enhancement_auto_attack", type = "checkbox", label = "Auto Attack", default = true },
                    { key = "enhancement_aoe_threshold", type = "slider", label = "AoE Threshold", min = 2, max = 6, default = 3 },
                },
            },
            {
                header = "Enhancement � Air Totems",
                settings = {
                    { key = "enhancement_air_totem", type = "dropdown", label = "Air Totem", default = "windfury", options = {
                        { text = "None", value = "none" },
                        { text = "Windfury Totem", value = "windfury" },
                        { text = "Grace of Air Totem", value = "grace" },
                    } },
                },
            },
            {
                header = "Enhancement � Earth Totems",
                settings = {
                    { key = "enhancement_earth_totem", type = "dropdown", label = "Earth Totem", default = "strength", options = {
                        { text = "None", value = "none" },
                        { text = "Strength of Earth Totem", value = "strength" },
                        { text = "Stoneskin Totem", value = "stoneskin" },
                    } },
                },
            },
            {
                header = "Enhancement � Fire Totems",
                settings = {
                    { key = "enhancement_fire_totem", type = "dropdown", label = "Fire Totem", default = "searing", options = {
                        { text = "None", value = "none" },
                        { text = "Searing Totem", value = "searing" },
                        { text = "Magma Totem", value = "magma" },
                        { text = "Fire Nova Totem", value = "fire_nova" },
                        { text = "Fire Weaving (Nova+Magma)", value = "fire_weaving" },
                    } },
                },
            },
            {
                header = "Enhancement � Water Totems",
                settings = {
                    { key = "enhancement_water_totem", type = "dropdown", label = "Water Totem", default = "mana_spring", options = {
                        { text = "None", value = "none" },
                        { text = "Healing Stream Totem", value = "healing_stream" },
                        { text = "Mana Spring Totem", value = "mana_spring" },
                    } },
                },
            },
            {
                header = "Enhancement � Weapon Buffs",
                settings = {
                    { key = "enhancement_main_hand_ench", type = "dropdown", label = "Main Hand Enchant", default = "windfury", options = {
                        { text = "Auto (Level)", value = "auto" },
                        { text = "None", value = "none" },
                        { text = "Windfury Weapon", value = "windfury" },
                        { text = "Flametongue Weapon", value = "flametongue" },
                        { text = "Rockbiter Weapon", value = "rockbiter" },
                        { text = "Frostbrand Weapon", value = "frostbrand" },
                    } },
                    { key = "enhancement_off_hand_ench", type = "dropdown", label = "Off Hand Enchant", default = "flametongue", options = {
                        { text = "Auto (Level)", value = "auto" },
                        { text = "None", value = "none" },
                        { text = "Windfury Weapon", value = "windfury" },
                        { text = "Flametongue Weapon", value = "flametongue" },
                        { text = "Rockbiter Weapon", value = "rockbiter" },
                        { text = "Frostbrand Weapon", value = "frostbrand" },
                    } },
                },
            },
            {
                header = "Enhancement � Self Survival",
                settings = {
                    { key = "enhancement_self_heal_hp", type = "slider", label = "Lesser Healing Wave HP %", min = 0, max = 100, default = 40 },
                    { key = "enhancement_chain_heal_hp", type = "slider", label = "Chain Heal HP %", min = 0, max = 100, default = 35 },
                },
            },
            {
                header = "Enhancement � Interrupts",
                settings = {
                    { key = "enhancement_interrupt_kick_min", type = "slider", label = "Kick Min Cast %", min = 0, max = 100, default = 40 },
                    { key = "enhancement_interrupt_kick_max", type = "slider", label = "Kick Max Cast %", min = 0, max = 100, default = 80 },
                    { key = "enhancement_interrupt_mode", type = "dropdown", label = "Interrupt Mode", default = "target", options = {
                        { text = "Target Only", value = "target" },
                        { text = "Any in Range", value = "any" },
                    } },
                    { key = "enhancement_sr_melee_only", type = "checkbox", label = "Shamanistic Rage Melee Only", default = true },
                },
            },
            {
                header = "Enhancement � Utility",
                settings = {
                    { key = "enhancement_totem_range", type = "slider", label = "Totem Range (yds)", min = 20, max = 30, default = 30 },
                    { key = "enhancement_fs_multi_target", type = "checkbox", label = "Flame Shock Multi-Target in AoE", default = false },
                    { key = "enhancement_hold_shocks_focus", type = "checkbox", label = "Hold Shocks OOC for Shamanistic Focus Proc", default = true },
                    { key = "enhancement_ghost_wolf_ooc", type = "checkbox", label = "Ghost Wolf OOC", default = true },
                    { key = "enhancement_water_shield_mana", type = "slider", label = "Water Shield Mana %", min = 0, max = 100, default = 60 },
                    { key = "enhancement_lightning_shield_mana", type = "slider", label = "Lightning Shield Return Mana %", min = 0, max = 100, default = 80 },
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
                    { key = "enhancement_auto_totemic_call", type = "checkbox", label = "Auto Totemic Call", default = true },
                },
            },
            {
                header = "Enhancement – Mana Conservation",
                settings = {
                    { key = "enhancement_mana_low_pct", type = "slider", label = "Mana Low (% — skip shocks, conserve)", min = 10, max = 50, default = 20 },
                    { key = "enhancement_mana_emergency_pct", type = "slider", label = "Mana Emergency (% — auto-attack only)", min = 0, max = 20, default = 10 },
                    { key = "enhancement_totem_twist_mana_floor", type = "slider", label = "Totem Twist Mana Floor (%)", min = 0, max = 100, default = 40 },
                },
            },
            {
                header = "Enhancement – Cooldowns",
                settings = {
                    { key = "enhancement_cd_shamanistic_rage", type = "checkbox", label = "Shamanistic Rage", default = true },
                    { key = "enhancement_cd_blood_fury", type = "checkbox", label = "Blood Fury (Orc)", default = true },
                    { key = "enhancement_cd_berserking", type = "checkbox", label = "Berserking (Troll)", default = true },
                    { key = "enhancement_cd_bloodlust", type = "checkbox", label = "Bloodlust", default = true },
                    { key = "enhancement_cd_mana_tide", type = "checkbox", label = "Mana Tide Totem", default = true },
                    { key = "enhancement_cd_gift_of_the_naaru", type = "checkbox", label = "Gift of the Naaru (Draenei)", default = true },
                },
            },
        },
    },
    {
        name = "Elemental",
        sections = {
            {
                header = "Elemental – Rotation & Mana",
                settings = {
                    { key = "elemental_cl_min_targets", type = "slider", label = "Chain Lightning Min Targets", min = 2, max = 5, default = 3 },
                    { key = "elemental_cl_single_target", type = "checkbox", label = "Chain Lightning on Single Target", default = false, tooltip = "Guide divergence (default OFF): allow Chain Lightning on single-target fights where it outperforms Lightning Bolt filler. When OFF, Chain Lightning stays AoE-only" },
                    { key = "elemental_fs_maintain", type = "checkbox", label = "Maintain Flame Shock (refresh <3s)", default = false, tooltip = "Guide divergence (default OFF): refresh Flame Shock on the current target at <3s remaining even in single-target rotation, keeping the DoT up for the Lava Burst crit synergy. When OFF, Flame Shock stays clip-window-only (<=1s)" },
                    { key = "elemental_cl_cluster_radius", type = "slider", label = "Chain Lightning Cluster Radius (yds)", min = 5, max = 20, default = 10 },
                    { key = "elemental_aoe_threshold", type = "slider", label = "AoE Totem Min Targets", min = 2, max = 6, default = 4 },
                    { key = "elemental_mana_low_pct", type = "slider", label = "Mana Low (% switch to lower Lightning Bolt)", min = 10, max = 50, default = 30 },
                    { key = "elemental_mana_conserve_pct", type = "slider", label = "Mana Conserve (% no Chain Lightning)", min = 5, max = 30, default = 15 },
                    { key = "elemental_mana_emergency_pct", type = "slider", label = "Mana Emergency (% all spells off)", min = 0, max = 15, default = 5 },
                    { key = "elemental_flame_shock_min_sp", type = "slider", label = "Flame Shock Min Spell Damage", min = 0, max = 2000, default = 400 },
                },
            },
            {
                header = "Elemental – Cooldowns & Burst",
                settings = {
                    { key = "elemental_use_elemental_mastery", type = "checkbox", label = "Elemental Mastery Burst", default = true },
                    { key = "elemental_use_natures_swiftness", type = "checkbox", label = "Nature's Swiftness Burst", default = true },
                },
            },
            {
                header = "Elemental – Totems",
                settings = {
                    { key = "elemental_manage_totems", type = "checkbox", label = "Auto Totems (Wrath/Air/Mana Spring)", default = true },
                    { key = "elemental_use_totem_of_wrath", type = "checkbox", label = "Totem of Wrath", default = true },
                    { key = "elemental_use_fire_nova_aoe", type = "checkbox", label = "Fire Nova Totem AoE", default = true },
                    { key = "elemental_use_magma_aoe", type = "checkbox", label = "Magma Totem AoE", default = true },
                },
            },
            {
                header = "Elemental – Defensive",
                settings = {
                    { key = "elemental_lightning_shield", type = "checkbox", label = "Lightning Shield Auto", default = true },
                    { key = "elemental_water_shield_mana", type = "slider", label = "Water Shield Mana %", min = 0, max = 100, default = 50 },
                    { key = "elemental_self_heal_hp", type = "slider", label = "Healing Wave HP %", min = 0, max = 100, default = 40 },
                    { key = "elemental_interrupt_reserve", type = "checkbox", label = "Reserve Earth Shock for Interrupts", default = true },
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
                    { key = "leveling_use_shocks", type = "checkbox", label = "Use Shocks", default = true },
                    { key = "leveling_use_weapon_imbue", type = "checkbox", label = "Weapon Imbue", default = true },
                    { key = "leveling_weapon_imbue", type = "dropdown", label = "Imbue", default = "auto", options = {
                            { text = "Auto", value = "auto" },
                            { text = "Windfury", value = "windfury" },
                            { text = "Rockbiter", value = "rockbiter" },
                            { text = "Flametongue", value = "flametongue" },
                            { text = "Frostbrand", value = "frostbrand" },
                    } },
                    { key = "leveling_use_totems", type = "checkbox", label = "Use Totems", default = true },
                    { key = "leveling_use_searing_totem", type = "checkbox", label = "Searing Totem", default = true },
                    { key = "leveling_use_strength_totem", type = "checkbox", label = "Strength Totem", default = true },
                    { key = "leveling_use_water_totem", type = "checkbox", label = "Water Totem", default = true },
                },
            },
        },
    },
    {
        name = "Restoration",
        sections = {
            {
                header = "Restoration – Combat & Rotation",
                settings = {
                    { key = "restoration_manage_totems", type = "checkbox", label = "Auto Totems", default = true },
                    { key = "restoration_shield_type", type = "dropdown", label = "Shield Type", default = "water", options = {
                            { text = "Lightning Shield", value = "lightning" },
                            { text = "Water Shield", value = "water" },
                    } },
                    { key = "restoration_earth_shield_charge_threshold", type = "slider", label = "Earth Shield Refresh at Charges ≤", min = 0, max = 5, default = 2 },
                    { key = "shaman_group_aware_utility", type = "checkbox", label = "Group-Aware Healing Utility", default = true, tooltip = "When enabled, Chain Heal requires 2+ injured (or raid) and Mana Tide Totem requires group/raid. When disabled, Chain Heal always requires 2+ injured and Mana Tide ignores group status." },
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
                },
            },
            {
                header = "Restoration – Healing Thresholds",
                settings = {
                    { key = "restoration_chain_heal_hp", type = "slider", label = "Chain Heal HP %", min = 0, max = 100, default = 65 },
                    { key = "restoration_mana_tide_pct", type = "slider", label = "Mana Tide Below %", min = 0, max = 100, default = 60 },
                    { key = "restoration_idle_hp", type = "slider", label = "Idle/DPS HP % (heal below)", min = 0, max = 100, default = 88 },
                },
            },
            {
                header = "Restoration – Mana Conservation",
                settings = {
                    { key = "restoration_mana_low_pct", type = "slider", label = "Mana Low (% — skip Chain Heal)", min = 10, max = 60, default = 30 },
                    { key = "restoration_mana_conserve_pct", type = "slider", label = "Mana Conserve (% — no DPS shocks)", min = 5, max = 30, default = 15 },
                    { key = "restoration_mana_emergency_pct", type = "slider", label = "Mana Emergency (% — healing only)", min = 0, max = 15, default = 5 },
                    { key = "fsr_enabled", type = "checkbox", label = "FSR Pause", default = true },
                    { key = "fsr_mana_threshold", type = "slider", label = "FSR Mana Threshold %", min = 0, max = 100, default = 35 },
                    { key = "fsr_emergency_hp", type = "slider", label = "FSR Emergency HP%", min = 0, max = 100, default = 40 },
                    { key = "fsr_max_pause_seconds", type = "slider", label = "FSR Max Pause (s, 0=full)", min = 0, max = 5, default = 0 },
                },
            },
            {
                header = "Restoration – DPS",
                settings = {
                    { key = "restoration_dps_when_idle", type = "checkbox", label = "DPS When Idle (explicit opt-in required)", default = false },
                    { key = "restoration_dps_mana_floor", type = "slider", label = "DPS Min Mana %", min = 10, max = 80, default = 35 },
                },
            },
        },
    },
    require("shared/schema_autoloot_sylvanas").build_tab(),
    consumables.build_tab({ use_drums = { default = true }, use_mana_potions = { default = true } }),
}
