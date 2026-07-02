-- =============================================================================
-- Navigation/Shoreline Solver Module - Find optimal fishing positions
-- =============================================================================

local Math = require("utils/math")
local Terrain = require("navigation/terrain")

local M = {}

local TAU = math.pi * 2.0

--- Build cache key for shoreline solver
-- @param player_pos table
-- @param pool_pos table
-- @param desired_distance number
-- @param max_depth_delta number
-- @param search_radius_limit number
-- @return string cache key
function M.build_cache_key(player_pos, pool_pos, desired_distance, max_depth_delta, search_radius_limit)
    local px = player_pos and math.floor((player_pos.x or 0) / 5) or 0
    local py = player_pos and math.floor((player_pos.y or 0) / 5) or 0
    local pz = player_pos and math.floor((player_pos.z or 0) / 2) or 0
    local pool_x = pool_pos and math.floor((pool_pos.x or 0) / 10) or 0
    local pool_y = pool_pos and math.floor((pool_pos.y or 0) / 10) or 0
    local pool_z = pool_pos and math.floor((pool_pos.z or 0) / 2) or 0
    return string.format("%d.%d.%d|%d.%d.%d|%.1f.%.1f.%.1f", 
        px, py, pz, pool_x, pool_y, pool_z, 
        desired_distance, max_depth_delta, search_radius_limit)
end

--- Check if terrain is a valid shoreline candidate
-- @param terrain_z number
-- @param pool_surface_z number
-- @param max_depth_delta number
-- @return boolean
function M.is_shoreline_candidate(terrain_z, pool_surface_z, max_depth_delta)
    local depth_below_pool = pool_surface_z - terrain_z
    return depth_below_pool >= 0 and depth_below_pool <= max_depth_delta
end

--- Build nearest above-ground point within radius
-- @param ctx table context
-- @param player_pos table
-- @param pool_pos table
-- @param max_radius number
-- @param min_above number
-- @return table? position {x, y, z}
function M.build_nearest_above_ground(ctx, player_pos, pool_pos, max_radius, min_above)
    local pool_z = pool_pos.z
    
    -- Scan in expanding circles
    local angle_steps = 8
    local radius_step = 2.0
    
    for radius = 5.0, max_radius, radius_step do
        for angle_idx = 0, angle_steps - 1 do
            local angle = (angle_idx / angle_steps) * TAU
            local test_x = pool_pos.x + math.cos(angle) * radius
            local test_y = pool_pos.y + math.sin(angle) * radius
            
            local terrain_z = Terrain.get_terrain_height_at(ctx, test_x, test_y, pool_z)
            
            if Terrain.is_ground_above_pool(terrain_z, pool_z, min_above) then
                return { x = test_x, y = test_y, z = terrain_z }
            end
        end
    end
    
    return nil
end

--- Build pool standoff point (optimal fishing position)
-- @param ctx table context
-- @param player_pos table
-- @param pool_pos table
-- @param desired_distance number
-- @param max_depth_delta number
-- @param max_search_radius number
-- @param angle_steps number
-- @param radius_step number
-- @return table? position {x, y, z}, number? radius
function M.build_standoff_point(ctx, player_pos, pool_pos, desired_distance, max_depth_delta, max_search_radius, angle_steps, radius_step)
    angle_steps = angle_steps or 16
    radius_step = radius_step or 1.0
    
    local pool_z = pool_pos.z
    local best_point = nil
    local best_dist_diff = math.huge
    
    for angle_idx = 0, angle_steps - 1 do
        local angle = (angle_idx / angle_steps) * TAU
        local dir_x = math.cos(angle)
        local dir_y = math.sin(angle)
        
        for radius = desired_distance - 5.0, desired_distance + 5.0, radius_step do
            if radius > 0 and radius <= max_search_radius then
                local test_x = pool_pos.x + dir_x * radius
                local test_y = pool_pos.y + dir_y * radius
                
                local terrain_z = Terrain.get_terrain_height_at(ctx, test_x, test_y, pool_z)
                
                if M.is_shoreline_candidate(terrain_z, pool_z, max_depth_delta) then
                    local dist_diff = math.abs(radius - desired_distance)
                    if dist_diff < best_dist_diff then
                        best_dist_diff = dist_diff
                        best_point = { x = test_x, y = test_y, z = terrain_z }
                    end
                end
            end
        end
    end
    
    return best_point, best_point and best_dist_diff or nil
end

--- Solve shoreline position with caching
-- @param ctx table context
-- @param now number current time
-- @param player_pos table
-- @param pool_pos table
-- @param desired_distance number
-- @param max_depth_delta number
-- @param search_radius_limit number
-- @return table? position, number? radius, boolean? throttled
function M.solve_shoreline_cached(ctx, now, player_pos, pool_pos, desired_distance, max_depth_delta, search_radius_limit)
    local state = ctx.state
    local cache = state.navigation.shoreline_solver_cache
    
    local cache_key = M.build_cache_key(player_pos, pool_pos, desired_distance, max_depth_delta, search_radius_limit)
    
    -- Check cache hit
    if cache.key == cache_key and cache.result then
        return cache.result, cache.result_radius, false
    end
    
    -- Check throttle
    if now < cache.next_retry_time then
        return nil, nil, true
    end
    
    -- Solve
    local result, radius = M.build_standoff_point(
        ctx, player_pos, pool_pos, 
        desired_distance, max_depth_delta, search_radius_limit,
        16, 1.0
    )
    
    if result then
        cache.key = cache_key
        cache.result = result
        cache.result_radius = radius
    else
        -- Throttle retries
        cache.next_retry_time = now + 2.0
    end
    
    return result, radius, false
end

return M
