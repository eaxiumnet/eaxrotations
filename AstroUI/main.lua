-- ext_lib_astro_ui entry point
-- Loads all modules and exports public API

local constants = require("AstroUI/core/constants")
local helpers = require("AstroUI/core/helpers")
local RotationSettingsUI = require("AstroUI/core/class")
local tab_builder = require("AstroUI/builder/tab_builder")

-- Attach TabBuilder to class for consumers
RotationSettingsUI.TabBuilder = tab_builder.TabBuilder

-- Load all modules (side-effect: attach methods to RotationSettingsUI)
require("AstroUI/builder/tabs")
require("AstroUI/features/presets")
require("AstroUI/features/scroll")
require("AstroUI/render/core")
require("AstroUI/render/inputs")
require("AstroUI/render/display")
require("AstroUI/render/components")
require("AstroUI/render/color")
require("AstroUI/features/lifecycle")

return {
    new = RotationSettingsUI.new,
    register_extension_tab = RotationSettingsUI.register_extension_tab,
    unregister_extension_tab = RotationSettingsUI.unregister_extension_tab,
    register_window = RotationSettingsUI.register_window,
    unregister_window = RotationSettingsUI.unregister_window,
    render_launcher = RotationSettingsUI.render_launcher,
    TabBuilder = tab_builder.TabBuilder,
}
