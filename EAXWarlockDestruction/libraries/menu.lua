-- EAX Warlock Destruction | libraries/menu.lua | Project Sylvanas
local unified = require("EAX_Unified/menu")
if not unified then error("[EAX Warlock Destruction] EAX_Unified/menu not found!") end

local ROTATION_KEY = "warlock_destruction"
local menu = {}

local MENU_DEF = {
    categories = {
        {
            name = "Rotation",
            settings = {
                { key = "use_immolate",           type = "checkbox", label = "Immolate",           default = true,  tooltip = "Core fire DoT — always maintain" },
                { key = "use_conflagrate",        type = "checkbox", label = "Conflagrate",        default = true,  tooltip = "Instant fire nuke on Immolate target" },
                { key = "use_incinerate",         type = "checkbox", label = "Incinerate",         default = true,  tooltip = "Primary filler — buffed by Immolate" },
                { key = "use_shadow_bolt",        type = "checkbox", label = "Shadow Bolt",        default = true,  tooltip = "Fallback filler if Incinerate unavailable" },
                { key = "use_curse_of_agony",     type = "checkbox", label = "Curse of Agony",     default = true },
                { key = "use_curse_of_elements",  type = "checkbox", label = "Curse of Elements",  default = false },
                { key = "use_soul_fire",          type = "checkbox", label = "Soul Fire",          default = true,  tooltip = "Backdraft proc consumer" },
                { key = "use_shadowburn",         type = "checkbox", label = "Shadowburn",         default = true,  tooltip = "Execute range instant" },
                { key = "mode",                   type = "combo",    label = "Priority Mode",      default = 1, options = {"Single Target", "AoE", "Chaos Bolt"} },
            },
        },
        {
            name = "Pet",
            settings = {
                { key = "use_summon_pet",  type = "checkbox", label = "Auto Summon Pet", default = true },
                { key = "preferred_pet",  type = "combo",    label = "Preferred Pet",   default = 1, options = {"Imp", "Succubus", "Felhunter", "Felguard"} },
                { key = "use_soulstone",  type = "checkbox", label = "Soulstone",       default = true },
            },
        },
        {
            name = "Sustain",
            settings = {
                { key = "use_life_tap",           type = "checkbox", label = "Life Tap",           default = true },
                { key = "life_tap_mana_pct",      type = "slider",   label = "Life Tap Mana %",    default = 60, min = 10, max = 90, suffix = "%" },
                { key = "life_tap_hp_pct",        type = "slider",   label = "Life Tap HP Floor %",default = 30, min = 10, max = 60, suffix = "%" },
                { key = "use_demon_armor",        type = "checkbox", label = "Demon Armor",        default = true },
                { key = "use_fel_armor",          type = "checkbox", label = "Fel Armor",          default = false },
                { key = "use_healthstone",        type = "checkbox", label = "Healthstone",        default = true },
                { key = "healthstone_hp_pct",     type = "slider",   label = "Healthstone HP %",   default = 35, min = 10, max = 60, suffix = "%" },
                { key = "use_create_healthstone", type = "checkbox", label = "Create Healthstone OOC", default = true },
            },
        },
        {
            name = "Cooldowns",
            settings = {
                { key = "use_death_coil", type = "checkbox", label = "Death Coil",     default = true },
                { key = "use_racial",     type = "checkbox", label = "Racial Ability", default = true },
                { key = "cd_min_ttd",     type = "slider",   label = "Min TTD for CDs (s)", default = 10, min = 5, max = 30 },
            },
        },
        {
            name = "System",
            settings = {
                { key = "debug", type = "checkbox", label = "Debug Mode", default = false },
            },
        },
    },
}

local callbacks = {
    on_enabled  = function() print("|cFFFF4411[EAX Destruction]|r Rotation ENABLED") end,
    on_disabled = function() print("|cFFFF4411[EAX Destruction]|r Rotation disabled") end,
}

unified.register_rotation("Warlock", "Destruction", MENU_DEF, callbacks)

function menu.is_enabled()       return unified.is_rotation_active(ROTATION_KEY) end
function menu.get_setting(k, d)  return unified.get_setting(ROTATION_KEY, k, d) end
function menu.set_setting(k, v)  unified.set_setting(ROTATION_KEY, k, v) end
function menu.toggle_menu()      if unified.toggle_menu then unified.toggle_menu() end end

local function proxy(key, default)
    return { is_checked = function() return menu.get_setting(key, default) end,
             get_state  = function() return menu.get_setting(key, default) end,
             get        = function() return menu.get_setting(key, default) end }
end

menu.enabled                  = { is_checked = menu.is_enabled, get_state = menu.is_enabled }
menu.use_immolate             = proxy("use_immolate",            true)
menu.use_conflagrate          = proxy("use_conflagrate",         true)
menu.use_incinerate           = proxy("use_incinerate",          true)
menu.use_shadow_bolt          = proxy("use_shadow_bolt",         true)
menu.use_curse_of_agony       = proxy("use_curse_of_agony",      true)
menu.use_curse_of_elements    = proxy("use_curse_of_elements",   false)
menu.use_soul_fire            = proxy("use_soul_fire",           true)
menu.use_shadowburn           = proxy("use_shadowburn",          true)
menu.mode                     = proxy("mode",                    1)
menu.use_summon_pet           = proxy("use_summon_pet",          true)
menu.preferred_pet            = proxy("preferred_pet",           1)
menu.use_soulstone            = proxy("use_soulstone",           true)
menu.use_life_tap             = proxy("use_life_tap",            true)
menu.life_tap_mana_pct        = proxy("life_tap_mana_pct",       60)
menu.life_tap_hp_pct          = proxy("life_tap_hp_pct",         30)
menu.use_demon_armor          = proxy("use_demon_armor",         true)
menu.use_fel_armor            = proxy("use_fel_armor",           false)
menu.use_healthstone          = proxy("use_healthstone",         true)
menu.healthstone_hp_pct       = proxy("healthstone_hp_pct",      35)
menu.use_create_healthstone   = proxy("use_create_healthstone",  true)
menu.use_death_coil           = proxy("use_death_coil",          true)
menu.use_racial               = proxy("use_racial",              true)
menu.cd_min_ttd               = proxy("cd_min_ttd",              10)
menu.debug                    = proxy("debug",                   false)

-- ============================================================================
-- NATIVE ELEMENTS & RENDER HOOKS  (added by EAX v4 patch)
-- These are required by main.lua:
--   core.register_on_render_callback(menu.on_render)
--   core.register_on_render_menu_callback(menu.on_menu_render)
-- ============================================================================

-- Native keybind for enable toggle (persisted by PS, shown in control panel)
-- Value 7 = "Unbound". main.lua uses get_state() / set() on this.
local _enabled_keybind  = core.menu.keybind(7, false, "eax_warlock_destruction_enabled_kb")
local _toggle_key_elem  = core.menu.keybind(107, false, "eax_warlock_destruction_toggle_key")

-- Wrap keybind as menu.enabled so existing proxy is overridden with the real element
menu.enabled   = _enabled_keybind
menu.toggle_key = _toggle_key_elem

-- Native tree_node for the PS main menu entry
local _menu_tree = core.menu.tree_node()

-- on_menu_render: called by core.register_on_render_menu_callback
-- Renders a collapsible node in the PS main menu.
function menu.on_menu_render()
    _menu_tree:render("EAX Destruction", function()
        _enabled_keybind:render("Enable EAX Destruction", "Toggle rotation on/off")
        _toggle_key_elem:render("Toggle Menu Key", "Hotkey to show/hide the settings window")
    end)
end

-- on_render: called by core.register_on_render_callback
-- Drives the AstroUI floating window via EAX_Unified/menu NS.on_render()
function menu.on_render()
    -- The unified system owns the window; just forward the render tick.
    -- Numpad+ toggle is also handled there.
    local unified_ok, unified_mod = pcall(require, "EAX_Unified/menu")
    if unified_ok and unified_mod and unified_mod._on_render_tick then
        unified_mod._on_render_tick()
    end
end

-- Register render callbacks
core.register_on_render_callback(menu.on_render)
core.register_on_render_menu_callback(menu.on_menu_render)

return menu
