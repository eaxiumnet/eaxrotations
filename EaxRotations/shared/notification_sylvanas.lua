-- ============================================================================
-- Shared Helper: Notification System
-- ============================================================================
-- Pattern: Brief on-screen alerts via Sylvanas graphics API.
-- ============================================================================

local M = {}
local _G = _G
local NS = _G.EaxRotations
local pcall = pcall
local tostring = tostring
local string = string

local color_ok, color = pcall(require, "common/color")
if not color_ok then color = nil end

local vec2_ok, vec2 = pcall(require, "common/geometry/vector_2")
if not vec2_ok then vec2 = nil end

-- Notification history to prevent spam
local last_notification_time = {}
local NOTIFICATION_COOLDOWN = 3  -- seconds between same notification

local function make_color(rgba)
    if color and color.new and type(rgba) == "table" then
        return color.new(rgba[1] or 255, rgba[2] or 255, rgba[3] or 255, rgba[4] or 255)
    end
    return rgba
end

local function make_id(message)
    local id = tostring(message or "notification"):lower():gsub("[^%w_]+", "_")
    return "eaxrotations_" .. id
end

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
    
    local col = make_color(color or {255, 255, 255, 255})

    -- Use core.graphics.add_notification if available.
    -- Documented shape: add_notification(unique_id, header, message, duration_s, color, ...)
    if NS.core and NS.core.graphics and NS.core.graphics.add_notification then
        NS.core.graphics.add_notification(make_id(message), "[EaxRotations]", message, duration or 2, col)
        last_notification_time[message] = now
        return true
    end
    
    -- Fallback to text_2d
    if NS.core and NS.core.graphics and NS.core.graphics.text_2d then
        -- Center of screen approximation.
        local position = vec2 and vec2.new and vec2.new(400, 300) or { x = 400, y = 300 }
        NS.core.graphics.text_2d(message, position, 16, col, true)
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
