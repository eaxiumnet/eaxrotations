-- ext_lib_astro_ui - DEPRECATED
-- This local implementation is deprecated in favor of the framework's simple_ui library.
--
-- MIGRATION GUIDE:
-- Old: local AstroUI = require("ext_lib_astro_ui/main")
-- New: local simple_ui = require("common/simple_ui")
--
-- API CHANGES:
-- Old: AstroUI.new({ id = "...", title = "...", ... })
--      ui:add_tab({ id = "...", label = "..." }, function(t) ... end)
--      t:checkbox_grid({ ... })
--      AstroUI.register_window(ui)
--
-- New: local menu = simple_ui.menu:new(title, width, height, save_key)
--      menu:add_treenode(label, x, y, is_open, on_toggle, options)
--      menu:add_checkbox(label, x, y, default, on_change, options)
--      menu:add_slider(label, x, y, min, max, default, on_change, options)
--      menu:add_combobox(label, x, y, items, default_index, on_change, options)
--      menu:add_keybind(label, x, y, default_key, on_change, options)
--      menu:show() / menu:hide() / menu:toggle()
--
-- See libraries/menu.lua in EAXPriestHoly for a complete working example.

-- For backward compatibility during transition, redirect to simple_ui
local simple_ui = require("common/simple_ui")

if not simple_ui then
    print("|cFFFF0000[ext_lib_astro_ui]|r simple_ui library not available!")
    print("|cFFFF0000[ext_lib_astro_ui]|r Please ensure common/simple_ui is accessible.")
    return nil
end

print("|cFFFFFF00[ext_lib_astro_ui]|r DEPRECATED: Use local simple_ui = require('common/simple_ui') instead")

-- Return simple_ui as the new API
return simple_ui
