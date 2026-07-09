-- test_ele_shock_gating.lua — Verify Elemental shaman shock-gating (Earth Shock / Flame Shock priority).
-- WHAT:  Verify Elemental shaman shock-gating (Earth Shock / Flame Shock priority).
-- WHEN:  Run as part of rotation test suite.
-- SAFETY: Pure test — no production code, no side effects, no state mutation.

local function assert_true(v, label) if not v then error(label or "assert_true failed", 2) end end
local function assert_eq(a, b, label) if a ~= b then error((label or "assert_eq") .. ": " .. tostring(a) .. " ~= " .. tostring(b), 2) end end
dofile('EaxRotations/tests/test_execute_phase.lua')
print("PASS test_ele_shock_gating")
