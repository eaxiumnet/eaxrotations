-- druid/schema_sylvanas.lua — Druid menu schema and settings defaults.
-- WHAT:  defines menu widgets (checkboxes, sliders, keybinds) for druid specs.
-- WHEN:  loaded at addon init to register middleware menu entries.
-- WHY:   centralized menu definition prevents duplicate widget IDs.
-- SAFETY: nil-guarded menu references; default fallbacks for all settings.

-- Druid menu schema.


local consumables = require("shared/schema_consumables_sylvanas")

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
                    { key = "barkskin_hp", type = "slider", label = "Barkskin HP Threshold", min = 0, max = 100, default = 0, tooltip = "Self-cast Barkskin when HP drops below this in combat (0 = disabled)" },
                    { key = "use_innervate", type = "checkbox", label = "Innervate", default = true },
                    { key = "innervate_mana_pct", type = "slider", label = "Innervate Mana %", min = 0, max = 100, default = 30 },
                    { key = "use_rebirth", type = "checkbox", label = "Rebirth (Combat Res)", default = true },
                },
            },
            {
                header = "Bear Tank",
                settings = {
                    { key = "bear_swing_timer", type = "checkbox", label = "Swing Timer Maul", default = true, tooltip = "Avoid Maul within 0.3s of a melee swing to prevent clipping auto-attacks" },
                    { key = "bear_aoe_threshold", type = "slider", label = "Bear AoE Count", min = 2, max = 5, default = 3 },
                    { key = "bear_maul_rage", type = "slider", label = "Maul Rage", min = 30, max = 80, default = 50, tooltip = "Rage required before Maul (endgame dump). Pre-Mangle, the rotation auto-scales this down by level so low-level bears spend sooner; never raises above this slider." },
                    { key = "bear_barkskin_hp", type = "slider", label = "Barkskin HP%", min = 0, max = 100, default = 55 },
                    { key = "bear_frenzied_regen_hp", type = "slider", label = "Frenzied Regen HP%", min = 0, max = 100, default = 35 },
                    { key = "bear_use_barkskin", type = "checkbox", label = "Barkskin (breaks form)", default = false, tooltip = "WARNING: Barkskin forces you out of Bear form in TBC. Only enable if you pre-shift manually." },
                    { key = "bear_use_challenging_roar", type = "checkbox", label = "Challenging Roar", default = false, tooltip = "AoE taunt — situational (10min CD). Enable only when you want the rotation to use it." },
                    { key = "bear_demo_roar", type = "checkbox", label = "Demoralizing Roar", default = true },
                    { key = "snap_threat_enabled", type = "checkbox", label = "Snap Threat on Combat Start", default = true, tooltip = "Fire Growl (or Mangle/Maul fallback) immediately when entering combat to establish threat" },
                    { key = "auto_bear_form_ooc", type = "checkbox", label = "Auto Bear Form OOC", default = true },
                },
            },
            {
                header = "Cat (Feral DPS)",
                settings = {
                    { key = "cat_powershift_enabled", type = "checkbox", label = "Powershifting", default = true },
                    { key = "cat_powershift_energy", type = "slider", label = "Powershift Energy", min = 10, max = 50, default = 20 },
                    { key = "cat_auto_travel_form", type = "checkbox", label = "Auto Travel Form OOC", default = false, tooltip = "Automatically shift to Travel Form when out of combat, moving, and target is far away." },
                    { key = "cat_shred_positional", type = "checkbox", label = "Shred Positional Check", default = true, tooltip = "Require being behind target to cast Shred. Disable if you play without positional awareness or on buggy servers." },
                    { key = "cat_execute_hp", type = "slider", label = "Ferocious Bite HP%", min = 0, max = 100, default = 25 },
                    { key = "cat_rip_cp", type = "slider", label = "Rip Combo Points", min = 3, max = 5, default = 5 },
                    { key = "cat_ferocious_bite_cp", type = "slider", label = "Bite Combo Points", min = 3, max = 5, default = 5 },
                    { key = "cat_wolfshead_helm", type = "checkbox", label = "Wolfshead Helm (override)", default = false },
                    { key = "cat_barkskin_hp", type = "slider", label = "Barkskin HP%", min = 0, max = 100, default = 85 },
                    { key = "cat_use_rake", type = "checkbox", label = "Use Rake (PvE builder)", default = true, description = "Use Rake as combo point builder with pandemic refresh" },
                    { key = "cat_rake_refresh_seconds", type = "slider", label = "Rake Refresh (sec)", min = 1, max = 10, default = 3 },
                    { key = "cat_use_rip", type = "checkbox", label = "Use Rip", default = true },
                    { key = "cat_rip_elites_only", type = "checkbox", label = "Rip Elites Only", default = false, description = "Only use Rip on elite or boss targets" },
                    { key = "cat_use_shred", type = "checkbox", label = "Use Shred", default = true },
                    { key = "cat_use_mangle", type = "checkbox", label = "Use Mangle (Cat)", default = true },
                    { key = "cat_use_ferocious_bite", type = "checkbox", label = "Use Ferocious Bite", default = true },
                    { key = "cat_bite_max_energy", type = "slider", label = "Bite Max Energy", min = 20, max = 60, default = 39, description = "Don't Bite above this energy to avoid waste" },
                    { key = "cat_use_faerie_fire", type = "checkbox", label = "Use Faerie Fire (Feral)", default = true },
                    { key = "cat_aoe_threshold", type = "slider", label = "AoE Enemy Count", min = 2, max = 6, default = 3 },
                    { key = "cat_energy_pooling", type = "checkbox", label = "Energy Pooling", default = true, description = "Pool energy for optimal finisher timing" },
                    { key = "cat_use_rip_trick", type = "checkbox", label = "Rip Trick (advanced)", default = false, description = "Cast Rip at low CP when energy is in [Rip, Mangle) window before powershifting. Short-fight / full-powershift only." },
                    { key = "cat_use_shred_trick", type = "checkbox", label = "Shred Trick (advanced)", default = false, description = "Prefer Shred over Mangle as builder when bleed active and energy window allows. Short-fight / full-powershift only." },
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
                header = "Restoration — Mana Conservation",
                settings = {
                    { key = "resto_mana_conserve_pct", type = "slider", label = "Mana Conserve %", min = 0, max = 100, default = 30 },
                    { key = "resto_mana_emergency_pct", type = "slider", label = "Mana Emergency %", min = 0, max = 100, default = 15 },
                    { key = "resto_mana_critical_pct", type = "slider", label = "Mana Critical %", min = 0, max = 100, default = 5 },
                    { key = "fsr_enabled", type = "checkbox", label = "FSR Pause", default = true },
                    { key = "fsr_mana_threshold", type = "slider", label = "FSR Mana Threshold %", min = 0, max = 100, default = 35 },
                    { key = "fsr_emergency_hp", type = "slider", label = "FSR Emergency HP%", min = 0, max = 100, default = 40 },
                    { key = "fsr_max_pause_seconds", type = "slider", label = "FSR Max Pause (s, 0=full)", min = 0, max = 5, default = 0 },
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
    require("shared/schema_autoloot_sylvanas").build_tab(),
    consumables.build_tab(
        { use_mana_potions = { default = true } },
        {
                    -- NOTE (2026-06-29): druid has TWO healthstone / healing potion paths --
                    -- the consumable_manager (``use_healthstones`` plural, default true) which
                    -- works in any form, plus the form-aware path (``use_healthstone`` singular,
                    -- default false) which un-shifts from Cat/Bear, uses the item, then re-shifts.
                    -- Both are exposed; the singular keys default off so the master
                    -- ``use_auto_consumables`` toggle drives default behaviour.
                    { key = "use_healthstone", type = "checkbox", label = "Healthstones (form-aware)", default = false, description = "Auto-use healthstone at HP threshold with form un-shift / re-shift" },
                    { key = "healthstone_hp", type = "slider", label = "Healthstone HP%", min = 0, max = 100, default = 30 },
                    { key = "use_healing_potion", type = "checkbox", label = "Healing Potions (form-aware)", default = false, description = "Auto-use healing potion at HP threshold with form un-shift / re-shift" },
                    { key = "healing_potion_hp", type = "slider", label = "Healing Potion HP%", min = 0, max = 100, default = 35 },
        }
    ),
}
