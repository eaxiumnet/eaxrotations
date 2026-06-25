-- What: Shared object scanner cache — single get_visible_objects() call per tick
-- When: Called by npc_manager, combat_helper, quest_state, questie_reader each tick
-- Why: Eliminates duplicate object scans per frame (~5 → 1), reducing CPU overhead
-- Safety: Cache invalidated at start of every tick; TTL of 1 frame; nil-guarded API
-- Decision: Centralized cache (not per-module), follows AGENTS.md Pattern 2 and 4

-- ============================================================================
-- API Caching at Module Load (Pattern 2 from AGENTS.md)
-- ============================================================================

local _get_visible_objects = core.object_manager.get_visible_objects
local _get_local_player = core.object_manager.get_local_player
local _core_time = core.time

-- ============================================================================
-- Static Table Reuse (Pattern 4 from AGENTS.md)
-- ============================================================================

local _scan_result = { n = 0 }
local _cache = {
    objects = nil,
    player = nil,
    player_pos = nil,
    timestamp = 0,
    valid = false,
}

-- ============================================================================
-- Internal Helpers
-- ============================================================================

--- Get player position with nil-guard.
--- @return table|nil { x, y, z }
local function get_player_pos()
    local me = _get_local_player()
    if not me then return nil end
    local ok, pos = pcall(function() return me:get_position() end)
    if ok and pos then return pos end
    return nil
end

-- ============================================================================
-- Module Table (declared first to avoid forward reference)
-- ============================================================================

local M = {}

-- ============================================================================
-- Cache Management
-- ============================================================================

--- Invalidate the cache at the start of each tick.
function M.invalidate()
    _cache.valid = false
    _cache.objects = nil
    _cache.player = nil
    _cache.player_pos = nil
end

--- Refresh the cache if invalid. Called lazily by scan functions.
local function ensure_cache()
    if _cache.valid then return end

    local ok, objects = pcall(_get_visible_objects)
    if ok and objects then
        _cache.objects = objects
    else
        _cache.objects = {}
    end

    _cache.player = _get_local_player()
    _cache.player_pos = get_player_pos()
    _cache.timestamp = _core_time()
    _cache.valid = true
end

-- ============================================================================
-- Public API
-- ============================================================================

--- Get all visible objects (cached).
--- @return table[] Array of visible objects
function M.get_visible_objects()
    ensure_cache()
    return _cache.objects or {}
end

--- Get the local player object (cached).
--- @return game_object|nil
function M.get_local_player()
    ensure_cache()
    return _cache.player
end

--- Get the local player position (cached).
--- @return table|nil { x, y, z }
function M.get_player_pos()
    ensure_cache()
    return _cache.player_pos
end

--- Scan for objects matching a filter function.
--- @param filter_fn function|nil function(object) -> boolean; if nil, returns all
--- @param max_count number|nil Maximum results to return (default: 50)
--- @return table[] Array of matching objects
function M.scan(filter_fn, max_count)
    ensure_cache()
    local objects = _cache.objects or {}
    local limit = max_count or 50

    _scan_result.n = 0
    for i = 1, #objects do
        local obj = objects[i]
        if not obj then break end
        if not filter_fn then
            _scan_result.n = _scan_result.n + 1
            _scan_result[_scan_result.n] = obj
        else
            local ok, match = pcall(filter_fn, obj)
            if ok and match then
                _scan_result.n = _scan_result.n + 1
                _scan_result[_scan_result.n] = obj
            end
        end
        if _scan_result.n >= limit then break end
    end

    if _scan_result.n == 0 then return {} end

    local result = {}
    for i = 1, _scan_result.n do
        result[i] = _scan_result[i]
    end
    return result
end

--- Find the nearest object matching a filter.
--- @param filter_fn function function(object) -> boolean
--- @param range number|nil Max range in yards (squared distance used internally)
--- @return game_object|nil Closest match, or nil
function M.find_nearest(filter_fn, range)
    ensure_cache()
    local objects = _cache.objects or {}
    local player_pos = _cache.player_pos
    if not player_pos then return nil end

    local range_sq = (range or 50) * (range or 50)
    local best = nil
    local best_dist_sq = range_sq

    for i = 1, #objects do
        local obj = objects[i]
        if not obj then break end

        local ok, match = pcall(filter_fn, obj)
        if ok and match then
            local pos_ok, pos = pcall(function() return obj:get_position() end)
            if pos_ok and pos then
                local dx = (pos.x or 0) - (player_pos.x or 0)
                local dy = (pos.y or 0) - (player_pos.y or 0)
                local dist_sq = dx * dx + dy * dy
                if dist_sq < best_dist_sq then
                    best_dist_sq = dist_sq
                    best = obj
                end
            end
        end
    end

    return best
end

--- Count objects matching a filter.
--- @param filter_fn function|nil function(object) -> boolean
--- @return number Count of matching objects
function M.count(filter_fn)
    ensure_cache()
    local objects = _cache.objects or {}
    if not filter_fn then return #objects end

    local count = 0
    for i = 1, #objects do
        local obj = objects[i]
        if not obj then break end
        local ok, match = pcall(filter_fn, obj)
        if ok and match then
            count = count + 1
        end
    end
    return count
end

-- ============================================================================
-- Exports
-- ============================================================================

_G.EaxAutoQuester = _G.EaxAutoQuester or {}
_G.EaxAutoQuester.object_scanner = M

return M
