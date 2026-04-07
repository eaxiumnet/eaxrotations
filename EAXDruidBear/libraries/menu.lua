-- EAX Druid Bear | menu.lua | Project Sylvanas
-- Uses unified EAX menu system with core.menu API

local unified = require("EAX_Unified/menu")
if not unified then
    error("[EAX Druid Bear] EAX_Unified menu system not available!")
end

local menu = {}
local ROTATION_KEY = "druid_bear"

-- ============================================================================
-- MENU DEFINITION
-- ============================================================================
local MENU_DEF = {
    categories = {
        {
            name = "Rotation",
            settings = {
                { key = "use_mangle", type = "checkbox", label = "Mangle", default = true, tooltip = "Use Mangle main ability" },
                { key = "use_lacerate", type = "checkbox", label = "Lacerate", default = true, tooltip = "Use Lacerate bleed" },
                { key = "use_swipe", type = "checkbox", label = "Swipe", default = true, tooltip = "Use Swipe AoE" },
                { key = "use_maul", type = "checkbox", label = "Maul", default = true, tooltip = "Use Maul rage dump" },
                { key = "use_bash", type = "checkbox", label = "Bash", default = true, tooltip = "Use Bash interrupt" },
                { key = "use_frenzied_regen", type = "checkbox", label = "Frenzied Regen", default = true, tooltip = "Use Frenzied Regeneration" },
            }
        },
        {
            name = "Defensive",
            settings = {
                { key = "use_barkskin", type = "checkbox", label = "Barkskin", default = true, tooltip = "Use Barkskin defensively" },
                { key = "barkskin_hp", type = "slider", label = "Barkskin HP %", default = 30, min = 10, max = 50, tooltip = "HP threshold for Barkskin" },
                { key = "frenzied_regen_hp", type = "slider", label = "Frenzied Regen HP %", default = 25, min = 10, max = 50, tooltip = "HP threshold for Frenzied Regen" },
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

-- Expose specific settings as direct properties for compatibility
menu.use_mangle = create_proxy("use_mangle", true)
menu.use_lacerate = create_proxy("use_lacerate", true)
menu.use_swipe = create_proxy("use_swipe", true)
menu.use_maul = create_proxy("use_maul", true)
menu.use_bash = create_proxy("use_bash", true)
menu.use_frenzied_regen = create_proxy("use_frenzied_regen", true)
menu.use_barkskin = create_proxy("use_barkskin", true)
menu.barkskin_hp = create_proxy("barkskin_hp", 30)
menu.frenzied_regen_hp = create_proxy("frenzied_regen_hp", 25)
menu.debug = create_proxy("debug", false)
menu.enabled = { is_checked = menu.is_enabled }

---Toggle the unified menu
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
        print("|cFF00FF00[EAX Bear]|r Rotation enabled")
    end,
    on_disabled = function()
        print("|cFF00FF00[EAX Bear]|r Rotation disabled")
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
    unified.register_rotation("Druid", "Bear", MENU_DEF, callbacks)
end

return menu
