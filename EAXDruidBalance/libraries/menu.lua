-- EAX Druid Balance | menu.lua | Project Sylvanas
-- Uses unified EAX menu system with core.menu API

local unified = require("EAX_Unified/menu")
if not unified then
    error("[EAX Druid Balance] EAX_Unified menu system not available!")
end

local menu = {}
local ROTATION_KEY = "druid_balance"

-- ============================================================================
-- MENU DEFINITION
-- ============================================================================
local MENU_DEF = {
    categories = {
        {
            name = "Rotation",
            settings = {
                { key = "use_moonfire", type = "checkbox", label = "Moonfire", default = true, tooltip = "Use Moonfire DoT" },
                { key = "use_insect_swarm", type = "checkbox", label = "Insect Swarm", default = true, tooltip = "Use Insect Swarm DoT" },
                { key = "use_starfire", type = "checkbox", label = "Starfire", default = true, tooltip = "Use Starfire nuke" },
                { key = "use_wrath", type = "checkbox", label = "Wrath", default = true, tooltip = "Use Wrath nuke" },
                { key = "use_faerie_fire", type = "checkbox", label = "Faerie Fire", default = true, tooltip = "Use Faerie Fire debuff" },
                { key = "use_hurricane", type = "checkbox", label = "Hurricane", default = true, tooltip = "Use Hurricane AoE" },
                { key = "hurricane_min_targets", type = "slider", label = "Hurricane Min Targets", default = 3, min = 2, max = 8, tooltip = "Min targets for Hurricane" },
            }
        },
        {
            name = "Cooldowns",
            settings = {
                { key = "use_force_of_nature", type = "checkbox", label = "Force of Nature", default = true, tooltip = "Use Force of Nature treants" },
                { key = "use_innervate", type = "checkbox", label = "Innervate", default = true, tooltip = "Auto-use Innervate" },
                { key = "innervate_mana", type = "slider", label = "Innervate Mana %", default = 20, min = 10, max = 50, tooltip = "Mana threshold for Innervate" },
            }
        },
        {
            name = "Defensive",
            settings = {
                { key = "use_barkskin", type = "checkbox", label = "Barkskin", default = true, tooltip = "Use Barkskin defensively" },
                { key = "barkskin_hp", type = "slider", label = "Barkskin HP %", default = 30, min = 10, max = 50, tooltip = "HP threshold for Barkskin" },
                { key = "use_moonkin_form", type = "checkbox", label = "Maintain Moonkin", default = true, tooltip = "Keep Moonkin Form active" },
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
menu.use_moonfire = create_proxy("use_moonfire", true)
menu.use_insect_swarm = create_proxy("use_insect_swarm", true)
menu.use_starfire = create_proxy("use_starfire", true)
menu.use_wrath = create_proxy("use_wrath", true)
menu.use_faerie_fire = create_proxy("use_faerie_fire", true)
menu.use_hurricane = create_proxy("use_hurricane", true)
menu.hurricane_min_targets = create_proxy("hurricane_min_targets", 3)
menu.use_force_of_nature = create_proxy("use_force_of_nature", true)
menu.use_innervate = create_proxy("use_innervate", true)
menu.innervate_mana = create_proxy("innervate_mana", 20)
menu.use_barkskin = create_proxy("use_barkskin", true)
menu.barkskin_hp = create_proxy("barkskin_hp", 30)
menu.use_moonkin_form = create_proxy("use_moonkin_form", true)
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
        print("|cFF00FF00[EAX Balance]|r Rotation enabled")
    end,
    on_disabled = function()
        print("|cFF00FF00[EAX Balance]|r Rotation disabled")
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
    unified.register_rotation("Druid", "Balance", MENU_DEF, callbacks)
end

return menu
