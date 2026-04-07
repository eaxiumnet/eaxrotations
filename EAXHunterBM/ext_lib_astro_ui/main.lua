-- ext_lib_astro_ui entry point
-- Loads all modules and exports public API
-- Updated to use simple_ui as primary UI framework when available

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

-- Try to load simple_ui as primary menu provider
local simple_ui = nil
local function get_simple_ui()
    if simple_ui == nil then
        local ok, mod = pcall(function() return require("common/simple_ui") end)
        simple_ui = ok and mod or false
    end
    return simple_ui
end

return {
    new = RotationSettingsUI.new,
    register_extension_tab = RotationSettingsUI.register_extension_tab,
    unregister_extension_tab = RotationSettingsUI.unregister_extension_tab,
    register_window = RotationSettingsUI.register_window,
    unregister_window = RotationSettingsUI.unregister_window,
    render_launcher = RotationSettingsUI.render_launcher,
    TabBuilder = tab_builder.TabBuilder,
    -- Export simple_ui integration helpers
    _get_simple_ui = get_simple_ui,
}


