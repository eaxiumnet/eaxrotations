-- recovery regression smoke test.

local function assert_true(v, label) if not v then error(label or "assert_true failed", 2) end end
local function assert_eq(a, b, label) if a ~= b then error((label or "assert_eq") .. ": " .. tostring(a) .. " ~= " .. tostring(b), 2) end end
local f=assert(io.open('EaxRotations/core_sylvanas.lua','rb')); local d=f:read('*a'); f:close(); assert_eq(d:find('\0',1,true), nil, 'no nul')
print("PASS api_lint")
