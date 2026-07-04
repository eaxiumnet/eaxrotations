-- =============================================================================
-- Common/Color Module - Simple RGBA color object
-- Version: 1.5.0
-- =============================================================================

local M = {}

--- Create a new color object
-- @param r number red (0-255)
-- @param g number green (0-255)
-- @param b number blue (0-255)
-- @param a number alpha (0-255)
-- @return table color object with r, g, b, a fields
function M.new(r, g, b, a)
    return {
        r = r or 255,
        g = g or 255,
        b = b or 255,
        a = a or 255
    }
end

return M
