-- EAX Priest Shadow | menu.lua | Project Sylvanas
-- Uses unified EAX menu system with core.menu API

local unified = require("EAX_Unified/menu")
if not unified then
    error("[EAX Priest Shadow] EAX_Unified menu system not available!")
end

local menu = {}
local ROTATION_KEY = "priest_shadow" -- lowercase with underscore

-- ============================================================================
-- MENU DEFINITION
-- ============================================================================
local MENU_DEF = {
    categories = {
        {
            name = "Rotation",
            settings = {
                { key = "use_shadow_word_pain", type = "checkbox", label = "Use Shadow Word: Pain", default = true, tooltip = "DoT maintenance" },
                { key = "use_vampiric_touch", type = "checkbox", label = "Use Vampiric Touch", default = true, tooltip = "DoT maintenance" },
                { key = "use_mind_blast", type = "checkbox", label = "Use Mind Blast", default = true, tooltip = "On CD" },
                { key = "use_mind_flay", type = "checkbox", label = "Use Mind Flay", default = true, tooltip = "Filler channel" },
                { key = "use_shadow_word_death", type = "checkbox", label = "Use Shadow Word: Death", default = true, tooltip = "Execute" },
                { key = "use_devouring_plague", type = "checkbox", label = "Use Devouring Plague", default = true, tooltip = "DoT" },
            }
        },
        {
            name = "Cooldowns",
            settings = {
                { key = "use_shadowfiend", type = "checkbox", label = "Use Shadowfiend", default = true, tooltip = "Mana/DPS" },
                { key = "use_vampiric_embrace", type = "checkbox", label = "Use Vampiric Embrace", default = true, tooltip = "Self-heal buff" },
            }
        },
        {
            name = "Defensive",
            settings = {
                { key = "use_power_word_shield", type = "checkbox", label = "Use Power Word: Shield", default = true, tooltip = "Shield self" },
                { key = "shield_hp", type = "slider", label = "Shield HP %", default = 40, min = 0, max = 100, tooltip = "Use below this %" },
                { key = "use_renew", type = "checkbox", label = "Use Renew", default = true, tooltip = "Self HoT" },
                { key = "renew_hp", type = "slider", label = "Renew HP %", default = 50, min = 0, max = 100, tooltip = "Use below this %" },
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
menu.use_shadow_word_pain = create_proxy("use_shadow_word_pain", true)
menu.use_vampiric_touch = create_proxy("use_vampiric_touch", true)
menu.use_mind_blast = create_proxy("use_mind_blast", true)
menu.use_mind_flay = create_proxy("use_mind_flay", true)
menu.use_shadow_word_death = create_proxy("use_shadow_word_death", true)
menu.use_devouring_plague = create_proxy("use_devouring_plague", true)
menu.use_shadowfiend = create_proxy("use_shadowfiend", true)
menu.use_vampiric_embrace = create_proxy("use_vampiric_embrace", true)
menu.use_power_word_shield = create_proxy("use_power_word_shield", true)
menu.shield_hp = create_proxy("shield_hp", 40)
menu.use_renew = create_proxy("use_renew", true)
menu.renew_hp = create_proxy("renew_hp", 50)
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
        print("|cFF00FF00[EAX Shadow]|r Rotation enabled")
    end,
    on_disabled = function()
        print("|cFF00FF00[EAX Shadow]|r Rotation disabled")
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
    unified.register_rotation("Priest", "Shadow", MENU_DEF, callbacks)
end

return menu
