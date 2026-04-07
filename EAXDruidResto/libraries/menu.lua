-- EAX Druid Restoration | menu.lua | Project Sylvanas
-- Uses unified EAX menu system with core.menu API

local unified = require("EAX_Unified/menu")
if not unified then
    error("[EAX Druid Restoration] EAX_Unified menu system not available!")
end

local menu = {}
local ROTATION_KEY = "druid_resto"

-- ============================================================================
-- MENU DEFINITION
-- ============================================================================
local MENU_DEF = {
    categories = {
        {
            name = "Healing",
            settings = {
                { key = "use_rejuvenation", type = "checkbox", label = "Rejuvenation", default = true, tooltip = "Use Rejuvenation HoT" },
                { key = "use_regrowth", type = "checkbox", label = "Regrowth", default = true, tooltip = "Use Regrowth direct heal" },
                { key = "use_lifebloom", type = "checkbox", label = "Lifebloom", default = true, tooltip = "Use Lifebloom tank HoT" },
                { key = "use_swiftmend", type = "checkbox", label = "Swiftmend", default = true, tooltip = "Use Swiftmend emergency heal" },
                { key = "use_nourish", type = "checkbox", label = "Nourish", default = true, tooltip = "Use Nourish filler" },
                { key = "use_healing_touch", type = "checkbox", label = "Healing Touch", default = true, tooltip = "Use Healing Touch big heal" },
            }
        },
        {
            name = "Tank Focus",
            settings = {
                { key = "tank_lifebloom_stacks", type = "slider", label = "Lifebloom Stacks", default = 3, min = 1, max = 3, tooltip = "Max Lifebloom stacks on tank" },
                { key = "tank_hp_threshold", type = "slider", label = "Tank HP Threshold", default = 70, min = 30, max = 90, tooltip = "HP % to prioritize tank healing" },
            }
        },
        {
            name = "Cooldowns",
            settings = {
                { key = "use_tree_of_life", type = "checkbox", label = "Tree of Life", default = true, tooltip = "Use Tree of Life form" },
                { key = "use_tranquility", type = "checkbox", label = "Tranquility", default = true, tooltip = "Use Tranquility for big damage" },
                { key = "tranquility_min_allies", type = "slider", label = "Tranquility Min Allies", default = 4, min = 2, max = 8, tooltip = "Min injured allies for Tranquility" },
                { key = "use_innervate", type = "checkbox", label = "Innervate", default = true, tooltip = "Auto-use Innervate" },
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
        get = function() return menu.get_setting(key, default) end,
    }
end

-- Expose specific settings as direct properties for compatibility
menu.use_rejuvenation = create_proxy("use_rejuvenation", true)
menu.use_regrowth = create_proxy("use_regrowth", true)
menu.use_lifebloom = create_proxy("use_lifebloom", true)
menu.use_swiftmend = create_proxy("use_swiftmend", true)
menu.use_nourish = create_proxy("use_nourish", true)
menu.use_healing_touch = create_proxy("use_healing_touch", true)
menu.tank_lifebloom_stacks = create_proxy("tank_lifebloom_stacks", 3)
menu.tank_hp_threshold = create_proxy("tank_hp_threshold", 70)
menu.use_tree_of_life = create_proxy("use_tree_of_life", true)
menu.use_tranquility = create_proxy("use_tranquility", true)
menu.tranquility_min_allies = create_proxy("tranquility_min_allies", 4)
menu.use_innervate = create_proxy("use_innervate", true)
menu.use_barkskin = create_proxy("use_barkskin", true)
menu.barkskin_hp = create_proxy("barkskin_hp", 30)
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
        print("|cFF00FF00[EAX Resto]|r Rotation enabled")
    end,
    on_disabled = function()
        print("|cFF00FF00[EAX Resto]|r Rotation disabled")
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
    unified.register_rotation("Druid", "Restoration", MENU_DEF, callbacks)
end

return menu
