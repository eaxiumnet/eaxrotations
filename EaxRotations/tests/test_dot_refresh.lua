-- recovery regression smoke test.

local function assert_true(v, label) if not v then error(label or "assert_true failed", 2) end end
local function assert_eq(a, b, label) if a ~= b then error((label or "assert_eq") .. ": " .. tostring(a) .. " ~= " .. tostring(b), 2) end end
dofile('EaxRotations/shared/dot_refresh.lua')
assert_true(_G.DotRefresh.should_refresh_dot(0.5, 1.5, 30, 18), 'refresh')
print("PASS dot_refresh")
