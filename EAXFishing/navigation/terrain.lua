-- =============================================================================
-- Navigation/Terrain Module - Terrain height helpers
-- REPLACED: core.terrain.get_height with documented alternatives
-- =============================================================================

local APISurface = require("core/api_surface")
local Math = require("utils/math")

local M = {}

local TAU = math.pi * 2.0
local MIN_GROUND_ABOVE_POOL = 0.01

--- Get terrain height at position
-- Uses fallback chain: coords_helper -> izi -> core.get_height_for_position
-- @param ctx table context
-- @param x number
-- @param y number
-- @param seed_z number fallback z
-- @return number terrain height
function M.get_height_at(ctx, x, y, seed_z)
    local height = APISurface.get_terrain_height(x, y)
    
    if type(height) == "number" then
        return height
    end
    
    return seed_z or 0
end

--- Get terrain height with fallback
-- @param ctx table context
-- @param x number
-- @param y number
-- @param seed_z number fallback
-- @return number terrain height
function M.get_terrain_height_at(ctx, x, y, seed_z)
    return M.get_height_at(ctx, x, y, seed_z)
end

--- Check if ground is above pool surface
-- @param terrain_z number terrain height
-- @param pool_surface_z number pool surface height
-- @param min_above number minimum required height difference
-- @return boolean
function M.is_ground_above_pool(terrain_z, pool_surface_z, min_above)
    min_above = min_above or MIN_GROUND_ABOVE_POOL
    return (terrain_z - pool_surface_z) >= min_above
end

--- Check if a position is probably dry land (above pool)
-- @param ctx table context
-- @param pos table position {x, y, z}
-- @param pool_surface_z number pool surface height
-- @param max_depth_delta number max allowed depth below pool
-- @return boolean
function M.is_position_probably_dry(ctx, pos, pool_surface_z, max_depth_delta)
    local terrain_z = M.get_terrain_height_at(ctx, pos.x, pos.y, pos.z)
    local depth_below_pool = pool_surface_z - terrain_z
    return depth_below_pool <= max_depth_delta
end

return M
