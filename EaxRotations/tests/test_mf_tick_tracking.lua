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
dofile('EaxRotations/shared/mf_tick_compute.lua')
local u={is_channeling=function() return true end,get_active_spell_id=function() return 25387 end,get_active_channel_cast_start_time=function() return 1000 end}
local active,ticks=_G.MfTickCompute.compute_channel_state(u,3200,{25387})
assert_true(active,'active')
assert_eq(ticks,2,'ticks')
print("PASS mf_tick")
