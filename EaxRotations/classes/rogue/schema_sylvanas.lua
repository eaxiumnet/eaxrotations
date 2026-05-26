-- Rogue menu schema.
-- ============================================================================
-- What: Rogue settings schema for combat, subtlety, assassination, and leveling
-- When: Load time
-- Why: Centralizes configurable thresholds and toggles for rogue playstyles
-- Safety: Static defaults only, no runtime API calls
-- ============================================================================

return {
    {
        name = "General",
        sections = {
            {
                header = "Rotation",
                settings = {
                    { key = "playstyle", type = "dropdown", label = "Playstyle", default = "combat", options = {
                            { text = "Leveling", value = "leveling" },
                            { text = "Assassination", value = "assassination" },
                            { text = "Combat", value = "combat" },
                            { text = "Subtlety", value = "subtlety" },
                    } },
                    { key = "use_cooldowns", type = "checkbox", label = "Cooldowns", default = true },
                    { key = "use_interrupt", type = "checkbox", label = "Interrupts", default = true },
                    { key = "use_threat_drop", type = "checkbox", label = "Threat Drop", default = true },
                    { key = "aoe_threshold", type = "slider", label = "AoE Count", min = 2, max = 6, default = 3 },
                    { key = "use_disarm", type = "checkbox", label = "Auto Disarm (PvP)", default = true, tooltip = "Dismantle enemy melee players (Warrior/Rogue/Paladin/Shaman). No stance requirement." },
                    { key = "disarm_trigger", type = "dropdown", label = "Disarm Trigger", default = "on_burst", options = {
                            { text = "On Burst (priority buffs)", value = "on_burst" },
                            { text = "On Cooldown", value = "on_cooldown" },
                    } },
                    { key = "disarm_pvp_only", type = "checkbox", label = "Disarm — Players Only", default = true, tooltip = "Only disarm enemy players (safer for PvE with CC'd mobs)." },
                    { key = "use_shiv_purge", type = "checkbox", label = "Shiv Purge (PvP)", default = true, tooltip = "Shiv dispels 1 magic buff on enemy players via Wound Poison (BoP, PW:S, Ice Barrier, etc.). Requires off-hand with Wound Poison applied." },
                    { key = "shiv_purge_pvp_only", type = "checkbox", label = "Shiv Purge — Players Only", default = true, tooltip = "Only purge buffs from enemy players (safer for PvE)." },
                },
            },
            {
                header = "Emergency Toolkit",
                settings = {
                    { key = "rogue_use_evasion", type = "checkbox", label = "Evasion", default = true },
                    { key = "rogue_evasion_hp", type = "slider", label = "Evasion HP", min = 10, max = 50, default = 35 },
                    { key = "rogue_use_cloak", type = "checkbox", label = "Cloak of Shadows", default = true },
                    { key = "rogue_cloak_hp", type = "slider", label = "Cloak HP", min = 20, max = 60, default = 45 },
                    { key = "use_pvp_cc_gating", type = "checkbox", label = "PvP CC Gate (skip AoE near CC)", default = true, tooltip = "Skip Blade Flurry when a nearby enemy is Polymorphed/Sapped/etc." },
                    { key = "use_cc_break", type = "checkbox", label = "CC Break (Cloak/Vanish)", default = true, tooltip = "Preemptively Cloak or Vanish when enemy casts Polymorph/Fear/Blind at you" },
                    { key = "rogue_use_vanish_defensive", type = "checkbox", label = "Vanish (Emergency)", default = false },
                    { key = "rogue_vanish_hp", type = "slider", label = "Vanish HP", min = 10, max = 40, default = 20 },
                    { key = "rogue_vanish_in_raid", type = "checkbox", label = "Vanish on Raid Bosses", default = false },
                    { key = "rogue_use_thistle_tea", type = "checkbox", label = "Thistle Tea", default = true },
                    { key = "rogue_thistle_tea_energy", type = "slider", label = "Thistle Tea Energy", min = 0, max = 100, default = 30 },
                },
            },
            {
                header = "Subtlety",
                settings = {
                    { key = "shadowstep_usage", type = "dropdown", label = "Shadowstep", default = "always", options = {
                            { text = "Always", value = "always" },
                            { text = "Burst Only", value = "burst_only" },
                            { text = "Off", value = "off" },
                    } },
                    { key = "shadowstep_min_range", type = "slider", label = "Shadowstep Min Range", min = 5, max = 25, default = 10 },
                    { key = "hemo_debuff_priority", type = "checkbox", label = "Hemorrhage Debuff Priority", default = true },
                    { key = "opener_preference", type = "dropdown", label = "Opener", default = "auto", options = {
                            { text = "Auto", value = "auto" },
                            { text = "Ambush", value = "ambush" },
                            { text = "Garrote", value = "garrote" },
                            { text = "Cheap Shot", value = "cheap_shot" },
                    } },
                    { key = "subtlety_prep_hp", type = "slider", label = "Preparation Max HP %", min = 10, max = 80, default = 40 },
                    { key = "subtlety_feint_threat", type = "slider", label = "Feint Threat %", min = 50, max = 100, default = 90 },
                },
            },
        },
    },
    {
        name = "Combat",
        sections = {
            {
                header = "Cooldowns",
                settings = {
                    { key = "combat_blade_flurry_count", type = "slider", label = "Blade Flurry Min Targets", min = 1, max = 6, default = 2 },
                    { key = "combat_adrenaline_rush_heroism", type = "checkbox", label = "Delay AR during Bloodlust", default = true },
                },
            },
            {
                header = "Finishers & DoTs",
                settings = {
                    { key = "combat_rupture_ttd", type = "slider", label = "Rupture TTD Floor (s)", min = 6, max = 30, default = 12 },
                    { key = "combat_expose_assigned", type = "checkbox", label = "Expose Armor Assigned", default = false },
                },
            },
            {
                header = "Threat & Survival",
                settings = {
                    { key = "combat_feint_threat", type = "slider", label = "Feint Threat %", min = 50, max = 100, default = 90 },
                    { key = "combat_vanish_hp", type = "slider", label = "Vanish HP %", min = 10, max = 50, default = 20 },
                },
            },
        },
    },
    {
        name = "Assassination",
        sections = {
            {
                header = "Cooldowns & Burst",
                settings = {
                    { key = "assassin_cold_blood_auto", type = "checkbox", label = "Auto Cold Blood + Envenom", default = true },
                    { key = "assassin_thistle_tea", type = "checkbox", label = "Thistle Tea", default = true },
                },
            },
            {
                header = "Finisher Settings",
                settings = {
                    { key = "assassin_envenom_stacks", type = "slider", label = "Min DP Stacks for Envenom", min = 1, max = 5, default = 3 },
                },
            },
            {
                header = "Defensive",
                settings = {
                    { key = "assassin_evasion_hp", type = "slider", label = "Evasion HP %", min = 10, max = 50, default = 25 },
                    { key = "assassin_clos_hp", type = "slider", label = "Cloak of Shadows HP %", min = 20, max = 60, default = 30 },
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
                    { key = "leveling_blade_flurry_enemies", type = "slider", label = "Blade Flurry Enemies", min = 2, max = 6, default = 3 },
                    { key = "leveling_vanish_hp", type = "slider", label = "Vanish HP %", min = 0, max = 100, default = 15 },
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
