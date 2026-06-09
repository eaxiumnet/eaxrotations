-- Mage menu schema.


return {
    {
        name = "General",
        sections = {
            {
                header = "Rotation",
                settings = {
                    { key = "playstyle", type = "dropdown", label = "Playstyle", default = "leveling", options = {
                            { text = "Leveling", value = "leveling" },
                            { text = "Arcane", value = "arcane" },
                            { text = "Fire", value = "fire" },
                            { text = "Frost", value = "frost" },
                    } },
                    { key = "use_cooldowns", type = "checkbox", label = "Cooldowns", default = true },
                    { key = "use_cooldowns_on_boss_only", type = "checkbox", label = "Cooldowns on Bosses Only", default = false, tooltip = "Only use major offensive cooldowns (Combustion, Icy Veins, Arcane Power) on boss targets — skip on trash" },
                    { key = "use_interrupt", type = "checkbox", label = "Interrupts", default = true },
                    { key = "use_threat_drop", type = "checkbox", label = "Threat Drop", default = true },
                    { key = "use_pvp_defensives", type = "checkbox", label = "PvP Defensives", default = true },
                    { key = "pvp_kite_threshold", type = "slider", label = "PvP Kite HP", min = 20, max = 80, default = 50 },
                    { key = "aoe_threshold", type = "slider", label = "AoE Count", min = 2, max = 6, default = 3 },
                },
            },
            {
                header = "Defensives",
                settings = {
                    { key = "use_defensives", type = "checkbox", label = "Defensives", default = true },
                    { key = "defensive_hp_threshold", type = "slider", label = "Defensive HP", min = 0, max = 100, default = 30 },
                    { key = "use_ice_block", type = "checkbox", label = "Ice Block", default = true },
                    { key = "use_mana_shield", type = "checkbox", label = "Mana Shield", default = true },
                    { key = "mana_shield_mana_threshold", type = "slider", label = "Mana Shield Min Mana", min = 0, max = 100, default = 50 },
                    { key = "use_ice_barrier", type = "checkbox", label = "Ice Barrier", default = true },
                    { key = "use_cc_break", type = "checkbox", label = "CC Break (Blink/Ice Block)", default = true, tooltip = "Preemptively Blink or Ice Block when enemy casts Polymorph/Fear/Cyclone at you" },
                },
            },
            {
                header = "Mana",
                settings = {
                    { key = "use_evocation", type = "checkbox", label = "Evocation", default = true },
                    { key = "evocation_mana_pct", type = "slider", label = "Evocation Mana", min = 0, max = 100, default = 20 },
                    { key = "use_mana_gem", type = "checkbox", label = "Mana Gem", default = true },
                    { key = "mana_gem_mana_pct", type = "slider", label = "Mana Gem Mana", min = 0, max = 100, default = 70 },
                },
            },
            {
                header = "Buffs / Utility",
                settings = {
                    { key = "use_self_buffs", type = "checkbox", label = "Self Buffs", default = true },
                    { key = "auto_remove_curse", type = "checkbox", label = "Remove Curse", default = true },
                    { key = "use_spellsteal", type = "checkbox", label = "Spellsteal", default = true, tooltip = "Steal priority enemy magic buffs (Bloodlust, BoP, Ice Barrier, etc.)" },
                    { key = "spellsteal_mana_floor", type = "slider", label = "Spellsteal Min Mana %", min = 10, max = 80, default = 30, tooltip = "Skip Spellsteal when mana is below this threshold" },
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
        name = "Arcane",
        sections = {
            {
                header = "Burn Phase",
                settings = {
                    { key = "arcane_use_burn", type = "checkbox", label = "Enable Burn Phase", default = true },
                    { key = "arcane_burn_mana_threshold", type = "slider", label = "Burn Mana Floor %", min = 30, max = 100, default = 65 },
                    { key = "arcane_burn_max_stacks", type = "slider", label = "Burn AB Max Stacks", min = 1, max = 3, default = 3 },
                },
            },
            {
                header = "Conserve Phase",
                settings = {
                    { key = "arcane_conserve_mana_threshold", type = "slider", label = "Conserve Mana %", min = 5, max = 50, default = 25 },
                    { key = "arcane_conserve_max_stacks", type = "slider", label = "Conserve AB Max Stacks", min = 0, max = 2, default = 0 },
                    { key = "arcane_mtte_min", type = "slider", label = "Min MTTE (s)", min = 5, max = 30, default = 12 },
                },
            },
            {
                header = "Mana Recovery",
                settings = {
                    { key = "arcane_evocation_mana", type = "slider", label = "Evocation Mana %", min = 5, max = 50, default = 20 },
                    { key = "arcane_mana_gem_mana", type = "slider", label = "Mana Gem at %", min = 20, max = 80, default = 55 },
                },
            },
        },
    },
    {
        name = "Fire",
        sections = {
            {
                header = "Rotation",
                settings = {
                    { key = "use_scorch_debuff", type = "checkbox", label = "Scorch Debuff Duty", default = true },
                    { key = "use_pyro_opener", type = "checkbox", label = "Pyroblast Opener", default = true },
                },
            },
            {
                header = "Utility",
                settings = {
                    { key = "use_remove_curse_fire", type = "checkbox", label = "Remove Curse", default = true },
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
                    { key = "leveling_polymorph_hp", type = "slider", label = "Polymorph HP %", min = 0, max = 100, default = 40 },
                    { key = "leveling_arcane_missiles_use", type = "checkbox", label = "Use Arcane Missiles", default = true },
                    { key = "leveling_scorch_use", type = "checkbox", label = "Use Scorch", default = true },
                    { key = "leveling_fire_blast_use", type = "checkbox", label = "Use Fire Blast", default = true },
                },
            },
        },
    },
}
