-- ext_lib_astro_ui entry point
-- NOTE: This module is deprecated for new code. Use simple_ui directly instead.
-- Example: local simple_ui = require("common/simple_ui")
--          local menu = simple_ui.menu:new("Title", 550, 500, "save_key")

local constants = require("ext_lib_astro_ui/core/constants")
local helpers = require("ext_lib_astro_ui/core/helpers")
local RotationSettingsUI = require("ext_lib_astro_ui/core/class")
local tab_builder = require("ext_lib_astro_ui/builder/tab_builder")

-- Attach TabBuilder to class for consumers
RotationSettingsUI.TabBuilder = tab_builder.TabBuilder

-- Load all modules (side-effect: attach methods to RotationSettingsUI)
require("ext_lib_astro_ui/builder/tabs")
require("ext_lib_astro_ui/features/presets")
require("ext_lib_astro_ui/features/scroll")
require("ext_lib_astro_ui/render/core")
require("ext_lib_astro_ui/render/inputs")
require("ext_lib_astro_ui/render/display")
require("ext_lib_astro_ui/render/components")
require("ext_lib_astro_ui/render/color")
require("ext_lib_astro_ui/features/lifecycle")

-- ============================================================================
-- DEPRECATION NOTICE
-- ============================================================================
-- For new code, use simple_ui directly:
--   local simple_ui = require("common/simple_ui")
--   local menu = simple_ui.menu:new("Title", width, height, "save_key")
--   menu:add_checkbox("Label", nil, nil, default, callback, opts)
--   menu:add_slider("Label", nil, nil, min, max, default, callback, opts)
--   menu:add_combobox("Label", nil, nil, items, default_idx, callback, opts)
--   menu:add_keybind("Label", nil, nil, keycode, callback, {is_toggle=true})
--   menu:toggle()  -- Show/hide menu
--
-- See /rotation/source/aio/settings.lua for full reference implementation.

return {
    new = RotationSettingsUI.new,
    register_extension_tab = RotationSettingsUI.register_extension_tab,
    unregister_extension_tab = RotationSettingsUI.unregister_extension_tab,
    register_window = RotationSettingsUI.register_window,
    unregister_window = RotationSettingsUI.unregister_window,
    render_launcher = RotationSettingsUI.render_launcher,
    TabBuilder = tab_builder.TabBuilder,
    -- Simple UI reference for migration
    _simple_ui_hint = "Use local simple_ui = require('common/simple_ui') instead",
}
