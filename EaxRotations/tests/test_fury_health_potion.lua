-- =========================================================================
-- EaxRotations File Version: 1.1.1
-- Last Modified: 2026-05-27
-- Change: File version stamp for runtime load verification
-- =========================================================================
local __eax_file = "tests/test_fury_health_potion.lua"
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
-- Feature audit for fury_sylvanas: Health potion fallback + Healthstone verification.
-- Documents gaps compared to FrostByte reference implementation.

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
        Bloodthirst = 23881,
        Whirlwind = 1680,
        MortalStrike = 30330,
        Execute = 25236,
        Hamstring = 25248,
        Overpower = 14802,
        Slam = 25241,
        Rend = 25233,
        Charge = 100,
        Intercept = 25272,
        BerserkerRage = 18499,
        Recklessness = 1719,
        DeathWish = 12292,
        PiercingHowl = 12323,
        Cleave = 20569,
        SweepingStrikes = 12292,
        BattleShout = 25289,
        DemoralizingShout = 25203,
        ThunderClap = 25260,
        Bloodrage = 2687,
        Pummel = 13491,
        ShieldBash = 72,
        ShieldBlock = 2565,
        ShieldWall = 871,
        LastStand = 12975,
        Taunt = 355,
        MockingBlow = 25261,
        ChallengingShout = 1161,
    },
    use_healthstone = function()
        return true
    end,
    spell_ready = function(spell, target) return true end,
    action_matches = function(ctx, act) return true end,
    action_execute = function(ctx, act, tag) return true end,
    log = function() end,
    rotation_registry = {
        register = function() end,
    },
}

local strategies = dofile("EaxRotations/classes/warrior/fury_sylvanas.lua")
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

-- Present features
assert_true(strategy_names["Bloodthirst"], "Bloodthirst should be present")
assert_true(strategy_names["Whirlwind"], "Whirlwind should be present")
assert_true(strategy_names["Execute"], "Execute should be present")
assert_true(strategy_names["Hamstring"], "Hamstring should be present")
assert_true(strategy_names["Rend"], "Rend should be present")
assert_true(strategy_names["Overpower"], "Overpower should be present")
assert_true(strategy_names["BattleShout"], "BattleShout should be present")
assert_true(strategy_names["Bloodrage"], "Bloodrage should be present")
assert_true(strategy_names["DeathWish"], "DeathWish should be present")
assert_true(strategy_names["Recklessness"], "Recklessness should be present")
assert_true(strategy_names["Healthstone"], "Healthstone should be present")

-- Missing FrostByte features
-- Health potion is a minor gap - if health pot is not ready, there's no fallback
assert_false(strategy_names["HealthPotion"], "HealthPotion is MISSING - FrostByte gap: health potion fallback not implemented")

print("PASS test_fury_health_potion (gap audit: " .. #strategies .. " strategies present, 1 minor FrostByte gap confirmed)")
