-- EAX Druid Feral | menu.lua | Project Sylvanas
-- Uses unified EAX menu system

local unified = require("EAX_Unified/menu")
if not unified then
    error("[EAX Druid Feral] EAX_Unified menu system not available!")
end

local menu = {}
local ROTATION_KEY = "druid_feral"

-- ============================================================================
-- MENU DEFINITION
-- ============================================================================
local MENU_DEF = {
    categories = {
        {
            name = "Rotation",
            settings = {
                { key = "use_rip", type = "checkbox", label = "Rip", default = true, tooltip = "Use Rip finisher" },
                { key = "use_rake", type = "checkbox", label = "Rake", default = true, tooltip = "Use Rake DoT" },
                { key = "use_shred", type = "checkbox", label = "Shred", default = true, tooltip = "Use Shred as builder" },
                { key = "use_mangle", type = "checkbox", label = "Mangle", default = true, tooltip = "Use Mangle debuff" },
                { key = "use_ferocious_bite", type = "checkbox", label = "Ferocious Bite", default = true, tooltip = "Use Ferocious Bite finisher" },
                { key = "use_tigers_fury", type = "checkbox", label = "Tiger's Fury", default = true, tooltip = "Use Tiger's Fury cooldown" },
                { key = "use_prowl_opener", type = "checkbox", label = "Prowl Opener", default = true, tooltip = "Use Prowl + Ravage opener" },
                { key = "use_faerie_fire", type = "checkbox", label = "Faerie Fire", default = true, tooltip = "Maintain Faerie Fire debuff" },
                { key = "use_berserk", type = "checkbox", label = "Berserk", default = true, tooltip = "Use Berserk cooldown" },
                { key = "cat_tick_optimization", type = "checkbox", label = "Tick Optimization", default = true, tooltip = "Prefer Mangle over Shred when a tick is imminent to avoid dead GCDs" },
            }
        },
        {
            name = "Powershift",
            settings = {
                { key = "auto_powershift", type = "checkbox", label = "Auto Powershift", default = true, tooltip = "Automatically powershift for energy" },
                { key = "powershift_min_mana", type = "slider", label = "Min Mana %", default = 25, min = 10, max = 50, tooltip = "Minimum mana % to powershift" },
            }
        },
        {
            name = "Defensive",
            settings = {
                { key = "use_barkskin", type = "checkbox", label = "Barkskin", default = true, tooltip = "Use Barkskin defensively" },
                { key = "barkskin_hp", type = "slider", label = "Barkskin HP %", default = 30, min = 10, max = 50, tooltip = "HP threshold for Barkskin" },
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
        get = function() return menu.get_setting(key, default) end,  --  compatibility
    }
end

-- Expose specific settings as direct properties for compatibility
menu.use_rip = create_proxy("use_rip", true)
menu.use_rake = create_proxy("use_rake", true)
menu.use_shred = create_proxy("use_shred", true)
menu.use_mangle = create_proxy("use_mangle", true)
menu.use_ferocious_bite = create_proxy("use_ferocious_bite", true)
menu.use_tigers_fury = create_proxy("use_tigers_fury", true)
menu.use_prowl_opener = create_proxy("use_prowl_opener", true)
menu.use_berserk = create_proxy("use_berserk", true)
menu.auto_powershift = create_proxy("auto_powershift", true)
menu.use_barkskin = create_proxy("use_barkskin", true)
menu.powershift_min_mana = create_proxy("powershift_min_mana", 25)
menu.barkskin_hp = create_proxy("barkskin_hp", 30)
menu.cat_tick_optimization = create_proxy("cat_tick_optimization", true)
menu.enabled = { is_checked = menu.is_enabled }

---Toggle the unified menu (for external access)
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
        -- Rotation enabled
    end,
    on_disabled = function()
        -- Rotation disabled
    end,
    is_valid = function()
        local me = core.object_manager and core.object_manager.get_local_player()
        if not me then return false end
        return me:get_class() == 11  -- Druid class ID
    end
}

-- ============================================================================
-- REGISTRATION
-- ============================================================================

local me = core.object_manager and core.object_manager.get_local_player()
if me and me:get_class() == 11 then
    unified.register_rotation("Druid", "Feral", MENU_DEF, callbacks)
end

return menu
