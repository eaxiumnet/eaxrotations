-- ext_lib_astro_ui/helpers.lua
-- Shared utility functions used across all modules
-- NOTE: This module provides compatibility helpers for core.menu API.
-- For new code, consider using simple_ui directly: require("common/simple_ui")

---@type color
local color = require("common/color")

-- ============================================================================
-- MENU API COMPATIBILITY HELPERS (legacy - consider using simple_ui instead)
-- ============================================================================
-- These helpers wrap the core.menu API. For new AstroUI patterns,
-- use: local simple_ui = require("common/simple_ui")
--      local menu = simple_ui.menu:new("Title", width, height, save_key)
--      menu:add_checkbox(...), menu:add_slider(...), etc.

local function menu_slider_int(min_value, max_value, default_value, id)
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
    return nil
end

local function menu_checkbox(default_value, id)
    if core.menu.checkbox then
        return core.menu.checkbox(default_value, id)
    end
    return nil
end

local function menu_combobox(default_value, id)
    if core.menu.combobox then
        return core.menu.combobox(default_value, id)
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


