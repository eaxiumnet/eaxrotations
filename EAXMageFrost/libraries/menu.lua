-- EAX Mage Frost | menu.lua | Project Sylvanas
-- Uses unified EAX menu system with core.menu API

local unified = require("EAX_Unified/menu")
if not unified then
    error("[EAX Mage Frost] EAX_Unified menu system not available!")
end

local menu = {}
local ROTATION_KEY = "mage_frost" -- lowercase with underscore

-- ============================================================================
-- MENU DEFINITION
-- ============================================================================
local MENU_DEF = {
    categories = {
        {
            name = "Rotation",
            settings = {
                { key = "use_frostbolt", type = "checkbox", label = "Use Frostbolt", default = true, tooltip = "Main filler" },
                { key = "use_ice_lance", type = "checkbox", label = "Use Ice Lance", default = true, tooltip = "Instant" },
                { key = "use_frostfire_bolt", type = "checkbox", label = "Use Frostfire Bolt", default = true, tooltip = "Dual school" },
                { key = "use_blizzard", type = "checkbox", label = "Use Blizzard", default = true, tooltip = "AoE" },
                { key = "use_deep_freeze", type = "checkbox", label = "Use Deep Freeze", default = true, tooltip = "On frozen" },
            }
        },
        {
            name = "Cooldowns",
            settings = {
                { key = "use_icy_veins", type = "checkbox", label = "Use Icy Veins", default = true, tooltip = "Haste buff" },
                { key = "use_cold_snap", type = "checkbox", label = "Use Cold Snap", default = true, tooltip = "Reset CDs" },
                { key = "use_evocation", type = "checkbox", label = "Use Evocation", default = true, tooltip = "Mana recovery" },
            }
        },
        {
            name = "Defensive",
            settings = {
                { key = "use_ice_barrier", type = "checkbox", label = "Use Ice Barrier", default = true, tooltip = "Shield" },
                { key = "ice_barrier_hp", type = "slider", label = "Ice Barrier HP %", default = 40, min = 0, max = 100, tooltip = "Use below this %" },
                { key = "use_ice_block", type = "checkbox", label = "Use Ice Block", default = true, tooltip = "Immunity" },
                { key = "ice_block_hp", type = "slider", label = "Ice Block HP %", default = 20, min = 0, max = 100, tooltip = "Use below this %" },
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
menu.use_frostbolt = create_proxy("use_frostbolt", true)
menu.use_ice_lance = create_proxy("use_ice_lance", true)
menu.use_frostfire_bolt = create_proxy("use_frostfire_bolt", true)
menu.use_blizzard = create_proxy("use_blizzard", true)
menu.use_deep_freeze = create_proxy("use_deep_freeze", true)
menu.use_icy_veins = create_proxy("use_icy_veins", true)
menu.use_cold_snap = create_proxy("use_cold_snap", true)
menu.use_evocation = create_proxy("use_evocation", true)
menu.use_ice_barrier = create_proxy("use_ice_barrier", true)
menu.ice_barrier_hp = create_proxy("ice_barrier_hp", 40)
menu.use_ice_block = create_proxy("use_ice_block", true)
menu.ice_block_hp = create_proxy("ice_block_hp", 20)
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
        print("|cFF00FF00[EAX Frost]|r Rotation enabled")
    end,
    on_disabled = function()
        print("|cFF00FF00[EAX Frost]|r Rotation disabled")
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
    unified.register_rotation("Mage", "Frost", MENU_DEF, callbacks)
end

return menu
