-- =============================================================================
-- Utils/Log Module - Debug logging utilities
-- =============================================================================

local M = {}

local debug_enabled = false

--- Enable or disable debug logging
-- @param enabled boolean
function M.set_debug(enabled)
    debug_enabled = enabled
end

--- Check if debug is enabled
-- @return boolean
function M.is_debug_enabled()
    return debug_enabled
end

--- Log a debug message
-- @param msg string
-- @param deps table? (optional) context deps for izi
function M.log_debug(msg, deps)
    if not debug_enabled then
        return
    end
    
    local izi = deps and deps.izi
    if izi and izi.print then
        pcall(izi.print, "[EaxFishing] " .. msg)
    end
end

--- Safely set a menu item value
-- Handles both set_state and set methods
-- @param menu_item table the menu item to set
-- @param value any the value to set
-- @param source string? optional source for debug logging
function M.set_menu_val(menu_item, value, source)
    if not menu_item then
        return
    end
    
    if source and debug_enabled then
        print("[EaxFishing] Setting menu item (" .. tostring(source) .. ") to " .. tostring(value))
    end
    
    if menu_item.set_state then
        menu_item:set_state(value)
    elseif menu_item.set then
        menu_item:set(value)
    end
end

return M
