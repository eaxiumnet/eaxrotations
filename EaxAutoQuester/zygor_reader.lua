-- What: Zygor guide reader — quest step info, waypoints, objectives from Zygor Guides
-- When: Polled by quest_state.lua each tick when Zygor is active and guide loaded
-- Why: Centralize Zygor data access with nil-guards; convert map coords to world coords
-- Safety: All core.addons.zygor.* calls nil-guarded via pcall; returns nil if Zygor not loaded
-- Decision: Uses core.addons.zygor.* API per core.lua docs; izi.map_to_world() for map→world conv

-- ============================================================================
-- Hot-path API Caching at Module Load (Pattern 2 from AGENTS.md)
-- ============================================================================

local _is_loaded      = core.addons.zygor.is_loaded
local _has_step       = core.addons.zygor.has_current_step
local _get_step       = core.addons.zygor.get_current_step
local _get_stickies   = core.addons.zygor.get_current_stickies
local _get_objectives = core.addons.zygor.get_objectives
local _get_wp         = core.addons.zygor.get_current_waypoint
local _get_step_wps   = core.addons.zygor.get_step_waypoints

-- Attempt to load izi SDK for map_to_world coordinate conversion — optional
local _izi_map_to_world = nil
local _ok, _izi = pcall(require, "common/izi_sdk")
if _ok and _izi and _izi.map_to_world then
    _izi_map_to_world = _izi.map_to_world
end

-- ============================================================================
-- Static Table Reuse (Pattern 4 from AGENTS.md)
-- ============================================================================

local _stack = { n = 0 }

-- ============================================================================
-- Helpers
-- ============================================================================

--- Check if Zygor addon is loaded (nil-guarded).
--- @return boolean true if Zygor is loaded
local function zygor_loaded()
    local ok, loaded = pcall(_is_loaded)
    return ok and loaded == true
end

--- Nil-guarded step fetch.
--- @return table|nil zygor_step_info or nil on failure
local function safe_get_step()
    if not zygor_loaded() then return nil end
    local ok, step = pcall(_get_step)
    if not ok or not step then return nil end
    return step
end

-- ============================================================================
-- Public API
-- ============================================================================

--- Get current step info: number, completion, goals.
--- @return table|nil { step_num, is_complete, goals[] } or nil if no step
function M_get_current_step_info()
    local step = safe_get_step()
    if not step then return nil end

    return {
        step_num    = step.num or 0,
        is_complete = step.is_complete or false,
        goals       = step.goals or {},
    }
end

--- Get current waypoint converted to world coordinates (vec3).
--- Converts Zygor map coordinates (map_id, x, y) via izi.map_to_world().
--- @return table|nil vec3 { x, y, z } or nil if no waypoint / conversion fails
function M_get_current_waypoint_world()
    if not zygor_loaded() then return nil end

    local ok, wp = pcall(_get_wp)
    if not ok or not wp then return nil end

    -- Need izi SDK and valid map coords
    if not _izi_map_to_world then return nil end
    if not wp.map_id or not wp.x or not wp.y then return nil end

    local wok, wpos = pcall(_izi_map_to_world, wp.map_id, wp.x, wp.y)
    if not wok or not wpos then return nil end

    return wpos
end

--- Get all waypoints for current step converted to world coordinates.
--- @return table[]|nil Array of vec3 { x, y, z } or nil if none
function M_get_step_waypoints_world()
    if not zygor_loaded() then return nil end
    if not _izi_map_to_world then return nil end

    local ok, waypoints = pcall(_get_step_wps)
    if not ok or not waypoints or #waypoints == 0 then return nil end

    _stack.n = 0
    for i = 1, #waypoints do
        local wp = waypoints[i]
        if wp and wp.map_id and wp.x and wp.y then
            local wok, wpos = pcall(_izi_map_to_world, wp.map_id, wp.x, wp.y)
            if wok and wpos then
                _stack.n = _stack.n + 1
                _stack[_stack.n] = wpos
            end
        end
    end

    if _stack.n == 0 then return nil end

    local result = {}
    for i = 1, _stack.n do
        result[i] = _stack[i]
    end
    return result
end

--- Get the raw current waypoint info table.
--- @return table|nil zygor_waypoint_info or nil if no waypoint
function M_get_current_waypoint_raw()
    if not zygor_loaded() then return nil end

    local ok, wp = pcall(_get_wp)
    if not ok or not wp then return nil end

    return {
        map_id    = wp.map_id,
        x         = wp.x,
        y         = wp.y,
        dist      = wp.dist,
        title     = wp.title,
        type      = wp.type,
        goal_num  = wp.goal_num,
        is_manual = wp.is_manual,
    }
end

--- Get current objectives as a clean array of IDs (numbers or strings).
--- @return (number|string)[]|nil Array of objective values or nil if none
function M_get_current_objectives()
    if not zygor_loaded() then return nil end

    local ok, objectives = pcall(_get_objectives)
    if not ok or not objectives or #objectives == 0 then return nil end

    _stack.n = 0
    for i = 1, #objectives do
        local v = objectives[i]
        if v ~= nil then
            _stack.n = _stack.n + 1
            _stack[_stack.n] = v
        end
    end

    if _stack.n == 0 then return nil end

    local result = {}
    for i = 1, _stack.n do
        result[i] = _stack[i]
    end
    return result
end

--- Get sticky step goals (persistent goals that follow across steps).
--- @return table[]|nil Array of { step_num, is_complete, goals[] } or nil if none
function M_get_sticky_goals()
    if not zygor_loaded() then return nil end

    local ok, stickies = pcall(_get_stickies)
    if not ok or not stickies or #stickies == 0 then return nil end

    local result = {}
    local count = 0

    for i = 1, #stickies do
        local s = stickies[i]
        if s then
            count = count + 1
            result[count] = {
                step_num    = s.num or 0,
                is_complete = s.is_complete or false,
                goals       = s.goals or {},
            }
        end
    end

    if count == 0 then return nil end
    return result
end

--- Check if Zygor has an active current step.
--- @return boolean true if active step exists
function M_has_current_step()
    if not zygor_loaded() then return false end

    local ok, has = pcall(_has_step)
    if not ok then return false end

    return has == true
end

--- Check if Zygor addon itself is loaded.
--- @return boolean
function M_is_loaded()
    return zygor_loaded()
end

-- ============================================================================
-- Exports
-- ============================================================================

local M = {
    get_current_step_info       = M_get_current_step_info,
    get_current_waypoint_world  = M_get_current_waypoint_world,
    get_step_waypoints_world    = M_get_step_waypoints_world,
    get_current_waypoint_raw    = M_get_current_waypoint_raw,
    get_current_objectives      = M_get_current_objectives,
    get_sticky_goals            = M_get_sticky_goals,
    has_current_step            = M_has_current_step,
    is_loaded                   = M_is_loaded,
}

_G.EaxAutoQuester = _G.EaxAutoQuester or {}
_G.EaxAutoQuester.zygor_reader = M

return M
