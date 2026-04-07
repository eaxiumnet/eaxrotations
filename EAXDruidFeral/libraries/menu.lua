-- EAX Druid Feral | libraries/menu.lua | Project Sylvanas
local unified = require("EAX_Unified/menu")
if not unified then error("[EAX Druid Feral] EAX_Unified/menu not found!") end

local ROTATION_KEY = "druid_feral"
local menu = {}

local MENU_DEF = {
    categories = {
        {
            name = "Rotation",
            settings = {
                { key = "use_rip",                type = "checkbox", label = "Rip",              default = true,  tooltip = "Primary finisher — bleed DoT" },
                { key = "use_rake",               type = "checkbox", label = "Rake",             default = true,  tooltip = "Maintain Rake DoT" },
                { key = "use_shred",              type = "checkbox", label = "Shred",            default = true,  tooltip = "Behind target — combo builder" },
                { key = "use_mangle",             type = "checkbox", label = "Mangle",           default = true,  tooltip = "Maintain Mangle debuff" },
                { key = "use_ferocious_bite",     type = "checkbox", label = "Ferocious Bite",   default = true,  tooltip = "Execute-range finisher" },
                { key = "use_tigers_fury",        type = "checkbox", label = "Tiger's Fury",     default = true,  tooltip = "Energy/damage cooldown" },
                { key = "use_berserk",            type = "checkbox", label = "Berserk",          default = true,  tooltip = "Major DPS cooldown" },
                { key = "use_prowl_opener",       type = "checkbox", label = "Prowl Opener",     default = true,  tooltip = "Stealth into Ravage for opener" },
                { key = "use_faerie_fire",        type = "checkbox", label = "Faerie Fire",      default = true,  tooltip = "Maintain armor debuff" },
                { key = "cat_tick_optimization",  type = "checkbox", label = "Tick Optimisation",default = true,  tooltip = "Delay Mangle to avoid dead GCDs at tick boundary" },
            },
        },
        {
            name = "Powershift",
            settings = {
                { key = "auto_powershift",        type = "checkbox", label = "Auto Powershift",  default = true,  tooltip = "Drop & re-enter Cat Form for energy" },
                { key = "powershift_min_mana",    type = "slider",   label = "Min Mana %",       default = 25, min = 10, max = 50, suffix = "%", tooltip = "Only powershift above this mana %" },
            },
        },
        {
            name = "Defensive",
            settings = {
                { key = "use_barkskin",   type = "checkbox", label = "Barkskin",      default = true,  tooltip = "17% DR — use on cooldown when taking damage" },
                { key = "barkskin_hp",    type = "slider",   label = "Barkskin HP %", default = 30, min = 10, max = 60, suffix = "%", tooltip = "HP threshold for Barkskin" },
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
    on_enabled  = function() print("|cFFFF7700[EAX Feral]|r Rotation ENABLED") end,
    on_disabled = function() print("|cFFFF7700[EAX Feral]|r Rotation disabled") end,
}

unified.register_rotation("Druid", "Feral", MENU_DEF, callbacks)

function menu.is_enabled()       return unified.is_rotation_active(ROTATION_KEY) end
function menu.get_setting(k, d)  return unified.get_setting(ROTATION_KEY, k, d) end
function menu.set_setting(k, v)  unified.set_setting(ROTATION_KEY, k, v) end
function menu.toggle_menu()      if unified.toggle_menu then unified.toggle_menu() end end

local function proxy(key, default)
    return { is_checked = function() return menu.get_setting(key, default) end,
             get_state  = function() return menu.get_setting(key, default) end,
             get        = function() return menu.get_setting(key, default) end }
end

menu.enabled                = { is_checked = menu.is_enabled, get_state = menu.is_enabled }
menu.use_rip                = proxy("use_rip",               true)
menu.use_rake               = proxy("use_rake",              true)
menu.use_shred              = proxy("use_shred",             true)
menu.use_mangle             = proxy("use_mangle",            true)
menu.use_ferocious_bite     = proxy("use_ferocious_bite",    true)
menu.use_tigers_fury        = proxy("use_tigers_fury",       true)
menu.use_berserk            = proxy("use_berserk",           true)
menu.use_prowl_opener       = proxy("use_prowl_opener",      true)
menu.use_faerie_fire        = proxy("use_faerie_fire",       true)
menu.cat_tick_optimization  = proxy("cat_tick_optimization", true)
menu.auto_powershift        = proxy("auto_powershift",       true)
menu.powershift_min_mana    = proxy("powershift_min_mana",   25)
menu.use_barkskin           = proxy("use_barkskin",          true)
menu.barkskin_hp            = proxy("barkskin_hp",           30)
menu.debug                  = proxy("debug",                 false)

-- ============================================================================
-- NATIVE ELEMENTS & RENDER HOOKS  (added by EAX v4 patch)
-- These are required by main.lua:
--   core.register_on_render_callback(menu.on_render)
--   core.register_on_render_menu_callback(menu.on_menu_render)
-- ============================================================================

-- Native keybind for enable toggle (persisted by PS, shown in control panel)
-- Value 7 = "Unbound". main.lua uses get_state() / set() on this.
local _enabled_keybind  = core.menu.keybind(7, false, "eax_druid_feral_enabled_kb")
local _toggle_key_elem  = core.menu.keybind(107, false, "eax_druid_feral_toggle_key")

-- Wrap keybind as menu.enabled so existing proxy is overridden with the real element
menu.enabled   = _enabled_keybind
menu.toggle_key = _toggle_key_elem

-- Native tree_node for the PS main menu entry
local _menu_tree = core.menu.tree_node()

-- on_menu_render: called by core.register_on_render_menu_callback
-- Renders a collapsible node in the PS main menu.
function menu.on_menu_render()
    _menu_tree:render("EAX Feral", function()
        _enabled_keybind:render("Enable EAX Feral", "Toggle rotation on/off")
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
