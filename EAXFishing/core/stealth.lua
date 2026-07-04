-- =============================================================================
-- Core/Stealth Module - Nearby player detection for Stealth Mode
-- WHAT:  Scans visible objects for other players within a configurable range.
-- WHEN:  every tick when stealth_mode is enabled.
-- WHY:   slows down casting rhythm when players are nearby to look less bot-like.
-- SAFETY: pcall on all API calls; never crashes on missing object fields.
-- =============================================================================

local APISurface = require("core/api_surface")

local M = {}

-- How often to re-scan for players (seconds)
local SCAN_INTERVAL = 1.5

-- Default range if menu value is unreadable (yards squared)
local DEFAULT_RANGE_YD = 30
local DEFAULT_RANGE_SQ = DEFAULT_RANGE_YD * DEFAULT_RANGE_YD

--- Check if any other player is within the configured stealth range.
-- @param ctx table context
-- @param me table player object
-- @param now number current time
-- @return boolean true if a player is nearby
function M.is_player_nearby(ctx, me, now)
    local state = ctx.state
    local config = ctx.deps.config

    -- Throttle: only scan every SCAN_INTERVAL seconds
    if state.stealth.last_scan_time > 0
       and (now - state.stealth.last_scan_time) < SCAN_INTERVAL then
        return state.stealth.player_nearby
    end
    state.stealth.last_scan_time = now

    -- Resolve range from menu (yards → squared)
    local range_yds = DEFAULT_RANGE_YD
    if config.menu.stealth_range and config.menu.stealth_range.get then
        range_yds = config.menu.stealth_range:get() or DEFAULT_RANGE_YD
    end
    local range_sq = range_yds * range_yds

    local my_pos = APISurface.get_object_position(me)
    if not my_pos then
        state.stealth.player_nearby = false
        return false
    end

    local objects = APISurface.get_all_objects()
    local found = false

    for _, obj in ipairs(objects) do
        if APISurface.is_valid(obj) then
            -- Skip self
            if obj ~= me then
                -- Check if this object is a player
                local is_player = false
                if type(obj.is_player) == "function" then
                    local ok, result = pcall(obj.is_player, obj)
                    if ok then is_player = result end
                end

                if is_player then
                    local pos = APISurface.get_object_position(obj)
                    if pos then
                        local dx = my_pos.x - pos.x
                        local dy = my_pos.y - pos.y
                        local dist_sq = dx*dx + dy*dy
                        if dist_sq <= range_sq then
                            found = true
                            break
                        end
                    end
                end
            end
        end
    end

    -- If state changed, log it (throttled to avoid spam)
    if found ~= state.stealth.player_nearby then
        if found then
            APISurface.print("[EaxFishing] Stealth: player detected — slowing down")
        else
            APISurface.print("[EaxFishing] Stealth: no players nearby — resuming normal pace")
        end
    end

    state.stealth.player_nearby = found
    return found
end

--- Get the current stealth multiplier for delays.
-- Returns 1.0 when no players are nearby, or a larger value (1.5–2.5)
-- when a player is detected, based on the behavior profile.
-- @param ctx table context
-- @param now number current time
-- @return number multiplier (≥1.0)
function M.get_delay_multiplier(ctx, now)
    local state = ctx.state
    local config = ctx.deps.config

    -- Stealth mode disabled — no effect
    local stealth_on = false
    if config.menu.stealth_mode and config.menu.stealth_mode.get_state then
        stealth_on = config.menu.stealth_mode:get_state()
    end
    if not stealth_on then
        return 1.0
    end

    local me = APISurface.get_local_player()
    if not me or not APISurface.is_valid(me) then
        return 1.0
    end

    local nearby = M.is_player_nearby(ctx, me, now)
    if not nearby then
        return 1.0
    end

    -- When a player is nearby, apply a profile-scaled delay multiplier.
    -- Ultra-safe mode pushes it to the max end of the range.
    local base = 1.5
    if config.menu.ultra_safe_mode and config.menu.ultra_safe_mode.get_state then
        local ultra = config.menu.ultra_safe_mode:get_state()
        if ultra then base = 2.5 end
    end

    return base
end

return M
