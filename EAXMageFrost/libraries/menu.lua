-- EAX Mage Frost | libraries/menu.lua | Project Sylvanas
local unified = require("EAX_Unified/menu")
if not unified then error("[EAX Mage Frost] EAX_Unified/menu not found!") end

local ROTATION_KEY = "mage_frost"
local menu = {}

local MENU_DEF = {
    categories = {
        {
            name = "Rotation",
            settings = {
                { key = "use_frostbolt",      type = "checkbox", label = "Frostbolt",      default = true,  tooltip = "Main filler — chill & freeze procs" },
                { key = "use_ice_lance",      type = "checkbox", label = "Ice Lance",      default = true,  tooltip = "Instant cast — priority on Fingers of Frost" },
                { key = "use_frostfire_bolt", type = "checkbox", label = "Frostfire Bolt", default = true,  tooltip = "Dual school filler" },
                { key = "use_blizzard",       type = "checkbox", label = "Blizzard",       default = true,  tooltip = "AoE channel" },
                { key = "use_deep_freeze",    type = "checkbox", label = "Deep Freeze",    default = true,  tooltip = "Use on frozen targets" },
                { key = "aoe_threshold",      type = "slider",   label = "AoE Min Targets",default = 3, min = 2, max = 10, tooltip = "Minimum targets for Blizzard" },
            },
        },
        {
            name = "Cooldowns",
            settings = {
                { key = "use_icy_veins",     type = "checkbox", label = "Icy Veins",         default = true,  tooltip = "Haste buff" },
                { key = "use_cold_snap",     type = "checkbox", label = "Cold Snap",          default = true,  tooltip = "Resets all Frost CDs" },
                { key = "use_evocation",     type = "checkbox", label = "Evocation",          default = true,  tooltip = "Mana recovery" },
                { key = "evocation_mana_pct",type = "slider",   label = "Evocation Mana %",   default = 20, min = 5, max = 50, suffix = "%" },
                { key = "use_racial",        type = "checkbox", label = "Racial Ability",     default = true },
                { key = "cd_min_ttd",        type = "slider",   label = "Min TTD for CDs (s)",default = 10, min = 5, max = 30 },
            },
        },
        {
            name = "Defensive",
            settings = {
                { key = "use_ice_barrier", type = "checkbox", label = "Ice Barrier",      default = true },
                { key = "ice_barrier_hp",  type = "slider",   label = "Ice Barrier HP %", default = 40, min = 0, max = 100, suffix = "%" },
                { key = "use_ice_block",   type = "checkbox", label = "Ice Block",        default = true },
                { key = "ice_block_hp",    type = "slider",   label = "Ice Block HP %",   default = 20, min = 0, max = 100, suffix = "%" },
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
    on_enabled  = function() print("|cFF88DDFF[EAX Frost]|r Rotation ENABLED") end,
    on_disabled = function() print("|cFF88DDFF[EAX Frost]|r Rotation disabled") end,
}

unified.register_rotation("Mage", "Frost", MENU_DEF, callbacks)

function menu.is_enabled()       return unified.is_rotation_active(ROTATION_KEY) end
function menu.get_setting(k, d)  return unified.get_setting(ROTATION_KEY, k, d) end
function menu.set_setting(k, v)  unified.set_setting(ROTATION_KEY, k, v) end
function menu.toggle_menu()      if unified.toggle_menu then unified.toggle_menu() end end

local function proxy(key, default)
    return { is_checked = function() return menu.get_setting(key, default) end,
             get_state  = function() return menu.get_setting(key, default) end,
             get        = function() return menu.get_setting(key, default) end }
end

menu.enabled             = { is_checked = menu.is_enabled, get_state = menu.is_enabled }
menu.use_frostbolt       = proxy("use_frostbolt",      true)
menu.use_ice_lance       = proxy("use_ice_lance",      true)
menu.use_frostfire_bolt  = proxy("use_frostfire_bolt", true)
menu.use_blizzard        = proxy("use_blizzard",       true)
menu.use_deep_freeze     = proxy("use_deep_freeze",    true)
menu.aoe_threshold       = proxy("aoe_threshold",      3)
menu.use_icy_veins       = proxy("use_icy_veins",      true)
menu.use_cold_snap       = proxy("use_cold_snap",      true)
menu.use_evocation       = proxy("use_evocation",      true)
menu.evocation_mana_pct  = proxy("evocation_mana_pct", 20)
menu.use_racial          = proxy("use_racial",         true)
menu.cd_min_ttd          = proxy("cd_min_ttd",         10)
menu.use_ice_barrier     = proxy("use_ice_barrier",    true)
menu.ice_barrier_hp      = proxy("ice_barrier_hp",     40)
menu.use_ice_block       = proxy("use_ice_block",      true)
menu.ice_block_hp        = proxy("ice_block_hp",       20)
menu.debug               = proxy("debug",              false)

-- ============================================================================
-- NATIVE ELEMENTS & RENDER HOOKS  (added by EAX v4 patch)
-- These are required by main.lua:
--   core.register_on_render_callback(menu.on_render)
--   core.register_on_render_menu_callback(menu.on_menu_render)
-- ============================================================================

-- Native keybind for enable toggle (persisted by PS, shown in control panel)
-- Value 7 = "Unbound". main.lua uses get_state() / set() on this.
local _enabled_keybind  = core.menu.keybind(7, false, "eax_mage_frost_enabled_kb")
local _toggle_key_elem  = core.menu.keybind(107, false, "eax_mage_frost_toggle_key")

-- Wrap keybind as menu.enabled so existing proxy is overridden with the real element
menu.enabled   = _enabled_keybind
menu.toggle_key = _toggle_key_elem

-- Native tree_node for the PS main menu entry
local _menu_tree = core.menu.tree_node()

-- on_menu_render: called by core.register_on_render_menu_callback
-- Renders a collapsible node in the PS main menu.
function menu.on_menu_render()
    _menu_tree:render("EAX Frost", function()
        _enabled_keybind:render("Enable EAX Frost", "Toggle rotation on/off")
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
