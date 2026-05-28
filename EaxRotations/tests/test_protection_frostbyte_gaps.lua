-- =========================================================================
-- EaxRotations File Version: 1.1.1
-- Last Modified: 2026-05-27
-- Change: File version stamp for runtime load verification
-- =========================================================================
local __eax_file = "tests/test_protection_frostbyte_gaps.lua"
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
-- Feature audit for protection_sylvanas: Bloodrage, VictoryRush, Rend, IntimidatingShout.
-- Documents FrostByte features and verifies all 4 gaps are now closed.

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

local strategies = dofile("EaxRotations/classes/warrior/protection_sylvanas.lua")
assert_true(strategies, "strategies table should load")
assert_true(#strategies > 0, "strategies table should have entries")

-- Collect strategy names for audit
local strategy_names = {}
for i = 1, #strategies do
    strategy_names[strategies[i].name] = true
end

-- ============================================================================
-- Feature Audit: Check which FrostByte features exist vs missing
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

-- Interrupts and taunts
assert_true(strategy_names["Pummel"], "Pummel should be present")
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

-- FrostByte gaps (4 newly implemented)
assert_true(strategy_names["Bloodrage"], "Bloodrage should be present - FrostByte feature: rage generation")
assert_true(strategy_names["VictoryRush"], "VictoryRush should be present - FrostByte feature: sustain/heal")
assert_true(strategy_names["Rend"], "Rend should be present - FrostByte feature: bleed threat")
assert_true(strategy_names["IntimidatingShout"], "IntimidatingShout should be present - FrostByte feature: AoE fear")

local expected_count = 30
assert_eq(#strategies, expected_count, "expected " .. expected_count .. " strategies, got " .. #strategies)
assert_true(strategy_names["ShieldSlamPurge"], "ShieldSlamPurge should be present - Ported from Flux middleware")

print("PASS test_protection_frostbyte_gaps (gap audit: " .. #strategies .. " strategies present, 4 FrostByte gaps closed)")

-- Print strategy inventory for reference
local sorted_names = {}
for name, _ in pairs(strategy_names) do
    sorted_names[#sorted_names + 1] = name
end
table.sort(sorted_names)
print("  Strategies present: " .. table.concat(sorted_names, ", "))
