-- EAX Unified Menu Loader | Project Sylvanas
-- Loads from rotation's own EAX_Unified folder

local unified = require("EAX_Unified/menu")
if not unified then
    error("[EAXRogueCombat] Menu system failed to load from EAX_Unified/menu")
end

local menu = {}
local ROTATION_KEY = "eaxroguecombat"

-- All the setting proxies from unified system
function menu.is_enabled()
    return unified.is_rotation_active and unified.is_rotation_active(ROTATION_KEY) or false
end

function menu.get_setting(key, default)
    return unified.get_setting and unified.get_setting(ROTATION_KEY, key, default) or default
end

function menu.set_setting(key, value)
    if unified.set_setting then
        unified.set_setting(ROTATION_KEY, key, value)
    end
end

-- Proxy helper
local function create_proxy(key, default)
    return {
        is_checked = function() return menu.get_setting(key, default) end,
        get_value = function() return menu.get_setting(key, default) end,
        get = function() return menu.get_setting(key, default) end,
    }
end

-- Default settings for all rotations
menu.debug = create_proxy("debug", false)
menu.enabled = { is_checked = menu.is_enabled }

-- Toggle menu
function menu.toggle_menu()
    if unified.toggle_menu then
        unified.toggle_menu()
    end
end

return menu
