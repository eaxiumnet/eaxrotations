-- What: Navigation module for EaxAutoQuester — SentinelNavClient with simple_movement fallback
-- When: Used by quest_state to move player to quest objectives
-- Why: Centralize movement logic with robust error handling and fallback
-- Safety: Lazy-init Sentinel; nil-guarded via pcall; 3s stuck timeout; no math.sqrt()
-- Decision: Standalone module (not EaxRotations), caches core API at load

-- Hot-path API caching at module load (Pattern 2 from AGENTS.md)
local _core_time = core.time
local _core_log = core.log
local _get_local_player = core.object_manager.get_local_player

-- Static table reuse (Pattern 4 from AGENTS.md)
local _t = { n = 0 }

-- ============================================================================
-- Module Table (defined first, exported at end)
-- ============================================================================
local M = {}

-- ============================================================================
-- State — nil-guarded defaults
-- ============================================================================

local _state = "IDLE"
local _client = nil           -- SentinelNavClient instance (lazy-init on first navigate_to)
local _destination = nil       -- vec3 target position
local _arrived_cb = nil        -- callback function on arrive/fail
local _stuck_timer = 0         -- seconds since last meaningful position change
local _last_position = nil     -- last recorded vec3 for stuck detection
local _last_pos_time = 0       -- core.time when last_position was captured
local _is_fallback = false     -- true when using simple_movement instead of Sentinel
local _fallback_mover = nil    -- simple_movement module reference (lazy-init)
local _nav_tolerance_sq = 9    -- 3 yards squared default arrival tolerance

local ARRIVAL_TOLERANCE_SQ = 9         -- 3 yards squared
local STUCK_TIMEOUT = 3.0               -- seconds before declaring stuck
local STUCK_MOVEMENT_THRESHOLD_SQ = 1.0 -- min squared movement to reset stuck timer

-- ============================================================================
-- Helpers
-- ============================================================================

--- Squared 2D distance — no math.sqrt() (Pattern 3 from AGENTS.md)
--- @param a table|nil Point with x, y
--- @param b table|nil Point with x, y
--- @return number
local function sq_distance(a, b)
    if not a or not b then return 0 end
    local dx = (a.x or 0) - (b.x or 0)
    local dy = (a.y or 0) - (b.y or 0)
    return dx * dx + dy * dy
end

-- ============================================================================
-- Internal: Fire callback with nil-guard
-- ============================================================================

--- @param success boolean
--- @param reason string|nil
local function fire_callback(success, reason)
    if not _arrived_cb then return end
    local cb = _arrived_cb
    _arrived_cb = nil
    local ok, err = pcall(cb, success, reason)
    if not ok and err then
        _core_log("[EaxAutoQuester] Navigation callback error: " .. tostring(err))
    end
end

-- ============================================================================
-- Internal: Stop movement (both Sentinel and fallback)
-- ============================================================================

local function stop_internal()
    if _client and not _is_fallback then
        pcall(function() _client:stop() end)
    elseif _fallback_mover then
        pcall(function() _fallback_mover.stop() end)
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

local function on_sentinel_failed(reason)
    if _state ~= "NAVIGATING" then return end
    _state = "FAILED"
    stop_internal()
    fire_callback(false, reason or "failed")
end

local function on_sentinel_stuck()
    if _state ~= "NAVIGATING" then return end
    _state = "STUCK"
    stop_internal()
    fire_callback(false, "stuck")
end

-- ============================================================================
-- Internal: Lazy-init SentinelNavClient
-- Returns boolean — true if Sentinel is ready
-- ============================================================================

local function init_sentinel()
    if _client then return true end

    local sentinel_ok, sentinel_ns = pcall(function() return _G.SentinelNavClient end)
    if not sentinel_ok or not sentinel_ns then
        return false
    end

    local client_ok, client = pcall(function() return sentinel_ns.client end)
    if not client_ok or not client then
        return false
    end

    _client = client

    local reg_ok = pcall(function()
        _client:on("arrived", on_sentinel_arrived)
        _client:on("failed", on_sentinel_failed)
        _client:on("stuck", on_sentinel_stuck)
    end)
    if not reg_ok then
        _client = nil
        return false
    end

    _core_log("[EaxAutoQuester] SentinelNavClient initialized")
    return true
end

-- ============================================================================
-- Internal: Lazy-init simple_movement fallback
-- Returns boolean — true if fallback is ready
-- ============================================================================

local function init_fallback()
    if _fallback_mover then return true end

    local ok, mover = pcall(require, "common/utility/simple_movement")
    if not ok or not mover then
        return false
    end

    _fallback_mover = mover
    _core_log("[EaxAutoQuester] Navigation fallback: simple_movement initialized")
    return true
end

-- ============================================================================
-- Public API
-- ============================================================================

--- Navigate to a target position.
--- Uses SentinelNavClient if available, otherwise falls back to simple_movement.
--- @param destination table Required — vec3 with fields x, y, z
--- @param callback function|nil Called on arrival/failure: fn(success: bool, reason?: string)
function M.navigate_to(destination, callback)
    if not destination then
        _core_log("[EaxAutoQuester] navigate_to called with nil destination")
        if callback then
            pcall(callback, false, "no_destination")
        end
        return
    end

    -- Stop any active navigation before starting a new one
    if _state == "NAVIGATING" then
        stop_internal()
    end

    _destination = destination
    _arrived_cb = callback
    _stuck_timer = 0
    _last_position = nil
    _last_pos_time = 0

    -- Try SentinelNavClient first (lazy-init)
    if not _is_fallback and init_sentinel() then
        _is_fallback = false
        _state = "NAVIGATING"

        local ok, err = pcall(function() _client:move_to(destination) end)
        if not ok then
            _state = "FAILED"
            _destination = nil
            _arrived_cb = nil
            _core_log("[EaxAutoQuester] SentinelNavClient move_to error: " .. tostring(err))
            if callback then
                pcall(callback, false, tostring(err))
            end
        end
        return
    end

    -- Fallback to simple_movement
    if init_fallback() then
        _is_fallback = true
        _state = "NAVIGATING"

        local ok, err = pcall(function() _fallback_mover:move_to_position(destination) end)
        if not ok then
            _state = "FAILED"
            _destination = nil
            _arrived_cb = nil
            _core_log("[EaxAutoQuester] simple_movement move_to_position error: " .. tostring(err))
            if callback then
                pcall(callback, false, tostring(err))
            end
        end
        return
    end

    -- Neither navigator available
    _state = "FAILED"
    _destination = nil
    _arrived_cb = nil
    _core_log("[EaxAutoQuester] No navigation system available")
    if callback then
        pcall(callback, false, "no_navigation_available")
    end
end

--- Cancel active navigation.
--- Fires callback with success=false, reason="cancelled" if navigating.
function M.stop()
    local was_navigating = (_state == "NAVIGATING")
    _state = "IDLE"
    stop_internal()
    if was_navigating then
        fire_callback(false, "cancelled")
    end
end

--- Check whether the module is currently navigating.
--- @return boolean
function M.is_navigating()
    return _state == "NAVIGATING"
end

--- Get current navigation state string.
--- @return string One of: "IDLE", "NAVIGATING", "ARRIVED", "FAILED", "STUCK"
function M.get_state()
    return _state
end

--- Per-frame update — call from on_pre_tick.
--- Handles stuck detection (3s timeout) and simple_movement processing.
function M.update()
    if _state ~= "NAVIGATING" then return end
    if not _destination then
        M.stop()
        return
    end

    if _is_fallback and _fallback_mover then
        -- Process fallback movement each frame
        pcall(function() _fallback_mover:process() end)

        -- Check arrival by distance (simple_movement has no event system)
        local me = _get_local_player()
        if me then
            local pos_ok, pos = pcall(function() return me:get_position() end)
            if not pos_ok or not pos then return end
            local dist_sq = sq_distance(pos, _destination)
            if dist_sq <= _nav_tolerance_sq then
                _state = "ARRIVED"
                stop_internal()
                fire_callback(true)
                return
            end
        end

        -- Check if movement stopped unexpectedly
        local moving_ok, is_moving = pcall(function() return _fallback_mover:is_moving() end)
        if moving_ok and not is_moving then
            _state = "FAILED"
            stop_internal()
            fire_callback(false, "movement_stopped")
            return
        end
    end

    -- Stuck detection (both Sentinel and fallback)
    local now = _core_time()
    local me = _get_local_player()
    if not me then return end

    -- Get player position via :get_position() (game_object has no .x/.y — must use API)
    local me_pos_ok, me_pos = pcall(function() return me:get_position() end)
    if not me_pos_ok or not me_pos then return end

    if not _last_position then
        _last_position = { x = me_pos.x, y = me_pos.y, z = me_pos.z }
        _last_pos_time = now
        return
    end

    -- Check if player moved since last check
    local dx = (me_pos.x or 0) - (_last_position.x or 0)
    local dy = (me_pos.y or 0) - (_last_position.y or 0)
    local moved_sq = dx * dx + dy * dy

    if moved_sq > STUCK_MOVEMENT_THRESHOLD_SQ then
        -- Player moved: update last position, reset stuck timer
        _last_position = { x = me_pos.x, y = me_pos.y, z = me_pos.z }
        _last_pos_time = now
        _stuck_timer = 0
    else
        -- No meaningful movement: accumulate stuck time
        if _last_pos_time > 0 then
            _stuck_timer = _stuck_timer + (now - _last_pos_time)
        end
        _last_pos_time = now

        if _stuck_timer >= STUCK_TIMEOUT then
            _core_log("[EaxAutoQuester] Stuck timeout (3s) — stopping navigation")
            _state = "STUCK"
            stop_internal()
            fire_callback(false, "stuck_timeout")
        end
    end
end

-- ============================================================================
-- Visual Rendering — draw destination marker in 3D world
-- ============================================================================

--- Render navigation visual indicators (destination marker + path line).
--- Called from quest_state's render_debug each frame when navigating.
function M.render_visual()
    if not _destination then return end

    -- Lazy-init color module
    local color_ok, color = pcall(require, "common/color")
    if not color_ok then return end

    local me = _get_local_player()
    if not me then return end
    local pos_ok, pos = pcall(function() return me:get_position() end)
    if not pos_ok or not pos then return end

    -- Destination fill circle (semi-transparent green)
    core.graphics.circle_3d_filled(
        _destination,
        3.0,
        color.green(60)
    )

    -- Destination outline (bright green)
    core.graphics.circle_3d(
        _destination,
        3.0,
        color.green(200),
        2.0,
        0.3
    )

    -- Inner pulse circle (slightly smaller, brighter)
    core.graphics.circle_3d(
        _destination,
        2.0,
        color.green(255),
        1.5,
        0.5
    )

    -- Path line from player to destination (thin green)
    core.graphics.line_3d(
        pos,
        _destination,
        color.green(150),
        1.0,
        0.5,
        false
    )
end

-- ============================================================================
-- Exports
-- ============================================================================

_G.EaxAutoQuester = _G.EaxAutoQuester or {}
_G.EaxAutoQuester.navigation = M

return M
