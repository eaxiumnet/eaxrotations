-- ext_lib_astro_ui entry point
-- DELEGATES TO simple_ui - This is now a compatibility wrapper
-- The actual implementation has moved to common/simple_ui
-- Use require("common/simple_ui") directly for new code

local simple_ui = require("common/simple_ui")

if not simple_ui then
    -- Fallback: return a minimal stub that won't crash
    return {
        new = function() return nil end,
        register_extension_tab = function() end,
        unregister_extension_tab = function() end,
        register_window = function() end,
        unregister_window = function() end,
        render_launcher = function() end,
        TabBuilder = {},
        _is_stub = true,
        _error = "simple_ui not available"
    }
end

-- Compatibility wrapper for old AstroUI API
local AstroUICompat = {}

-- Wrap simple_ui.menu:new for compatibility
function AstroUICompat.new(options)
    -- Old API used options like { id=..., title=..., theme=..., ... }
    -- New simple_ui uses menu:new(title, width, height, save_key)
    local title = options and options.title or "AstroUI"
    local width = options and options.default_w or 550
    local height = options and options.default_h or 500
    local save_key = options and options.id or "astro_compat_default"

    local menu = simple_ui.menu:new(title, width, height, save_key)

    -- Attach compatibility methods that old code might expect
    menu._compat_wrapped = true
    menu._original_options = options

    -- Old on_render/on_menu_render callbacks - simple_ui handles this internally
    menu.on_render = function() end
    menu.on_menu_render = function() end

    return menu
end

-- Window registration is now handled internally by simple_ui
function AstroUICompat.register_window(menu)
    -- simple_ui handles window registration automatically
    if menu and menu.show then
        menu:show()
    end
end

function AstroUICompat.unregister_window(menu)
    -- simple_ui handles cleanup automatically
    if menu and menu.hide then
        menu:hide()
    end
end

-- Extension tabs are now handled via simple_ui's tree node system
function AstroUICompat.register_extension_tab(menu, tab_def, builder_fn)
    -- Build via simple_ui.add_treenode pattern
    if menu and menu.add_treenode then
        local node = menu:add_treenode(
            tab_def.label or "Tab",
            nil, nil,
            false,
            nil,
            { indent = 15, font_size = 14 }
        )
        -- The builder_fn would receive a tab builder context
        -- This is a simplified compatibility layer
        if builder_fn then
            -- Create a minimal tab context
            local tab_ctx = {
                checkbox_grid = function() end,
                slider_list = function() end,
                keybind_grid = function() end,
                combo_list = function() end,
            }
            builder_fn(tab_ctx)
        end
    end
end

function AstroUICompat.unregister_extension_tab(menu, tab_id)
    -- No-op in simple_ui - tabs are static after creation
end

function AstroUICompat.render_launcher()
    -- simple_ui handles its own rendering loop
end

-- TabBuilder compatibility stub
AstroUICompat.TabBuilder = {
    new = function() return {} end,
    checkbox_grid = function() end,
    slider_list = function() end,
}

-- Export deprecation notice (will print once when loaded)
local core = _G.core
if core and core.log then
    core.log("|cFFFFFF00[EAX Shaman Elemental]|r ext_lib_astro_ui is deprecated. Using simple_ui compatibility wrapper.")
    core.log("|cFFFFFF00[EAX Shaman Elemental]|r Update code to use require('common/simple_ui') directly.")
end

return AstroUICompat
