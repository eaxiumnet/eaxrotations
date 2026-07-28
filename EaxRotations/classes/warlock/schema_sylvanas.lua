-- warlock/schema_sylvanas.lua — Warlock menu schema and settings defaults.
-- WHAT:  defines menu widgets (checkboxes, sliders, keybinds) for warlock specs.
-- WHEN:  loaded at addon init to register middleware menu entries.
-- WHY:   centralized menu definition prevents duplicate widget IDs.
-- SAFETY: nil-guarded menu references; default fallbacks for all settings.

-- Warlock menu schema.

local consumables = require("shared/schema_consumables_sylvanas")

return {
    {
        name = "General",
        sections = {
            {
                header = "Rotation",
                settings = {
                    { key = "playstyle", type = "dropdown", label = "Playstyle", default = "auto", options = {
                            { text = "Auto (Talent-Based)", value = "auto" },
                            { text = "Leveling", value = "leveling" },
                            { text = "Affliction", value = "affliction" },
                            { text = "Demonology", value = "demonology" },
                            { text = "Destruction", value = "destruction" },
                    }, tooltip = "Auto = detects spec from your talent tree. Choose a specific spec to lock it in manually." },
                    { key = "use_cooldowns", type = "checkbox", label = "Cooldowns", default = true },
                    { key = "use_interrupt", type = "checkbox", label = "Interrupts", default = true },
                    { key = "use_threat_drop", type = "checkbox", label = "Threat Drop", default = true },
                    { key = "use_pvp_defensives", type = "checkbox", label = "PvP Defensives", default = true },
                    { key = "use_fear_cc", type = "checkbox", label = "Use Fear (CC)", default = true, tooltip = "Enable Fear for CC (PvP kiting/arena/world). Strictly suppressed in PvE (including groups/dungeons/raids) to prevent pack scattering and tank annoyance. Default=true preserves prior PvP behavior; setting available early for spec consumption." },
                    { key = "pvp_kite_threshold", type = "slider", label = "PvP Kite HP", min = 20, max = 80, default = 50 },
                    { key = "aoe_threshold", type = "slider", label = "AoE Count", min = 2, max = 6, default = 3 },
                },
            },
            {
                header = "Curse Governance",
                settings = {
                    { key = "warlock_curse_mode", type = "dropdown", label = "Curse Mode", default = "auto", options = {
                        { text = "Auto (Raid-Aware)", value = "auto" },
                        { text = "Agony", value = "agony" },
                        { text = "Doom", value = "doom" },
                        { text = "Elements", value = "elements" },
                        { text = "Recklessness", value = "recklessness" },
                        { text = "Weakness", value = "weakness" },
                        { text = "None", value = "none" },
                    } },
                    { key = "warlock_assigned_curse", type = "dropdown", label = "Assigned Curse", default = "none", options = {
                        { text = "None (use Auto logic)", value = "none" },
                        { text = "Agony", value = "agony" },
                        { text = "Doom", value = "doom" },
                        { text = "Elements", value = "elements" },
                        { text = "Recklessness", value = "recklessness" },
                        { text = "Weakness", value = "weakness" },
                    }, tooltip = "If set, always maintain this curse. 'None' uses spec-specific auto logic. Use this to coordinate multiple Warlocks (e.g., one on Elements, one on Doom)." },
                    { key = "warlock_curse_reck_threshold", type = "slider", label = "Recklessness Melee Threshold", min = 1, max = 5, default = 2, tooltip = "Auto-Curse Recklessness in group/raid if this many physical DPS are present." },
                    { key = "warlock_curse_group_aware", type = "checkbox", label = "Group/Raid Curse Logic", default = false, tooltip = "When enabled, Auto curse mode applies group/raid logic (Curse of Elements/Recklessness). When disabled, Auto uses Agony in PvE so the player controls debuff choice." },
                },
            },
            {
                header = "Survival",
                settings = {
                    { key = "use_death_coil", type = "checkbox", label = "Auto Death Coil", default = true, tooltip = "Auto-cast Death Coil on enemy target at low HP for emergency self-heal (also used as CC Break; see PvP section)" },
                    { key = "death_coil_hp", type = "slider", label = "Death Coil HP", min = 0, max = 100, default = 40 },
                    { key = "use_cc_break", type = "checkbox", label = "CC Break (Death Coil)", default = true, tooltip = "Preemptively Death Coil when enemy casts Polymorph/Fear/Cyclone at you to interrupt + self-heal" },
                    { key = "healthstone_hp", type = "slider", label = "Healthstone HP", min = 0, max = 100, default = 0 },
                    { key = "use_shadow_ward", type = "checkbox", label = "Shadow Ward", default = true },
                    { key = "warlock_group_aware_utility", type = "checkbox", label = "Group-Aware Utility (CC/Ward)", default = true, tooltip = "Allow group/raid context to enable utility spells such as Fear, Howl of Terror, Curse of Tongues, Shadow Ward, and Shadowfury. Disable to ignore group/raid requirements." },
                    { key = "shadow_ward_hp", type = "slider", label = "Shadow Ward HP", min = 0, max = 100, default = 70 },
                },
            },
            {
                header = "Pet / Stones",
                settings = {
                    { key = "use_devour_magic", type = "checkbox", label = "Devour Magic (Felhunter)", default = true, tooltip = "Felhunter auto-strips priority enemy magic buffs (Bloodlust, BoP, Ice Barrier, etc.)" },
                    { key = "devour_magic_mana_floor", type = "slider", label = "Devour Magic Min Mana %", min = 10, max = 80, default = 20, tooltip = "Skip Devour Magic when mana is below this threshold" },
                    { key = "use_devour_magic_friendly", type = "checkbox", label = "Devour Magic (friendly/group)", default = false, tooltip = "Use Felhunter to dispel harmful magic debuffs from party members in dungeons (safe help, default off to not impact parses)" },
                    { key = "devour_magic_friendly_mana_floor", type = "slider", label = "Devour Magic Friendly Min Mana %", min = 10, max = 80, default = 30, tooltip = "Skip friendly dispel when mana below this" },
                    { key = "use_fel_domination", type = "checkbox", label = "Fel Domination", default = true },
                    { key = "fel_domination_hp", type = "slider", label = "Fel Domination HP", min = 0, max = 100, default = 35 },
                    { key = "use_demonic_sacrifice", type = "checkbox", label = "Demonic Sacrifice", default = true },
                    { key = "demonic_sacrifice_hp", type = "slider", label = "Demonic Sacrifice HP", min = 0, max = 100, default = 20 },
                    { key = "use_health_funnel", type = "checkbox", label = "Health Funnel", default = true },
                    { key = "health_funnel_hp", type = "slider", label = "Health Funnel Player HP", min = 0, max = 100, default = 60 },
                    { key = "health_funnel_pet_hp", type = "slider", label = "Health Funnel Pet HP", min = 0, max = 100, default = 40 },
                    { key = "auto_create_healthstone", type = "checkbox", label = "Create Healthstone", default = true },
                    { key = "auto_create_soulstone", type = "checkbox", label = "Create Soulstone", default = true },
                    { key = "auto_demon_armor", type = "checkbox", label = "Demon / Fel Armor", default = true, tooltip = "Maintain Demon Armor (or Fel Armor at 62+) out of combat" },
                },
            },
        },
    },
    {
        name = "Leveling",
        sections = {
            {
                header = "Leveling Rotation",
                settings = {
                    { key = "leveling_wand_threshold", type = "slider", label = "Wand Mana Threshold", min = 0, max = 100, default = 30 },
                    { key = "leveling_life_tap_mana", type = "slider", label = "Life Tap Mana %", min = 0, max = 100, default = 30 },
                    { key = "leveling_drain_soul_execute", type = "slider", label = "Drain Soul Execute %", min = 0, max = 100, default = 25 },
                    { key = "leveling_use_immolate", type = "checkbox", label = "Use Immolate", default = true },
                    { key = "leveling_use_corruption", type = "checkbox", label = "Use Corruption", default = true },
                    { key = "leveling_use_curse_of_agony", type = "checkbox", label = "Use Curse of Agony", default = true },
                },
            },
        },
    },
    {
        name = "Affliction",
        sections = {
            {
                header = "Mana Management",
                settings = {
                    { key = "aff_life_tap_mana", type = "slider", label = "Life Tap Mana %", min = 0, max = 65, default = 30 },
                    { key = "aff_dark_pact_mana", type = "slider", label = "Dark Pact Mana %", min = 0, max = 100, default = 20 },
                    { key = "aff_mana_potion", type = "slider", label = "Mana Potion at %", min = 0, max = 100, default = 15 },
                    { key = "aff_wand_mana", type = "slider", label = "Wand Mana %", min = 0, max = 100, default = 30, tooltip = "Switch to wand when mana is below this threshold and Life Tap is unsafe (HP too low)." },
                },
            },
            {
                header = "Damage",
                settings = {
                    { key = "aff_seed_targets", type = "slider", label = "Seed of Corruption Min", min = 3, max = 10, default = 3 },
                    { key = "aff_use_amplify_curse", type = "checkbox", label = "Amplify Curse", default = true },
                    { key = "dot_ttd_threshold", type = "slider", label = "DoT TTD Threshold (%)", min = 0, max = 100, default = 50, tooltip = "Skip DoT reapplication if target dies before this % of DoT duration" },
                },
            },
        },
    },
    {
        name = "Destruction",
        sections = {
            {
                header = "Rotation & Mana",
                settings = {
                    { key = "destro_use_immolate", type = "checkbox", label = "Use Immolate", default = true, tooltip = "Apply and refresh Immolate. Disable for speed kills where Immolate is a DPS loss (pure Shadow Bolt spam)." },
                    { key = "destro_immolate_min_sp", type = "slider", label = "Immolate Min SP", min = 0, max = 2000, default = 400 },
                    { key = "destro_shadowburn_hp", type = "slider", label = "Shadowburn HP %", min = 0, max = 100, default = 20 },
                    { key = "destro_mana_gem_threshold", type = "slider", label = "Mana Gem at %", min = 0, max = 100, default = 35 },
                    { key = "destro_life_tap_mana", type = "slider", label = "Life Tap Mana %", min = 0, max = 50, default = 20, tooltip = "Life Tap when mana drops below this percentage." },
                    { key = "destro_life_tap_min_hp", type = "slider", label = "Life Tap Min HP %", min = 20, max = 80, default = 50, tooltip = "Never Life Tap if HP is below this. Safety gate to prevent killing yourself." },
                    { key = "destro_pet_preference", type = "dropdown", label = "Pet / Sac Preference", default = "auto", options = {
                        { text = "Auto (Succubus shadow, Imp fire)", value = "auto" },
                        { text = "Succubus (Shadow build)", value = "succubus" },
                        { text = "Imp (Fire build)", value = "imp" },
                    }, tooltip = "Which pet to summon then Demonic Sacrifice. Succubus = +15% Shadow, Imp = +15% Fire." },
                },
            },
        },
    },
    require("shared/schema_autoloot_sylvanas").build_tab(),
    consumables.build_tab({ use_mana_potions = { default = true } }),
}
