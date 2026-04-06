-- EAX Priest Holy | menu.lua | Project Sylvanas
-- Uses unified EAX menu system with core.menu API

local unified = require("EAX_Unified/menu")
if not unified then
    error("[EAX Priest Holy] EAX_Unified menu system not available!")
end

local menu = {}
local ROTATION_KEY = "priest_holy" -- lowercase with underscore

-- ============================================================================
-- MENU DEFINITION
-- ============================================================================
local MENU_DEF = {
    categories = {
        {
            name = "Rotation",
            settings = {
                { key = "use_flash_heal", type = "checkbox", label = "Use Flash Heal", default = true, tooltip = "Fast direct heal" },
                { key = "use_greater_heal", type = "checkbox", label = "Use Greater Heal", default = true, tooltip = "Slow efficient heal" },
                { key = "use_renew", type = "checkbox", label = "Use Renew", default = true, tooltip = "HoT maintenance" },
                { key = "use_circle_of_healing", type = "checkbox", label = "Use Circle of Healing", default = true, tooltip = "AoE heal" },
                { key = "use_prayer_of_mending", type = "checkbox", label = "Use Prayer of Mending", default = true, tooltip = "Bouncing heal" },
                { key = "use_binding_heal", type = "checkbox", label = "Use Binding Heal", default = true, tooltip = "Self + target heal" },
            }
        },
        {
            name = "Cooldowns",
            settings = {
                { key = "use_holy_nova", type = "checkbox", label = "Use Holy Nova", default = true, tooltip = "AoE heal + damage" },
                { key = "use_lightwell", type = "checkbox", label = "Use Lightwell", default = true, tooltip = "Click heal" },
                { key = "use_divine_hymn", type = "checkbox", label = "Use Divine Hymn", default = true, tooltip = "Raid heal CD" },
            }
        },
        {
            name = "Defensive",
            settings = {
                { key = "use_power_word_shield", type = "checkbox", label = "Use Power Word: Shield", default = true, tooltip = "Shield self" },
                { key = "shield_hp", type = "slider", label = "Shield HP %", default = 40, min = 0, max = 100, tooltip = "Use below this %" },
                { key = "self_heal_hp", type = "slider", label = "Self Heal HP %", default = 50, min = 0, max = 100, tooltip = "Heal self below this %" },
            }
        },
    }
}

-- ============================================================================
-- SETTING ACCESS API
-- ============================================================================
function menu.is_enabled()
    return unified.is_rotation_active(ROTATION_KEY)
end

function menu.get_setting(key, default)
    return unified.get_setting(ROTATION_KEY, key, default)
end

function menu.set_setting(key, value)
    return unified.set_setting(ROTATION_KEY, key, value)
end

-- Backward compatible checkbox proxy
local function create_proxy(key, default)
    return {
        is_checked = function() return menu.get_setting(key, default) end,
        get_value = function() return menu.get_setting(key, default) end,
        get = function() return menu.get_setting(key, default) end,
    }
end

-- Expose specific settings (create proxies for each key in MENU_DEF)
menu.use_flash_heal = create_proxy("use_flash_heal", true)
menu.use_greater_heal = create_proxy("use_greater_heal", true)
menu.use_renew = create_proxy("use_renew", true)
menu.use_circle_of_healing = create_proxy("use_circle_of_healing", true)
menu.use_prayer_of_mending = create_proxy("use_prayer_of_mending", true)
menu.use_binding_heal = create_proxy("use_binding_heal", true)
menu.use_holy_nova = create_proxy("use_holy_nova", true)
menu.use_lightwell = create_proxy("use_lightwell", true)
menu.use_divine_hymn = create_proxy("use_divine_hymn", true)
menu.use_power_word_shield = create_proxy("use_power_word_shield", true)
menu.shield_hp = create_proxy("shield_hp", 40)
menu.self_heal_hp = create_proxy("self_heal_hp", 50)
menu.debug = create_proxy("debug", false)
menu.enabled = { is_checked = menu.is_enabled }

function menu.toggle_menu()
    if unified and unified.toggle_menu then
        unified.toggle_menu()
    end
end

-- ============================================================================
-- CALLBACKS
-- ============================================================================
local callbacks = {
    on_enabled = function()
        print("|cFF00FF00[EAX Holy]|r Rotation enabled")
    end,
    on_disabled = function()
        print("|cFF00FF00[EAX Holy]|r Rotation disabled")
    end,
    is_valid = function()
        local me = core.object_manager and core.object_manager.get_local_player()
        if not me then return false end
        return me:get_class() == 5
    end
}

-- ============================================================================
-- REGISTRATION
-- ============================================================================
local me = core.object_manager and core.object_manager.get_local_player()
if me and me:get_class() == 5 then
    unified.register_rotation("Priest", "Holy", MENU_DEF, callbacks)
end

return menu
