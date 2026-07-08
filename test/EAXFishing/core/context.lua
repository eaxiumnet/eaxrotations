-- =============================================================================
-- Core Context Module - Dependency injection and context creation
-- Provides a single ctx object that all modules use
-- Uses APISurface for timestamp instead of raw izi
-- =============================================================================

local State = require("core/state")
local APISurface = require("core/api_surface")

local M = {}

-- Required dependencies that must be provided
local REQUIRED_DEPS = {
    "config",
    "constants",
    "control_panel_helper",
}

--- Validate that all required dependencies are provided
-- @param deps table dependency table
local function validate_deps(deps)
    assert(type(deps) == "table", "core/context.create expects a dependency table")
    
    for _, key in ipairs(REQUIRED_DEPS) do
        if deps[key] == nil then
            error("core/context.create missing dependency: " .. key, 2)
        end
    end
end

--- Create a new application context
-- @param deps table dependency injection table
-- @return table context with deps and state
function M.create(deps)
    validate_deps(deps)
    
    -- Use APISurface for timestamp instead of raw izi
    local now = APISurface.now()
    
    return {
        deps = deps,
        state = State.create(now),
    }
end

return M
