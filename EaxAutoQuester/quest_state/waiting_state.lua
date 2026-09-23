-- What: WAITING state handler — poll for Zygor step to appear
-- When: Called by coordinator when shared._state == "WAITING"
-- Why: Centralize waiting logic with 3s throttle, transition to IDLE when step appears
-- API: exports run(shared, ctx) → next_state string

-- ============================================================================
-- Module Table
-- ============================================================================

local M = {}

-- The destination fields belong to shared/nav_destination.lua; WAITING is one of its producers
-- (the pre-set waypoint that gives IDLE a head start), never a direct writer of them.
local nav_destination = require("shared/nav_destination")

-- ============================================================================
-- State: WAITING — Poll for Zygor step to appear
-- ============================================================================

--- Recheck Zygor every 3s (throttled via utils.throttle).
--- Transitions to IDLE when a step appears.
--- @param shared table Shared state variables
--- @param ctx table Per-tick context with submodules, me, helpers
--- @return string next_state
function M.run(shared, ctx)
    local utils = ctx.utils

    -- 3s throttle between checks
    if not utils or not utils.throttle("quest_state_waiting", 3.0) then
        return "WAITING"
    end

    local zygor = ctx.zygor
    if zygor and zygor.has_current_step() then
        ctx.debug_log("WAITING: step appeared → IDLE")

        -- B.build: Pre-set nav destination from next waypoint lookahead
        local next_wp = zygor.get_next_waypoint_world and zygor.get_next_waypoint_world()
        if next_wp then
            nav_destination.point(shared, next_wp)
        end

        shared._last_step_num = 0 -- force fresh evaluation
        return "IDLE"
    end

    return "WAITING"
end

return M
