-- EAX Mage Fire | menu.lua | Project Sylvanas
-- Uses unified EAX menu system with core.menu API

local unified = require("EAX_Unified/menu")
if not unified then
    error("[EAX Mage Fire] EAX_Unified menu system not available!")
end

local menu = {}
local ROTATION_KEY = "mage_fire" -- lowercase with underscore

-- ============================================================================
-- MENU DEFINITION
-- ============================================================================
local MENU_DEF = {
    categories = {
        {
            name = "Rotation",
            settings = {
                { key = "use_fireball", type = "checkbox", label = "Use Fireball", default = true, tooltip = "Main filler" },
                { key = "use_pyroblast", type = "checkbox", label = "Use Pyroblast", default = true, tooltip = "Opener/proc" },
                { key = "use_scorch", type = "checkbox", label = "Use Scorch", default = true, tooltip = "Debuff maintenance" },
                { key = "use_fire_blast", type = "checkbox", label = "Use Fire Blast", default = true, tooltip = "Instant" },
                { key = "use_living_bomb", type = "checkbox", label = "Use Living Bomb", default = true, tooltip = "DoT" },
                { key = "use_flamestrike", type = "checkbox", label = "Use Flamestrike", default = true, tooltip = "AoE" },
            }
        },
        {
            name = "Cooldowns",
            settings = {
                { key = "use_combustion", type = "checkbox", label = "Use Combustion", default = true, tooltip = "Burst CD" },
                { key = "use_presence_of_mind", type = "checkbox", label = "Use Presence of Mind", default = true, tooltip = "Instant cast" },
                { key = "use_evocation", type = "checkbox", label = "Use Evocation", default = true, tooltip = "Mana recovery" },
            }
        },
        {
            name = "Defensive",
            settings = {
                { key = "use_ice_barrier", type = "checkbox", label = "Use Ice Barrier", default = true, tooltip = "Shield" },
                { key = "ice_barrier_hp", type = "slider", label = "Ice Barrier HP %", default = 40, min = 0, max = 100, tooltip = "Use below this %" },
                { key = "use_ice_block", type = "checkbox", label = "Use Ice Block", default = true, tooltip = "Immunity" },
                { key = "ice_block_hp", type = "slider", label = "Ice Block HP %", default = 30, min = 0, max = 100, tooltip = "Use below this %" },
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
menu.use_fireball = create_proxy("use_fireball", true)
menu.use_pyroblast = create_proxy("use_pyroblast", true)
menu.use_scorch = create_proxy("use_scorch", true)
menu.use_fire_blast = create_proxy("use_fire_blast", true)
menu.use_living_bomb = create_proxy("use_living_bomb", true)
menu.use_flamestrike = create_proxy("use_flamestrike", true)
menu.use_combustion = create_proxy("use_combustion", true)
menu.use_presence_of_mind = create_proxy("use_presence_of_mind", true)
menu.use_evocation = create_proxy("use_evocation", true)
menu.use_ice_barrier = create_proxy("use_ice_barrier", true)
menu.ice_barrier_hp = create_proxy("ice_barrier_hp", 40)
menu.use_ice_block = create_proxy("use_ice_block", true)
menu.ice_block_hp = create_proxy("ice_block_hp", 30)
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
        print("|cFF00FF00[EAX Fire]|r Rotation enabled")
    end,
    on_disabled = function()
        print("|cFF00FF00[EAX Fire]|r Rotation disabled")
    end,
    is_valid = function()
        local me = core.object_manager and core.object_manager.get_local_player()
        if not me then return false end
        return me:get_class() == 8
    end
}

-- ============================================================================
-- REGISTRATION
-- ============================================================================
local me = core.object_manager and core.object_manager.get_local_player()
if me and me:get_class() == 8 then
    unified.register_rotation("Mage", "Fire", MENU_DEF, callbacks)
end

return menu
