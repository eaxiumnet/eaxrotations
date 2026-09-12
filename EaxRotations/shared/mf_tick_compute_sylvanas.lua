-- mf_tick_compute_sylvanas.lua -- Mind Flay tick computation helper for Shadow Priest..
-- WHAT:   Mind Flay tick computation helper for Shadow Priest.
-- WHEN:   called per-frame in shadow_sylvanas while MF is channeling
-- WHY:    lets Shadow lock MF for exactly N ticks then bail to VT
-- SAFETY: pure module; engine-optional and nil-guarded (see below)
-- 2026-09-12: the channel clock now comes from the ENGINE (get_channel_elapsed_ms
--   / get_channel_duration_ms / get_channel_remaining_ms via
--   shared/cast_timing_sylvanas.lua). The old path derived elapsed as
--   `game_time_ms - get_active_channel_cast_start_time()`, which is blind to a
--   haste-scaled channel and rounds every tick onto a hardcoded 1s cadence; the
--   tick interval is now duration/3. That start-time path is kept only as the
--   fallback for a harness/build with no engine channel clock (fail-open).
-- DECISION: pure helper consumed via require() by specs; no on_update side-effects.

-- Pure function extracted from shadow_sylvanas.lua build_shadow_state.
-- Computes MF channel state (channeling, ticks, clip signal) from injectable
-- API-like parameters. No NS/api/ dependencies — safe for unit testing.
--
-- Mind Flay: 3s channel, ticks every 1s (ticks land at 1s, 2s, 3s per TBC).
--   mf_ticks = floor(elapsed_s) gives ticks-landed count matching sim's
--   spellChanneledTicks.
--
-- Clipping gate: mf_ticks >= 2 AND mf_ticks < 3 AND priority spell ready
--
--   local mf_tick = require("shared/mf_tick_compute_sylvanas")  -- or NS.compute_mf_channel_state
--   local mf_channeling, mf_ticks = mf_tick.compute_channel_state(me, NS.game_time_ms(), mf_ids)
--   local should_clip = mf_tick.should_clip_mf(mf_channeling, mf_ticks, vt_clip_threshold, mb_ready, swd_ready, vt_remaining, swp_remaining, swp_clip_threshold)
--
-- Usage (unit test — dofile pattern):
--   dofile("EaxRotations/shared/mf_tick_compute_sylvanas.lua")
--   local mf_tick = _G.MfTickCompute
--   ...same as above...

local floor = math.floor
local max = math.max
local ipairs = ipairs

-- Engine channel clock (shared/cast_timing_sylvanas.lua). Optional: when the
-- module is unavailable this file falls back to the hand-rolled start-time math
-- below, so the helper stays usable standalone under `dofile`.
local ok_timing, cast_timing = pcall(require, "shared/cast_timing_sylvanas")
if not ok_timing or type(cast_timing) ~= "table" then
    cast_timing = nil
end

-- Era base tick interval. Mind Flay channels three ticks; without an engine
-- duration this is the unhaste-assumed 1s cadence the old estimate hardcoded.
local BASE_TICK_MS = 1000
local MF_TICKS_PER_CHANNEL = 3

local M = {}

local function call_method(obj, name)
    local fn = obj and obj[name]
    if type(fn) ~= "function" then return nil end
    local ok, value = pcall(fn, obj)
    return ok and value or nil
end

--- Compute MF channel state from unit APIs and game time.
-- Prefers the engine's channel clock (get_channel_elapsed_ms /
-- get_channel_duration_ms / get_channel_remaining_ms via cast_timing) and falls
-- back to start-time arithmetic when those are absent. The tick interval is
-- derived from the engine duration, so a haste-scaled channel reports its real
-- tick boundaries instead of assuming a 1s cadence.
-- @param me            unit object with is_channeling()/is_channelling_spell(),
--                       get_active_channel_spell_id(), and (fallback path)
--                       get_active_channel_cast_start_time()
-- @param game_time_ms  current game time in milliseconds (fallback path only)
-- @param mf_ids        table of Mind Flay spell IDs (e.g. {15407, 25387})
-- @return mf_channeling     boolean — are we channeling Mind Flay?
-- @return mf_ticks          number — ticks landed so far (0..3)
-- @return mf_remaining_sec  number|nil — seconds left in the channel (nil when
--                           the engine reports no channel clock)
function M.compute_channel_state(me, game_time_ms, mf_ids)
    local mf_channeling = false
    local mf_ticks = 0
    local mf_remaining_sec = nil

    local is_channeling = call_method(me, "is_channeling")
    if is_channeling ~= true then
        is_channeling = call_method(me, "is_channelling_spell") == true
    end
    if not is_channeling then
        return false, 0, nil
    end

    local channel_spell_id = (cast_timing and cast_timing.channel_id(me))
        or call_method(me, "get_active_channel_spell_id")
        or call_method(me, "get_active_spell_id")
        or 0
    local is_mf = false
    if mf_ids then
        for _, id in ipairs(mf_ids) do
            if id == channel_spell_id then
                is_mf = true
                break
            end
        end
    end
    if not is_mf then
        return false, 0, nil
    end
    mf_channeling = true

    -- Engine-first: the authoritative channel clock, already in milliseconds
    -- and already scaled by haste.
    local duration_ms = cast_timing and cast_timing.channel_duration_ms(me) or nil
    local remaining_ms = cast_timing and cast_timing.channel_remaining_ms(me) or nil
    local elapsed_ms = cast_timing and cast_timing.channel_elapsed_ms(me) or nil
    if type(remaining_ms) == "number" then
        mf_remaining_sec = remaining_ms / 1000.0
    end

    -- Fallback: derive elapsed (and then remaining) from the channel start time.
    if type(elapsed_ms) ~= "number" then
        local channel_start_ms = call_method(me, "get_active_channel_cast_start_time")
            or call_method(me, "get_active_spell_cast_start_time")
            or 0
        if channel_start_ms > 0 and game_time_ms and game_time_ms > channel_start_ms then
            elapsed_ms = game_time_ms - channel_start_ms
        end
    end

    local tick_ms = (type(duration_ms) == "number" and duration_ms > 0)
        and (duration_ms / MF_TICKS_PER_CHANNEL)
        or BASE_TICK_MS

    if type(elapsed_ms) == "number" and elapsed_ms > 0 and tick_ms > 0 then
        mf_ticks = floor(elapsed_ms / tick_ms)
        if mf_ticks > MF_TICKS_PER_CHANNEL then mf_ticks = MF_TICKS_PER_CHANNEL end
        if mf_ticks < 0 then mf_ticks = 0 end
        if mf_remaining_sec == nil then
            -- Fallback remaining: whatever is left of the derived channel length.
            local total_ms = (type(duration_ms) == "number" and duration_ms > 0)
                and duration_ms
                or (tick_ms * MF_TICKS_PER_CHANNEL)
            mf_remaining_sec = max(0, (total_ms - elapsed_ms)) / 1000.0
        end
    end

    return mf_channeling, mf_ticks, mf_remaining_sec
end

--- Determine whether MF should be clipped at 2 ticks.
-- APL: spellChanneledTicks == 2 — clip exactly at 2 ticks, not at 3.
-- @param mf_channeling       boolean — are we channeling MF?
-- @param mf_ticks            number — ticks landed so far
-- @param vt_clip_threshold   number — haste-aware VT cast time (from spell_cast_time)
-- @param mb_ready            boolean — is Mind Blast ready?
-- @param swd_ready           boolean — is SW:D ready?
-- @param vt_remaining        number — VT debuff remaining seconds
-- @param swp_remaining       number — SW:P debuff remaining seconds
-- @param swp_clip_threshold  number (optional) — SW:P remaining window that
--                             justifies clipping MF (defaults to 0.7 for
--                             backward compat with 7-arg callers; live
--                             shadow_sylvanas passes the configured
--                             shadow_swp_refresh_window via swp_clip_threshold())
-- @param channel_remaining_sec number (optional) — seconds left in the current
--                             channel (third return of compute_channel_state)
-- @return should_clip_mf     boolean — should we interrupt MF for a higher-priority spell?
function M.should_clip_mf(mf_channeling, mf_ticks, vt_clip_threshold, mb_ready, swd_ready, vt_remaining, swp_remaining, swp_clip_threshold, channel_remaining_sec)
    if not (mf_channeling and mf_ticks >= 2 and mf_ticks < 3) then
        return false
    end
    if mb_ready or swd_ready then return true end
    local vt_window = vt_clip_threshold
    if type(vt_window) ~= "number" then vt_window = 0.7 end
    local swp_window = swp_clip_threshold
    if type(swp_window) ~= "number" then swp_window = 0.7 end
    if vt_remaining < vt_window or swp_remaining < swp_window then return true end
    -- Engine end-time rule (2026-09-12): a DoT that expires before THIS channel
    -- ends loses uptime by waiting for the third tick, so clip now even outside
    -- the static refresh window. Mirrors the wowsims shadow APL's
    -- `dotRemainingTime <= spellCastTime + channelClipDelay` wait/clip pair; the
    -- channel clock now comes from the engine instead of a hand-rolled estimate.
    if type(channel_remaining_sec) == "number" and channel_remaining_sec > 0 then
        if vt_remaining > 0 and vt_remaining <= channel_remaining_sec + vt_window then return true end
        if swp_remaining > 0 and swp_remaining <= channel_remaining_sec + swp_window then return true end
    end
    return false
end

-- Export to NS namespace (Sylvanas production path). Mock-NS guard (survey
-- item #2): a mock NS (battery / apl_status, marked _EAX_MOCK) must never
-- capture module instances via require-time write-back.
local _G = _G
_G.MfTickCompute = M

return M
