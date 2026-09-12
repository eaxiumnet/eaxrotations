-- test_mf_tick_tracking.lua — Verify Mind Flay tick tracking for shadow priest channel management.
-- WHAT:  Verify Mind Flay tick tracking for shadow priest channel management.
-- WHEN:  Run as part of rotation test suite.
-- SAFETY: Pure test — no production code, no side effects, no state mutation.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path
local function assert_true(v, label) if not v then error(label or "assert_true failed", 2) end end
local function assert_eq(a, b, label) if a ~= b then error((label or "assert_eq") .. ": " .. tostring(a) .. " ~= " .. tostring(b), 2) end end
dofile('EaxRotations/shared/mf_tick_compute_sylvanas.lua')
local u={is_channeling=function() return true end,get_active_spell_id=function() return 25387 end,get_active_channel_cast_start_time=function() return 1000 end}
local active,ticks=_G.MfTickCompute.compute_channel_state(u,3200,{25387})
assert_true(active,'active')
assert_eq(ticks,2,'ticks')
-- Engine channel clock (2026-09-12): the authoritative accessors take
-- precedence over the channel_start arithmetic, and the tick interval is
-- duration/3 so a haste-scaled channel reports its real tick boundaries.
local u2 = {
    is_channeling = function() return true end,
    get_active_channel_spell_id = function() return 25387 end,
    get_channel_elapsed_ms = function() return 1200 end,
    get_channel_duration_ms = function() return 1500 end,
    get_channel_remaining_ms = function() return 300 end,
}
local active2, ticks2, remaining2 = _G.MfTickCompute.compute_channel_state(u2, 999999, {25387})
assert_true(active2, "engine active")
assert_eq(ticks2, 2, "engine ticks (duration/3 = 500ms)")   -- the 1s cadence would say 1
assert_true(remaining2 and math.abs(remaining2 - 0.3) < 1e-9, "engine remaining seconds")

-- Fail-open side: without the engine accessors the same 1200ms elapsed is 1
-- tick under the 1s cadence, so the engine clock is what changed the answer.
local u3 = {
    is_channeling = function() return true end,
    get_active_spell_id = function() return 25387 end,
    get_active_channel_cast_start_time = function() return 100000 end,
}
local active3, ticks3 = _G.MfTickCompute.compute_channel_state(u3, 101200, {25387})
assert_true(active3, "fallback active")
assert_eq(ticks3, 1, "fallback ticks (1s cadence)")

-- should_clip_mf engine end-time rule: open the clip only when a debuff would
-- expire before this channel ends (2 ticks, VT 2.9s outside the 1.5s window).
assert_true(_G.MfTickCompute.should_clip_mf(true, 2, 1.5, false, false, 2.9, 99, 1.5, 3.0),
    "clip when the debuff outlives the channel")
assert_true(not _G.MfTickCompute.should_clip_mf(true, 2, 1.5, false, false, 2.9, 99, 1.5, 0.5),
    "hold when the channel ends first")
assert_true(not _G.MfTickCompute.should_clip_mf(true, 2, 1.5, false, false, 2.9, 99, 1.5, nil),
    "no engine clock: static windows only, so 2.9s VT holds")

print("PASS mf_tick")
