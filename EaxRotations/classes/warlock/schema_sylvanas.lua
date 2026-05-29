-- Warlock menu schema.

return {
    {
        name = "General",
        sections = {
            {
                header = "Rotation",
                settings = {
                    { key = "playstyle", type = "dropdown", label = "Playstyle", default = "leveling", options = {
                            { text = "Leveling", value = "leveling" },
                            { text = "Affliction", value = "affliction" },
                            { text = "Demonology", value = "demonology" },
                            { text = "Destruction", value = "destruction" },
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
                    { key = "warlock_curse_elements_threshold", type = "slider", label = "Elements Caster Threshold", min = 1, max = 5, default = 2, tooltip = "Auto-Curse Elements if this many casters are in the party." },
                    { key = "warlock_curse_reck_threshold", type = "slider", label = "Recklessness Melee Threshold", min = 1, max = 5, default = 2, tooltip = "Auto-Curse Recklessness if this many physical DPS are in the party." },
                },
            },
            {
                header = "Survival",
                settings = {
                    { key = "death_coil_hp", type = "slider", label = "Death Coil HP", min = 0, max = 100, default = 0 },
                    { key = "use_cc_break", type = "checkbox", label = "CC Break (Death Coil)", default = true, tooltip = "Preemptively Death Coil when enemy casts Polymorph/Fear/Cyclone at you to interrupt + self-heal" },
                    { key = "healthstone_hp", type = "slider", label = "Healthstone HP", min = 0, max = 100, default = 0 },
                    { key = "use_shadow_ward", type = "checkbox", label = "Shadow Ward", default = true },
                    { key = "shadow_ward_hp", type = "slider", label = "Shadow Ward HP", min = 0, max = 100, default = 70 },
                },
            },
            {
                header = "Pet / Stones",
                settings = {
                    { key = "use_devour_magic", type = "checkbox", label = "Devour Magic (Felhunter)", default = true, tooltip = "Felhunter auto-strips priority enemy magic buffs (Bloodlust, BoP, Ice Barrier, etc.)" },
                    { key = "devour_magic_mana_floor", type = "slider", label = "Devour Magic Min Mana %", min = 10, max = 80, default = 20, tooltip = "Skip Devour Magic when mana is below this threshold" },
                    { key = "use_fel_domination", type = "checkbox", label = "Fel Domination", default = true },
                    { key = "fel_domination_hp", type = "slider", label = "Fel Domination HP", min = 0, max = 100, default = 35 },
                    { key = "use_demonic_sacrifice", type = "checkbox", label = "Demonic Sacrifice", default = true },
                    { key = "demonic_sacrifice_hp", type = "slider", label = "Demonic Sacrifice HP", min = 0, max = 100, default = 20 },
                    { key = "use_health_funnel", type = "checkbox", label = "Health Funnel", default = true },
                    { key = "health_funnel_hp", type = "slider", label = "Health Funnel Player HP", min = 0, max = 100, default = 60 },
                    { key = "health_funnel_pet_hp", type = "slider", label = "Health Funnel Pet HP", min = 0, max = 100, default = 40 },
                    { key = "auto_create_healthstone", type = "checkbox", label = "Create Healthstone", default = true },
                    { key = "auto_create_soulstone", type = "checkbox", label = "Create Soulstone", default = true },
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
                    { key = "aff_wand_mana", type = "slider", label = "Wand Mana %", min = 0, max = 100, default = 15 },
                },
            },
            {
                header = "Damage",
                settings = {
                    { key = "aff_seed_targets", type = "slider", label = "Seed of Corruption Min", min = 3, max = 10, default = 3 },
                    { key = "aff_use_amplify_curse", type = "checkbox", label = "Amplify Curse", default = true },
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
                    { key = "destro_immolate_min_sp", type = "slider", label = "Immolate Min SP", min = 0, max = 2000, default = 400 },
                    { key = "destro_shadowburn_hp", type = "slider", label = "Shadowburn HP %", min = 0, max = 100, default = 20 },
                    { key = "destro_mana_gem_threshold", type = "slider", label = "Mana Gem at %", min = 0, max = 100, default = 35 },
                },
            },
        },
    },
}
