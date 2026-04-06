-- EAX Paladin %s | menu.lua | Project Sylvanas
-- Uses unified EAX menu system

local unified = require("EAX_Unified/menu")
if not unified then
    error("[EAX Paladin %s] EAX_Unified menu system not available!")
end

local menu = {}
local ROTATION_KEY = "paladin_%s"

-- ============================================================================
-- MENU DEFINITION
-- ============================================================================
local MENU_DEF = {
    categories = {
        {
            name = "Rotation",
            settings = {
                { key = "use_crusader_strike", type = "checkbox", label = "Crusader Strike", default = true },
                { key = "use_judgement", type = "checkbox", label = "Judgement", default = true },
                { key = "use_divine_storm", type = "checkbox", label = "Divine Storm", default = true },
            }
        },
        {
            name = "Cooldowns",
            settings = {
                { key = "use_avenging_wrath", type = "checkbox", label = "Avenging Wrath", default = true },
                { key = "use_divine_protection", type = "checkbox", label = "Divine Protection", default = true },
            }
        },
    }
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

menu.use_crusader_strike = create_proxy("use_crusader_strike", true)
menu.use_judgement = create_proxy("use_judgement", true)
menu.use_divine_storm = create_proxy("use_divine_storm", true)
menu.use_avenging_wrath = create_proxy("use_avenging_wrath", true)
menu.use_divine_protection = create_proxy("use_divine_protection", true)
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
        return me:get_class() == 2
    end
}

-- ============================================================================
-- REGISTRATION
-- ============================================================================

local me = core.object_manager and core.object_manager.get_local_player()
if me and me:get_class() == 2 then
    unified.register_rotation("Paladin", "%s", MENU_DEF, callbacks)
end

return menu
