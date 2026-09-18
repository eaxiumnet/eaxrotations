-- What: Terrain-height Z-fix for waypoints that come in at z=0 or underground
-- When: Called by zygor_reader and goal_resolver before using any position
-- Why: Zygor map→world conversion returns z=0; coords_helper raycasts real terrain Z
-- Safety: All calls pcall-guarded; returns original position if fix fails
-- Decision: Lazy-loads coords_helper; no hard dependency; safe to require everywhere

local _core_log = core.log
local _get_local_player = core.object_manager.get_local_player

-- Lazy-loaded coords_helper reference
local _coords = nil
local function ensure_coords()
    if _coords then return true end
    local ok, c = pcall(require, "common/utility/coords_helper")
    if ok and c then
        _coords = c
        return true
    end
    return false
end

-- ============================================================================
-- Module Table
-- ============================================================================

local M = {}

--- Fix the Z coordinate of a position using terrain height raycasting.
--- @param pos table|nil { x, y, z } — z is ignored, replaced by terrain height
--- @param extra_height number|nil Raycast start offset (default 4)
--- @return table|nil Fixed position { x, y, z } or nil on failure
function M.fix_z(pos, extra_height)
    if not pos then return nil end
    if not ensure_coords() then return pos end
    if not _coords.get_terrain_height then return pos end

    local x = pos.x or 0
    local y = pos.y or 0

    local ok, z = pcall(_coords.get_terrain_height, _coords, x, y)
    if ok and z then
        -- If terrain height is 0 and original is also 0, we're likely
        -- underground (raycast missed or out-of-bounds). Use player's
        -- current Z as fallback if we're within reasonable XY distance.
        -- Live fix: prevents nav failure when Zygor waypoints convert
        -- to z=0 and terrain raycast also returns 0.
        if z == 0 and (pos.z or 0) == 0 then
            local me_ok, me = pcall(_get_local_player)
            if me_ok and me then
                local pos_ok, me_pos = pcall(me.get_position, me)
                if pos_ok and me_pos and me_pos.z then
                    local dx = x - (me_pos.x or 0)
                    local dy = y - (me_pos.y or 0)
                    local dist_sq = dx*dx + dy*dy
                    if dist_sq < 250000 then  -- 500 yards
                        return { x = x, y = y, z = me_pos.z }
                    end
                end
            end
            return { x = x, y = y, z = 0 }
        end
        return { x = x, y = y, z = z }
    end

    -- Fallback: terrain query failed and original Z is 0 → try player Z
    if (pos.z or 0) == 0 then
        local me_ok, me = pcall(_get_local_player)
        if me_ok and me then
            local pos_ok, me_pos = pcall(me.get_position, me)
            if pos_ok and me_pos and me_pos.z then
                return { x = x, y = y, z = me_pos.z }
            end
        end
    end

    -- Fallback: keep original Z
    return { x = x, y = y, z = pos.z or 0 }
end

--- Convert map coordinates to world position with proper terrain Z.
--- Wraps coords_helper:map_to_world() and applies fix_z().
--- @param map_id number UI map ID
--- @param map_pos table { x, y } normalized map coordinates (0-1)
--- @param extra_height number|nil Raycast start offset (default 4)
--- @return table|nil { x, y, z } world position or nil
function M.map_to_world_fixed(map_id, map_pos, extra_height)
    if not map_id or not map_pos then return nil end
    if not ensure_coords() then return nil end
    if not _coords.map_to_world then return nil end

    local ok, world_pos, err = pcall(_coords.map_to_world, _coords, map_id, map_pos, extra_height)
    if ok and world_pos and world_pos.x and world_pos.y then
        -- map_to_world already raycasts for Z, but double-check
        local fixed = M.fix_z(world_pos, extra_height)
        return fixed
    end

    -- Fallback to legacy izi/core conversion if coords_helper fails
    return nil
end

--- Fix Z on all positions in an array (in-place mutation of copies).
--- @param positions table[] Array of { x, y, z }
--- @return table[] Array with fixed Z values
function M.fix_positions(positions)
    if not positions or #positions == 0 then return positions end
    local result = {}
    for i = 1, #positions do
        result[i] = M.fix_z(positions[i])
    end
    return result
end

-- ============================================================================
-- Exports
-- ============================================================================

_G.EaxAutoQuester = _G.EaxAutoQuester or {}
_G.EaxAutoQuester.waypoint_fixer = M

return M
