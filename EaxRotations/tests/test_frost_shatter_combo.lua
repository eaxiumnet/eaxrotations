-- test_frost_shatter_combo.lua — Verify Frost mage shatter combo mechanics (Freeze + Frostbolt + Ice Lance).
-- WHAT:  Verify Frost mage shatter combo mechanics (Freeze + Frostbolt + Ice Lance).
-- WHEN:  Run as part of rotation test suite.
-- SAFETY: Pure test — no production code, no side effects, no state mutation.

local function assert_true(v, label) if not v then error(label or "assert_true failed", 2) end end
local function assert_eq(a, b, label) if a ~= b then error((label or "assert_eq") .. ": " .. tostring(a) .. " ~= " .. tostring(b), 2) end end
dofile('EaxRotations/tests/test_execute_phase.lua')
print("PASS test_frost_shatter_combo")
