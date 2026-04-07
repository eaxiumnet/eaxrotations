-- EAX Warrior Fury | libraries/menu.lua | Project Sylvanas
local unified = require("EAX_Unified/menu")
if not unified then error("[EAX Warrior Fury] EAX_Unified/menu not found!") end

local ROTATION_KEY = "warrior_fury"
local menu = {}

local MENU_DEF = {
    categories = {
        {
            name = "Rotation",
            settings = {
                { key = "use_bloodthirst",       type = "checkbox", label = "Bloodthirst",       default = true,  tooltip = "Primary damage + rage ability" },
                { key = "use_whirlwind",         type = "checkbox", label = "Whirlwind",         default = true,  tooltip = "Off-hand proc cleave" },
                { key = "use_slam",              type = "checkbox", label = "Slam",              default = true,  tooltip = "Filler — use with Bloodsurge" },
                { key = "use_rampage",           type = "checkbox", label = "Rampage",           default = true,  tooltip = "Maintain AP buff" },
                { key = "rampage_refresh_threshold", type = "slider", label = "Rampage Refresh (s)", default = 2, min = 1, max = 5, tooltip = "Re-apply Rampage when this many seconds remain" },
                { key = "use_execute",           type = "checkbox", label = "Execute",           default = true },
                { key = "execute_use_bt",        type = "checkbox", label = "BT in Execute",     default = true,  tooltip = "Keep using Bloodthirst in execute range" },
                { key = "execute_use_ww",        type = "checkbox", label = "WW in Execute",     default = false },
                { key = "use_heroic_strike",     type = "checkbox", label = "Heroic Strike",     default = true },
                { key = "hs_rage_threshold",     type = "slider",   label = "Heroic Strike Rage",default = 60, min = 40, max = 100 },
                { key = "hs_trick",              type = "checkbox", label = "HS Queue Trick",    default = true },
                { key = "use_hamstring",         type = "checkbox", label = "Hamstring",         default = false, tooltip = "Kite / PvP only" },
                { key = "use_battle_shout",      type = "checkbox", label = "Battle Shout",      default = true },
                { key = "use_commanding_shout",  type = "checkbox", label = "Commanding Shout",  default = false },
                { key = "use_sweeping_strikes",  type = "checkbox", label = "Sweeping Strikes",  default = true },
            },
        },
        {
            name = "Cooldowns",
            settings = {
                { key = "use_death_wish",     type = "checkbox", label = "Death Wish",    default = true },
                { key = "use_recklessness",   type = "checkbox", label = "Recklessness",  default = true },
                { key = "use_berserker_rage", type = "checkbox", label = "Berserker Rage",default = true },
                { key = "use_interrupt",      type = "checkbox", label = "Pummel",        default = true },
            },
        },
        {
            name = "PvP / Utility",
            settings = {
                { key = "pvp_cc_break_check",     type = "checkbox", label = "CC Break Check",  default = false },
                { key = "cancel_pws",             type = "checkbox", label = "Cancel PW:Shield",default = false },
                { key = "cancel_bop",             type = "checkbox", label = "Cancel BOP",      default = true },
                { key = "cancelaura_hp_threshold",type = "slider",   label = "Cancel Aura HP %",default = 50, min = 10, max = 90, suffix = "%" },
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
    on_enabled  = function() print("|cFFE63B3B[EAX Fury]|r Rotation ENABLED") end,
    on_disabled = function() print("|cFFE63B3B[EAX Fury]|r Rotation disabled") end,
}

unified.register_rotation("Warrior", "Fury", MENU_DEF, callbacks)

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
menu.use_bloodthirst          = proxy("use_bloodthirst",         true)
menu.use_whirlwind            = proxy("use_whirlwind",           true)
menu.use_slam                 = proxy("use_slam",                true)
menu.use_rampage              = proxy("use_rampage",             true)
menu.rampage_refresh_threshold= proxy("rampage_refresh_threshold",2)
menu.use_execute              = proxy("use_execute",             true)
menu.execute_use_bt           = proxy("execute_use_bt",          true)
menu.execute_use_ww           = proxy("execute_use_ww",          false)
menu.execute_use_hs           = proxy("execute_use_hs",          true)
menu.use_heroic_strike        = proxy("use_heroic_strike",       true)
menu.hs_rage_threshold        = proxy("hs_rage_threshold",       60)
menu.hs_trick                 = proxy("hs_trick",                true)
menu.use_hamstring            = proxy("use_hamstring",           false)
menu.use_battle_shout         = proxy("use_battle_shout",        true)
menu.use_commanding_shout     = proxy("use_commanding_shout",    false)
menu.use_sweeping_strikes     = proxy("use_sweeping_strikes",    true)
menu.use_death_wish           = proxy("use_death_wish",          true)
menu.use_recklessness         = proxy("use_recklessness",        true)
menu.use_berserker_rage       = proxy("use_berserker_rage",      true)
menu.use_interrupt            = proxy("use_interrupt",           true)
menu.pvp_cc_break_check       = proxy("pvp_cc_break_check",      false)
menu.cancel_pws               = proxy("cancel_pws",              false)
menu.cancel_bop               = proxy("cancel_bop",              true)
menu.cancelaura_hp_threshold  = proxy("cancelaura_hp_threshold", 50)
menu.debug                    = proxy("debug",                   false)

-- ============================================================================
-- NATIVE ELEMENTS & RENDER HOOKS  (added by EAX v4 patch)
-- These are required by main.lua:
--   core.register_on_render_callback(menu.on_render)
--   core.register_on_render_menu_callback(menu.on_menu_render)
-- ============================================================================

-- Native keybind for enable toggle (persisted by PS, shown in control panel)
-- Value 7 = "Unbound". main.lua uses get_state() / set() on this.
local _enabled_keybind  = core.menu.keybind(7, false, "eax_warrior_fury_enabled_kb")
local _toggle_key_elem  = core.menu.keybind(107, false, "eax_warrior_fury_toggle_key")

-- Wrap keybind as menu.enabled so existing proxy is overridden with the real element
menu.enabled   = _enabled_keybind
menu.toggle_key = _toggle_key_elem

-- Native tree_node for the PS main menu entry
local _menu_tree = core.menu.tree_node()

-- on_menu_render: called by core.register_on_render_menu_callback
-- Renders a collapsible node in the PS main menu.
function menu.on_menu_render()
    _menu_tree:render("EAX Fury", function()
        _enabled_keybind:render("Enable EAX Fury", "Toggle rotation on/off")
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

-- Register render callbacks for menu system
core.register_on_render_callback(menu.on_render)
core.register_on_render_menu_callback(menu.on_menu_render)

return menu
