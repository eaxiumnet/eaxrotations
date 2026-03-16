-- =============================================================================
-- Utils/Menu Module - Menu and config helpers
-- =============================================================================

local M = {}

--- Set a menu value with source tracking
-- @param item table menu item with set_state method
-- @param val boolean
-- @param source string source of the change
function M.set_menu_val(item, val, source)
    if item and item.set_state then
        item:set_state(val)
    end
end

--- Check if a config menu item is enabled
-- @param menu_item table?
-- @param default boolean default if nil
-- @return boolean
function M.is_enabled(menu_item, default)
    if not menu_item then
        return default
    end
    if type(menu_item.get_state) == "function" then
        return menu_item:get_state()
    end
    if type(menu_item.get) == "function" then
        return menu_item:get()
    end
    return default
end

--- Get a config value with default
-- @param menu_item table?
-- @param default any default if nil or invalid
-- @return any
function M.get_config_value(menu_item, default)
    if not menu_item then
        return default
    end
    if type(menu_item.get) == "function" then
        local val = menu_item:get()
        if val ~= nil then
            return val
        end
    end
    return default
end

return M
