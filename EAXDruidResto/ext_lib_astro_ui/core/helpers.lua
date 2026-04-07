-- ext_lib_astro_ui/helpers.lua
-- Shared utility functions used across all modules

---@type color
local color = require("common/color")

-- ============================================================================
-- SIMPLE_UI MENU API COMPATIBILITY HELPERS
-- ============================================================================

-- simple_ui is the primary menu API - this module is now a compatibility layer
local simple_ui = require("common/simple_ui")

-- These functions maintain compatibility with old code but use simple_ui internally
local function menu_slider_int(min_value, max_value, default_value, id)
    -- simple_ui uses menu:add_slider() pattern instead
    -- This helper is kept for backward compatibility with existing code
    if simple_ui and simple_ui.menu then
        return {
            get = function() return default_value end,
            set = function(self, v) default_value = v end,
            get_value = function() return default_value end,
            _simple_ui_compat = true,
            _type = "slider"
        }
    end
    return nil
end

local function menu_checkbox(default_value, id)
    if simple_ui and simple_ui.menu then
        return {
            get = function() return default_value end,
            get_state = function() return default_value end,
            set = function(self, v) default_value = v end,
            is_checked = function() return default_value end,
            _simple_ui_compat = true,
            _type = "checkbox"
        }
    end
    return nil
end

local function menu_combobox(default_value, id)
    if simple_ui and simple_ui.menu then
        return {
            get = function() return default_value end,
            set = function(self, v) default_value = v end,
            get_value = function() return default_value end,
            _simple_ui_compat = true,
            _type = "combobox"
        }
    end
    return nil
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
}


