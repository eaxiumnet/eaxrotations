-- EAX Druid Bear | libraries/menu.lua | Project Sylvanas
local unified = require("EAX_Unified/menu")
if not unified then error("[EAX Druid Bear] EAX_Unified/menu not found!") end

local ROTATION_KEY = "druid_bear"
local menu = {}

local MENU_DEF = {
    categories = {
        {
            name = "Rotation",
            settings = {
                { key = "use_mangle",         type = "checkbox", label = "Mangle",         default = true,  tooltip = "Primary threat + damage ability" },
                { key = "use_lacerate",       type = "checkbox", label = "Lacerate",       default = true,  tooltip = "Bleed stack — maintain on boss" },
                { key = "use_swipe",          type = "checkbox", label = "Swipe",          default = true,  tooltip = "AoE threat on multi-target" },
                { key = "use_maul",           type = "checkbox", label = "Maul",           default = true,  tooltip = "Rage dump — passive on next auto" },
                { key = "use_bash",           type = "checkbox", label = "Bash",           default = true,  tooltip = "Stun interrupt" },
                { key = "use_faerie_fire",    type = "checkbox", label = "Faerie Fire",    default = true,  tooltip = "Armor debuff + ranged pull" },
                { key = "swipe_min_mobs",     type = "slider",   label = "Swipe Min Mobs", default = 2, min = 2, max = 8, tooltip = "Use Swipe when this many enemies in range" },
            },
        },
        {
            name = "Defensive",
            settings = {
                { key = "use_frenzied_regen",  type = "checkbox", label = "Frenzied Regen",    default = true,  tooltip = "Emergency self-heal" },
                { key = "frenzied_regen_hp",   type = "slider",   label = "Frenzied Regen HP %",default = 25, min = 5, max = 60, suffix = "%" },
                { key = "use_barkskin",        type = "checkbox", label = "Barkskin",           default = true },
                { key = "barkskin_hp",         type = "slider",   label = "Barkskin HP %",      default = 30, min = 5, max = 60, suffix = "%" },
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
    on_enabled  = function() print("|cFF8B4513[EAX Bear]|r Rotation ENABLED") end,
    on_disabled = function() print("|cFF8B4513[EAX Bear]|r Rotation disabled") end,
}

unified.register_rotation("Druid", "Bear", MENU_DEF, callbacks)

function menu.is_enabled()       return unified.is_rotation_active(ROTATION_KEY) end
function menu.get_setting(k, d)  return unified.get_setting(ROTATION_KEY, k, d) end
function menu.set_setting(k, v)  unified.set_setting(ROTATION_KEY, k, v) end
function menu.toggle_menu()      if unified.toggle_menu then unified.toggle_menu() end end

local function proxy(key, default)
    return { is_checked = function() return menu.get_setting(key, default) end,
             get_state  = function() return menu.get_setting(key, default) end,
             get        = function() return menu.get_setting(key, default) end }
end

menu.enabled              = { is_checked = menu.is_enabled, get_state = menu.is_enabled }
menu.use_mangle           = proxy("use_mangle",          true)
menu.use_lacerate         = proxy("use_lacerate",        true)
menu.use_swipe            = proxy("use_swipe",           true)
menu.use_maul             = proxy("use_maul",            true)
menu.use_bash             = proxy("use_bash",            true)
menu.use_faerie_fire      = proxy("use_faerie_fire",     true)
menu.swipe_min_mobs       = proxy("swipe_min_mobs",      2)
menu.use_frenzied_regen   = proxy("use_frenzied_regen",  true)
menu.frenzied_regen_hp    = proxy("frenzied_regen_hp",   25)
menu.use_barkskin         = proxy("use_barkskin",        true)
menu.barkskin_hp          = proxy("barkskin_hp",         30)
menu.debug                = proxy("debug",               false)

-- ============================================================================
-- NATIVE ELEMENTS & RENDER HOOKS  (added by EAX v4 patch)
-- These are required by main.lua:
--   core.register_on_render_callback(menu.on_render)
--   core.register_on_render_menu_callback(menu.on_menu_render)
-- ============================================================================

-- Native keybind for enable toggle (persisted by PS, shown in control panel)
-- Value 7 = "Unbound". main.lua uses get_state() / set() on this.
local _enabled_keybind  = core.menu.keybind(7, false, "eax_druid_bear_enabled_kb")
local _toggle_key_elem  = core.menu.keybind(107, false, "eax_druid_bear_toggle_key")

-- Wrap keybind as menu.enabled so existing proxy is overridden with the real element
menu.enabled   = _enabled_keybind
menu.toggle_key = _toggle_key_elem

-- Native tree_node for the PS main menu entry
local _menu_tree = core.menu.tree_node()

-- on_menu_render: called by core.register_on_render_menu_callback
-- Renders a collapsible node in the PS main menu.
function menu.on_menu_render()
    _menu_tree:render("EAX Bear", function()
        _enabled_keybind:render("Enable EAX Bear", "Toggle rotation on/off")
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
