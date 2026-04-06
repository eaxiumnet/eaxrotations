-- EAX Hunter Beast Mastery | menu.lua | Project Sylvanas
-- Uses unified EAX menu system with core.menu API

local unified = require("EAX_Unified/menu")
if not unified then
    error("[EAX Hunter Beast Mastery] EAX_Unified menu system not available!")
end

local menu = {}
local ROTATION_KEY = "hunter_beast_mastery"

-- ============================================================================
-- MENU DEFINITION
-- ============================================================================
local MENU_DEF = {
    categories = {
        {
            name = "Rotation",
            settings = {
                { key = "use_kill_command", type = "checkbox", label = "Kill Command", default = true, tooltip = "Use Kill Command on cooldown" },
                { key = "use_bestial_wrath", type = "checkbox", label = "Bestial Wrath", default = true, tooltip = "Use Bestial Wrath cooldown" },
                { key = "use_serpent_sting", type = "checkbox", label = "Serpent Sting", default = true, tooltip = "Maintain Serpent Sting DoT" },
                { key = "use_arcane_shot", type = "checkbox", label = "Arcane Shot", default = true, tooltip = "Use Arcane Shot as focus dump" },
                { key = "use_steady_shot", type = "checkbox", label = "Steady Shot", default = true, tooltip = "Use Steady Shot to build focus" },
                { key = "use_multi_shot", type = "checkbox", label = "Multi-Shot", default = true, tooltip = "Use Multi-Shot for AoE" },
            }
        },
        {
            name = "Pet",
            settings = {
                { key = "use_mend_pet", type = "checkbox", label = "Mend Pet", default = true, tooltip = "Heal pet with Mend Pet" },
                { key = "mend_pet_hp", type = "slider", label = "Mend Pet HP %", default = 50, min = 20, max = 80, tooltip = "Pet HP threshold for Mend Pet" },
                { key = "use_intimidation", type = "checkbox", label = "Intimidation", default = true, tooltip = "Use Intimidation stun" },
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
menu.use_kill_command = create_proxy("use_kill_command", true)
menu.use_bestial_wrath = create_proxy("use_bestial_wrath", true)
menu.use_serpent_sting = create_proxy("use_serpent_sting", true)
menu.use_arcane_shot = create_proxy("use_arcane_shot", true)
menu.use_steady_shot = create_proxy("use_steady_shot", true)
menu.use_multi_shot = create_proxy("use_multi_shot", true)
menu.use_mend_pet = create_proxy("use_mend_pet", true)
menu.mend_pet_hp = create_proxy("mend_pet_hp", 50)
menu.use_intimidation = create_proxy("use_intimidation", true)
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
        print("|cFF00FF00[EAX BM]|r Rotation enabled")
    end,
    on_disabled = function()
        print("|cFF00FF00[EAX BM]|r Rotation disabled")
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
    unified.register_rotation("Hunter", "Beast Mastery", MENU_DEF, callbacks)
end

return menu
