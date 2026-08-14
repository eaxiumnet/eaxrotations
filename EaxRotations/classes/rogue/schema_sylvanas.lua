-- rogue/schema_sylvanas.lua — Rogue menu schema and settings defaults.
-- WHAT:  defines menu widgets (checkboxes, sliders, keybinds) for rogue specs.
-- WHEN:  loaded at addon init to register middleware menu entries.
-- WHY:   centralized menu definition prevents duplicate widget IDs.
-- SAFETY: nil-guarded menu references; default fallbacks for all settings.

-- Rogue menu schema.

local consumables = require("shared/schema_consumables_sylvanas")

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
                    { key = "use_cooldowns_on_boss_only", type = "checkbox", label = "Cooldowns on Bosses Only", default = false, tooltip = "Only use major offensive cooldowns (Adrenaline Rush, Blade Flurry) on boss targets — skip on trash" },
                    { key = "use_interrupt", type = "checkbox", label = "Interrupts", default = true },
                    { key = "use_threat_drop", type = "checkbox", label = "Threat Drop", default = true },
                    { key = "aoe_threshold", type = "slider", label = "AoE Count", min = 2, max = 6, default = 3 },
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
                    { key = "rogue_group_aware_defensives", type = "checkbox", label = "Group-Aware Defensive Thresholds", default = true, tooltip = "Raise defensive cooldown HP thresholds when in a group or raid. Disable to use solo thresholds everywhere." },
                    { key = "rogue_group_aware_utility", type = "checkbox", label = "Group-Aware Utility", default = true, tooltip = "Allow group/raid context to enable utility spells such as Blind and Kidney Shot. Disable to ignore group/raid requirements." },
                    { key = "use_pvp_cc_gating", type = "checkbox", label = "PvP CC Gate (skip AoE near CC)", default = true, tooltip = "Skip Blade Flurry when a nearby enemy is Polymorphed/Sapped/etc." },
                    { key = "use_cc_break", type = "checkbox", label = "CC Break (Cloak/Vanish)", default = true, tooltip = "Preemptively Cloak or Vanish when enemy casts Polymorph/Fear/Blind at you" },
                    { key = "rogue_poison_check", type = "checkbox", label = "Poison Check", default = true, tooltip = "Warn when weapon poisons are missing in combat. Applies to all rogue specs." },
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
                    { key = "subtlety_energy_tick_sync", type = "checkbox", label = "Energy Tick Prediction", default = true, tooltip = "Synchronize ability usage with the server's energy ticks (2.0s interval) to maximize energy pooling and avoid capping." },
                    { key = "subtlety_energy_tick_offset", type = "slider", label = "Tick Advance (ms)", min = 0, max = 500, default = 100, tooltip = "Attempt to cast abilities this many ms BEFORE a predicted energy tick. Compensates for input latency." },
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
                    { key = "combat_blade_flurry_count", type = "slider", label = "Blade Flurry Min Targets", min = 1, max = 6, default = 1 },
                    { key = "combat_adrenaline_rush_heroism", type = "checkbox", label = "Delay AR during Bloodlust", default = true },
                    { key = "combat_energy_tick_sync", type = "checkbox", label = "Energy Tick Prediction", default = true, tooltip = "Synchronize ability usage with the server's energy ticks (2.0s interval) to maximize energy pooling and avoid capping." },
                    { key = "combat_energy_tick_offset", type = "slider", label = "Tick Advance (ms)", min = 0, max = 500, default = 100, tooltip = "Attempt to cast abilities this many ms BEFORE a predicted energy tick. Compensates for input latency." },
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
                    { key = "assassin_expose_assigned", type = "checkbox", label = "Expose Armor Assigned", default = false },
                },
            },
            {
                header = "Energy",
                settings = {
                    { key = "assassin_energy_tick_sync", type = "checkbox", label = "Energy Tick Prediction", default = true, tooltip = "Synchronize ability usage with the server's energy ticks (2.0s interval) to maximize energy pooling and avoid capping." },
                    { key = "assassin_energy_tick_offset", type = "slider", label = "Tick Advance (ms)", min = 0, max = 500, default = 100, tooltip = "Attempt to cast abilities this many ms BEFORE a predicted energy tick. Compensates for input latency." },
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
    require("shared/schema_autoloot_sylvanas").build_tab(),
    consumables.build_tab(),
}
