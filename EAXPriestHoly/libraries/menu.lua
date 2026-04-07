-- EAX Priest Holy | libraries/menu.lua | Project Sylvanas
local unified = require("EAX_Unified/menu")
if not unified then error("[EAX Priest Holy] EAX_Unified/menu not found!") end

local ROTATION_KEY = "priest_holy"
local menu = {}

local MENU_DEF = {
    categories = {
        {
            name = "Healing",
            settings = {
                { key = "use_flash_heal",          type = "checkbox", label = "Flash Heal",          default = true,  tooltip = "Fast direct heal" },
                { key = "use_greater_heal",        type = "checkbox", label = "Greater Heal",        default = true,  tooltip = "Efficient slow heal" },
                { key = "use_renew",               type = "checkbox", label = "Renew",               default = true,  tooltip = "HoT maintenance" },
                { key = "use_circle_of_healing",   type = "checkbox", label = "Circle of Healing",   default = true,  tooltip = "Smart AoE heal" },
                { key = "use_prayer_of_mending",   type = "checkbox", label = "Prayer of Mending",   default = true,  tooltip = "Bouncing heal" },
                { key = "use_binding_heal",        type = "checkbox", label = "Binding Heal",        default = true,  tooltip = "Heal self + target simultaneously" },
                { key = "self_heal_hp",            type = "slider",   label = "Self Heal HP %",      default = 50, min = 10, max = 80, suffix = "%" },
                { key = "use_power_word_shield",   type = "checkbox", label = "Power Word: Shield",  default = true,  tooltip = "Emergency absorb on self" },
                { key = "shield_hp",               type = "slider",   label = "Shield HP %",         default = 40, min = 10, max = 70, suffix = "%" },
            },
        },
        {
            name = "Cooldowns",
            settings = {
                { key = "use_holy_nova",    type = "checkbox", label = "Holy Nova",     default = true,  tooltip = "AoE heal + damage" },
                { key = "use_lightwell",    type = "checkbox", label = "Lightwell",     default = true },
                { key = "use_divine_hymn",  type = "checkbox", label = "Divine Hymn",   default = true,  tooltip = "Raid healing channel" },
                { key = "use_shadowfiend",  type = "checkbox", label = "Shadowfiend",   default = true },
                { key = "shadowfiend_pct",  type = "slider",   label = "Shadowfiend Mana %", default = 30, min = 5, max = 60, suffix = "%" },
            },
        },
        {
            name = "Buffs / Utility",
            settings = {
                { key = "use_fortitude",     type = "checkbox", label = "Power Word: Fortitude", default = true },
                { key = "use_divine_spirit", type = "checkbox", label = "Divine Spirit",         default = true },
                { key = "use_inner_fire",    type = "checkbox", label = "Inner Fire",            default = true },
                { key = "use_fear_ward",     type = "checkbox", label = "Fear Ward",             default = true },
                { key = "use_fade",          type = "checkbox", label = "Fade",                  default = true },
                { key = "use_racial",        type = "checkbox", label = "Racial Ability",        default = true },
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
    on_enabled  = function() print("|cFFFFFFC8[EAX Holy Priest]|r Rotation ENABLED") end,
    on_disabled = function() print("|cFFFFFFC8[EAX Holy Priest]|r Rotation disabled") end,
}

unified.register_rotation("Priest", "Holy", MENU_DEF, callbacks)

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
menu.use_flash_heal           = proxy("use_flash_heal",          true)
menu.use_greater_heal         = proxy("use_greater_heal",        true)
menu.use_renew                = proxy("use_renew",               true)
menu.use_circle_of_healing    = proxy("use_circle_of_healing",   true)
menu.use_prayer_of_mending    = proxy("use_prayer_of_mending",   true)
menu.use_binding_heal         = proxy("use_binding_heal",        true)
menu.self_heal_hp             = proxy("self_heal_hp",            50)
menu.use_power_word_shield    = proxy("use_power_word_shield",   true)
menu.shield_hp                = proxy("shield_hp",               40)
menu.use_holy_nova            = proxy("use_holy_nova",           true)
menu.use_lightwell            = proxy("use_lightwell",           true)
menu.use_divine_hymn          = proxy("use_divine_hymn",         true)
menu.use_shadowfiend          = proxy("use_shadowfiend",         true)
menu.shadowfiend_pct          = proxy("shadowfiend_pct",         30)
menu.use_fortitude            = proxy("use_fortitude",           true)
menu.use_divine_spirit        = proxy("use_divine_spirit",       true)
menu.use_inner_fire           = proxy("use_inner_fire",          true)
menu.use_fear_ward            = proxy("use_fear_ward",           true)
menu.use_fade                 = proxy("use_fade",                true)
menu.use_racial               = proxy("use_racial",              true)
menu.debug                    = proxy("debug",                   false)

-- ============================================================================
-- NATIVE ELEMENTS & RENDER HOOKS  (added by EAX v4 patch)
-- These are required by main.lua:
--   core.register_on_render_callback(menu.on_render)
--   core.register_on_render_menu_callback(menu.on_menu_render)
-- ============================================================================

-- Native keybind for enable toggle (persisted by PS, shown in control panel)
-- Value 7 = "Unbound". main.lua uses get_state() / set() on this.
local _enabled_keybind  = core.menu.keybind(7, false, "eax_priest_holy_enabled_kb")
local _toggle_key_elem  = core.menu.keybind(107, false, "eax_priest_holy_toggle_key")

-- Wrap keybind as menu.enabled so existing proxy is overridden with the real element
menu.enabled   = _enabled_keybind
menu.toggle_key = _toggle_key_elem

-- Native tree_node for the PS main menu entry
local _menu_tree = core.menu.tree_node()

-- on_menu_render: called by core.register_on_render_menu_callback
-- Renders a collapsible node in the PS main menu.
function menu.on_menu_render()
    _menu_tree:render("EAX Holy Priest", function()
        _enabled_keybind:render("Enable EAX Holy Priest", "Toggle rotation on/off")
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
