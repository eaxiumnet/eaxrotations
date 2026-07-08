-- =============================================================================
-- Navigation/Client Module - Nav client wrapper
-- Uses APISurface for all input operations
-- =============================================================================

local APISurface = require("core/api_surface")

local M = {}

-- SentinelNavClient reference (populated at init)
local nav_client = nil
local nav_global_name = "SentinelNavClient"

--- Get the nav client if available
-- @param ctx table context
-- @return table? nav client
function M.get_client(ctx)
    if nav_client then
        return nav_client
    end
    
    -- Try to get from globals
    local global_nav = _G[nav_global_name]
    if global_nav then
        nav_client = global_nav
        return nav_client
    end
    
    return nil
end

--- Check if nav client is available
-- @param ctx table context
-- @return boolean
function M.has_client(ctx)
    return M.get_client(ctx) ~= nil
end

--- Stop navigation
-- @param ctx table context
function M.stop(ctx)
    local client = M.get_client(ctx)
    if client and client.stop then
        client:stop()
    end
    -- Also ensure physical stop using APISurface
    APISurface.move_forward_stop()
end

--- Move to destination
-- @param ctx table context
-- @param destination table position {x, y, z}
-- @param stop_distance number
-- @return boolean success
function M.move(ctx, destination, stop_distance)
    local client = M.get_client(ctx)
    if not client then
        return false
    end
    
    if client.move_to then
        return client:move_to(destination, stop_distance)
    end
    
    return false
end

--- Check if currently moving
-- @param ctx table context
-- @return boolean
function M.is_moving(ctx)
    local client = M.get_client(ctx)
    if client and client.is_moving then
        return client:is_moving()
    end
    return false
end

--- Get current destination
-- @param ctx table context
-- @return table? position
function M.get_destination(ctx)
    local client = M.get_client(ctx)
    if client and client.get_destination then
        return client:get_destination()
    end
    return nil
end

return M
