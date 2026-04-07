-- ext_lib_astro_ui entry point
-- DEPRECATED: This module is retained for backward compatibility.
-- New code should use simple_ui directly via: local simple_ui = require("api/common/simple_ui")
--
-- Migration guide:
-- - Replace RotationSettingsUI.new() with simple_ui.menu:new(title, width, height, save_key)
-- - Replace checkbox_grid/slider_list/combo_list with menu:add_checkbox/add_slider/add_combobox
-- - Use menu:add_keybind() for hotkey toggles (keycode 106 for NUMPAD MULTIPLY)
-- - See libraries/menu.lua for the migration example

local simple_ui = require("api/common/simple_ui")

-- Return simple_ui as the primary interface
-- The old RotationSettingsUI API is no longer exported; use simple_ui directly
return {
    -- Deprecated: RotationSettingsUI is no longer supported
    -- Use simple_ui.menu:new() instead
    new = function(config)
        -- Create a simple_ui menu with equivalent settings
        local menu = simple_ui.menu:new(
            config.title or "Settings",
            config.default_w or 550,
            config.default_h or 500,
            config.id or "settings_menu"
        )
        return menu
    end,

    -- Deprecated tab builder - not needed with simple_ui
    TabBuilder = nil,

    -- Deprecated window registration - simple_ui handles this internally
    register_extension_tab = function() end,
    unregister_extension_tab = function() end,
    register_window = function() end,
    unregister_window = function() end,
    render_launcher = function() end,

    -- Export simple_ui for direct access
    simple_ui = simple_ui,
}

