-- EAX Druid Restoration | libraries/menu.lua | Project Sylvanas
local unified = require("EAX_Unified/menu")
if not unified then error("[EAX Druid Resto] EAX_Unified/menu not found!") end

local ROTATION_KEY = "druid_restoration"
local menu = {}

local MENU_DEF = {
    categories = {
        {
            name = "Healing",
            settings = {
                { key = "use_rejuvenation",       type = "checkbox", label = "Rejuvenation",       default = true,  tooltip = "Core HoT — spam on injured allies" },
                { key = "use_regrowth",           type = "checkbox", label = "Regrowth",           default = true,  tooltip = "Direct heal + short HoT" },
                { key = "use_lifebloom",          type = "checkbox", label = "Lifebloom",          default = true,  tooltip = "Bloom stack on tank" },
                { key = "tank_lifebloom_stacks",  type = "slider",   label = "Lifebloom Stacks",   default = 3, min = 1, max = 3, tooltip = "Target stack count on primary tank" },
                { key = "use_swiftmend",          type = "checkbox", label = "Swiftmend",          default = true,  tooltip = "Emergency instant heal" },
                { key = "use_nourish",            type = "checkbox", label = "Nourish",            default = true,  tooltip = "Efficient filler — boosted by HoTs" },
                { key = "use_healing_touch",      type = "checkbox", label = "Healing Touch",      default = true,  tooltip = "Big slow heal — use with Nature's Swiftness" },
                { key = "tank_hp_threshold",      type = "slider",   label = "Tank HP Priority %", default = 70, min = 30, max = 95, suffix = "%", tooltip = "Prioritise tank heals below this HP %" },
            },
        },
        {
            name = "Cooldowns",
            settings = {
                { key = "use_tree_of_life",       type = "checkbox", label = "Tree of Life",       default = true,  tooltip = "Major healing cooldown" },
                { key = "use_tranquility",        type = "checkbox", label = "Tranquility",        default = true,  tooltip = "Raid AoE heal channel" },
                { key = "tranquility_min_allies", type = "slider",   label = "Tranquility Min Injured", default = 4, min = 2, max = 10, tooltip = "Minimum injured allies to trigger Tranquility" },
                { key = "use_innervate",          type = "checkbox", label = "Innervate",          default = true,  tooltip = "Auto-use on low mana" },
                { key = "innervate_mana_pct",     type = "slider",   label = "Innervate Mana %",   default = 25, min = 5, max = 60, suffix = "%" },
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
    on_enabled  = function() print("|cFF44FF88[EAX Resto Druid]|r Rotation ENABLED") end,
    on_disabled = function() print("|cFF44FF88[EAX Resto Druid]|r Rotation disabled") end,
}

unified.register_rotation("Druid", "Restoration", MENU_DEF, callbacks)

function menu.is_enabled()       return unified.is_rotation_active(ROTATION_KEY) end
function menu.get_setting(k, d)  return unified.get_setting(ROTATION_KEY, k, d) end
function menu.set_setting(k, v)  unified.set_setting(ROTATION_KEY, k, v) end
function menu.toggle_menu()      if unified.toggle_menu then unified.toggle_menu() end end

local function proxy(key, default)
    return { is_checked = function() return menu.get_setting(key, default) end,
             get_state  = function() return menu.get_setting(key, default) end,
             get        = function() return menu.get_setting(key, default) end }
end

menu.enabled                 = { is_checked = menu.is_enabled, get_state = menu.is_enabled }
menu.use_rejuvenation        = proxy("use_rejuvenation",       true)
menu.use_regrowth            = proxy("use_regrowth",           true)
menu.use_lifebloom           = proxy("use_lifebloom",          true)
menu.tank_lifebloom_stacks   = proxy("tank_lifebloom_stacks",  3)
menu.use_swiftmend           = proxy("use_swiftmend",          true)
menu.use_nourish             = proxy("use_nourish",            true)
menu.use_healing_touch       = proxy("use_healing_touch",      true)
menu.tank_hp_threshold       = proxy("tank_hp_threshold",      70)
menu.use_tree_of_life        = proxy("use_tree_of_life",       true)
menu.use_tranquility         = proxy("use_tranquility",        true)
menu.tranquility_min_allies  = proxy("tranquility_min_allies", 4)
menu.use_innervate           = proxy("use_innervate",          true)
menu.innervate_mana_pct      = proxy("innervate_mana_pct",     25)
menu.use_barkskin            = proxy("use_barkskin",           true)
menu.barkskin_hp             = proxy("barkskin_hp",            30)
menu.debug                   = proxy("debug",                  false)

-- ============================================================================
-- NATIVE ELEMENTS & RENDER HOOKS  (added by EAX v4 patch)
-- These are required by main.lua:
--   core.register_on_render_callback(menu.on_render)
--   core.register_on_render_menu_callback(menu.on_menu_render)
-- ============================================================================

-- Native keybind for enable toggle (persisted by PS, shown in control panel)
-- Value 7 = "Unbound". main.lua uses get_state() / set() on this.
local _enabled_keybind  = core.menu.keybind(7, false, "eax_druid_restoration_enabled_kb")
local _toggle_key_elem  = core.menu.keybind(107, false, "eax_druid_restoration_toggle_key")

-- Wrap keybind as menu.enabled so existing proxy is overridden with the real element
menu.enabled   = _enabled_keybind
menu.toggle_key = _toggle_key_elem

-- Native tree_node for the PS main menu entry
local _menu_tree = core.menu.tree_node()

-- on_menu_render: called by core.register_on_render_menu_callback
-- Renders a collapsible node in the PS main menu.
function menu.on_menu_render()
    _menu_tree:render("EAX Resto", function()
        _enabled_keybind:render("Enable EAX Resto", "Toggle rotation on/off")
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
