-- test_melee_combat_math.lua -- Combat tests.
-- WHAT:  Combat tests
-- WHEN:  During rotation test suite execution.
-- WHY:   Protects against regressions in rotation logic and state handling.
-- SAFETY: Pure unit tests with mocked API context.

-- Test: Melee Combat Math (TBC 2.4.3)
-- EaxRotations File Version: 1.0.0
-- Pure math functions — no NS/api stubs needed.

-- Load module under test (dofile pattern)
local mod_ok, mod_err = pcall(dofile, "EaxRotations/shared/melee_combat_math_sylvanas.lua")
if not mod_ok then
    print("FAIL: could not load shared/melee_combat_math_sylvanas.lua: " .. tostring(mod_err))
    return
end

local M = _G.MeleeCombatMath
if not M then
    print("FAIL: _G.MeleeCombatMath not registered")
    return
end

-- Assert helpers (Style 3: print-based, return boolean)
local function assert_eq(a, b, msg)
    if a ~= b then
        print("FAIL " .. tostring(msg) .. ": expected " .. tostring(b) .. " got " .. tostring(a))
        return false
    end
    print("PASS " .. tostring(msg))
    return true
end

local function assert_near(a, b, tolerance, msg)
    tolerance = tolerance or 0.001
    if math.abs(a - b) > tolerance then
        print("FAIL " .. tostring(msg) .. ": expected ~" .. tostring(b) .. " got " .. tostring(a))
        return false
    end
    print("PASS " .. tostring(msg))
    return true
end

local all_pass = true
local function check(result, _label)
    if not result then all_pass = false end
end

-- =========================================================================
-- Glancing Blow Tests
-- =========================================================================

-- Test 1: level_delta=0 → no glancing (0%)
check(assert_eq(M.glancing_chance(0), 0.0, "glancing_chance(0) == 0.0"), "t1")

-- Test 2: level_delta=3 → boss cap (24%)
check(assert_eq(M.glancing_chance(3), 0.24, "glancing_chance(3) == 0.24"), "t2")

-- Test 3: fixed 40% damage penalty
check(assert_eq(M.glancing_damage_penalty(), 0.4, "glancing_damage_penalty() == 0.4"), "t3")

-- =========================================================================
-- Off-Hand / Dual Wield Tests
-- =========================================================================

-- Test 4: no talent → base 50% off-hand multiplier
check(assert_eq(M.off_hand_multiplier(0), 0.5, "off_hand_multiplier(0) == 0.5"), "t4")

-- Test 5: max talent (5 ranks) → 62.5% off-hand multiplier
check(assert_eq(M.off_hand_multiplier(5), 0.625, "off_hand_multiplier(5) == 0.625"), "t5")

-- Test 6: same-level target → 19% DW miss
check(assert_eq(M.dual_wield_miss_chance(0), 0.19, "dual_wield_miss_chance(0) == 0.19"), "t6")

-- Test 7: boss (+3) → 27% DW miss
check(assert_eq(M.dual_wield_miss_chance(3), 0.27, "dual_wield_miss_chance(3) == 0.27"), "t7")

-- =========================================================================
-- Armor Mitigation Tests
-- =========================================================================

-- Test 8: 7700 armor vs level 70 → ~42.2% mitigation
check(assert_near(M.armor_mitigation(7700, 70), 0.422, 0.01, "armor_mitigation(7700, 70) ~ 0.422"), "t8")

-- Test 9: 0 armor → 0% mitigation
check(assert_eq(M.armor_mitigation(0, 70), 0.0, "armor_mitigation(0, 70) == 0.0"), "t9")

-- =========================================================================
-- Rage Normalization Tests
-- =========================================================================

-- Test 10: 3.5s weapon → 1.4x normalization factor
check(assert_eq(M.rage_normalization(3.5), 1.4, "rage_normalization(3.5) == 1.4"), "t10")

-- Test 11: 2.5s weapon → 1.0x normalization factor (baseline)
check(assert_eq(M.rage_normalization(2.5), 1.0, "rage_normalization(2.5) == 1.0"), "t11")

-- =========================================================================
-- Summary
-- =========================================================================

if all_pass then
    print("PASS test_melee_combat_math")
else
    print("FAIL test_melee_combat_math")
end
