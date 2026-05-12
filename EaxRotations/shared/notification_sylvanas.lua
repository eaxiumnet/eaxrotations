-- ============================================================================
-- Shared Helper: Notification System
-- ============================================================================
-- Readability notes:
--   What: Center-screen notifications for important events.
--   When: Burst active, defensive used, trinket ready, etc.
--   Why: Visual feedback for rotation state changes.
--   Safety: Throttled to prevent spam; uses core.graphics.add_notification().
--
-- Pattern: Brief on-screen alerts via Sylvanas graphics API.
-- ============================================================================

local M = {}
local _G = _G
local NS = _G.EaxRotations

-- Notification history to prevent spam
local last_notification_time = {}
local NOTIFICATION_COOLDOWN = 3  -- seconds between same notification

--- Show a notification if cooldown has expired.
-- @param message string - Text to display
-- @param duration number - Duration in seconds (default 2)
-- @param color table - RGBA color (default white)
-- @return boolean - true if notification was shown
function M.show(message, duration, color)
    if not NS then return false end
    
    -- Check cooldown
    local now = NS.time_now and NS.time_now() or 0
    if last_notification_time[message] and (now - last_notification_time[message]) < NOTIFICATION_COOLDOWN then
        return false
    end
    
    -- Use core.graphics.add_notification if available
    if NS.core and NS.core.graphics and NS.core.graphics.add_notification then
        NS.core.graphics.add_notification(message, duration or 2, color or {255, 255, 255, 255})
        last_notification_time[message] = now
        return true
    end
    
    -- Fallback to text_2d
    if NS.core and NS.core.graphics and NS.core.graphics.text_2d then
        -- Center of screen approximation
        NS.core.graphics.text_2d(message, 400, 300, color or {255, 255, 255, 255})
        last_notification_time[message] = now
        return true
    end
    
    return false
end

--- Show burst active notification.
function M.show_burst_active()
    return M.show("BURST ACTIVE", 2, {255, 215, 0, 255})  -- Gold
end

--- Show defensive used notification.
function M.show_defensive_used(spell_name)
    return M.show("DEFENSIVE: " .. (spell_name or ""), 2, {0, 255, 0, 255})  -- Green
end

--- Show trinket ready notification.
function M.show_trinket_ready(slot)
    return M.show("TRINKET READY (Slot " .. (slot or "") .. ")", 2, {0, 191, 255, 255})  -- Deep Sky Blue
end

--- Show execute phase notification.
function M.show_execute_phase()
    return M.show("EXECUTE PHASE", 2, {255, 69, 0, 255})  -- Red Orange
end

--- Show low health warning.
function M.show_low_health()
    return M.show("LOW HEALTH", 2, {255, 0, 0, 255})  -- Red
end

--- Show force command active notification.
function M.show_force_command(command)
    return M.show("FORCE: " .. string.upper(command or ""), 2, {255, 255, 0, 255})  -- Yellow
end

-- Register with EaxRotations namespace if available
if _G.EaxRotations then
    _G.EaxRotations.Notification = M
end

return M
