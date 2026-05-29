-- recovery regression smoke test.

local function assert_true(v, label) if not v then error(label or "assert_true failed", 2) end end
local function assert_eq(a, b, label) if a ~= b then error((label or "assert_eq") .. ": " .. tostring(a) .. " ~= " .. tostring(b), 2) end end
dofile('EaxRotations/shared/mf_tick_compute_sylvanas.lua')
local u={is_channeling=function() return true end,get_active_spell_id=function() return 25387 end,get_active_channel_cast_start_time=function() return 1000 end}
local active,ticks=_G.MfTickCompute.compute_channel_state(u,3200,{25387})
assert_true(active,'active')
assert_eq(ticks,2,'ticks')
print("PASS mf_tick")
