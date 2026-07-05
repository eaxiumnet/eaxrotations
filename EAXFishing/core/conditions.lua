-- conditions.lua — Time-of-day and weather awareness for fishing.
-- WHAT:  tracks whether the current time is within a fishing window.
--        Since Sylvanas does not expose WoW's in-game clock (GetGameTime),
--        this module uses core.game_time() (ms since game start) as a proxy
--        and provides a framework for time-window scheduling.
-- WHEN:  checked every 30s, updates state.conditions.in_fishing_window.
-- WHY:   some fish only bite at night or during specific weather conditions.
--        This module provides the scheduling framework; when the API exposes
--        the in-game clock, it can be wired in here.
-- SAFETY: pcall on all API; passive (never blocks fishing, just sets a flag).

local APISurface = require("core/api_surface")

local M = {}

--- Check if current time is within the fishing window
-- Currently uses core.game_time() (ms since game start) as a proxy.
-- When Sylvanas exposes the in-game clock, replace this with real time check.
-- @param ctx table
-- @param now number
-- @return boolean true if in fishing window
function M.is_in_fishing_window(ctx, now)
    local state = ctx.state
    if not state.conditions then return true end

    -- Throttle check (every 30s)
    if now - state.conditions.window_checked_at < 30.0 then
        return state.conditions.in_fishing_window
    end
    state.conditions.window_checked_at = now

    -- Get game time in seconds
    local game_time_ms = 0
    if core and core.game_time then
        local ok, result = pcall(core.game_time)
        if ok and type(result) == "number" then
            game_time_ms = result
        end
    end

    -- Placeholder: until Sylvanas exposes the in-game clock,
    -- we assume we're always in the fishing window.
    -- When the API becomes available, implement:
    --   local hour = (game_time_ms / 1000 / 60) % 24  -- approximate
    --   local is_night = hour >= 21 or hour < 6
    --   state.conditions.in_fishing_window = is_night
    state.conditions.in_fishing_window = true

    return state.conditions.in_fishing_window
end

--- Update conditions state
-- @param ctx table
-- @param now number
function M.update(ctx, now)
    M.is_in_fishing_window(ctx, now)
end

--- Reset conditions state
function M.reset(state)
    if not state.conditions then return end
    state.conditions.in_fishing_window = true
    state.conditions.window_checked_at = 0.0
end

return M
