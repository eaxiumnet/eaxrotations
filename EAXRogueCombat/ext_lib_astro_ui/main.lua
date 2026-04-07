-- ext_lib_astro_ui entry point
-- Loads all modules and exports public API
-- Updated for simple_ui compatibility

-- Try to load simple_ui library for modern menu patterns
local simple_ui = nil
local simple_ui_ok, simple_ui_result = pcall(function()
    return require("common/simple_ui")
end)
if simple_ui_ok then
    simple_ui = simple_ui_result
end

-- Only load core modules if simple_ui is NOT available (legacy fallback)
if not simple_ui then
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

    return {
        new = RotationSettingsUI.new,
        register_extension_tab = RotationSettingsUI.register_extension_tab,
        unregister_extension_tab = RotationSettingsUI.unregister_extension_tab,
        register_window = RotationSettingsUI.register_window,
        unregister_window = RotationSettingsUI.unregister_window,
        render_launcher = RotationSettingsUI.render_launcher,
        TabBuilder = tab_builder.TabBuilder,
        simple_ui_available = false,
        _is_legacy = true,
    }
else
    -- simple_ui is available - export simple_ui directly as the preferred API
    -- This allows consumers to use the modern simple_ui.menu patterns
    return {
        -- Pass through simple_ui for direct access
        simple_ui = simple_ui,
        menu = simple_ui.menu,

        -- Legacy API compatibility stubs (these will use simple_ui internally)
        new = function(config)
            -- Create a simple_ui based menu instead of legacy RotationSettingsUI
            local save_key = config.id or "astro_ui_window"
            local menu = simple_ui.menu:new(config.title or "Settings", config.default_w or 550, config.default_h or 600, save_key)

            -- Store reference in helpers for component creation
            local helpers = require("ext_lib_astro_ui/core/helpers")
            helpers.set_simple_ui_menu_instance(menu)

            -- Return a compatibility wrapper
            return {
                id = config.id,
                title = config.title,
                menu = menu,
                _is_simple_ui = true,

                add_tab = function(self, tab_info, build_fn)
                    -- Use treenode for tabs in simple_ui
                    local tab_node = menu:add_treenode(
                        tab_info.label,
                        nil, nil,
                        false,
                        nil,
                        { indent = 15, font_size = 14 }
                    )
                    if build_fn and type(build_fn) == "function" then
                        -- Build function would need access to TabBuilder
                        -- For now, components are added directly via menu:add_*
                    end
                    return tab_node
                end,

                on_render = function() end,
                on_menu_render = function() end,
            }
        end,

        register_extension_tab = function() end,
        unregister_extension_tab = function() end,
        register_window = function(menu_ui)
            -- simple_ui handles its own registration
            if menu_ui and menu_ui._is_simple_ui and menu_ui.menu then
                -- Already managed by simple_ui
            end
        end,
        unregister_window = function() end,
        render_launcher = function() end,

        -- TabBuilder is not needed with simple_ui direct API
        TabBuilder = nil,

        simple_ui_available = true,
        _is_simple_ui = true,
    }
end


