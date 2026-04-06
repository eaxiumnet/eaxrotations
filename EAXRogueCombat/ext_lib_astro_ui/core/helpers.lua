-- ext_lib_astro_ui/helpers.lua
-- Shared utility functions used across all modules
-- Updated to use simple_ui library with core.menu fallback

---@type color
local color = require("common/color")

-- ============================================================================
-- SIMPLE_UI API COMPATIBILITY HELPERS
-- ============================================================================

-- Try to load simple_ui library
local simple_ui = nil
local ok_simple_ui, result = pcall(function()
    return require("common/simple_ui")
end)
if ok_simple_ui and result then
    simple_ui = result
end

-- Store for menu:new() created instances (will be set by menu.lua)
local _simple_ui_menu_instance = nil

---Set the simple_ui menu instance for component creation
---@param instance table
function set_simple_ui_menu_instance(instance)
    _simple_ui_menu_instance = instance
end

---Get the simple_ui menu instance
---@return table|nil
function get_simple_ui_menu_instance()
    return _simple_ui_menu_instance
end

-- ============================================================================
-- MENU API COMPATIBILITY HELPERS
-- ============================================================================

-- Wrapper for checkbox that provides both simple_ui and core.menu compatibility
local function menu_checkbox(default_value, id)
    -- Try simple_ui first
    if simple_ui and simple_ui.menu and _simple_ui_menu_instance then
        local comp = _simple_ui_menu_instance:add_checkbox(
            id or "Checkbox",
            nil, nil,
            default_value,
            nil,
            { tooltip = id }
        )
        if comp then
            -- Return wrapper matching core.menu API
            return {
                get = function() return comp:is_checked() end,
                get_state = function() return comp:is_checked() end,
                set = function(_, val) comp:set_value(val and true or false) end,
                _is_simple_ui = true,
                _component = comp,
            }
        end
    end

    -- Fallback to core.menu
    if core and core.menu and core.menu.checkbox then
        return core.menu.checkbox(default_value, id)
    end

    -- Return mock as last resort
    return {
        get = function() return default_value end,
        get_state = function() return default_value end,
        set = function() end,
        _is_mock = true,
    }
end

-- Wrapper for slider_int that provides both simple_ui and core.menu compatibility
local function menu_slider_int(min_value, max_value, default_value, id)
    -- Try simple_ui first
    if simple_ui and simple_ui.menu and _simple_ui_menu_instance then
        local comp = _simple_ui_menu_instance:add_slider(
            id or "Slider",
            nil, nil,
            min_value, max_value, default_value,
            nil,
            { tooltip = id, show_value = true, slider_type = "int" }
        )
        if comp then
            -- Return wrapper matching core.menu API
            return {
                get = function() return comp:get_value() end,
                set = function(_, val) comp:set_value(val) end,
                _is_simple_ui = true,
                _component = comp,
            }
        end
    end

    -- Fallback to core.menu with all variations
    if core and core.menu then
        if core.menu.slider_int then
            return core.menu.slider_int(min_value, max_value, default_value, id)
        end
        if core.menu.slider then
            local slider = core.menu.slider(min_value, max_value, default_value, id)
            if slider and slider.as_int then
                return slider:as_int()
            end
            return slider
        end
        if core.menu.new_slider then
            local slider = core.menu.new_slider(min_value, max_value, default_value, id)
            if slider and slider.as_int then
                return slider:as_int()
            end
            return slider
        end
    end

    -- Return mock as last resort
    return {
        get = function() return default_value end,
        set = function() end,
        _is_mock = true,
    }
end

-- Wrapper for combobox that provides both simple_ui and core.menu compatibility
local function menu_combobox(default_value, id)
    -- Try simple_ui first
    if simple_ui and simple_ui.menu and _simple_ui_menu_instance then
        local items = { "Option 1", "Option 2", "Option 3" }  -- Default items
        local comp = _simple_ui_menu_instance:add_combobox(
            id or "Combobox",
            nil, nil,
            items,
            default_value,
            nil,
            { tooltip = id }
        )
        if comp then
            -- Return wrapper matching core.menu API
            return {
                get = function() return comp:get_value() end,
                set = function(_, val) comp:set_value(val) end,
                _is_simple_ui = true,
                _component = comp,
            }
        end
    end

    -- Fallback to core.menu
    if core and core.menu and core.menu.combobox then
        return core.menu.combobox(default_value, id)
    end

    -- Return mock as last resort
    return {
        get = function() return default_value end,
        set = function() end,
        _is_mock = true,
    }
end

-- ============================================================================
-- COLOR HELPER
-- ============================================================================

local function lighten_color(base_color, amount)
    if not base_color then
        return color.new(60, 60, 70, 200)
    end
    local ok, r, g, b, a = pcall(function() return base_color:get() end)
    if not ok then
        return color.new(60, 60, 70, 200)
    end
    local amt = amount or 20
    return color.new(
        math.min(255, (r or 60) + amt),
        math.min(255, (g or 60) + amt),
        math.min(255, (b or 70) + amt),
        a or 200
    )
end

-- ============================================================================
-- MOUSE / INPUT HELPERS
-- ============================================================================

local function safe_window_mouse_check(window, method_name, button)
    if not window then
        return false
    end
    local method = window[method_name]
    if type(method) ~= "function" then
        return false
    end
    local ok, result = pcall(method, window, button)
    return ok and result
end

local function is_mouse_pressed_left(window)
    if safe_window_mouse_check(window, "is_mouse_button_pressed", 0) or safe_window_mouse_check(window, "is_mouse_button_pressed", 1) then
        return true
    end
    return core.input.is_key_pressed(1) or core.input.is_key_pressed(2)
end

local function is_mouse_clicked_left(window)
    return safe_window_mouse_check(window, "is_mouse_button_clicked", 0) or safe_window_mouse_check(window, "is_mouse_button_clicked", 1)
end

local SCROLL_CENTER = 5000

local function get_wheel_delta(window)
    if not window then return 0 end
    local ok, scroll = pcall(function() return window:get_scroll() end)
    if not ok or not scroll then return 0 end
    local y = scroll.y or 0
    local delta = y - SCROLL_CENTER
    -- Reset to center so both up and down scrolling can be detected next frame
    pcall(function() window:set_scroll_y(SCROLL_CENTER) end)
    -- Ignore large jumps (initialization frames before center is established)
    if math.abs(delta) > 200 then return 0 end
    if delta == 0 then return 0 end
    return delta
end

-- ============================================================================
-- NUMERIC HELPER
-- ============================================================================

local function clamp_255(value)
    local v = tonumber(value) or 0
    v = math.floor(v + 0.5)
    if v < 0 then
        return 0
    end
    if v > 255 then
        return 255
    end
    return v
end

return {
    menu_slider_int = menu_slider_int,
    menu_checkbox = menu_checkbox,
    menu_combobox = menu_combobox,
    lighten_color = lighten_color,
    safe_window_mouse_check = safe_window_mouse_check,
    is_mouse_pressed_left = is_mouse_pressed_left,
    is_mouse_clicked_left = is_mouse_clicked_left,
    get_wheel_delta = get_wheel_delta,
    clamp_255 = clamp_255,
    set_simple_ui_menu_instance = set_simple_ui_menu_instance,
    get_simple_ui_menu_instance = get_simple_ui_menu_instance,
}
