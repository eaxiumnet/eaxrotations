-- recovery regression smoke test.

local function assert_true(v, label) if not v then error(label or "assert_true failed", 2) end end
local function assert_eq(a, b, label) if a ~= b then error((label or "assert_eq") .. ": " .. tostring(a) .. " ~= " .. tostring(b), 2) end end
dofile('EaxRotations/shared/execute_phase_sylvanas.lua')
assert_true(_G.ExecutePhase.is_execute_phase(20, 20), 'execute')
assert_eq(_G.ExecutePhase.is_execute_phase(21, 20), false, 'not execute')
print("PASS execute_phase")
