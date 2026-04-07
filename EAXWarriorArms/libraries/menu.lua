-- EAX Warrior Arms | libraries/menu.lua | Project Sylvanas
local unified = require("EAX_Unified/menu")
if not unified then error("[EAX Warrior Arms] EAX_Unified/menu not found!") end

local ROTATION_KEY = "warrior_arms"
local menu = {}

local MENU_DEF = {
    categories = {
        {
            name = "Rotation",
            settings = {
                { key = "use_mortal_strike",     type = "checkbox", label = "Mortal Strike",     default = true,  tooltip = "Primary finisher" },
                { key = "use_overpower",         type = "checkbox", label = "Overpower",         default = true,  tooltip = "Use on dodge procs" },
                { key = "use_rend",              type = "checkbox", label = "Rend",              default = true,  tooltip = "Maintain Rend bleed" },
                { key = "use_slam",              type = "checkbox", label = "Slam",              default = true,  tooltip = "Filler on reset procs" },
                { key = "use_whirlwind",         type = "checkbox", label = "Whirlwind",         default = true,  tooltip = "AoE / rage dump" },
                { key = "use_thunder_clap",      type = "checkbox", label = "Thunder Clap",      default = true,  tooltip = "AoE slow + AP debuff" },
                { key = "use_demo_shout",        type = "checkbox", label = "Demoralising Shout",default = true,  tooltip = "AP debuff on targets" },
                { key = "use_battle_shout",      type = "checkbox", label = "Battle Shout",      default = true,  tooltip = "Maintain Battle Shout buff" },
                { key = "use_commanding_shout",  type = "checkbox", label = "Commanding Shout",  default = false, tooltip = "Use instead of Battle Shout" },
                { key = "use_sweeping_strikes",  type = "checkbox", label = "Sweeping Strikes",  default = true,  tooltip = "Cleave 2 targets" },
                { key = "use_execute",           type = "checkbox", label = "Execute",           default = true,  tooltip = "Use in execute phase" },
                { key = "execute_use_ms",        type = "checkbox", label = "MS in Execute",     default = false, tooltip = "Keep using Mortal Strike in execute range" },
                { key = "execute_use_ww",        type = "checkbox", label = "WW in Execute",     default = false, tooltip = "Keep using Whirlwind in execute range" },
                { key = "hs_rage_threshold",     type = "slider",   label = "Heroic Strike Rage",default = 60, min = 40, max = 100, tooltip = "Use Heroic Strike above this rage" },
                { key = "hs_trick",              type = "checkbox", label = "HS Queue Trick",    default = true,  tooltip = "Queue HS to avoid rage capping" },
                { key = "slam_safety_buffer_ms", type = "slider",   label = "Slam Safety Buffer (ms)", default = 200, min = 50, max = 500, tooltip = "Slam cast safety window in milliseconds" },
            },
        },
        {
            name = "Cooldowns",
            settings = {
                { key = "use_death_wish",        type = "checkbox", label = "Death Wish",        default = true },
                { key = "use_recklessness",      type = "checkbox", label = "Recklessness",      default = true },
                { key = "use_berserker_rage",    type = "checkbox", label = "Berserker Rage",    default = true },
                { key = "use_interrupt",         type = "checkbox", label = "Pummel",            default = true,  tooltip = "Auto-interrupt casts" },
            },
        },
        {
            name = "PvP / Utility",
            settings = {
                { key = "pvp_cc_break_check",    type = "checkbox", label = "CC Break Check",    default = false, tooltip = "Avoid AoE that breaks nearby CC" },
                { key = "cancel_pws",            type = "checkbox", label = "Cancel PW:Shield",  default = false, tooltip = "Cancel Power Word: Shield for Enrage" },
                { key = "cancel_bop",            type = "checkbox", label = "Cancel BOP",        default = true,  tooltip = "Cancel Blessing of Protection" },
                { key = "cancelaura_hp_threshold",type = "slider",  label = "Cancel Aura HP %",  default = 50, min = 10, max = 90, suffix = "%" },
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
    on_enabled  = function() print("|cFFC79C6E[EAX Arms]|r Rotation ENABLED") end,
    on_disabled = function() print("|cFFC79C6E[EAX Arms]|r Rotation disabled") end,
}

unified.register_rotation("Warrior", "Arms", MENU_DEF, callbacks)

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
menu.use_mortal_strike        = proxy("use_mortal_strike",      true)
menu.use_overpower            = proxy("use_overpower",          true)
menu.use_rend                 = proxy("use_rend",               true)
menu.use_slam                 = proxy("use_slam",               true)
menu.use_whirlwind            = proxy("use_whirlwind",          true)
menu.use_thunder_clap         = proxy("use_thunder_clap",       true)
menu.use_demo_shout           = proxy("use_demo_shout",         true)
menu.use_battle_shout         = proxy("use_battle_shout",       true)
menu.use_commanding_shout     = proxy("use_commanding_shout",   false)
menu.use_sweeping_strikes     = proxy("use_sweeping_strikes",   true)
menu.use_execute              = proxy("use_execute",            true)
menu.execute_use_ms           = proxy("execute_use_ms",         false)
menu.execute_use_ww           = proxy("execute_use_ww",         false)
menu.execute_use_hs           = proxy("execute_use_hs",         true)
menu.hs_rage_threshold        = proxy("hs_rage_threshold",      60)
menu.hs_trick                 = proxy("hs_trick",               true)
menu.slam_safety_buffer_ms    = proxy("slam_safety_buffer_ms",  200)
menu.use_death_wish           = proxy("use_death_wish",         true)
menu.use_recklessness         = proxy("use_recklessness",       true)
menu.use_berserker_rage       = proxy("use_berserker_rage",     true)
menu.use_interrupt            = proxy("use_interrupt",          true)
menu.pvp_cc_break_check       = proxy("pvp_cc_break_check",     false)
menu.cancel_pws               = proxy("cancel_pws",             false)
menu.cancel_bop               = proxy("cancel_bop",             true)
menu.cancelaura_hp_threshold  = proxy("cancelaura_hp_threshold",50)
menu.debug                    = proxy("debug",                  false)

-- ============================================================================
-- NATIVE ELEMENTS & RENDER HOOKS  (added by EAX v4 patch)
-- These are required by main.lua:
--   core.register_on_render_callback(menu.on_render)
--   core.register_on_render_menu_callback(menu.on_menu_render)
-- ============================================================================

-- Native keybind for enable toggle (persisted by PS, shown in control panel)
-- Value 7 = "Unbound". main.lua uses get_state() / set() on this.
local _enabled_keybind  = core.menu.keybind(7, false, "eax_warrior_arms_enabled_kb")
local _toggle_key_elem  = core.menu.keybind(107, false, "eax_warrior_arms_toggle_key")

-- Wrap keybind as menu.enabled so existing proxy is overridden with the real element
menu.enabled   = _enabled_keybind
menu.toggle_key = _toggle_key_elem

-- Native tree_node for the PS main menu entry
local _menu_tree = core.menu.tree_node()

-- on_menu_render: called by core.register_on_render_menu_callback
-- Renders a collapsible node in the PS main menu.
function menu.on_menu_render()
    _menu_tree:render("EAX Arms", function()
        _enabled_keybind:render("Enable EAX Arms", "Toggle rotation on/off")
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

-- Register render callbacks (REQUIRED for menu rendering)
core.register_on_render_callback(menu.on_render)
core.register_on_render_menu_callback(menu.on_menu_render)

return menu
