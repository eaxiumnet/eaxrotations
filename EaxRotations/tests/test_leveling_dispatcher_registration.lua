-- test_leveling_dispatcher_registration.lua -- leveling rotation dispatcher tick tests.
-- WHAT:  leveling rotation dispatcher tick tests
-- WHEN:  During rotation test suite execution.
-- WHY:   Protects against regressions in rotation logic and state handling.
-- SAFETY: Pure unit tests with mocked API context.

-- Regression: every class leveling module must register the "leveling"
-- playstyle with the dispatcher. A module that only exposes on_update() loads
-- successfully but never runs when selected from the playstyle dropdown.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;" .. package.path

local function assert_true(v, label)
    if not v then error(label or "assert_true failed", 2) end
end

_G.core = {
    time = function() return 0 end,
    input = { cast_target_spell = function() return true end },
}

local function spell_table(keys)
    local out = {}
    for i = 1, #keys do
        out[keys[i]] = { 1000 + i }
    end
    return out
end

local cases = {
    {
        class = "druid",
        module = "EaxRotations/classes/druid/leveling_sylvanas.lua",
        table_name = "DruidSpells",
        keys = {
            "MarkOfTheWild", "Thorns", "Moonfire", "Wrath", "Starfire",
            "InsectSwarm", "Hurricane", "Rejuvenation", "HealingTouch",
            "Barkskin", "EntanglingRoots", "NaturesGrasp", "FaerieFire",
        },
    },
    {
        class = "rogue",
        module = "EaxRotations/classes/rogue/leveling_sylvanas.lua",
        table_name = "RogueSpells",
        keys = {
            "Stealth", "Sap", "Kick", "SinisterStrike", "Eviscerate",
            "SliceAndDice", "Rupture", "Garrote", "Gouge", "Evasion",
            "Sprint", "BladeFlurry", "AdrenalineRush", "ColdBlood",
            "Vanish", "Blind", "ExposeArmor",
        },
    },
    {
        class = "shaman",
        module = "EaxRotations/classes/shaman/leveling_sylvanas.lua",
        table_name = "ShamanSpells",
        keys = {
            "LightningBolt", "EarthShock", "FlameShock", "FrostShock",
            "ChainLightning", "LightningShield", "WaterShield", "HealingWave",
            "LesserHealingWave", "GhostWolf", "Purge", "EarthbindTotem",
            "StoneclawTotem", "FireNovaTotem", "SearingTotem",
            "StrengthOfEarthTotem", "GraceOfAirTotem", "ManaSpringTotem",
            "HealingStreamTotem", "GroundingTotem", "WindfuryTotem", "TremorTotem",
            "WindfuryWeapon", "RockbiterWeapon", "FlametongueWeapon", "FrostbrandWeapon",
        },
    },
    {
        class = "warrior",
        module = "EaxRotations/classes/warrior/leveling_sylvanas.lua",
        table_name = "WarriorSpells",
        keys = {
            "Charge", "Rend", "HeroicStrike", "Overpower", "ThunderClap",
            "DemoralizingShout", "Execute", "VictoryRush", "Pummel",
            "BattleShout", "Bloodrage", "BerserkerRage", "Cleave",
            "Whirlwind", "SweepingStrikes", "MortalStrike", "Bloodthirst",
            "SunderArmor", "Hamstring", "Slam", "Disarm", "ShieldBash",
            "ShieldSlam", "Rampage", "DefensiveStance", "ShieldWall",
            "IntimidatingShout",
        },
    },
}

for i = 1, #cases do
    local case = cases[i]
    local registry = {
        playstyles = {},
        options = {},
        register = function(self, name, strategies, options)
            self.playstyles[name] = strategies
            self.options[name] = options
            return true
        end,
    }

    _G.EaxRotations = {
        rotation_registry = registry,
        log = function() end,
        spell_ready = function(spell) return spell ~= nil end,
        spell_exists = function() return true end,
        try_cast = function(spell) return spell ~= nil end,
        get_local_player = function()
            return {
                has_buff = function() return false end,
                get_power = function() return 100 end,
            }
        end,
        get_distance = function() return 10 end,
        debuff_remains = function() return 0 end,
        debuff_stacks = function() return 0 end,
        combo_points = 0,
        energy = 100,
    }
    _G.EaxRotations[case.table_name] = spell_table(case.keys)

    local module = dofile(case.module)
    assert_true(module ~= nil, case.class .. " leveling module should load")
    assert_true(type(registry.playstyles.leveling) == "table", case.class .. " should register leveling playstyle")
    assert_true(type(registry.options.leveling) == "table", case.class .. " should register leveling options")
    assert_true(type(registry.options.leveling.get_state) == "function", case.class .. " should expose get_state")
end

print("PASS test_leveling_dispatcher_registration")
