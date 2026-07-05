-- Feature audit for protection_sylvanas: Bloodrage, VictoryRush, Rend, IntimidatingShout.
-- Documents parity features and verifies all 4 gaps are now closed.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local assert_true, assert_eq, assert_false

local function setup_asserts()
    assert_true = function(v, label) if not v then error(label or "assert_true failed", 2) end end
    assert_eq = function(a, b, label) if a ~= b then error((label or "assert_eq") .. ": " .. tostring(a) .. " ~= " .. tostring(b), 2) end end
    assert_false = function(v, label) if v then error(label or "assert_false failed", 2) end end
end
setup_asserts()

-- Mock NS namespace
_G.EaxRotations = {
    WarriorSpells = {
        BattleShout = {},
        BattleStance = {},
        BerserkerRage = {},
        BerserkerStance = {},
        Bloodrage = {},
        Bloodthirst = {},
        ChallengingShout = {},
        Charge = {},
        Cleave = {},
        CommandingShout = {},
        ConcussionBlow = {},
        DeathWish = {},
        DefensiveStance = {},
        DemoralizingShout = {},
        Devastate = {},
        Disarm = {},
        Execute = {},
        VictoryRush = {},
        HeroicStrike = {},
        Hamstring = {},
        Intercept = {},
        Pummel = {},
        IntimidatingShout = {},
        LastStand = {},
        MockingBlow = {},
        MortalStrike = {},
        Overpower = {},
        Rampage = {},
        Rend = {},
        Revenge = {},
        ShieldBlock = {},
        ShieldBash = {},
        ShieldSlam = {},
        ShieldWall = {},
        Slam = {},
        SpellReflection = {},
        SunderArmor = {},
        SweepingStrikes = {},
        Taunt = {},
        ThunderClap = {},
        Whirlwind = {},
    },
    WarriorConstants = {
        STANCE = { BATTLE = 1, DEFENSIVE = 2, BERSERKER = 3 },
    },
    spell_ready = function() return false end,
    action_matches = function() return true end,
    action_execute = function() return true end,
    try_cast = function() return true end,
    debuff_remains = function() return 0 end,
    get_debuff_stacks = function() return 0 end,
    buff_up = function() return false end,
    try_interrupt = function() return false end,
    is_interruptible = function() return false end,
    is_execute_phase = function() return false end,
    GetPlayer = function() return nil end,
    log = function() end,
    rotation_registry = {
        register = function() end,
    },
}

local result = dofile("EaxRotations/classes/warrior/protection_sylvanas.lua")
assert_true(result, "rotation module should load")
local strategies = (type(result) == "table" and result.strategies) or result
assert_true(strategies, "strategies table should load")
assert_true(#strategies > 0, "strategies table should have entries")

-- Collect strategy names for audit
local strategy_names = {}
for i = 1, #strategies do
    strategy_names[strategies[i].name] = true
end

-- ============================================================================
-- Feature Audit: Check which parity features exist vs missing
-- ============================================================================

-- Core threat-gen features
assert_true(strategy_names["ShieldSlam"], "ShieldSlam should be present")
assert_true(strategy_names["Revenge"], "Revenge should be present")
assert_true(strategy_names["SunderArmor"], "SunderArmor should be present")
assert_true(strategy_names["Devastate"], "Devastate should be present")
assert_true(strategy_names["ThunderClap"], "ThunderClap should be present")
assert_true(strategy_names["DemoralizingShout"], "DemoralizingShout should be present")
assert_true(strategy_names["ShieldBlock"], "ShieldBlock should be present")
assert_true(strategy_names["Execute"], "Execute should be present")

-- Interrupts and taunts (Pummel removed — handled by interrupt_manager)
assert_true(strategy_names["ShieldBash"], "ShieldBash should be present")
assert_true(strategy_names["Taunt"], "Taunt should be present")
assert_true(strategy_names["MockingBlow"], "MockingBlow should be present")
assert_true(strategy_names["ChallengingShout"], "ChallengingShout should be present")

-- Defensives
assert_true(strategy_names["ShieldWall"], "ShieldWall should be present")
assert_true(strategy_names["LastStand"], "LastStand should be present")

-- Buffs and shouts
assert_true(strategy_names["BattleShout"], "BattleShout should be present")
assert_true(strategy_names["CommandingShout"], "CommandingShout should be present")

-- Rage management
assert_true(strategy_names["HeroicStrike"], "HeroicStrike should be present")
assert_true(strategy_names["Cleave"], "Cleave should be present")

-- PvP / utility
assert_true(strategy_names["SpellReflection"], "SpellReflection should be present")
assert_true(strategy_names["Disarm"], "Disarm should be present")
assert_true(strategy_names["ConcussionBlow"], "ConcussionBlow should be present")
assert_true(strategy_names["Hamstring"], "Hamstring should be present")
assert_true(strategy_names["Intercept"], "Intercept should be present")
assert_true(strategy_names["BerserkerRage"], "BerserkerRage should be present")

-- Parity features (4 newly implemented)
assert_true(strategy_names["Bloodrage"], "Bloodrage should be present - rage generation")
assert_true(strategy_names["VictoryRush"], "VictoryRush should be present - sustain/heal")
assert_true(strategy_names["Rend"], "Rend should be present - bleed threat")
assert_true(strategy_names["IntimidatingShout"], "IntimidatingShout should be present - AoE fear")
assert_true(strategy_names["RageDumpSafetyNet"], "RageDumpSafetyNet should be present - rage cap safety net")

local expected_count = 37
assert_eq(#strategies, expected_count, "expected " .. expected_count .. " strategies (34 base + Pummel + StanceSwitch), got " .. #strategies)
assert_true(strategy_names["ShieldSlamPurge"], "ShieldSlamPurge should be present")
assert_true(strategy_names["TauntSecondary"], "TauntSecondary should be present - tab-target MockingBlow cycling")

print("PASS test_protection_feature_gaps (gap audit: " .. #strategies .. " strategies present, 4 parity gaps closed)")

-- Print strategy inventory for reference
local sorted_names = {}
for name, _ in pairs(strategy_names) do
    sorted_names[#sorted_names + 1] = name
end
table.sort(sorted_names)
print("  Strategies present: " .. table.concat(sorted_names, ", "))
