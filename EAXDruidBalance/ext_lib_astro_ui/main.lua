-- ext_lib_astro_ui entry point
-- Loads all modules and exports public API
-- Now supports both traditional core.menu API and simple_ui (AstroUI v2) API

local constants = require("ext_lib_astro_ui/core/constants")
local helpers = require("ext_lib_astro_ui/core/helpers")
local RotationSettingsUI = require("ext_lib_astro_ui/core/class")
local tab_builder = require("ext_lib_astro_ui/builder/tab_builder")

-- Try to import simple_ui (AstroUI v2)
local simple_ui_available, simple_ui = pcall(function()
    return require("api/common/simple_ui")
end)

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

-- Public API
local api = {
    new = RotationSettingsUI.new,
    register_extension_tab = RotationSettingsUI.register_extension_tab,
    unregister_extension_tab = RotationSettingsUI.unregister_extension_tab,
    register_window = RotationSettingsUI.register_window,
    unregister_window = RotationSettingsUI.unregister_window,
    render_launcher = RotationSettingsUI.render_launcher,
    TabBuilder = tab_builder.TabBuilder,
}

-- If simple_ui is available, also export simple_ui integration helpers
if simple_ui_available and simple_ui then
    api.simple_ui = simple_ui
    api.has_simple_ui = true

    -- Helper to create a simple_ui-based menu with the same interface as RotationSettingsUI.new()
    api.new_simple = function(config)
        local menu = simple_ui.menu:new(
            config.title or "Settings",
            config.default_w or 550,
            config.default_h or 500,
            config.id or "settings_menu"
        )
        return menu
    end
else
    api.has_simple_ui = false
end

return api

