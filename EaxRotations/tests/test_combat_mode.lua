-- test_combat_mode.lua — Unit tests for CombatMode override module.
-- WHAT:  Validates ST/AoE/Auto mode detection and gating.
-- WHEN:  Run via run_rotation_tests.lua or standalone.
-- WHY:   Ensures users can force rotation mode and auto falls back to enemy count.

local _G = _G
local NS = _G.EaxRotations or {}
_G.EaxRotations = NS

NS.log = function(msg) end
NS.settings = {}

-- Load module
local mod_ok, mod_err = pcall(dofile, "EaxRotations/shared/combat_mode_sylvanas.lua")
if not mod_ok then
    print("FAIL: could not load shared/combat_mode_sylvanas.lua: " .. tostring(mod_err))
    return
end

local function assert_true(v, msg)
    if not v then
        print("FAIL " .. tostring(msg))
        return false
    end
    print("PASS " .. tostring(msg))
    return true
end

local function assert_false(v, msg)
    return assert_true(not v, msg)
end

local function assert_eq(a, b, msg)
    if a ~= b then
        print("FAIL " .. tostring(msg) .. ": " .. tostring(a) .. " ~= " .. tostring(b))
        return false
    end
    print("PASS " .. tostring(msg))
    return true
end

local all_ok = true

-- Test 1: Module loaded
all_ok = assert_true(NS.CombatMode ~= nil, "NS.CombatMode is non-nil after load") and all_ok
all_ok = assert_eq(NS.CombatMode.MODE_AUTO, 1, "MODE_AUTO = 1") and all_ok
all_ok = assert_eq(NS.CombatMode.MODE_SINGLE, 2, "MODE_SINGLE = 2") and all_ok
all_ok = assert_eq(NS.CombatMode.MODE_AOE, 3, "MODE_AOE = 3") and all_ok

-- Test 2: Auto mode with enemy count below threshold
local mode = NS.CombatMode.get_mode({ combat_mode = 1 })
all_ok = assert_eq(mode, 1, "Numeric auto mode returns 1") and all_ok
local is_aoe = NS.CombatMode.is_aoe({ combat_mode = 1 }, 2, 3)
all_ok = assert_false(is_aoe, "Auto mode: 2 enemies < threshold 3 = not AoE") and all_ok

-- Test 3: Auto mode with enemy count above threshold
is_aoe = NS.CombatMode.is_aoe({ combat_mode = 1 }, 4, 3)
all_ok = assert_true(is_aoe, "Auto mode: 4 enemies >= threshold 3 = AoE") and all_ok

-- Test 4: Force Single Target mode
is_aoe = NS.CombatMode.is_aoe({ combat_mode = 2 }, 10, 3)
all_ok = assert_false(is_aoe, "Force ST: 10 enemies but ST mode = not AoE") and all_ok
all_ok = assert_true(NS.CombatMode.is_single_target({ combat_mode = 2 }, 10, 3), "Force ST is_single_target true") and all_ok

-- Test 5: Force AoE mode
is_aoe = NS.CombatMode.is_aoe({ combat_mode = 3 }, 1, 3)
all_ok = assert_true(is_aoe, "Force AoE: 1 enemy but AoE mode = AoE") and all_ok

-- Test 6: String mode values (from dropdown schemas)
all_ok = assert_eq(NS.CombatMode.get_mode({ combat_mode = "single" }), 2, "String 'single' resolves to MODE_SINGLE") and all_ok
all_ok = assert_eq(NS.CombatMode.get_mode({ combat_mode = "aoe" }), 3, "String 'aoe' resolves to MODE_AOE") and all_ok
all_ok = assert_eq(NS.CombatMode.get_mode({ combat_mode = "auto" }), 1, "String 'auto' resolves to MODE_AUTO") and all_ok

-- Test 7: Default mode name
local name = NS.CombatMode.mode_name({ combat_mode = 2 })
all_ok = assert_eq(name, "Single Target", "mode_name for ST is correct") and all_ok

-- Test 8: Nil/invalid settings default to auto
all_ok = assert_eq(NS.CombatMode.get_mode({}), 1, "Empty settings default to auto") and all_ok
all_ok = assert_eq(NS.CombatMode.get_mode({ combat_mode = 999 }), 1, "Invalid mode defaults to auto") and all_ok
all_ok = assert_eq(NS.CombatMode.get_mode(nil), 1, "Nil settings default to auto") and all_ok

if all_ok then
    print("OK combat_mode")
else
    print("FAIL combat_mode")
end
