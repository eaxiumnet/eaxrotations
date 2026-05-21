-- Paladin menu schema.

-- ============================================================================
-- What: Paladin menu schema.
-- When: Load time.
-- Why: Define settings, sections, and conservative defaults.
-- Safety: Static data only; no runtime logic.
-- ============================================================================

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
                    { key = "holy_light_rank", type = "dropdown", label = "Holy Light Rank", default = "max", options = {
                            { text = "Max / Smart", value = "max" },
                            { text = "Rank 9", value = "rank9" },
                            { text = "Rank 7", value = "rank7" },
                            { text = "Rank 4", value = "rank4" },
                    } },
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
                header = "Paladin Utility",
                settings = {
                    { key = "divine_shield_hp", type = "slider", label = "Divine Shield HP", min = 0, max = 100, default = 0 },
                    { key = "lay_on_hands_hp", type = "slider", label = "Lay on Hands HP", min = 0, max = 100, default = 0 },
                    { key = "use_seal_of_wisdom_low_mana", type = "checkbox", label = "Seal of Wisdom Low Mana", default = false },
                    { key = "seal_of_wisdom_mana_pct", type = "slider", label = "Seal of Wisdom Mana", min = 0, max = 100, default = 20 },
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
