-- EAX Hunter Survival | menu.lua | Project Sylvanas
-- Uses unified EAX menu system with core.menu API

local unified = require("EAX_Unified/menu")
if not unified then
    error("[EAX Hunter Survival] EAX_Unified menu system not available!")
end

local menu = {}
local ROTATION_KEY = "hunter_survival" -- lowercase with underscore

-- ============================================================================
-- MENU DEFINITION
-- ============================================================================
local MENU_DEF = {
    categories = {
        {
            name = "Rotation",
            settings = {
                { key = "use_explosive_shot", type = "checkbox", label = "Use Explosive Shot", default = true, tooltip = "Main ability" },
                { key = "use_black_arrow", type = "checkbox", label = "Use Black Arrow", default = true, tooltip = "DoT ability" },
                { key = "use_serpent_sting", type = "checkbox", label = "Use Serpent Sting", default = true, tooltip = "DoT maintenance" },
                { key = "use_steady_shot", type = "checkbox", label = "Use Steady Shot", default = true, tooltip = "Filler ability" },
                { key = "use_arcane_shot", type = "checkbox", label = "Use Arcane Shot", default = true, tooltip = "Instant filler" },
                { key = "use_multi_shot", type = "checkbox", label = "Use Multi-Shot", default = true, tooltip = "AoE shot" },
            }
        },
        {
            name = "Cooldowns",
            settings = {
                { key = "use_rapid_fire", type = "checkbox", label = "Use Rapid Fire", default = true, tooltip = "Burst CD" },
                { key = "use_misdirection", type = "checkbox", label = "Use Misdirection", default = true, tooltip = "Threat transfer" },
            }
        },
        {
            name = "Defensive",
            settings = {
                { key = "use_deterrence", type = "checkbox", label = "Use Deterrence", default = true, tooltip = "Self-defense" },
                { key = "deterrence_hp", type = "slider", label = "Deterrence HP %", default = 12, min = 5, max = 40, tooltip = "Use below this %" },
                { key = "use_feign_death", type = "checkbox", label = "Use Feign Death", default = true, tooltip = "Emergency fade" },
                { key = "feign_death_hp", type = "slider", label = "Feign Death HP %", default = 20, min = 5, max = 40, tooltip = "Use below this %" },
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
menu.use_explosive_shot = create_proxy("use_explosive_shot", true)
menu.use_black_arrow = create_proxy("use_black_arrow", true)
menu.use_serpent_sting = create_proxy("use_serpent_sting", true)
menu.use_steady_shot = create_proxy("use_steady_shot", true)
menu.use_arcane_shot = create_proxy("use_arcane_shot", true)
menu.use_multi_shot = create_proxy("use_multi_shot", true)
menu.use_rapid_fire = create_proxy("use_rapid_fire", true)
menu.use_misdirection = create_proxy("use_misdirection", true)
menu.use_deterrence = create_proxy("use_deterrence", true)
menu.deterrence_hp = create_proxy("deterrence_hp", 12)
menu.use_feign_death = create_proxy("use_feign_death", true)
menu.feign_death_hp = create_proxy("feign_death_hp", 20)
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
        print("|cFF00FF00[EAX Survival]|r Rotation enabled")
    end,
    on_disabled = function()
        print("|cFF00FF00[EAX Survival]|r Rotation disabled")
    end,
    is_valid = function()
        local me = core.object_manager and core.object_manager.get_local_player()
        if not me then return false end
        return me:get_class() == 3
    end
}

-- ============================================================================
-- REGISTRATION
-- ============================================================================
local me = core.object_manager and core.object_manager.get_local_player()
if me and me:get_class() == 3 then
    unified.register_rotation("Hunter", "Survival", MENU_DEF, callbacks)
end

return menu
