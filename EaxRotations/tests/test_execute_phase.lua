-- Readability notes:
--   What: recovery regression smoke test.
--   When: run with lua from the repository root.
--   Why: confirms helper code loads without live client dependencies.
--   Safety: no game input APIs are called.

-- Decision notes:
--   Tests use local stubs instead of a live Sylvanas client so API-bound behavior remains reproducible.
--   Each case protects one previous failure mode or role rule; keep assertions narrow and descriptive.
--   No test should call real input/cast APIs because regression runs must be safe outside the game.
local function assert_true(v, label) if not v then error(label or "assert_true failed", 2) end end
local function assert_eq(a, b, label) if a ~= b then error((label or "assert_eq") .. ": " .. tostring(a) .. " ~= " .. tostring(b), 2) end end
dofile('EaxRotations/shared/execute_phase.lua')
assert_true(_G.ExecutePhase.is_execute_phase(20, 20), 'execute')
assert_eq(_G.ExecutePhase.is_execute_phase(21, 20), false, 'not execute')
print("PASS execute_phase")
