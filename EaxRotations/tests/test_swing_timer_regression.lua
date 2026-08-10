-- test_swing_timer_regression.lua — pins shared/swing_timer_sylvanas.lua.
-- WHAT:  Exercises the swing timer's per-frame arithmetic: update() state
--        capture, progress clamping (0..1), time-until math, weaving hints,
--        can_weave, spell-cast swing resets (Slam / Aimed / Multi-Shot),
--        get_status aggregation, on_update alias, init idempotency, and the
--        nil / absent-SDK guards. The module is ticked every frame by the
--        dispatcher (main_sylvanas on_update) and previously had ZERO test
--        references — its progress/remaining/reset math is exactly the
--        boundary class this repo guards elsewhere.
-- WHEN:  rotation suite execution.
-- WHY:   a future edit to the progress / time-until / reset arithmetic could
--        silently break melee weaving gates (get_weaving_hint/can_weave) or
--        the swing window the class files read; this test fails on regressions.
-- SAFETY: Pure unit test. The module caches NS = _G.EaxRotations at load, so a
--        mock NS with a controllable time_now + swing-reporting player is
--        installed BEFORE dofile; the real SDK is never touched. All API calls
--        in the module are pcall-wrapped, and the throwing-SDK path is pinned.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local function assert_true(v, label)
    if not v then error(label or "assert_true failed", 2) end
end
local function assert_eq(a, b, label)
    if a ~= b then error((label or "assert_eq") .. ": expected " .. tostring(b) .. ", got " .. tostring(a), 2) end
end
local function assert_close(a, b, label)
    if math.abs(a - b) > 1e-9 then
        error((label or "assert_close") .. ": expected " .. tostring(b) .. " +/- 1e-9, got " .. tostring(a), 2)
    end
end

-- Controllable mock NS. The module caches NS at require time, so the mock
-- must exist BEFORE dofile. swing_data[wt] = { start, duration } for
-- wt 1 = mainhand, 2 = offhand, 3 = ranged (mirrors Player:GetSwingStart /
-- Player:GetSwing, which the module calls with colon syntax).
local now = 0.0
local swing_data = {}
local registered_spell_casts = 0

local NS = {
    time_now = function() return now end,
    get_global_cooldown = function() return 1.5 end,
    register_on_spell_cast = function() registered_spell_casts = registered_spell_casts + 1 end,
    GetPlayer = function()
        return {
            GetSwingStart = function(self, wt) return (swing_data[wt] or {}).start end,
            GetSwing = function(self, wt) return (swing_data[wt] or {}).duration end,
        }
    end,
}
_G.EaxRotations = NS

local st = dofile("EaxRotations/shared/swing_timer_sylvanas.lua")
assert_true(type(st) == "table", "swing_timer must load under mock NS")
assert_eq(NS.SwingTimer, st, "module registers itself as NS.SwingTimer")
assert_eq(registered_spell_casts, 1, "module auto-inits when a player exists at load")
st.init()
assert_eq(registered_spell_casts, 1, "init is idempotent (single callback registration)")

-- ---------------------------------------------------------------------------
-- 1. Initial / empty state: nothing tracked yet -> zero progress and remaining
-- ---------------------------------------------------------------------------
assert_eq(st.get_mh_progress(), 0, "initial mh progress is 0")
assert_eq(st.get_oh_progress(), 0, "initial oh progress is 0")
assert_eq(st.get_ranged_progress(), 0, "initial ranged progress is 0")
assert_eq(st.get_mh_time_until(), 0, "initial mh time until is 0")

-- ---------------------------------------------------------------------------
-- 2. update() capture + progress clamp + time-until math (main-hand)
-- ---------------------------------------------------------------------------
now = 100
swing_data[1] = { start = 100, duration = 10 }
st.update()
assert_eq(st.get_mh_progress(), 0, "progress 0 at swing start")
assert_eq(st.get_mh_time_until(), 10, "time until equals duration at swing start")

now = 105
assert_eq(st.get_mh_progress(), 0.5, "progress 0.5 halfway through swing")
assert_eq(st.get_mh_time_until(), 5, "time until 5 halfway through swing")

now = 110
assert_eq(st.get_mh_progress(), 1, "progress clamps at 1 on swing completion")
assert_eq(st.get_mh_time_until(), 0, "time until 0 on swing completion")

now = 115
assert_eq(st.get_mh_progress(), 1, "progress stays clamped at 1 after swing")
assert_eq(st.get_mh_time_until(), 0, "time until stays 0 after swing")

now = 90  -- before the swing starts: progress clamps at 0, remaining is the
assert_eq(st.get_mh_progress(), 0, "progress clamps at 0 before swing start")  -- distance to swing COMPLETION
assert_eq(st.get_mh_time_until(), 20, "time until computed to swing completion before start")

-- State is captured only on a start change: a second update with identical
-- swing info keeps the duration (progress still tracks the clock).
now = 120
swing_data[1] = { start = 120, duration = 10 }
st.update()
now = 125
st.update()  -- same start 120 -> no recapture
assert_eq(st.get_mh_progress(), 0.5, "repeated update with same start keeps duration")
assert_eq(st.get_mh_time_until(), 5, "repeated update keeps time until math")

-- Zero-duration swing (e.g. just after a reset, before the engine re-scans).
now = 130
swing_data[1] = { start = 130, duration = 0 }
st.update()
assert_eq(st.get_mh_progress(), 0, "zero duration yields zero progress")
assert_eq(st.get_mh_time_until(), 0, "zero duration yields zero time until")

-- ---------------------------------------------------------------------------
-- 3. Independent per-weapon tracking (mh / oh / ranged)
-- ---------------------------------------------------------------------------
now = 300
swing_data = {
    [1] = { start = 300, duration = 10 },
    [2] = { start = 300, duration = 4 },
    [3] = { start = 300, duration = 20 },
}
st.update()
now = 302
assert_close(st.get_mh_progress(), 0.2, "mh progress 2/10")
assert_close(st.get_oh_progress(), 0.5, "oh progress 2/4")
assert_close(st.get_ranged_progress(), 0.1, "ranged progress 2/20")
assert_eq(st.get_oh_time_until(), 2, "oh time until")
assert_eq(st.get_ranged_time_until(), 18, "ranged time until")
assert_eq(st.get_mh_time_until(), 8, "mh time until unaffected by other weapons")

-- ---------------------------------------------------------------------------
-- 4. Weaving hints (all four buckets + custom cast_time + default GCD)
-- ---------------------------------------------------------------------------
now = 400
swing_data[1] = { start = 400, duration = 20 }  -- remaining = 20 - (now - 400)
st.update()

now = 405  -- remaining 15
assert_eq(st.get_weaving_hint(), "cast_now", "swing far away -> cast_now (default GCD 1.5)")
assert_eq(st.get_weaving_hint(10), "cast_now", "swing far away even for a 10s cast")

now = 418.2  -- remaining 1.8
assert_eq(st.get_weaving_hint(), "optimal", "cast fits before swing (1.8 > 1.5) but not beyond +0.5 buffer")

now = 418.5  -- remaining 1.5 == cast time
assert_eq(st.get_weaving_hint(), "hold", "remaining == cast time -> hold")

now = 419.8  -- remaining 0.2
assert_eq(st.get_weaving_hint(), "clip_warning", "swing imminent -> clip_warning (< 0.3)")

-- can_weave: safe when remaining > cast_time + buffer
now = 405  -- remaining 15
assert_true(st.can_weave(), "default cast 1.5 + buffer 0.2 fits in 15s remaining")
assert_true(st.can_weave(1.5, 0.9), "custom buffer 0.9 still fits in 15s remaining")
assert_eq(st.can_weave(14.9), false, "cast near remaining duration is not safe")
assert_eq(st.can_weave(15.5), false, "cast beyond remaining is not safe")

-- ---------------------------------------------------------------------------
-- 5. Spell-cast swing resets (Slam resets mh; Aimed/Multi-Shot reset ranged)
-- ---------------------------------------------------------------------------
now = 500
st.record_spell_cast(1464)  -- Slam
assert_eq(st.get_mh_progress(), 0, "Slam resets mh progress to 0")
assert_eq(st.get_mh_time_until(), 0, "Slam resets mh time until to 0")
assert_eq(st.get_weaving_hint(), "clip_warning", "reset swing reports clip_warning until the next scan")
assert_eq(st.can_weave(), false, "reset swing cannot weave safely")

st.record_spell_cast(133)  -- Fireball: NOT a swing reset
assert_eq(st.get_mh_time_until(), 0, "non-reset spell leaves the reset state alone")
st.record_spell_cast(nil)
assert_eq(st.get_mh_time_until(), 0, "nil spell id is a no-op")

-- Re-sync from the engine: a NEW swing start recaptures duration.
now = 600
swing_data[1] = { start = 600, duration = 10 }
st.update()  -- start 600 != state 500 -> recapture
now = 601
assert_eq(st.get_mh_time_until(), 9, "mh re-synced from engine after reset")
st.record_spell_cast(133)
assert_eq(st.get_mh_time_until(), 9, "non-reset spell keeps the synced state")
st.record_spell_cast(nil)
assert_eq(st.get_mh_time_until(), 9, "nil spell id is a no-op after sync")

-- Ranged resets.
now = 610
swing_data[3] = { start = 610, duration = 10 }
st.update()
assert_eq(st.get_ranged_time_until(), 10, "ranged baseline before reset")
st.record_spell_cast(19434)  -- Aimed Shot
assert_eq(st.get_ranged_time_until(), 0, "Aimed Shot resets the ranged swing")
st.record_spell_cast(2643)   -- Multi-Shot
assert_eq(st.get_ranged_time_until(), 0, "Multi-Shot also resets the ranged swing")

-- ---------------------------------------------------------------------------
-- 6. get_status aggregates all weapons + hint, refreshing first
-- ---------------------------------------------------------------------------
now = 700
swing_data = {
    [1] = { start = 700, duration = 10 },
    [2] = { start = 700, duration = 5 },
    [3] = { start = 700, duration = 20 },
}
st.update()
now = 702
local status = st.get_status()
assert_close(status.mh_progress, 0.2, "status mh progress")
assert_eq(status.mh_remaining, 8, "status mh remaining")
assert_close(status.oh_progress, 0.4, "status oh progress")
assert_eq(status.oh_remaining, 3, "status oh remaining")
assert_close(status.ranged_progress, 0.1, "status ranged progress")
assert_eq(status.ranged_remaining, 18, "status ranged remaining")
assert_eq(status.weaving_hint, "cast_now", "status weaving hint (remaining 8 > 2.0)")

-- ---------------------------------------------------------------------------
-- 7. on_update is an alias of update() (dispatcher calls it per frame)
-- ---------------------------------------------------------------------------
now = 800
swing_data[1] = { start = 800, duration = 10 }
st.on_update()
now = 803
assert_close(st.get_mh_progress(), 0.3, "on_update drives the same state machine as update")

-- ---------------------------------------------------------------------------
-- 8. Nil / absent-SDK guards
-- ---------------------------------------------------------------------------
-- No player object: update() bails and PRESERVES prior state.
now = 900
local real_get_player = NS.GetPlayer
NS.GetPlayer = function() return nil end
st.update()
NS.GetPlayer = real_get_player
assert_eq(st.get_mh_progress(), 1, "update with no player preserves prior state (progress clamped)")
assert_eq(st.get_mh_time_until(), 0, "update with no player preserves prior state (time until)")

-- Player present but lacking swing APIs: get_swing_info falls back to (0,0)
-- and the module re-captures a zeroed swing (documented fallback behavior).
NS.GetPlayer = function() return {} end
st.update()
assert_eq(st.get_mh_progress(), 0, "bare unit without swing APIs zeroes the tracked mh state")
assert_eq(st.get_mh_time_until(), 0, "bare unit without swing APIs zeroes mh time until")

-- Throwing swing API: the pcall wrappers must isolate the error.
NS.GetPlayer = function()
    return {
        GetSwingStart = function() error("boom") end,
        GetSwing = function() error("boom") end,
    }
end
st.update()  -- must not raise
assert_true(true, "throwing swing API is pcall-isolated (update does not raise)")

print("PASS test_swing_timer_regression")
