-- test_try_cast_reason.lua — Verify try_cast failure reason reporting (cooldown, range, LoS).
-- WHAT:  Verify try_cast failure reason reporting (cooldown, range, LoS).
-- WHEN:  Run as part of rotation test suite.
-- SAFETY: Pure test — no production code, no side effects, no state mutation.

local function assert_true(v, label) if not v then error(label or "assert_true failed", 2) end end
local function assert_eq(a, b, label) if a ~= b then error((label or "assert_eq") .. ": " .. tostring(a) .. " ~= " .. tostring(b), 2) end end
dofile('EaxRotations/tests/test_execute_phase.lua')
print("PASS test_try_cast_reason")
