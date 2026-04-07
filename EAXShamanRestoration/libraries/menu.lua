-- EAX Shaman Restoration | libraries/menu.lua | Project Sylvanas
local unified = require("EAX_Unified/menu")
if not unified then error("[EAX Shaman Restoration] EAX_Unified/menu not found!") end

local ROTATION_KEY = "shaman_restoration"
local menu = {}

local MENU_DEF = {
    categories = {
        {
            name = "Healing",
            settings = {
                { key = "resto_primary_heal",            type = "combo",    label = "Primary Heal",          default = 1, options = {"Lesser Healing Wave", "Healing Wave", "Chain Heal"}, tooltip = "Main spam heal" },
                { key = "resto_chain_heal_threshold",    type = "slider",   label = "Chain Heal HP %",       default = 75, min = 30, max = 95, suffix = "%", tooltip = "Use Chain Heal when injured target below this HP" },
                { key = "resto_lhw_emergency_threshold", type = "slider",   label = "Emergency LHW HP %",    default = 35, min = 10, max = 60, suffix = "%", tooltip = "Spam LHW on targets below this HP" },
                { key = "resto_ns_hp_threshold",         type = "slider",   label = "Nature's Swiftness HP %",default = 20, min = 5, max = 50, suffix = "%" },
                { key = "resto_use_natures_swiftness",   type = "checkbox", label = "Nature's Swiftness",    default = true },
                { key = "resto_maintain_earth_shield",   type = "checkbox", label = "Maintain Earth Shield", default = true,  tooltip = "Keep Earth Shield on tank" },
                { key = "resto_earth_shield_refresh",    type = "slider",   label = "Earth Shield Refresh Stacks", default = 3, min = 1, max = 9, tooltip = "Re-apply when stacks drop below this" },
            },
        },
        {
            name = "Totems",
            settings = {
                { key = "resto_fire_totem",  type = "combo", label = "Fire Totem",  default = 1, options = {"Flametongue", "Totem of Wrath", "None"} },
                { key = "resto_earth_totem", type = "combo", label = "Earth Totem", default = 1, options = {"Strength of Earth", "Stoneskin", "Stoneclaw", "None"} },
                { key = "resto_water_totem", type = "combo", label = "Water Totem", default = 1, options = {"Mana Spring", "Healing Stream", "None"} },
                { key = "resto_air_totem",   type = "combo", label = "Air Totem",   default = 1, options = {"Wrath of Air", "Windfury", "Grounding", "None"} },
                { key = "use_auto_tremor",   type = "checkbox", label = "Auto Tremor Totem", default = true },
            },
        },
        {
            name = "Cooldowns",
            settings = {
                { key = "resto_use_mana_tide",   type = "checkbox", label = "Mana Tide Totem",  default = true },
                { key = "resto_mana_tide_pct",   type = "slider",   label = "Mana Tide Mana %", default = 30, min = 5, max = 60, suffix = "%" },
            },
        },
        {
            name = "Utility",
            settings = {
                { key = "use_cure_poison",  type = "checkbox", label = "Cure Poison",  default = true },
                { key = "use_cure_disease", type = "checkbox", label = "Cure Disease", default = true },
                { key = "use_ghost_wolf",   type = "checkbox", label = "Ghost Wolf OOC", default = true },
                { key = "shield_mode",      type = "combo",    label = "Shield Mode",  default = 1, options = {"Water Shield", "Lightning Shield", "None"} },
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
    on_enabled  = function() print("|cFF11CCCC[EAX Resto Shaman]|r Rotation ENABLED") end,
    on_disabled = function() print("|cFF11CCCC[EAX Resto Shaman]|r Rotation disabled") end,
}

unified.register_rotation("Shaman", "Restoration", MENU_DEF, callbacks)

function menu.is_enabled()       return unified.is_rotation_active(ROTATION_KEY) end
function menu.get_setting(k, d)  return unified.get_setting(ROTATION_KEY, k, d) end
function menu.set_setting(k, v)  unified.set_setting(ROTATION_KEY, k, v) end
function menu.toggle_menu()      if unified.toggle_menu then unified.toggle_menu() end end

local function proxy(key, default)
    return { is_checked = function() return menu.get_setting(key, default) end,
             get_state  = function() return menu.get_setting(key, default) end,
             get        = function() return menu.get_setting(key, default) end }
end

menu.enabled                       = { is_checked = menu.is_enabled, get_state = menu.is_enabled }
menu.resto_primary_heal             = proxy("resto_primary_heal",             1)
menu.resto_chain_heal_threshold     = proxy("resto_chain_heal_threshold",     75)
menu.resto_lhw_emergency_threshold  = proxy("resto_lhw_emergency_threshold",  35)
menu.resto_ns_hp_threshold          = proxy("resto_ns_hp_threshold",          20)
menu.resto_use_natures_swiftness    = proxy("resto_use_natures_swiftness",    true)
menu.resto_maintain_earth_shield    = proxy("resto_maintain_earth_shield",    true)
menu.resto_earth_shield_refresh     = proxy("resto_earth_shield_refresh",     3)
menu.resto_fire_totem               = proxy("resto_fire_totem",               1)
menu.resto_earth_totem              = proxy("resto_earth_totem",              1)
menu.resto_water_totem              = proxy("resto_water_totem",              1)
menu.resto_air_totem                = proxy("resto_air_totem",                1)
menu.use_auto_tremor                = proxy("use_auto_tremor",                true)
menu.resto_use_mana_tide            = proxy("resto_use_mana_tide",            true)
menu.resto_mana_tide_pct            = proxy("resto_mana_tide_pct",            30)
menu.use_cure_poison                = proxy("use_cure_poison",                true)
menu.use_cure_disease               = proxy("use_cure_disease",               true)
menu.use_ghost_wolf                 = proxy("use_ghost_wolf",                 true)
menu.shield_mode                    = proxy("shield_mode",                    1)
menu.debug                          = proxy("debug",                          false)

-- ============================================================================
-- NATIVE ELEMENTS & RENDER HOOKS  (added by EAX v4 patch)
-- These are required by main.lua:
--   core.register_on_render_callback(menu.on_render)
--   core.register_on_render_menu_callback(menu.on_menu_render)
-- ============================================================================

-- Native keybind for enable toggle (persisted by PS, shown in control panel)
-- Value 7 = "Unbound". main.lua uses get_state() / set() on this.
local _enabled_keybind  = core.menu.keybind(7, false, "eax_shaman_restoration_enabled_kb")
local _toggle_key_elem  = core.menu.keybind(107, false, "eax_shaman_restoration_toggle_key")

-- Wrap keybind as menu.enabled so existing proxy is overridden with the real element
menu.enabled   = _enabled_keybind
menu.toggle_key = _toggle_key_elem

-- Native tree_node for the PS main menu entry
local _menu_tree = core.menu.tree_node()

-- on_menu_render: called by core.register_on_render_menu_callback
-- Renders a collapsible node in the PS main menu.
function menu.on_menu_render()
    _menu_tree:render("EAX Resto Shaman", function()
        _enabled_keybind:render("Enable EAX Resto Shaman", "Toggle rotation on/off")
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

-- Register render callbacks (required for native menu integration)
core.register_on_render_callback(menu.on_render)
core.register_on_render_menu_callback(menu.on_menu_render)

return menu
