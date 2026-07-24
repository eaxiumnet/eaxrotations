-- aoe_high_severity_manifest.lua
-- WHAT:  Single source of high-severity AoE multi-target matchers that MUST use
--        hit-volume helpers (not bare 40yd enemy_count / state.enemies).
-- WHEN:  Consumed by test_aoe_range_audit_contracts.lua and tools/scan_aoe_manifest.py.
-- WHY:  Cross-expansion completeness — every *_vanilla / *_sylvanas / *_wotlk path
--       that implements the matcher is listed; one dirty row = one unfixed expansion.
-- SAFETY: Pure data table; no combat logic.

--[[
Each entry:
  family     — spell family name (audit grouping)
  needle     — unique start of the match function / strategy block to scan
  helper     — "aoe_self_meets" | "aoe_target_meets"
  paths      — repo-relative paths that must contain needle + helper nearby
  window     — optional chars after needle (default 700)
]]

return {
    -- ========== Mage Arcane Explosion (self 10yd) ==========
    {
        family = "ArcaneExplosion",
        needle = "arcane_explosion_matches",
        helper = "aoe_self_meets",
        paths = {
            "EaxRotations/classes/mage/fire_sylvanas.lua",
            "EaxRotations/classes/mage/frost_sylvanas.lua",
            "EaxRotations/classes/mage/fire_vanilla.lua",
            "EaxRotations/classes/mage/frost_vanilla.lua",
            "EaxRotations/classes/mage/leveling_wotlk.lua",
        },
    },
    -- ========== Priest Holy Nova (self 10yd) ==========
    {
        family = "HolyNova",
        needle = "holy_nova_aoe_matches",
        helper = "aoe_self_meets",
        paths = {
            "EaxRotations/classes/priest/shadow_sylvanas.lua",
            "EaxRotations/classes/priest/shadow_vanilla.lua",
        },
    },
    {
        family = "HolyNova",
        needle = "holy_nova_matches",
        helper = "aoe_self_meets",
        paths = {
            "EaxRotations/classes/priest/leveling_sylvanas.lua",
            "EaxRotations/classes/priest/leveling_vanilla.lua",
        },
    },
    {
        family = "HolyNova",
        needle = 'name = "HolyNova"',
        helper = "aoe_self_meets",
        paths = {
            "EaxRotations/classes/priest/smite_sylvanas.lua",
            "EaxRotations/classes/priest/smite_vanilla.lua",
        },
        window = 900,
    },
    -- ========== Warlock Hellfire (self 10yd) ==========
    {
        family = "Hellfire",
        needle = "hellfire_matches",
        helper = "aoe_self_meets",
        paths = {
            "EaxRotations/classes/warlock/demonology_sylvanas.lua",
        },
    },
    -- ========== Rogue Fan of Knives (self 8yd WotLK) ==========
    {
        family = "FanOfKnives",
        needle = 'name = "FanOfKnives"',  -- DSL-converted: imperative fan_of_knives_matches removed
        helper = "aoe_self_meets",
        paths = {
            "EaxRotations/classes/rogue/leveling_wotlk.lua",
        },
        window = 900,
    },
    -- ========== DK Blood Boil (self 10yd) ==========
    {
        family = "BloodBoil",
        needle = "blood_boil",
        helper = "aoe_self_meets",
        paths = {
            "EaxRotations/classes/deathknight/leveling_wotlk.lua",
        },
    },
    -- ========== Warrior Whirlwind (self 8yd) ==========
    {
        family = "Whirlwind",
        needle = "whirlwind_matches",
        helper = "aoe_self_meets",
        paths = {
            "EaxRotations/classes/warrior/arms_vanilla.lua",
            "EaxRotations/classes/warrior/arms_sylvanas.lua",
            "EaxRotations/classes/warrior/leveling_vanilla.lua",
            "EaxRotations/classes/warrior/leveling_sylvanas.lua",
            "EaxRotations/classes/warrior/leveling_wotlk.lua",
        },
    },
    {
        family = "Whirlwind",
        needle = 'name = "Whirlwind"',
        helper = "aoe_self_meets",
        paths = {
            "EaxRotations/classes/warrior/kebab_vanilla.lua",
            "EaxRotations/classes/warrior/kebab_sylvanas.lua",
            "EaxRotations/classes/warrior/fury_sylvanas.lua",  -- DSL-converted: imperative whirlwind_matches removed
        },
        window = 900,
    },
    -- ========== Warrior Thunder Clap (self 8yd) ==========
    {
        family = "ThunderClap",
        needle = "thunder_clap_matches",
        helper = "aoe_self_meets",
        paths = {
            "EaxRotations/classes/warrior/arms_vanilla.lua",
            -- "EaxRotations/classes/warrior/arms_wotlk.lua" -- DSL-converted: use name=ThunderClap entry below
            "EaxRotations/classes/warrior/leveling_vanilla.lua",
            "EaxRotations/classes/warrior/leveling_sylvanas.lua",
            "EaxRotations/classes/warrior/leveling_wotlk.lua",
        },
    },
    {
        family = "ThunderClap",
        needle = 'name = "ThunderClap"',
        helper = "aoe_self_meets",
        paths = {
            "EaxRotations/classes/warrior/arms_sylvanas.lua",  -- DSL-converted: imperative thunder_clap_matches removed
            "EaxRotations/classes/warrior/arms_wotlk.lua",    -- DSL-converted: imperative thunder_clap_matches removed
        },
        window = 900,
    },
    {
        family = "ThunderClap",
        needle = "thunderclap_matches",
        helper = "aoe_self_meets",
        paths = {
            "EaxRotations/classes/warrior/protection_vanilla.lua",
            "EaxRotations/classes/warrior/protection_sylvanas.lua",
        },
    },
    -- ========== Warrior Piercing Howl (self 10yd) ==========
    {
        family = "PiercingHowl",
        needle = "piercing_howl_matches",
        helper = "aoe_self_meets",
        paths = {
            "EaxRotations/classes/warrior/arms_vanilla.lua",
            "EaxRotations/classes/warrior/arms_sylvanas.lua",
        },
    },
    -- ========== Warrior Cleave (target 8yd) ==========
    {
        family = "Cleave",
        needle = "cleave_matches",
        helper = "aoe_target_meets",
        paths = {
            "EaxRotations/classes/warrior/arms_vanilla.lua",
            "EaxRotations/classes/warrior/arms_sylvanas.lua",
            "EaxRotations/classes/warrior/fury_sylvanas.lua",
            "EaxRotations/classes/warrior/leveling_sylvanas.lua",
            "EaxRotations/classes/warrior/leveling_wotlk.lua",
            "EaxRotations/classes/warrior/protection_vanilla.lua",
            "EaxRotations/classes/warrior/protection_sylvanas.lua",
        },
    },
    {
        family = "Cleave",
        needle = 'name = "Cleave"',
        helper = "aoe_target_meets",
        paths = {
            "EaxRotations/classes/warrior/fury_vanilla.lua",
        },
        window = 500,
    },
    -- ========== Mage Cone of Cold (frontal 10yd cone) ==========
    {
        family = "ConeOfCold",
        needle = "cone_of_cold_matches",
        helper = "aoe_cone_meets",
        window = 900, -- frost_sylvanas has frozen-target branch before multi cone gate
        paths = {
            "EaxRotations/classes/mage/frost_sylvanas.lua",
            "EaxRotations/classes/mage/leveling_wotlk.lua",
            "EaxRotations/classes/mage/frost_vanilla.lua",
        },
    },
    -- ========== Mage Dragon's Breath (frontal 10yd cone) ==========
    {
        family = "DragonsBreath",
        needle = "dragons_breath_matches_fn",
        helper = "aoe_cone_meets",
        paths = {
            "EaxRotations/classes/mage/fire_sylvanas.lua",
        },
    },
    -- ========== Ground place helper (cast_ground_aoe) ==========
    {
        family = "FlamestrikeGroundPlace",
        needle = 'name = "Flamestrike"',
        helper = "cast_ground_aoe",
        paths = {
            "EaxRotations/classes/mage/fire_sylvanas.lua",
        },
        window = 500,
    },
    -- ========== Druid Swipe (target 8yd) ==========
    {
        family = "Swipe",
        needle = "swipe_aoe_matches",
        helper = "aoe_target_meets",
        paths = {
            "EaxRotations/classes/druid/bear_sylvanas.lua",
            "EaxRotations/classes/druid/bear_vanilla.lua",
        },
    },
    -- ========== Druid Hurricane (ground 8yd at target) ==========
    {
        family = "Hurricane",
        needle = "HurricaneAoE",
        helper = "aoe_target_meets",
        paths = {
            "EaxRotations/classes/druid/balance_sylvanas.lua",
            "EaxRotations/classes/druid/balance_vanilla.lua",
        },
        window = 400,
    },
}
