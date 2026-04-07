-- EAX Druid Balance | libraries/menu.lua | Project Sylvanas
local unified = require("EAX_Unified/menu")
if not unified then error("[EAX Druid Balance] EAX_Unified/menu not found!") end

local ROTATION_KEY = "druid_balance"
local menu = {}

local MENU_DEF = {
    categories = {
        {
            name = "Rotation",
            settings = {
                { key = "use_moonfire",         type = "checkbox", label = "Moonfire",          default = true,  tooltip = "Maintain Moonfire DoT" },
                { key = "use_insect_swarm",     type = "checkbox", label = "Insect Swarm",      default = true,  tooltip = "Maintain Insect Swarm DoT" },
                { key = "use_starfire",         type = "checkbox", label = "Starfire",          default = true,  tooltip = "Eclipse-buffed primary nuke" },
                { key = "use_wrath",            type = "checkbox", label = "Wrath",             default = true,  tooltip = "Filler / Solar eclipse nuke" },
                { key = "use_faerie_fire",      type = "checkbox", label = "Faerie Fire",       default = true,  tooltip = "Armor debuff — keep up" },
                { key = "use_force_of_nature",  type = "checkbox", label = "Force of Nature",   default = true,  tooltip = "Treant cooldown on boss" },
                { key = "use_hurricane",        type = "checkbox", label = "Hurricane",         default = true,  tooltip = "AoE channel" },
                { key = "hurricane_min_targets",type = "slider",   label = "Hurricane Min Targets", default = 3, min = 2, max = 8, tooltip = "Minimum enemies for Hurricane" },
                { key = "use_moonkin_form",     type = "checkbox", label = "Maintain Moonkin",  default = true,  tooltip = "Auto re-enter Moonkin Form if dropped" },
            },
        },
        {
            name = "Cooldowns",
            settings = {
                { key = "use_innervate",    type = "checkbox", label = "Innervate",      default = true,  tooltip = "Auto-use on low mana" },
                { key = "innervate_mana",   type = "slider",   label = "Innervate Mana %",default = 20, min = 5, max = 50, suffix = "%" },
                { key = "use_racial",       type = "checkbox", label = "Racial Ability", default = true },
                { key = "cd_min_ttd",       type = "slider",   label = "Min TTD for CDs (s)", default = 10, min = 5, max = 30 },
            },
        },
        {
            name = "Defensive",
            settings = {
                { key = "use_barkskin", type = "checkbox", label = "Barkskin",      default = true },
                { key = "barkskin_hp",  type = "slider",   label = "Barkskin HP %", default = 30, min = 5, max = 60, suffix = "%" },
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
    on_enabled  = function() print("|cFFAA44FF[EAX Balance]|r Rotation ENABLED") end,
    on_disabled = function() print("|cFFAA44FF[EAX Balance]|r Rotation disabled") end,
}

unified.register_rotation("Druid", "Balance", MENU_DEF, callbacks)

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
menu.use_moonfire           = proxy("use_moonfire",         true)
menu.use_insect_swarm       = proxy("use_insect_swarm",     true)
menu.use_starfire           = proxy("use_starfire",         true)
menu.use_wrath              = proxy("use_wrath",            true)
menu.use_faerie_fire        = proxy("use_faerie_fire",      true)
menu.use_force_of_nature    = proxy("use_force_of_nature",  true)
menu.use_hurricane          = proxy("use_hurricane",        true)
menu.hurricane_min_targets  = proxy("hurricane_min_targets",3)
menu.use_moonkin_form       = proxy("use_moonkin_form",     true)
menu.use_innervate          = proxy("use_innervate",        true)
menu.innervate_mana         = proxy("innervate_mana",       20)
menu.use_racial             = proxy("use_racial",           true)
menu.cd_min_ttd             = proxy("cd_min_ttd",           10)
menu.use_barkskin           = proxy("use_barkskin",         true)
menu.barkskin_hp            = proxy("barkskin_hp",          30)
menu.debug                  = proxy("debug",                false)

-- ============================================================================
-- NATIVE ELEMENTS & RENDER HOOKS  (added by EAX v4 patch)
-- These are required by main.lua:
--   core.register_on_render_callback(menu.on_render)
--   core.register_on_render_menu_callback(menu.on_menu_render)
-- ============================================================================

-- Native keybind for enable toggle (persisted by PS, shown in control panel)
-- Value 7 = "Unbound". main.lua uses get_state() / set() on this.
local _enabled_keybind  = core.menu.keybind(7, false, "eax_druid_balance_enabled_kb")
local _toggle_key_elem  = core.menu.keybind(107, false, "eax_druid_balance_toggle_key")

-- Wrap keybind as menu.enabled so existing proxy is overridden with the real element
menu.enabled   = _enabled_keybind
menu.toggle_key = _toggle_key_elem

-- Native tree_node for the PS main menu entry
local _menu_tree = core.menu.tree_node()

-- on_menu_render: called by core.register_on_render_menu_callback
-- Renders a collapsible node in the PS main menu.
function menu.on_menu_render()
    _menu_tree:render("EAX Balance", function()
        _enabled_keybind:render("Enable EAX Balance", "Toggle rotation on/off")
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

core.register_on_render_callback(menu.on_render)
core.register_on_render_menu_callback(menu.on_menu_render)

return menu
