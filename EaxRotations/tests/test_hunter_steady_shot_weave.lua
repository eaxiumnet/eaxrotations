-- test_hunter_steady_shot_weave.lua -- Hunter shot timer tests.
-- WHAT:  Hunter shot timer tests
-- WHEN:  During rotation test suite execution.
-- WHY:   Protects against regressions in rotation logic and state handling.
-- SAFETY: Pure unit tests with mocked API context.

-- ============================================================================
-- Test: Hunter Core Steady Shot Weave (HU2)
-- ----------------------------------------------------------------------------
-- Verifies can_cast_steady() in shared/hunter_core_sylvanas.lua correctly
-- handles the high-haste case where weapon speed drops below Steady cast time.
--
-- TBC hunter shot-weave theory:
--   - Normal haste: fit Steady between autos (remain > cast + buffer + 500)
--   - High haste: 1:1 rotation — cast Steady even if it delays the auto,
--     but NEVER during the 500ms auto-shot wind-up window.
-- ============================================================================

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local function assert_true(v, label) if not v then error(label or "assert_true failed", 2) end end
local function assert_false(v, label) if v then error(label or "assert_false failed", 2) end end
local function assert_eq(a, b, label) if a ~= b then error((label or "assert_eq") .. ": " .. tostring(a) .. " ~= " .. tostring(b), 2) end end

-- ============================================================================
-- Mock NS + player
-- ============================================================================
local _weapon_speed = 3.0
local _base_weapon_speed = 3.0
local _last_auto_time = 0
local _now = 1000

_G.NS = {
    time_now = function() return _now end,
}

_G.core = {}

local me = {
    get_ranged_weapon_speed = function() return _weapon_speed end,
}

_G.EaxRotations = {
    GetPlayer = function() return me end,
    time_now = function() return _now end,
}

-- ============================================================================
-- Load hunter_core (clear both preload and loaded caches first)
-- ============================================================================
package.preload["shared/hunter_core_sylvanas"] = nil
package.loaded["shared/hunter_core_sylvanas"] = nil
local hunter_core = require("shared/hunter_core_sylvanas")
assert_true(hunter_core ~= nil, "hunter_core should load")

-- Helper: set auto-shot state directly
local function set_auto_state(weapon_speed, elapsed_ms)
    _weapon_speed = weapon_speed
    _base_weapon_speed = weapon_speed
    _now = 1000
    hunter_core.record_auto_shot()  -- sets last_auto_time = 1000, auto_shot_active = true
    _now = 1000 + (elapsed_ms or 0) / 1000  -- advance time by elapsed_ms
end

-- ============================================================================
-- Contract 1: Normal haste (3.0s weapon), plenty of time → can cast
-- elapsed = 500ms, remain = 2500ms, steady_cast = 1500ms, needed = 2150ms
-- 2500 > 2150 → true
-- ============================================================================
set_auto_state(3.0, 500)  -- 500ms elapsed, 2500ms remain
assert_true(hunter_core.can_cast_steady(150),
    "C1: normal haste, 2500ms remain → should cast")
print("  [ PASS ] C1: normal haste, plenty of time → can cast")

-- ============================================================================
-- Contract 2: Normal haste, tight window → cannot cast
-- elapsed = 1000ms, remain = 2000ms, needed = 2150ms → false
-- ============================================================================
set_auto_state(3.0, 1000)  -- 1000ms elapsed, 2000ms remain
assert_false(hunter_core.can_cast_steady(150),
    "C2: normal haste, 2000ms remain < 2150 needed → should NOT cast")
print("  [ PASS ] C2: normal haste, tight window → cannot cast")

-- ============================================================================
-- Contract 3: High haste (1.2s weapon), mid-cycle → CAN cast (1:1 rotation)
-- elapsed = 400ms, remain = 800ms, steady_cast = 600ms, needed = 1250ms
-- weapon_speed_ms = 1200 <= 1250 (high haste case)
-- remain = 800 > 500 (not in wind-up) → true
-- ============================================================================
set_auto_state(1.2, 400)  -- 400ms elapsed, 800ms remain
assert_true(hunter_core.can_cast_steady(150),
    "C3: high haste (1.2s weapon), 800ms remain → should cast (1:1 rotation)")
print("  [ PASS ] C3: high haste, mid-cycle → can cast (1:1 rotation)")

-- ============================================================================
-- Contract 4: High haste, in 500ms wind-up → cannot cast
-- elapsed = 900ms, remain = 300ms, in wind-up → false
-- ============================================================================
set_auto_state(1.2, 900)  -- 900ms elapsed, 300ms remain
assert_false(hunter_core.can_cast_steady(150),
    "C4: high haste, 300ms remain (in wind-up) → should NOT cast")
print("  [ PASS ] C4: high haste, in wind-up → cannot cast")

-- ============================================================================
-- Contract 5: Extreme haste (0.8s weapon), mid-cycle → CAN cast
-- elapsed = 300ms, remain = 500ms
-- ============================================================================
set_auto_state(0.8, 300)  -- 300ms elapsed, 500ms remain
assert_true(hunter_core.can_cast_steady(150),
    "C5: extreme haste (0.8s weapon), 500ms remain → should cast")
print("  [ PASS ] C5: extreme haste, mid-cycle → can cast")

-- ============================================================================
-- Contract 6: High haste, early cycle → CAN cast
-- ============================================================================
set_auto_state(1.2, 100)  -- 100ms elapsed, 1100ms remain
assert_true(hunter_core.can_cast_steady(150),
    "C6: high haste, early cycle → should cast")
print("  [ PASS ] C6: high haste, early cycle → can cast")

-- ============================================================================
-- Contract 7: Normal haste, just after auto → can cast
-- elapsed = 10ms, remain = 2990ms, plenty of room → true
-- ============================================================================
set_auto_state(3.0, 10)  -- 10ms elapsed, 2990ms remain
assert_true(hunter_core.can_cast_steady(150),
    "C7: just after auto, 2990ms remain → should cast")
print("  [ PASS ] C7: just after auto → can cast")

print("PASS test_hunter_steady_shot_weave")
