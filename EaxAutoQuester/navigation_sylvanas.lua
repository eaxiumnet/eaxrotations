-- What: Navigation for EaxAutoQuester — SentinelNavClient + simple_movement fallback
-- When: Used by quest_state to move player to Zygor waypoints
-- Why: SentinelNavClient provides navmesh pathfinding, multi-waypoint routes
--      via follow_path, TSP route planning via plan_route, stuck recovery
-- Safety: Lazy-init Sentinel; nil-guarded via pcall; fallback to simple_movement
-- Decision: SentinelNavClient is primary; simple_movement is last resort

-- API caching at module load (Pattern 2)
local _core_time = core.time
local _core_log = core.log
local _get_local_player = core.object_manager.get_local_player

-- Module table
local M = {}

-- State
local _state = "IDLE"
local _client = nil               -- SentinelNavClient.client singleton
local _destination = nil          -- final vec3 target
local _arrived_cb = nil           -- callback on arrive/fail
local _is_fallback = false        -- using simple_movement?
local _fallback_mover = nil
local _stuck_timer = 0
local _last_position = nil
local _last_pos_time = 0

local _nav_tolerance_sq = 9       -- 3 yards
local STUCK_TIMEOUT = 3.0
local STUCK_THRESHOLD_SQ = 1.0

-- Color (lazy)
local _color = nil
local function get_color()
    if not _color then
        local ok, c = pcall(require, "common/color")
        if ok then _color = c end
    end
    return _color
end

-- Squared 2D distance
local function sq_distance(a, b)
    if not a or not b then return 0 end
    local dx = (a.x or 0) - (b.x or 0)
    local dy = (a.y or 0) - (b.y or 0)
    return dx * dx + dy * dy
end

-- Fire callback nil-guarded
local function fire_callback(success, reason)
    if not _arrived_cb then return end
    local cb = _arrived_cb
    _arrived_cb = nil
    local ok, err = pcall(cb, success, reason)
    if not ok and err then
        _core_log("[EaxAutoQuester] Nav callback err: " .. tostring(err))
    end
end

-- Stop movement
local function stop_internal()
    if _client and not _is_fallback then
        pcall(function() _client:stop() end)
    elseif _fallback_mover then
        pcall(function() _fallback_mover:stop() end)
    end
    _destination = nil
    _stuck_timer = 0
    _last_position = nil
    _last_pos_time = 0
end

-- ============================================================================
-- Sentinel Event Handlers
-- ============================================================================

local function on_sentinel_arrived()
    if _state ~= "NAVIGATING" then return end
    _state = "ARRIVED"
    stop_internal()
    fire_callback(true)
end

local function on_sentinel_failed()
    if _state ~= "NAVIGATING" then return end
    _state = "FAILED"
    stop_internal()
    fire_callback(false, "sentinel_failed")
end

-- ============================================================================
-- Lazy-init SentinelNavClient
-- ============================================================================

local function init_sentinel()
    if _client then return true end

    local ok, ns = pcall(function() return _G.SentinelNavClient end)
    if not ok or not ns then return false end

    local c_ok, c = pcall(function() return ns.client end)
    if not c_ok or not c then return false end

    local reg_ok = pcall(function()
        c:on("arrived", on_sentinel_arrived)
        c:on("failed", on_sentinel_failed)
    end)
    if not reg_ok then return false end

    _client = c
    _core_log("[EaxAutoQuester] SentinelNavClient initialized")
    return true
end

-- ============================================================================
-- Lazy-init simple_movement fallback
-- ============================================================================

local function init_fallback()
    if _fallback_mover then return true end
    local ok, m = pcall(require, "common/utility/simple_movement")
    if not ok or not m then return false end
    _fallback_mover = m
    _core_log("[EaxAutoQuester] simple_movement fallback initialized")
    return true
end

-- ============================================================================
-- Public API
-- ============================================================================

--- Navigate to single destination via Sentinel:move_to().
function M.navigate_to(destination, callback)
    if not destination then
        if callback then pcall(callback, false, "no_destination") end
        return
    end
    if _state == "NAVIGATING" then stop_internal() end

    _destination = destination
    _arrived_cb = callback
    _stuck_timer = 0; _last_position = nil; _last_pos_time = 0

    if not _is_fallback and init_sentinel() then
        _is_fallback = false; _state = "NAVIGATING"
        local ok, err = pcall(function()
            _client:move_to(destination, function(success, reason)
                if _state == "NAVIGATING" then
                    _state = success and "ARRIVED" or "FAILED"
                    stop_internal(); fire_callback(success, reason)
                end
            end)
        end)
        if not ok then _state = "FAILED"; _destination = nil; _arrived_cb = nil
            if callback then pcall(callback, false, tostring(err)) end
        end
        return
    end

    if init_fallback() then
        _is_fallback = true; _state = "NAVIGATING"
        local ok, err = pcall(function() _fallback_mover:move_to_position(destination) end)
        if not ok then _state = "FAILED"; _destination = nil; _arrived_cb = nil
            if callback then pcall(callback, false, tostring(err)) end
        end
        return
    end

    _state = "FAILED"; _destination = nil; _arrived_cb = nil
    _core_log("[EaxAutoQuester] No navigation available")
    if callback then pcall(callback, false, "no_navigation") end
end

--- Follow multi-waypoint path via Sentinel:follow_path().
function M.follow_path(waypoints, callback)
    if not waypoints or #waypoints == 0 then
        if callback then pcall(callback, false, "no_waypoints") end
        return
    end
    if _state == "NAVIGATING" then stop_internal() end

    _destination = waypoints[#waypoints]
    _arrived_cb = callback
    _stuck_timer = 0; _last_position = nil; _last_pos_time = 0

    if init_sentinel() then
        _is_fallback = false; _state = "NAVIGATING"
        local ok, err = pcall(function()
            _client:follow_path(waypoints, function(success, reason)
                if _state == "NAVIGATING" then
                    _state = success and "ARRIVED" or "FAILED"
                    stop_internal(); fire_callback(success, reason)
                end
            end)
        end)
        if not ok then _state = "FAILED"; _destination = nil; _arrived_cb = nil
            if callback then pcall(callback, false, tostring(err)) end
        end
        return
    end

    _core_log("[EaxAutoQuester] Sentinel unavailable — single-wp fallback")
    M.navigate_to(waypoints[#waypoints], callback)
end

--- Plan TSP route + follow via Sentinel:plan_route() + follow_path().
function M.plan_route(nodes, callback)
    if not nodes or #nodes == 0 then
        if callback then pcall(callback, false, "no_nodes") end
        return
    end
    if not init_sentinel() then
        M.navigate_to(nodes[#nodes], callback); return end

    _client:plan_route(nodes, function(ok, data)
        if ok and data and data.waypoints then
            M.follow_path(data.waypoints, callback)
        else
            local err = (data and data.error) or "route_failed"
            _core_log("[EaxAutoQuester] Route plan failed: " .. tostring(err))
            M.navigate_to(nodes[#nodes], callback)
        end
    end, { return_to_start = false })
end

--- Cancel navigation.
function M.stop()
    local was_nav = (_state == "NAVIGATING")
    _state = "IDLE"; stop_internal()
    if was_nav then fire_callback(false, "cancelled") end
end

function M.is_navigating() return _state == "NAVIGATING" end
function M.get_state() return _state end
function M.get_nav_type() return _is_fallback and "simple" or (_client and "sentinel" or nil) end

--- Get Sentinel's current path for visualization.
function M.get_current_path()
    if not _client or _is_fallback then return nil end
    local ok, path = pcall(function() return _client:get_current_path() end)
    return (ok and path) or nil
end

--- Per-frame update — only for simple_movement fallback.
function M.update()
    if _state ~= "NAVIGATING" or not _destination then
        if _state == "NAVIGATING" then M.stop() end; return
    end
    if not _is_fallback or not _fallback_mover then return end

    pcall(function() _fallback_mover:process() end)
    local me = _get_local_player()
    if not me then return end
    local _, pos = pcall(function() return me:get_position() end)
    if not pos then return end

    if sq_distance(pos, _destination) <= _nav_tolerance_sq then
        _state = "ARRIVED"; stop_internal(); fire_callback(true); return
    end

    local mov_ok, moving = pcall(function() return _fallback_mover:is_moving() end)
    if mov_ok and not moving then
        _state = "FAILED"; stop_internal(); fire_callback(false, "stopped"); return
    end

    local now = _core_time()
    if not _last_position then
        _last_position = { x = pos.x, y = pos.y, z = pos.z }
        _last_pos_time = now; return
    end

    local dx = (pos.x or 0) - (_last_position.x or 0)
    local dy = (pos.y or 0) - (_last_position.y or 0)
    if dx * dx + dy * dy > STUCK_THRESHOLD_SQ then
        _last_position = { x = pos.x, y = pos.y, z = pos.z }
        _last_pos_time = now; _stuck_timer = 0
    else
        if _last_pos_time > 0 then _stuck_timer = _stuck_timer + (now - _last_pos_time) end
        _last_pos_time = now
        if _stuck_timer >= STUCK_TIMEOUT then
            _state = "STUCK"; stop_internal(); fire_callback(false, "stuck_timeout")
        end
    end
end

-- ============================================================================
-- Visual Rendering — Sentinel navmesh path + destination marker
-- ============================================================================

function M.render_visual()
    local c = get_color()
    if not c or not _destination then return end

    -- Draw Sentinel navmesh path (multi-step waypoints)
    if _client and not _is_fallback then
        local ok, path = pcall(function() return _client:get_current_path() end)
        if ok and path and #path > 0 then
            for i = 1, #path do
                if i % 6 == 1 or i == 1 or i == #path then
                    pcall(core.graphics.circle_3d, path[i], 0.5, c.cyan(180), 5, 1.5)
                end
                if i < #path then
                    pcall(core.graphics.line_3d, path[i], path[i + 1], c.cyan(70), 1.5, 1.0, false)
                end
            end
        end
    end

    -- Destination marker (green rings)
    pcall(core.graphics.circle_3d_filled, _destination, 3.0, c.green(60))
    pcall(core.graphics.circle_3d, _destination, 3.0, c.green(200), 2.0, 0.3)
    pcall(core.graphics.circle_3d, _destination, 2.0, c.green(255), 1.5, 0.5)

    -- Path line from player
    local me = _get_local_player()
    if me then
        local _, pos = pcall(function() return me:get_position() end)
        if pos then pcall(core.graphics.line_3d, pos, _destination, c.green(150), 1.0, 0.5, false) end
    end
end

-- Exports
_G.EaxAutoQuester = _G.EaxAutoQuester or {}
_G.EaxAutoQuester.navigation = M
return M
