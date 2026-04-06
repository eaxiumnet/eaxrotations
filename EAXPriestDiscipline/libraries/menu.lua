-- EAX Priest Discipline | menu.lua | Project Sylvanas
-- Uses unified EAX menu system with core.menu API

local unified = require("EAX_Unified/menu")
if not unified then
    error("[EAX Priest Discipline] EAX_Unified menu system not available!")
end

local menu = {}
local ROTATION_KEY = "priest_discipline" -- lowercase with underscore

-- ============================================================================
-- MENU DEFINITION
-- ============================================================================
local MENU_DEF = {
    categories = {
        {
            name = "Rotation",
            settings = {
                { key = "use_penance", type = "checkbox", label = "Use Penance", default = true, tooltip = "Main heal/damage" },
                { key = "use_flash_heal", type = "checkbox", label = "Use Flash Heal", default = true, tooltip = "Fast direct heal" },
                { key = "use_greater_heal", type = "checkbox", label = "Use Greater Heal", default = true, tooltip = "Slow efficient heal" },
                { key = "use_power_word_shield", type = "checkbox", label = "Use Power Word: Shield", default = true, tooltip = "Shield target" },
                { key = "use_renew", type = "checkbox", label = "Use Renew", default = true, tooltip = "HoT maintenance" },
                { key = "use_smite", type = "checkbox", label = "Use Smite", default = true, tooltip = "DPS filler" },
            }
        },
        {
            name = "Cooldowns",
            settings = {
                { key = "use_power_infusion", type = "checkbox", label = "Use Power Infusion", default = true, tooltip = "Haste buff" },
                { key = "use_divine_aegis", type = "checkbox", label = "Use Divine Aegis", default = true, tooltip = "Shield proc" },
                { key = "use_pain_suppression", type = "checkbox", label = "Use Pain Suppression", default = true, tooltip = "Damage reduction" },
            }
        },
        {
            name = "Defensive",
            settings = {
                { key = "use_self_shield", type = "checkbox", label = "Use Shield on Self", default = true, tooltip = "Shield when low" },
                { key = "self_shield_hp", type = "slider", label = "Self Shield HP %", default = 40, min = 0, max = 100, tooltip = "Use below this %" },
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
menu.use_penance = create_proxy("use_penance", true)
menu.use_flash_heal = create_proxy("use_flash_heal", true)
menu.use_greater_heal = create_proxy("use_greater_heal", true)
menu.use_power_word_shield = create_proxy("use_power_word_shield", true)
menu.use_renew = create_proxy("use_renew", true)
menu.use_smite = create_proxy("use_smite", true)
menu.use_power_infusion = create_proxy("use_power_infusion", true)
menu.use_divine_aegis = create_proxy("use_divine_aegis", true)
menu.use_pain_suppression = create_proxy("use_pain_suppression", true)
menu.use_self_shield = create_proxy("use_self_shield", true)
menu.self_shield_hp = create_proxy("self_shield_hp", 40)
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
        print("|cFF00FF00[EAX Discipline]|r Rotation enabled")
    end,
    on_disabled = function()
        print("|cFF00FF00[EAX Discipline]|r Rotation disabled")
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
    unified.register_rotation("Priest", "Discipline", MENU_DEF, callbacks)
end

return menu
