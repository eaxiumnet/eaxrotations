-- What: Shared utilities for EaxAutoQuester
-- When: Required by submodules for common operations
-- Why: Centralize distance calc, rate limiting, logging — avoid duplication
-- Safety: All functions nil-guarded; static table reuse for hot paths; no math.sqrt()
-- Decision: Standalone module (not EaxRotations), caches core API at load

-- Hot-path API caching at module load (Pattern 2 from AGENTS.md)
local _core_time = core.time
local _core_log = core.log

-- Static table reuse for throttle iteration (Pattern 4 from AGENTS.md)
local _t = { n = 0 }

-- Throttle state: name -> last_time
local _throttles = {}

-- ============================================================================
-- Squared Distance (Pattern 3 from AGENTS.md)
-- Uses dx*dx + dy*dy NOT math.sqrt()
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
-- Vec3 Helpers
-- ============================================================================

--- Format a vec3 as a human-readable string.
--- @param v table|nil Point with fields x, y, z
--- @return string "(x, y, z)" or "(0, 0, 0)" if nil
local function vec3_to_string(v)
    if not v then return "(0, 0, 0)" end
    local x = tostring(v.x or 0)
    local y = tostring(v.y or 0)
    local z = tostring(v.z or 0)
    return "(" .. x .. ", " .. y .. ", " .. z .. ")"
end

-- ============================================================================
-- Throttle (Rate Limiter)
-- ============================================================================

--- Check if a named action is allowed this frame (once per interval).
--- @param name string Unique identifier for this throttled action
--- @param interval number Minimum seconds between allowed calls
--- @return boolean true if the action should execute, false if throttled
local function throttle(name, interval)
    if not name then return false end
    local now = _core_time()
    local last = _throttles[name]
    if not last or (now - last) >= (interval or 0) then
        _throttles[name] = now
        return true
    end
    return false
end

-- ============================================================================
-- Logging
-- ============================================================================

--- Log an info message with EaxAutoQuester prefix.
--- @param msg string Message to log
local function log(msg)
    if msg then
        _core_log("[EaxAutoQuester] " .. tostring(msg))
    end
end

--- Log a debug message — no-op if debug flag is false.
--- @param msg string Message to log
--- @param debug_flag boolean|nil Enable debug output (default: false)
local function debug_log(msg, debug_flag)
    if not debug_flag then return end
    if msg then
        _core_log("[EaxAutoQuester-DEBUG] " .. tostring(msg))
    end
end

-- ============================================================================
-- Module Table
-- ============================================================================

local M = {
    squared_distance = squared_distance,
    vec3_to_string = vec3_to_string,
    throttle = throttle,
    log = log,
    debug_log = debug_log,
}

-- Expose globally for cross-module access without re-require
_G.EaxAutoQuester = _G.EaxAutoQuester or {}
_G.EaxAutoQuester.utils = M

return M
