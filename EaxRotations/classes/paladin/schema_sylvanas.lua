-- Paladin menu schema.


return {
    {
        name = "General",
        sections = {
            {
                header = "Rotation",
                settings = {
                    { key = "playstyle", type = "dropdown", label = "Playstyle", default = "holy", options = {
                            { text = "Leveling", value = "leveling" },
                            { text = "Holy", value = "holy" },
                            { text = "Protection", value = "protection" },
                            { text = "Retribution", value = "retribution" },
                    } },
                    { key = "use_cooldowns", type = "checkbox", label = "Cooldowns", default = true },
                    { key = "seal_twisting", type = "checkbox", label = "Seal Twisting", default = true },
                    { key = "use_interrupt", type = "checkbox", label = "Interrupts", default = true },
                    { key = "use_threat_drop", type = "checkbox", label = "Threat Drop", default = true },
                    { key = "aoe_threshold", type = "slider", label = "AoE Count", min = 2, max = 6, default = 3 },
                },
            },
            {
                header = "Blessing Refresh",
                settings = {
                    { key = "holy_refresh_enabled", type = "checkbox", label = "Combat Refresh", default = true, tooltip = "Refresh Wisdom and Kings in combat when duration is low" },
                    { key = "holy_refresh_threshold", type = "slider", label = "Refresh When < (sec)", min = 30, max = 300, default = 120, tooltip = "Refresh blessings when remaining time drops below this" },
                    { key = "holy_refresh_mana", type = "slider", label = "Min Mana %", min = 0, max = 100, default = 30, tooltip = "Only refresh blessings when mana is above this threshold" },
                },
            },
            {
                header = "Holy Healing",
                settings = {
                    { key = "holy_shock_hp", type = "slider", label = "Holy Shock HP %", min = 0, max = 100, default = 40, tooltip = "Use Holy Shock for instant emergency or movement healing" },
                    { key = "holy_divine_favor_hp", type = "slider", label = "Divine Favor HP %", min = 0, max = 100, default = 45, tooltip = "Use Divine Favor before critical Holy Light healing" },
                    { key = "holy_flash_light_hp", type = "slider", label = "Flash of Light HP %", min = 0, max = 100, default = 85, tooltip = "Use efficient Flash of Light below this HP" },
                    { key = "holy_light_hp", type = "slider", label = "Holy Light HP %", min = 40, max = 100, default = 70, tooltip = "Prefer Holy Light over Flash of Light below this HP" },
                    { key = "holy_light_rank", type = "dropdown", label = "Holy Light Rank", default = "max", options = {
                            { text = "Max / Smart", value = "max" },
                            { text = "Rank 9", value = "rank9" },
                            { text = "Rank 7", value = "rank7" },
                            { text = "Rank 4", value = "rank4" },
                    } },
                    { key = "holy_lights_grace_chaining", type = "checkbox", label = "Light's Grace Chaining", default = true, tooltip = "Cast cheap Holy Light R4 to refresh Light's Grace before it expires" },
                },
            },
            {
                header = "Holy Utility",
                settings = {
                    { key = "holy_blessing_light", type = "checkbox", label = "Blessing of Light", default = true, tooltip = "Maintain Blessing of Light on tanks for increased healing received" },
                    { key = "holy_blessing_wisdom", type = "checkbox", label = "Blessing of Wisdom", default = true, tooltip = "Maintain Blessing of Wisdom on mana users" },
                    { key = "holy_auto_cleanse", type = "checkbox", label = "Auto Cleanse", default = true, tooltip = "Cleanse disease, poison, and magic from party members" },
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
                header = "Paladin Utility",
                settings = {
                    { key = "divine_shield_hp", type = "slider", label = "Divine Shield HP", min = 0, max = 100, default = 0 },
                    { key = "lay_on_hands_hp", type = "slider", label = "Lay on Hands HP", min = 0, max = 100, default = 0 },
                    { key = "use_seal_of_wisdom_low_mana", type = "checkbox", label = "Seal of Wisdom Low Mana", default = false },
                    { key = "seal_of_wisdom_mana_pct", type = "slider", label = "Seal of Wisdom Mana", min = 0, max = 100, default = 20 },
                    { key = "use_cc_break", type = "checkbox", label = "CC Break (Divine Shield/Freedom)", default = true, tooltip = "Preemptively Divine Shield or Blessing of Freedom when enemy casts Polymorph/Fear/Repentance at you" },
                    { key = "use_pvp_cc_gating", type = "checkbox", label = "PvP CC Gate (skip AoE near CC)", default = true, tooltip = "Skip Consecration/Holy Wrath when a nearby enemy is Polymorphed/Repentance/etc." },
                    { key = "use_cleanse", type = "checkbox", label = "Cleanse", default = true },
                    { key = "use_hammer_of_justice", type = "checkbox", label = "Hammer of Justice", default = true },
                    { key = "combat_kings_refresh_mana", type = "slider", label = "Kings Refresh Min Mana", min = 0, max = 100, default = 30 },
                    { key = "combat_kings_refresh_threshold", type = "slider", label = "Kings Refresh Time", min = 30, max = 300, default = 60 },
                    { key = "combat_wisdom_refresh_mana", type = "slider", label = "Wisdom Refresh Min Mana", min = 0, max = 100, default = 30 },
                    { key = "combat_wisdom_refresh_threshold", type = "slider", label = "Wisdom Refresh Time", min = 30, max = 300, default = 120 },
                },
            },
        },
    },
    {
        name = "Protection",
        sections = {
            {
                header = "Rotation & Seals",
                settings = {
                    { key = "prot_holy_shield", type = "checkbox", label = "Holy Shield", default = true, tooltip = "Maintain Holy Shield for uncrushable and damage" },
                    { key = "prot_holy_shield_charges", type = "slider", label = "Holy Shield Refresh at Charges", min = 1, max = 8, default = 2, tooltip = "Refresh Holy Shield when charges drop to this level" },
                    { key = "prot_consecration", type = "checkbox", label = "Consecration", default = true, tooltip = "Use Consecration for AoE threat" },
                    { key = "prot_judgement", type = "checkbox", label = "Judgement", default = true, tooltip = "Judgement to consume seals for damage" },
                    { key = "prot_seal_of_righteousness", type = "checkbox", label = "Seal of Righteousness", default = true, tooltip = "Maintain Seal of Righteousness for threat" },
                    { key = "prot_seal_of_wisdom", type = "checkbox", label = "Seal of Wisdom Low Mana", default = true, tooltip = "Auto-switch to Seal of Wisdom when mana is low" },
                    { key = "prot_seal_of_wisdom_mana", type = "slider", label = "Seal of Wisdom Mana %", min = 0, max = 100, default = 30, tooltip = "Switch to Seal of Wisdom below this mana %" },
                    { key = "prot_devotion_aura", type = "checkbox", label = "Devotion Aura", default = true, tooltip = "Maintain Devotion Aura for armor" },
                    { key = "prot_blessing_sanctuary", type = "checkbox", label = "Blessing of Sanctuary", default = true, tooltip = "Maintain Blessing of Sanctuary for damage reduction" },
                },
            },
            {
                header = "AoE",
                settings = {
                    { key = "prot_consecration_targets", type = "slider", label = "Consecration Min Targets", min = 1, max = 6, default = 3, tooltip = "Minimum enemies to cast Consecration in combat" },
                    { key = "prot_consecration_min_mana", type = "slider", label = "Consecration Min Mana %", min = 0, max = 100, default = 35, tooltip = "Minimum mana to cast Consecration" },
                    { key = "prot_avenger_shield", type = "checkbox", label = "Avenger's Shield", default = true, tooltip = "Use Avenger's Shield for pulling and threat" },
                    { key = "prot_avenger_opener", type = "checkbox", label = "Avenger's Shield Pre-Pull", default = true, tooltip = "Cast Avenger's Shield before combat as an opener" },
                    { key = "prot_holy_wrath", type = "checkbox", label = "Holy Wrath", default = true, tooltip = "Use Holy Wrath on undead/demon AoE pulls" },
                },
            },
            {
                header = "Cooldowns",
                settings = {
                    { key = "prot_avenging_wrath", type = "checkbox", label = "Avenging Wrath", default = true, tooltip = "Use Avenging Wrath for +20% damage" },
                    { key = "prot_exorcism", type = "checkbox", label = "Exorcism", default = true, tooltip = "Use Exorcism on demons and undead" },
                    { key = "prot_hammer_of_wrath", type = "checkbox", label = "Hammer of Wrath", default = true, tooltip = "Execute-range Hammer of Wrath" },
                    { key = "prot_hammer_of_wrath_hp", type = "slider", label = "Hammer of Wrath Target HP %", min = 5, max = 35, default = 20, tooltip = "Use Hammer of Wrath when target HP is below this" },
                },
            },
            {
                header = "Defensives & Utility",
                settings = {
                    { key = "prot_divine_shield_hp", type = "slider", label = "Divine Shield HP %", min = 0, max = 50, default = 15, tooltip = "Emergency Divine Shield below this HP" },
                    { key = "prot_lay_on_hands_hp", type = "slider", label = "Lay on Hands HP %", min = 0, max = 50, default = 10, tooltip = "Emergency Lay on Hands below this HP" },
                    { key = "prot_hammer_of_justice", type = "checkbox", label = "Hammer of Justice", default = true, tooltip = "Interrupt casting enemies" },
                    { key = "prot_righteous_defense", type = "checkbox", label = "Righteous Defense", default = true, tooltip = "Peel aggro from threatened allies" },
                    { key = "prot_blessing_of_protection", type = "checkbox", label = "Blessing of Protection", default = true, tooltip = "BoP emergency peel for low HP allies" },
                },
            },
            {
                header = "Self Healing",
                settings = {
                    { key = "prot_flash_of_light_hp", type = "slider", label = "Flash of Light HP %", min = 0, max = 100, default = 40, tooltip = "Self-heal with Flash of Light below this HP" },
                    { key = "prot_holy_light_hp", type = "slider", label = "Holy Light HP %", min = 0, max = 100, default = 25, tooltip = "Self-heal with Holy Light below this HP (emergency)" },
                    { key = "prot_cleanse", type = "checkbox", label = "Cleanse", default = true, tooltip = "Cleanse debuffs from self" },
                },
            },
            {
                header = "Threat & Utility",
                settings = {
                    { key = "snap_threat_enabled", type = "checkbox", label = "Snap Threat on Combat Start", default = true, tooltip = "Fire Judgement immediately when entering combat to establish threat" },
                    { key = "combat_mode", type = "dropdown", label = "Combat Mode", default = "auto", options = {
                        { text = "Auto", value = "auto" },
                        { text = "Single Target", value = "single" },
                        { text = "AoE", value = "aoe" },
                    }, tooltip = "Force rotation mode: Auto uses enemy count, ST/AoE override" },
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
                    { key = "leveling_heal_hp", type = "slider", label = "Heal HP %", min = 0, max = 100, default = 40 },
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
    {
        name = "Retribution",
        sections = {
            {
                header = "Seals & Rotation",
                settings = {
                    { key = "retri_seal_preference", type = "dropdown", label = "Seal Preference", default = "auto", options = {
                        { text = "Auto (Faction)", value = "auto" },
                        { text = "Seal of Blood", value = "blood" },
                        { text = "Seal of Command", value = "command" },
                        { text = "Seal of the Martyr", value = "martyr" },
                    } },
                    { key = "retri_seal_twisting", type = "checkbox", label = "Seal Twisting", default = true, tooltip = "Twist Seal of Command into Blood/Martyr near swing impact for double seal procs" },
                    { key = "retri_twist_window", type = "slider", label = "Twist Window (ms)", min = 200, max = 600, default = 450, tooltip = "The time window before swing impact to attempt a seal twist. Increase if high latency." },
                    { key = "retri_twist_mana_floor", type = "slider", label = "Twist Min Mana %", min = 0, max = 100, default = 20, tooltip = "Stop seal twisting when mana drops below this threshold" },
                    { key = "retri_judge_wisdom_mana", type = "slider", label = "Judge Wisdom Below Mana %", min = 0, max = 100, default = 45, tooltip = "Judge Seal of Wisdom for mana return when below this threshold" },
                },
            },
            {
                header = "Cooldowns",
                settings = {
                    { key = "retri_aw_enabled", type = "checkbox", label = "Avenging Wrath", default = true, tooltip = "Use Avenging Wrath for +20% damage during burst windows" },
                    { key = "retri_aura_enabled", type = "checkbox", label = "Sanctity Aura", default = true, tooltip = "Maintain Sanctity Aura for +10% Holy damage" },
                },
            },
            {
                header = "AoE & Utility",
                settings = {
                    { key = "retri_consecration_targets", type = "slider", label = "Consecration Min Targets", min = 1, max = 6, default = 3, tooltip = "Minimum enemies for Consecration AoE usage" },
                    { key = "consecration_single_target", type = "checkbox", label = "Consecration Single Target", default = false, tooltip = "Use Consecration on single target as mana dump (requires 75%+ mana)" },
                    { key = "command_cleave_min_targets", type = "slider", label = "Command Cleave Min Targets", min = 2, max = 6, default = 2, tooltip = "Minimum enemies to switch to Seal of Command for cleave" },
                    { key = "retri_bless_might", type = "checkbox", label = "Blessing of Might Self", default = true },
                    { key = "blessing_of_kings_self", type = "checkbox", label = "Blessing of Kings Self", default = false },
                    { key = "blessing_of_freedom_self", type = "checkbox", label = "Freedom Self", default = true },
                    { key = "blessing_of_freedom_allies", type = "checkbox", label = "Freedom Allies", default = true },
                    { key = "retri_auto_cleanse", type = "checkbox", label = "Auto Cleanse", default = true },
                    { key = "cleanse_allies", type = "checkbox", label = "Cleanse Allies", default = true },
                },
            },
            {
                header = "PvP",
                settings = {
                    { key = "repentance_pvp_usage", type = "checkbox", label = "Repentance PvP", default = true },
                },
            },
        },
    },
}
