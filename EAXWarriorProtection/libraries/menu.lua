-- EAX Warrior Protection | libraries/menu.lua | Project Sylvanas
local unified = require("EAX_Unified/menu")
if not unified then error("[EAX Warrior Prot] EAX_Unified/menu not found!") end

local ROTATION_KEY = "warrior_protection"
local menu = {}

local MENU_DEF = {
    categories = {
        {
            name = "Rotation",
            settings = {
                { key = "use_devastate",       type = "checkbox", label = "Devastate",         default = true,  tooltip = "Primary filler — applies Sunder" },
                { key = "use_heroic_strike",   type = "checkbox", label = "Heroic Strike",     default = true,  tooltip = "Rage dump" },
                { key = "hs_rage_threshold",   type = "slider",   label = "HS Rage Threshold", default = 60, min = 40, max = 100, tooltip = "Queue HS above this rage" },
                { key = "use_execute",         type = "checkbox", label = "Execute",           default = true },
                { key = "sunder_max_stacks",   type = "slider",   label = "Sunder Max Stacks", default = 5, min = 1, max = 5, tooltip = "Stop Sunder at this stack count" },
                { key = "use_battle_shout",    type = "checkbox", label = "Battle Shout",      default = true },
                { key = "use_commanding_shout",type = "checkbox", label = "Commanding Shout",  default = false },
            },
        },
        {
            name = "Threat / AoE",
            settings = {
                { key = "use_demo_shout",      type = "checkbox", label = "Demoralising Shout",default = true,  tooltip = "AP debuff" },
                { key = "demo_min_mobs",       type = "slider",   label = "Demo Shout Min Mobs",default = 1, min = 1, max = 5 },
                { key = "demo_threat_lead",    type = "slider",   label = "Demo Threat Lead %", default = 110, min = 100, max = 130, tooltip = "Only use when at this threat %" },
                { key = "use_thunder_clap",    type = "checkbox", label = "Thunder Clap",       default = true },
                { key = "tc_min_mobs",         type = "slider",   label = "TC Min Mobs",        default = 2, min = 1, max = 8 },
                { key = "tc_threat_lead",      type = "slider",   label = "TC Threat Lead %",   default = 110, min = 100, max = 130 },
                { key = "use_challenging_shout",type = "checkbox",label = "Challenging Shout",  default = true,  tooltip = "Emergency AoE taunt" },
                { key = "cshout_min_trash",    type = "slider",   label = "CS Min Trash Mobs",  default = 3, min = 1, max = 10 },
                { key = "cshout_min_elites",   type = "slider",   label = "CS Min Elites",      default = 2, min = 1, max = 5 },
                { key = "cshout_min_bosses",   type = "slider",   label = "CS Min Bosses",      default = 1, min = 1, max = 3 },
                { key = "shield_block_threat_lead", type = "slider", label = "Shield Block Threat Lead %", default = 110, min = 100, max = 130 },
                { key = "no_taunt",            type = "checkbox", label = "Disable Taunt",      default = false, tooltip = "Disable auto-taunt (e.g. BG/arena)" },
            },
        },
        {
            name = "Defensive",
            settings = {
                { key = "shield_wall_hp",  type = "slider",   label = "Shield Wall HP %",  default = 20, min = 5, max = 50, suffix = "%" },
                { key = "last_stand_hp",   type = "slider",   label = "Last Stand HP %",   default = 15, min = 5, max = 40, suffix = "%" },
            },
        },
        {
            name = "PvP / Utility",
            settings = {
                { key = "pvp_cc_break_check",    type = "checkbox", label = "CC Break Check",  default = false },
                { key = "cancel_pws",            type = "checkbox", label = "Cancel PW:Shield",default = false },
                { key = "cancel_bop",            type = "checkbox", label = "Cancel BOP",      default = true },
                { key = "cancelaura_hp_threshold",type = "slider",  label = "Cancel Aura HP %",default = 50, min = 10, max = 90, suffix = "%" },
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
    on_enabled  = function() print("|cFFC79C6E[EAX Prot Warrior]|r Rotation ENABLED") end,
    on_disabled = function() print("|cFFC79C6E[EAX Prot Warrior]|r Rotation disabled") end,
}

unified.register_rotation("Warrior", "Protection", MENU_DEF, callbacks)

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
menu.use_devastate            = proxy("use_devastate",          true)
menu.use_heroic_strike        = proxy("use_heroic_strike",      true)
menu.hs_rage_threshold        = proxy("hs_rage_threshold",      60)
menu.use_execute              = proxy("use_execute",            true)
menu.sunder_max_stacks        = proxy("sunder_max_stacks",      5)
menu.use_battle_shout         = proxy("use_battle_shout",       true)
menu.use_commanding_shout     = proxy("use_commanding_shout",   false)
menu.use_demo_shout           = proxy("use_demo_shout",         true)
menu.demo_min_mobs            = proxy("demo_min_mobs",          1)
menu.demo_threat_lead         = proxy("demo_threat_lead",       110)
menu.use_thunder_clap         = proxy("use_thunder_clap",       true)
menu.tc_min_mobs              = proxy("tc_min_mobs",            2)
menu.tc_threat_lead           = proxy("tc_threat_lead",         110)
menu.use_challenging_shout    = proxy("use_challenging_shout",  true)
menu.cshout_min_trash         = proxy("cshout_min_trash",       3)
menu.cshout_min_elites        = proxy("cshout_min_elites",      2)
menu.cshout_min_bosses        = proxy("cshout_min_bosses",      1)
menu.shield_block_threat_lead = proxy("shield_block_threat_lead",110)
menu.no_taunt                 = proxy("no_taunt",               false)
menu.shield_wall_hp           = proxy("shield_wall_hp",         20)
menu.last_stand_hp            = proxy("last_stand_hp",          15)
menu.pvp_cc_break_check       = proxy("pvp_cc_break_check",     false)
menu.cancel_pws               = proxy("cancel_pws",             false)
menu.cancel_bop               = proxy("cancel_bop",             true)
menu.cancelaura_hp_threshold  = proxy("cancelaura_hp_threshold",50)
menu.tab_max_mobs             = proxy("tab_max_mobs",           5)
menu.use_auto_tab             = proxy("use_auto_tab",           true)
menu.debug                    = proxy("debug",                  false)

-- ============================================================================
-- NATIVE ELEMENTS & RENDER HOOKS  (added by EAX v4 patch)
-- These are required by main.lua:
--   core.register_on_render_callback(menu.on_render)
--   core.register_on_render_menu_callback(menu.on_menu_render)
-- ============================================================================

-- Native keybind for enable toggle (persisted by PS, shown in control panel)
-- Value 7 = "Unbound". main.lua uses get_state() / set() on this.
local _enabled_keybind  = core.menu.keybind(7, false, "eax_warrior_protection_enabled_kb")
local _toggle_key_elem  = core.menu.keybind(107, false, "eax_warrior_protection_toggle_key")

-- Wrap keybind as menu.enabled so existing proxy is overridden with the real element
menu.enabled   = _enabled_keybind
menu.toggle_key = _toggle_key_elem

-- Native tree_node for the PS main menu entry
local _menu_tree = core.menu.tree_node()

-- on_menu_render: called by core.register_on_render_menu_callback
-- Renders a collapsible node in the PS main menu.
function menu.on_menu_render()
    _menu_tree:render("EAX Prot Warrior", function()
        _enabled_keybind:render("Enable EAX Prot Warrior", "Toggle rotation on/off")
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
