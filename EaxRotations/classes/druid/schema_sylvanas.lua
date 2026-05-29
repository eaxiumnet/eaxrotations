-- Druid menu schema.


return {
    {
        name = "General",
        sections = {
            {
                header = "Rotation",
                settings = {
                    { key = "playstyle", type = "dropdown", label = "Playstyle", default = "balance", options = {
                            { text = "Leveling", value = "leveling" },
                            { text = "Balance", value = "balance" },
                            { text = "Bear", value = "bear" },
                            { text = "Cat", value = "cat" },
                            { text = "Caster", value = "caster" },
                            { text = "Resto", value = "resto" },
                    } },
                    { key = "use_cooldowns", type = "checkbox", label = "Cooldowns", default = true },
                    { key = "use_interrupt", type = "checkbox", label = "Interrupts", default = true },
                    { key = "use_threat_drop", type = "checkbox", label = "Threat Drop", default = true },
                    { key = "use_self_buffs", type = "checkbox", label = "Self Buffs", default = true },
                    { key = "auto_dispel", type = "checkbox", label = "Auto Dispel (party)", default = true, description = "Auto-remove curse and poison on self and party members" },
                    { key = "use_cc_break", type = "checkbox", label = "CC Break (Shapeshift)", default = true, tooltip = "Preemptively shapeshift when enemy casts Polymorph/Cyclone/Hibernate at you; shift to break roots/snares" },
                    { key = "use_pvp_cc_gating", type = "checkbox", label = "PvP CC Gate (skip AoE near CC)", default = true, tooltip = "Skip Swipe/Hurricane when a nearby enemy is Polymorphed/Cycloned/etc." },
                    { key = "aoe_threshold", type = "slider", label = "AoE Count", min = 2, max = 6, default = 3 },
                },
            },
            {
                header = "Bear Tank",
                settings = {
                    { key = "bear_aoe_threshold", type = "slider", label = "Bear AoE Count", min = 2, max = 5, default = 3 },
                    { key = "bear_maul_rage", type = "slider", label = "Maul Rage", min = 30, max = 80, default = 50 },
                    { key = "bear_barkskin_hp", type = "slider", label = "Barkskin HP%", min = 0, max = 100, default = 55 },
                    { key = "bear_frenzied_regen_hp", type = "slider", label = "Frenzied Regen HP%", min = 0, max = 100, default = 35 },
                    { key = "bear_demo_roar", type = "checkbox", label = "Demoralizing Roar", default = true },
                    { key = "auto_bear_form_ooc", type = "checkbox", label = "Auto Bear Form OOC", default = true },
                },
            },
            {
                header = "Cat (Feral DPS)",
                settings = {
                    { key = "cat_powershift_enabled", type = "checkbox", label = "Powershifting", default = true },
                    { key = "cat_powershift_energy", type = "slider", label = "Powershift Energy", min = 10, max = 50, default = 20 },
                    { key = "cat_execute_hp", type = "slider", label = "Ferocious Bite HP%", min = 0, max = 100, default = 25 },
                    { key = "cat_rip_cp", type = "slider", label = "Rip Combo Points", min = 3, max = 5, default = 5 },
                    { key = "cat_ferocious_bite_cp", type = "slider", label = "Bite Combo Points", min = 3, max = 5, default = 5 },
                    { key = "cat_wolfshead_helm", type = "checkbox", label = "Wolfshead Helm (override)", default = false },
                    { key = "cat_barkskin_hp", type = "slider", label = "Barkskin HP%", min = 0, max = 100, default = 85 },
                },
            },
            {
                header = "Balance",
                settings = {
                    { key = "balance_starfire_mana", type = "slider", label = "Starfire Mana Floor", min = 0, max = 100, default = 40 },
                    { key = "balance_barkskin_hp", type = "slider", label = "Barkskin HP%", min = 0, max = 100, default = 40 },
                    { key = "balance_innervate_mana", type = "slider", label = "Innervate Mana%", min = 0, max = 100, default = 30 },
                    { key = "balance_moonkin_auto", type = "checkbox", label = "Moonkin Form", default = true },
                    { key = "balance_use_force_of_nature", type = "checkbox", label = "Force of Nature", default = true },
                    { key = "balance_use_insect_swarm", type = "checkbox", label = "Insect Swarm", default = true },
                    { key = "balance_hurricane_targets", type = "slider", label = "Hurricane Targets", min = 2, max = 6, default = 3 },
                    { key = "balance_auto_dispel", type = "checkbox", label = "Auto Dispel", default = false },
                    { key = "balance_mana_potion", type = "slider", label = "Mana Potion Mana%", min = 0, max = 100, default = 25 },
                    { key = "balance_insect_swarm_min_sp", type = "slider", label = "Insect Swarm Min SP", min = 0, max = 2000, default = 800 },
                    { key = "balance_moonfire_min_sp", type = "slider", label = "Moonfire Min SP", min = 0, max = 2000, default = 800 },
                },
            },
            {
                header = "Restoration",
                settings = {
                    { key = "resto_lifebloom_targets", type = "slider", label = "Lifebloom Targets", min = 1, max = 3, default = 3 },
                    { key = "resto_swiftmend_hp", type = "slider", label = "Swiftmend HP%", min = 0, max = 100, default = 50 },
                    { key = "resto_ns_hp", type = "slider", label = "Nature's Swiftness HP%", min = 0, max = 100, default = 30 },
                    { key = "resto_innervate_mana", type = "slider", label = "Innervate Mana%", min = 0, max = 100, default = 30 },
                    { key = "resto_tranquility_hp", type = "slider", label = "Tranquility HP%", min = 0, max = 100, default = 25 },
                    { key = "resto_tranquility_count", type = "slider", label = "Tranquility Count", min = 2, max = 5, default = 3 },
                    { key = "resto_auto_dispel", type = "checkbox", label = "Auto Dispel", default = true },
                    { key = "resto_tol_enabled", type = "checkbox", label = "Tree of Life", default = true },
                },
            },
            {
                header = "Restoration — Mana Conservation",
                settings = {
                    { key = "resto_mana_conserve_pct", type = "slider", label = "Mana Conserve %", min = 0, max = 100, default = 30 },
                    { key = "resto_mana_emergency_pct", type = "slider", label = "Mana Emergency %", min = 0, max = 100, default = 15 },
                    { key = "resto_mana_critical_pct", type = "slider", label = "Mana Critical %", min = 0, max = 100, default = 5 },
                },
            },
            {
                header = "Restoration — Solo DPS",
                settings = {
                    { key = "resto_dps_when_idle", type = "checkbox", label = "DPS When Idle", default = false },
                    { key = "resto_idle_hp", type = "slider", label = "Idle HP% Floor", min = 0, max = 100, default = 88 },
                    { key = "resto_dps_mana_floor", type = "slider", label = "DPS Mana Floor%", min = 0, max = 100, default = 35 },
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
                    { key = "use_healthstone", type = "checkbox", label = "Healthstones (auto-use)", default = false, description = "Auto-use healthstone at HP threshold" },
                    { key = "healthstone_hp", type = "slider", label = "Healthstone HP%", min = 0, max = 100, default = 30 },
                    { key = "use_healing_potion", type = "checkbox", label = "Healing Potions (auto-use)", default = false, description = "Auto-use healing potion at HP threshold" },
                    { key = "healing_potion_hp", type = "slider", label = "Healing Potion HP%", min = 0, max = 100, default = 35 },
                },
            },
        },
    },
}
