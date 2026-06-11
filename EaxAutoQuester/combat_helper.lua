-- What: Non-rotation combat helper for EaxAutoQuester
-- When: Required by auto-questing logic to tag enemies for EaxRotations to kill
-- Why: Plugin-independent target acquisition — only sets target, never casts spells
-- Safety: No rotation API (no izi.spell); all functions nil-guarded via pcall
-- Decision: Standalone module (not EaxRotations), caches core API at load

-- Hot-path API caching at module load (Pattern 2 from AGENTS.md)
local _get_local_player = core.object_manager.get_local_player
local _get_visible_objects = core.object_manager.get_visible_objects
local _set_target = core.input.set_target
local _use_item_target = core.input.use_item_target

-- Static table reuse for enemy scan (Pattern 4 from AGENTS.md)
local _enemies = { n = 0 }

-- ============================================================================
-- Squared Distance — local copy avoids cross-module dep (Pattern 3)
-- ============================================================================

--- Compute squared 3D distance between two vec3 points.
--- @param a table|nil Point A with fields x, y, z
--- @param b table|nil Point B with fields x, y, z
--- @return number Squared distance (0 if either point is nil)
local function squared_distance(a, b)
    if not a or not b then return 0 end
    local dx = (a.x or 0) - (b.x or 0)
    local dy = (a.y or 0) - (b.y or 0)
    local dz = (a.z or 0) - (b.z or 0)
    return dx * dx + dy * dy + dz * dz
end

-- ============================================================================
-- Target Acquisition
-- ============================================================================

--- Find and target the nearest enemy within range.
--- Returns true if a target was set, false otherwise.
--- Scan capped at 50 objects. Uses squared distance (no math.sqrt).
--- @param range number Maximum distance in yards
--- @return boolean target_set
local function target_and_tag_nearest(range)
    local me = _get_local_player()
    if not me then return false end

    local range_sq = (range or 10) * (range or 10)
    local me_pos = me.get_position and me:get_position()
    if not me_pos then return false end

    local objects = _get_visible_objects()
    if not objects then return false end

    -- Reuse static table for enemy list
    _enemies.n = 0

    local count = 0
    for _, obj in ipairs(objects) do
        count = count + 1
        if count > 50 then break end

        -- Must be a unit, not dead, not the player
        if obj and obj.is_unit and obj:is_unit() then
            if not obj.is_dead or not obj:is_dead() then
                if obj.is_enemy_with and obj:is_enemy_with(me) then
                    _enemies.n = _enemies.n + 1
                    _enemies[_enemies.n] = obj
                end
            end
        end
    end

    -- Find nearest valid enemy
    local nearest = nil
    local nearest_sq = range_sq

    for i = 1, _enemies.n do
        local obj = _enemies[i]
        local pos = obj.get_position and obj:get_position()
        if pos then
            local dist_sq = squared_distance(me_pos, pos)
            if dist_sq < nearest_sq then
                nearest = obj
                nearest_sq = dist_sq
            end
        end
    end

    if not nearest then return false end

    -- Set as target
    local ok, result = pcall(_set_target, nearest)
    if not ok then return false end
    return result == true
end

-- ============================================================================
-- Target Validity
-- ============================================================================

--- Check if the current target is valid for combat (alive, enemy, in range).
--- Health percentage computed from raw values (no API call for hp_pct).
--- @param range number|nil Maximum distance in yards (default: 30)
--- @return boolean is_valid
local function is_current_target_valid(range)
    local me = _get_local_player()
    if not me then return false end

    local target = me.get_target and me:get_target()
    if not target then return false end

    -- Must be alive (not dead)
    if target.is_dead and target:is_dead() then return false end

    -- Must be an enemy
    if not target.is_enemy_with or not target:is_enemy_with(me) then return false end

    -- Must be in range (optional check)
    if range and range > 0 then
        local me_pos = me.get_position and me:get_position()
        local t_pos = target.get_position and target:get_position()
        if me_pos and t_pos then
            local range_sq = range * range
            if squared_distance(me_pos, t_pos) > range_sq then return false end
        end
    end

    return true
end

-- ============================================================================
-- Quest Item Usage
-- ============================================================================

--- Use a quest item on the current target.
--- Returns true if the item was used, false otherwise.
--- @param item_id number The item ID to use
--- @return boolean used
local function use_quest_item_on_target(item_id)
    if not item_id then return false end

    local me = _get_local_player()
    if not me then return false end

    local target = me.get_target and me:get_target()
    if not target then return false end

    -- Must be alive (can't use item on corpse)
    if target.is_dead and target:is_dead() then return false end

    -- Use item on target
    local ok, result = pcall(_use_item_target, item_id, target)
    if not ok then return false end
    return result == true
end

-- ============================================================================
-- Module Table
-- ============================================================================

local M = {
    target_and_tag_nearest = target_and_tag_nearest,
    is_current_target_valid = is_current_target_valid,
    use_quest_item_on_target = use_quest_item_on_target,
}

-- Expose globally for cross-module access without re-require
_G.EaxAutoQuester = _G.EaxAutoQuester or {}
_G.EaxAutoQuester.combat_helper = M

return M
