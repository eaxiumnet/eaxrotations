-- mf_tick_compute_sylvanas.lua -- Mind Flay tick computation helper for Shadow Priest..
-- WHAT:   Mind Flay tick computation helper for Shadow Priest.
-- WHEN:   called per-frame in shadow_sylvanas while MF is channeling
-- WHY:    lets Shadow lock MF for exactly N ticks then bail to VT
-- SAFETY: uses NS.tbc_time; nil-guarded
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
--   local should_clip = mf_tick.should_clip_mf(mf_channeling, mf_ticks, vt_clip_threshold, mb_ready, swd_ready, vt_remaining, swp_remaining)
--
-- Usage (unit test — dofile pattern):
--   dofile("EaxRotations/shared/mf_tick_compute_sylvanas.lua")
--   local mf_tick = _G.MfTickCompute
--   ...same as above...

local floor = math.floor
local ipairs = ipairs

local M = {}

local function call_method(obj, name)
    local fn = obj and obj[name]
    if type(fn) ~= "function" then return nil end
    local ok, value = pcall(fn, obj)
    return ok and value or nil
end

--- Compute MF channel state from unit APIs and game time.
-- @param me            unit object with is_channeling(), get_active_spell_id(),
--                       get_active_channel_cast_start_time() (or nil)
-- @param game_time_ms  current game time in milliseconds
-- @param mf_ids        table of Mind Flay spell IDs (e.g. {15407, 25387})
-- @return mf_channeling  boolean — are we channeling Mind Flay?
-- @return mf_ticks       number — ticks landed so far (0-3)
function M.compute_channel_state(me, game_time_ms, mf_ids)
    local mf_channeling = false
    local mf_ticks = 0

    local is_channeling = call_method(me, "is_channeling")
    if is_channeling ~= true then
        is_channeling = call_method(me, "is_channelling_spell") == true
    end

    if is_channeling then
        local channel_spell_id = call_method(me, "get_active_channel_spell_id")
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
        if is_mf then
            mf_channeling = true
            local channel_start_ms = call_method(me, "get_active_channel_cast_start_time")
                or call_method(me, "get_active_spell_cast_start_time")
                or 0
            if channel_start_ms > 0 and game_time_ms > channel_start_ms then
                local elapsed_s = (game_time_ms - channel_start_ms) / 1000.0
                mf_ticks = floor(elapsed_s)
            end
        end
    end

    return mf_channeling, mf_ticks
end

--- Determine whether MF should be clipped at 2 ticks.
-- APL: spellChanneledTicks == 2 — clip exactly at 2 ticks, not at 3.
-- @param mf_channeling     boolean — are we channeling MF?
-- @param mf_ticks          number — ticks landed so far
-- @param vt_clip_threshold number — haste-aware VT cast time (from spell_cast_time)
-- @param mb_ready          boolean — is Mind Blast ready?
-- @param swd_ready         boolean — is SW:D ready?
-- @param vt_remaining      number — VT debuff remaining seconds
-- @param swp_remaining     number — SW:P debuff remaining seconds
-- @return should_clip_mf   boolean — should we interrupt MF for a higher-priority spell?
function M.should_clip_mf(mf_channeling, mf_ticks, vt_clip_threshold, mb_ready, swd_ready, vt_remaining, swp_remaining)
    return mf_channeling
        and mf_ticks >= 2
        and mf_ticks < 3
        and (mb_ready or swd_ready or vt_remaining < vt_clip_threshold or swp_remaining < 0.7)
end

-- Export to NS namespace (Sylvanas production path)
local _G = _G
_G.MfTickCompute = M
if _G.EaxRotations then
    _G.EaxRotations.compute_channel_state = M.compute_channel_state
    _G.EaxRotations.should_clip_mf = M.should_clip_mf
end

return M
