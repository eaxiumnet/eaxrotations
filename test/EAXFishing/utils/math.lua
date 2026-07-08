-- =============================================================================
-- Utils/Math Module - Pure math utilities
-- =============================================================================

local M = {}

--- Clamp a value between min and max
-- @param value number
-- @param min_value number
-- @param max_value number
-- @return number
function M.clamp(value, min_value, max_value)
    return math.max(min_value, math.min(max_value, value))
end

--- Generate random float between min and max seconds
-- @param min_seconds number
-- @param max_seconds number
-- @return number
function M.random_seconds(min_seconds, max_seconds)
    return math.random() * (max_seconds - min_seconds) + min_seconds
end

--- Get ordered ms range from config items
-- @param min_item table? config item with get() method
-- @param max_item table? config item with get() method
-- @param default_min_ms number
-- @param default_max_ms number
-- @return number min_ms, number max_ms
function M.get_ordered_ms_range(min_item, max_item, default_min_ms, default_max_ms)
    local min_ms = default_min_ms
    local max_ms = default_max_ms

    if min_item and min_item.get then
        min_ms = min_item:get()
    end
    if max_item and max_item.get then
        max_ms = max_item:get()
    end

    if type(min_ms) ~= "number" then
        min_ms = default_min_ms
    end
    if type(max_ms) ~= "number" then
        max_ms = default_max_ms
    end

    -- Enforce ordering: if the user set min > max (easy with sliders),
    -- math.random(min, max) would crash. Swap silently.
    if min_ms > max_ms then
        min_ms, max_ms = max_ms, min_ms
    end

    -- Ensure at least 1ms range so math.random never gets equal values
    -- when the engine needs a non-zero wait.
    if max_ms <= min_ms then
        max_ms = min_ms + 1
    end

    return min_ms, max_ms
end

--- Round a value to a specific step
-- @param value number
-- @param step number
-- @return number
function M.round_to_step(value, step)
    return math.floor((value / step) + 0.5) * step
end

--- Calculate distance squared between two positions
-- @param x1 number
-- @param y1 number
-- @param z1 number
-- @param x2 number
-- @param y2 number
-- @param z2 number
-- @return number distance squared
function M.distance_sq(x1, y1, z1, x2, y2, z2)
    local dx = x1 - x2
    local dy = y1 - y2
    local dz = z1 - z2
    return dx * dx + dy * dy + dz * dz
end

--- Calculate 2D distance squared
-- @param x1 number
-- @param y1 number
-- @param x2 number
-- @param y2 number
-- @return number distance squared
function M.distance_sq_2d(x1, y1, x2, y2)
    local dx = x1 - x2
    local dy = y1 - y2
    return dx * dx + dy * dy
end

return M
