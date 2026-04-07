-- EAX Hunter Marksmanship | menu.lua | Project Sylvanas
-- Uses unified EAX menu system with core.menu API

local unified = require("EAX_Unified/menu")
if not unified then
    error("[EAX Hunter Marksmanship] EAX_Unified menu system not available!")
end

local menu = {}
local ROTATION_KEY = "hunter_marksmanship"

-- ============================================================================
-- MENU DEFINITION
-- ============================================================================
local MENU_DEF = {
    categories = {
        {
            name = "Rotation",
            settings = {
                { key = "use_aimed_shot", type = "checkbox", label = "Aimed Shot", default = true, tooltip = "Use Aimed Shot hardcast" },
                { key = "use_chimera_shot", type = "checkbox", label = "Chimera Shot", default = true, tooltip = "Use Chimera Shot on cooldown" },
                { key = "use_serpent_sting", type = "checkbox", label = "Serpent Sting", default = true, tooltip = "Maintain Serpent Sting DoT" },
                { key = "use_steady_shot", type = "checkbox", label = "Steady Shot", default = true, tooltip = "Use Steady Shot as filler" },
                { key = "use_arcane_shot", type = "checkbox", label = "Arcane Shot", default = true, tooltip = "Use Arcane Shot when moving" },
                { key = "use_kill_shot", type = "checkbox", label = "Kill Shot", default = true, tooltip = "Use Kill Shot on low HP targets" },
            }
        },
        {
            name = "Cooldowns",
            settings = {
                { key = "use_rapid_fire", type = "checkbox", label = "Rapid Fire", default = true, tooltip = "Use Rapid Fire cooldown" },
                { key = "use_readiness", type = "checkbox", label = "Readiness", default = true, tooltip = "Use Readiness to reset cooldowns" },
            }
        },
        {
            name = "Defensive",
            settings = {
                { key = "use_feign_death", type = "checkbox", label = "Feign Death", default = true, tooltip = "Use Feign Death when aggro" },
                { key = "feign_hp", type = "slider", label = "Feign HP %", default = 25, min = 10, max = 50, tooltip = "HP threshold for Feign Death" },
                { key = "use_disengage", type = "checkbox", label = "Disengage", default = true, tooltip = "Use Disengage to escape" },
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
menu.use_aimed_shot = create_proxy("use_aimed_shot", true)
menu.use_chimera_shot = create_proxy("use_chimera_shot", true)
menu.use_serpent_sting = create_proxy("use_serpent_sting", true)
menu.use_steady_shot = create_proxy("use_steady_shot", true)
menu.use_arcane_shot = create_proxy("use_arcane_shot", true)
menu.use_kill_shot = create_proxy("use_kill_shot", true)
menu.use_rapid_fire = create_proxy("use_rapid_fire", true)
menu.use_readiness = create_proxy("use_readiness", true)
menu.use_feign_death = create_proxy("use_feign_death", true)
menu.feign_hp = create_proxy("feign_hp", 25)
menu.use_disengage = create_proxy("use_disengage", true)
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
        print("|cFF00FF00[EAX MM]|r Rotation enabled")
    end,
    on_disabled = function()
        print("|cFF00FF00[EAX MM]|r Rotation disabled")
    end,
    is_valid = function()
        local me = core.object_manager and core.object_manager.get_local_player()
        if not me then return false end
        return me:get_class() == 3  -- Hunter class ID
    end
}

-- ============================================================================
-- REGISTRATION
-- ============================================================================
local me = core.object_manager and core.object_manager.get_local_player()
if me and me:get_class() == 3 then
    unified.register_rotation("Hunter", "Marksmanship", MENU_DEF, callbacks)
end

return menu
