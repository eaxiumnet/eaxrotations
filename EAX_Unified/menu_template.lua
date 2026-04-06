-- EAX %s %s | menu.lua | Project Sylvanas
-- Uses unified EAX menu system

local unified = require("EAX_Unified/menu")
if not unified then
    error("[EAX %s %s] EAX_Unified menu system not available!")
end

local menu = {}
local ROTATION_KEY = "%s_%s"

-- ============================================================================
-- MENU DEFINITION
-- ============================================================================
local MENU_DEF = {
    categories = %s
}

-- ============================================================================
-- SETTING ACCESS API
-- ============================================================================

function menu.is_enabled()
    return unified.is_enabled(ROTATION_KEY)
end

function menu.get_setting(key, default)
    return unified.get_setting(ROTATION_KEY, key, default)
end

function menu.set_setting(key, value)
    return unified.set_setting(ROTATION_KEY, key, value)
end

-- Backward compatible proxy
local function create_proxy(key, default)
    return {
        is_checked = function() return menu.get_setting(key, default) end,
        get_value = function() return menu.get_setting(key, default) end,
    }
end

%s
menu.enabled = { is_checked = menu.is_enabled }

-- ============================================================================
-- CALLBACKS
-- ============================================================================

local callbacks = {
    on_enabled = function() end,
    on_disabled = function() end,
    is_valid = function()
        local me = core.object_manager and core.object_manager.get_local_player()
        if not me then return false end
        return me:get_class() == %d
    end
}

-- ============================================================================
-- REGISTRATION
-- ============================================================================

local me = core.object_manager and core.object_manager.get_local_player()
if me and me:get_class() == %d then
    unified.register_rotation("%s", "%s", MENU_DEF, callbacks)
end

return menu
