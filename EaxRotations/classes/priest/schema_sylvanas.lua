-- =========================================================================
-- EaxRotations File Version: 1.1.1
-- Last Modified: 2026-05-27
-- Change: File version stamp for runtime load verification
-- =========================================================================
local __eax_file = "classes/priest/schema_sylvanas.lua"
local __eax_version = "1.1.1"
local __eax_modified = "2026-05-27"
local __eax_change = "File version stamp for runtime load verification"
local __eax_versions = rawget(_G, "EaxRotationsFileVersions") or {}
_G.EaxRotationsFileVersions = __eax_versions
__eax_versions[__eax_file] = { version = __eax_version, modified = __eax_modified, change = __eax_change }
local __eax_core = rawget(_G, "core")
if type(__eax_core) == "table" and type(__eax_core.log) == "function" then
    pcall(__eax_core.log, "[EaxRotations] Loaded " .. __eax_file .. " v" .. __eax_version)
end
local __eax_ns = rawget(_G, "EaxRotations")
if type(__eax_ns) == "table" then __eax_ns.file_versions = __eax_versions end
-- Priest menu schema.
-- ============================================================================
-- What: Priest settings schema for healing, shadow, and leveling
-- When: Load time
-- Why: Defines user-facing options for all priest playstyles in one place
-- Safety: Static defaults only, no runtime API calls
-- ============================================================================

return {
    {
        name = "General",
        sections = {
            {
                header = "Rotation",
                settings = {
                    { key = "playstyle", type = "dropdown", label = "Playstyle", default = "discipline", options = {
                            { text = "Leveling", value = "leveling" },
                            { text = "Discipline", value = "discipline" },
                            { text = "Holy", value = "holy" },
                            { text = "Shadow", value = "shadow" },
                            { text = "Smite", value = "smite" },
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
                header = "Utility",
                settings = {
                    { key = "use_party_dispel", type = "checkbox", label = "Party Dispel", default = true },
                    { key = "party_dispel_mana_floor", type = "slider", label = "Dispel Mana Floor (%)", min = 10, max = 50, default = 30 },
                    { key = "use_self_dispel", type = "checkbox", label = "Self Dispel", default = true },
                    { key = "use_shadowfiend", type = "checkbox", label = "Shadowfiend", default = true },
                    { key = "shadowfiend_mana_threshold", type = "slider", label = "Shadowfiend Mana", min = 10, max = 60, default = 30 },
                    { key = "use_enhanced_fade", type = "checkbox", label = "Enhanced Fade", default = true },
                },
            },
        },
    },
    {
        name = "Discipline",
        sections = {
            {
                header = "Healing Priority",
                settings = {
                    { key = "discipline_pws_hp", type = "slider", label = "PW:S HP Threshold (%)", min = 10, max = 60, default = 35 },
                    { key = "discipline_flash_hp", type = "slider", label = "Flash Heal HP (%)", min = 20, max = 80, default = 55 },
                    { key = "discipline_greater_heal_hp", type = "slider", label = "Greater Heal HP (%)", min = 30, max = 95, default = 82 },
                    { key = "discipline_renew_hp", type = "slider", label = "Renew HP (%)", min = 50, max = 100, default = 90 },
                },
            },
            {
                header = "Cooldowns",
                settings = {
                    { key = "discipline_pain_suppression_hp", type = "slider", label = "Pain Suppression HP (%)", min = 10, max = 50, default = 25 },
                    { key = "discipline_use_power_infusion", type = "checkbox", label = "Power Infusion", default = true },
                    { key = "discipline_pi_safety_hp", type = "slider", label = "PI Safety HP (%)", min = 40, max = 100, default = 80 },
                    { key = "discipline_use_inner_focus", type = "checkbox", label = "Inner Focus", default = true },
                    { key = "discipline_if_hp", type = "slider", label = "Inner Focus HP (%)", min = 30, max = 90, default = 65 },
                },
            },
            {
                header = "AoE Healing",
                settings = {
                    { key = "discipline_aoe_hp", type = "slider", label = "AoE HP Threshold (%)", min = 50, max = 100, default = 85 },
                },
            },
            {
                header = "DPS When Idle",
                settings = {
                    { key = "discipline_dps_when_idle", type = "checkbox", label = "DPS When Idle", default = false },
                    { key = "discipline_dps_mana_floor", type = "slider", label = "DPS Mana Floor (%)", min = 10, max = 70, default = 35 },
                    { key = "discipline_idle_hp", type = "slider", label = "Idle DPS Group Safe HP (%)", min = 50, max = 100, default = 92 },
                },
            },
            {
                header = "Shield Targeting",
                settings = {
                    { key = "disc_shield_tank_only", type = "checkbox", label = "Shield Tank Only", default = false, tooltip = "Only cast Power Word: Shield on the tank. Disable to shield any injured party member." },
                },
            },
            {
                header = "Self Survival",
                settings = {
                    { key = "discipline_healthstone_hp", type = "slider", label = "Healthstone HP (%)", min = 10, max = 60, default = 35 },
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
        name = "Holy",
        sections = {
            {
                header = "Healing Priority",
                settings = {
                    { key = "holy_use_pws", type = "checkbox", label = "Power Word: Shield", default = true },
                    { key = "holy_pws_hp", type = "slider", label = "PW:S HP Threshold (%)", min = 10, max = 60, default = 30 },
                    { key = "holy_emergency_hp", type = "slider", label = "Emergency Heal HP (%)", min = 10, max = 60, default = 30 },
                    { key = "holy_flash_heal_hp", type = "slider", label = "Flash Heal HP (%)", min = 20, max = 80, default = 50 },
                    { key = "holy_renew_hp", type = "slider", label = "Renew HP (%)", min = 50, max = 100, default = 90 },
                },
            },
            {
                header = "AoE Healing",
                settings = {
                    { key = "holy_use_coh", type = "checkbox", label = "Circle of Healing", default = true },
                    { key = "holy_use_poh", type = "checkbox", label = "Prayer of Healing", default = true },
                    { key = "holy_aoe_count", type = "slider", label = "AoE Target Count", min = 2, max = 6, default = 3 },
                    { key = "holy_aoe_hp", type = "slider", label = "AoE HP Threshold (%)", min = 50, max = 100, default = 80 },
                },
            },
            {
                header = "Cooldowns & Utility",
                settings = {
                    { key = "holy_use_lightwell", type = "checkbox", label = "Lightwell", default = false },
                    { key = "holy_use_inner_focus", type = "checkbox", label = "Inner Focus", default = true },
                    { key = "holy_use_binding_heal", type = "checkbox", label = "Binding Heal", default = true },
                    { key = "holy_binding_self_hp", type = "slider", label = "Binding Heal Self HP (%)", min = 20, max = 100, default = 80 },
                    { key = "holy_use_desperate_prayer", type = "checkbox", label = "Desperate Prayer", default = true },
                    { key = "holy_desp_prayer_hp", type = "slider", label = "Desperate Prayer HP (%)", min = 10, max = 60, default = 30 },
                    { key = "holy_healthstone_hp", type = "slider", label = "Healthstone HP (%)", min = 10, max = 60, default = 35 },
                },
            },
            {
                header = "Pre-Pull & Idle",
                settings = {
                    { key = "holy_prepull_pom", type = "checkbox", label = "Pre-Pull PoM", default = true },
                    { key = "holy_prepull_renew", type = "checkbox", label = "Pre-Pull Renew", default = true },
                    { key = "holy_dps_when_idle", type = "checkbox", label = "DPS When Idle", default = false },
                    { key = "holy_dps_mana_floor", type = "slider", label = "DPS Mana Floor (%)", min = 10, max = 90, default = 70 },
                },
            },
            {
                header = "Mana Conservation",
                settings = {
                    { key = "holy_gh_mana_floor", type = "slider", label = "GH Mana Floor (%)", min = 10, max = 50, default = 30 },
                    { key = "holy_fh_mana_floor", type = "slider", label = "FH Mana Floor (%)", min = 5, max = 40, default = 15 },
                },
            },
        },
    },
    {
        name = "Shadow",
        sections = {
            {
                header = "Combat",
                settings = {
                    { key = "shadow_combat_mode", type = "dropdown", label = "Combat Mode", default = "auto", options = {
                        { text = "Auto", value = "auto" },
                        { text = "Single Target", value = "st" },
                        { text = "Cleave", value = "cleave" },
                        { text = "AoE", value = "aoe" },
                    } },
                    { key = "shadow_multi_dot_range", type = "slider", label = "Multi-DoT Range", min = 10, max = 40, default = 30 },
                    { key = "shadow_multi_dot_targets", type = "slider", label = "Multi-DoT Targets", min = 2, max = 6, default = 3 },
                },
            },
            {
                header = "DoT Refresh",
                settings = {
                    { key = "shadow_vt_refresh_window", type = "slider", label = "VT Refresh Window (s)", min = 1, max = 6, default = 3 },
                    { key = "shadow_swp_refresh_window", type = "slider", label = "SW:P Refresh Window (s)", min = 1, max = 6, default = 3 },
                    { key = "shadow_dp_refresh_window", type = "slider", label = "DP Refresh Window (s)", min = 1, max = 6, default = 3 },
                },
            },
            {
                header = "Mana Conservation",
                settings = {
                    { key = "shadow_mb_mana_floor", type = "slider", label = "MB Mana Floor (%)", min = 10, max = 50, default = 30 },
                    { key = "shadow_conserve_mana_floor", type = "slider", label = "Conserve Mana Floor (%)", min = 5, max = 30, default = 15 },
                },
            },
            {
                header = "Self Survival",
                settings = {
                    { key = "shadow_swd_safety_hp", type = "slider", label = "SW:D Min Self HP %", min = 20, max = 100, default = 80 },
                    { key = "shadow_shield_hp", type = "slider", label = "PW:Shield HP %", min = 0, max = 80, default = 35 },
                    { key = "shadow_flash_heal_hp", type = "slider", label = "Flash Heal HP %", min = 0, max = 80, default = 25 },
                },
            },
            {
                header = "Threat & Safety",
                settings = {
                    { key = "shadow_threat_safe", type = "checkbox", label = "Threat Safety Gate", default = true },
                },
            },
            {
                header = "Utility",
                settings = {
                    { key = "shadow_use_inner_fire", type = "checkbox", label = "Auto Inner Fire", default = true },
                    { key = "shadow_mounted_bail", type = "checkbox", label = "Mounted Bail", default = true },
                },
            },
        },
    },
    {
        name = "Smite",
        sections = {
            {
                header = "DPS Priority",
                settings = {
                    { key = "smite_holy_fire_weave", type = "checkbox", label = "Holy Fire Weave Mode", default = true },
                    { key = "smite_use_inner_focus", type = "checkbox", label = "Inner Focus", default = true },
                    { key = "smite_use_starshards", type = "checkbox", label = "Starshards (NE)", default = true },
                    { key = "smite_use_devouring_plague", type = "checkbox", label = "Devouring Plague (UD)", default = true },
                    { key = "smite_use_power_infusion", type = "checkbox", label = "Power Infusion", default = true },
                },
            },
            {
                header = "Optional Shadow Spells",
                settings = {
                    { key = "smite_use_mb", type = "checkbox", label = "Mind Blast", default = false },
                    { key = "smite_use_swd", type = "checkbox", label = "Shadow Word: Death", default = false },
                    { key = "smite_swd_hp", type = "slider", label = "SW:D Min Self HP (%)", min = 20, max = 100, default = 40 },
                },
            },
            {
                header = "Mana Conservation",
                settings = {
                    { key = "smite_mana_floor", type = "slider", label = "Mana Low Floor (%)", min = 10, max = 60, default = 30 },
                    { key = "smite_conserve_mana_floor", type = "slider", label = "Spell Cut Floor (%)", min = 5, max = 30, default = 15 },
                    { key = "smite_wand_floor", type = "slider", label = "Wand-Only Floor (%)", min = 1, max = 20, default = 5 },
                    { key = "smite_use_shadowfiend", type = "checkbox", label = "Shadowfiend", default = true },
                    { key = "smite_shadowfiend_mana", type = "slider", label = "Shadowfiend Mana (%)", min = 10, max = 70, default = 35 },
                },
            },
            {
                header = "Solo & Survival",
                settings = {
                    { key = "smite_solo_pws_hp", type = "slider", label = "PW:S HP Threshold (%)", min = 10, max = 90, default = 55 },
                    { key = "smite_solo_renew_hp", type = "slider", label = "Renew HP Threshold (%)", min = 20, max = 100, default = 72 },
                    { key = "smite_solo_scream_hp", type = "slider", label = "Scream HP Threshold (%)", min = 10, max = 90, default = 75 },
                    { key = "smite_solo_scream_enemies", type = "slider", label = "Scream Min Enemies", min = 1, max = 6, default = 2 },
                    { key = "smite_pvp_scream_hp", type = "slider", label = "PvP Scream HP (%)", min = 10, max = 90, default = 65 },
                    { key = "smite_group_safe_hp", type = "slider", label = "Group Safe HP (%)", min = 50, max = 100, default = 80 },
                },
            },
            {
                header = "Threat & Safety",
                settings = {
                    { key = "smite_threat_safe", type = "checkbox", label = "Threat Safety Gate", default = true },
                },
            },
        },
    },
}
