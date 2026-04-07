-- EAX Shaman Enhancement | libraries/menu.lua | Project Sylvanas
local unified = require("EAX_Unified/menu")
if not unified then error("[EAX Shaman Enhancement] EAX_Unified/menu not found!") end

local ROTATION_KEY = "shaman_enhancement"
local menu = {}

local MENU_DEF = {
    categories = {
        {
            name = "Rotation",
            settings = {
                { key = "enh_use_stormstrike",    type = "checkbox", label = "Stormstrike",        default = true,  tooltip = "Primary melee ability" },
                { key = "enh_primary_shock",      type = "combo",    label = "Primary Shock",      default = 1, options = {"Earth Shock", "Flame Shock", "Frost Shock"} },
                { key = "enh_mana_stop_shocks",   type = "slider",   label = "Stop Shocks Mana %", default = 10, min = 5, max = 30, suffix = "%" },
                { key = "enh_weave_flame_shock",  type = "checkbox", label = "Weave Flame Shock",  default = true,  tooltip = "Maintain Flame Shock while melee weaving" },
                { key = "enh_twist_windfury",     type = "checkbox", label = "Twist Windfury",     default = false, tooltip = "Expert: alternate WF and FT totems" },
                { key = "enh_twist_fire_nova",    type = "checkbox", label = "Fire Nova AoE",      default = true },
                { key = "enable_aoe",             type = "checkbox", label = "Enable AoE",         default = true },
                { key = "aoe_threshold",          type = "slider",   label = "AoE Min Targets",    default = 3, min = 2, max = 8 },
            },
        },
        {
            name = "Totems",
            settings = {
                { key = "enh_fire_totem",   type = "combo", label = "Fire Totem",  default = 1, options = {"Totem of Wrath", "Flametongue", "Magma", "None"} },
                { key = "enh_earth_totem",  type = "combo", label = "Earth Totem", default = 1, options = {"Strength of Earth", "Stoneclaw", "Stoneskin", "None"} },
                { key = "enh_water_totem",  type = "combo", label = "Water Totem", default = 1, options = {"Mana Spring", "Healing Stream", "None"} },
                { key = "enh_air_totem",    type = "combo", label = "Air Totem",   default = 1, options = {"Windfury", "Wrath of Air", "Grounding", "None"} },
                { key = "use_auto_tremor",  type = "checkbox", label = "Auto Tremor Totem", default = true },
            },
        },
        {
            name = "Cooldowns",
            settings = {
                { key = "enh_use_shamanistic_rage",    type = "checkbox", label = "Shamanistic Rage",    default = true },
                { key = "enh_shamanistic_rage_pct",    type = "slider",   label = "Shamanistic Rage Mana %", default = 30, min = 5, max = 60, suffix = "%" },
                { key = "enh_use_fire_elemental",      type = "checkbox", label = "Fire Elemental",      default = true },
                { key = "use_racial",                  type = "checkbox", label = "Racial Ability",      default = true },
            },
        },
        {
            name = "Utility",
            settings = {
                { key = "shield_mode",    type = "combo",    label = "Shield Mode",    default = 1, options = {"Lightning Shield", "Water Shield", "None"} },
                { key = "use_ghost_wolf", type = "checkbox", label = "Ghost Wolf OOC", default = true },
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
    on_enabled  = function() print("|cFFCC6611[EAX Enhancement]|r Rotation ENABLED") end,
    on_disabled = function() print("|cFFCC6611[EAX Enhancement]|r Rotation disabled") end,
}

unified.register_rotation("Shaman", "Enhancement", MENU_DEF, callbacks)

function menu.is_enabled()       return unified.is_rotation_active(ROTATION_KEY) end
function menu.get_setting(k, d)  return unified.get_setting(ROTATION_KEY, k, d) end
function menu.set_setting(k, v)  unified.set_setting(ROTATION_KEY, k, v) end
function menu.toggle_menu()      if unified.toggle_menu then unified.toggle_menu() end end

local function proxy(key, default)
    return { is_checked = function() return menu.get_setting(key, default) end,
             get_state  = function() return menu.get_setting(key, default) end,
             get        = function() return menu.get_setting(key, default) end }
end

menu.enabled                    = { is_checked = menu.is_enabled, get_state = menu.is_enabled }
menu.enh_use_stormstrike        = proxy("enh_use_stormstrike",       true)
menu.enh_primary_shock          = proxy("enh_primary_shock",         1)
menu.enh_mana_stop_shocks       = proxy("enh_mana_stop_shocks",      10)
menu.enh_weave_flame_shock      = proxy("enh_weave_flame_shock",     true)
menu.enh_twist_windfury         = proxy("enh_twist_windfury",        false)
menu.enh_twist_fire_nova        = proxy("enh_twist_fire_nova",       true)
menu.enable_aoe                 = proxy("enable_aoe",                true)
menu.aoe_threshold              = proxy("aoe_threshold",             3)
menu.enh_fire_totem             = proxy("enh_fire_totem",            1)
menu.enh_earth_totem            = proxy("enh_earth_totem",           1)
menu.enh_water_totem            = proxy("enh_water_totem",           1)
menu.enh_air_totem              = proxy("enh_air_totem",             1)
menu.use_auto_tremor            = proxy("use_auto_tremor",           true)
menu.enh_use_shamanistic_rage   = proxy("enh_use_shamanistic_rage",  true)
menu.enh_shamanistic_rage_pct   = proxy("enh_shamanistic_rage_pct",  30)
menu.enh_use_fire_elemental     = proxy("enh_use_fire_elemental",    true)
menu.use_racial                 = proxy("use_racial",                true)
menu.shield_mode                = proxy("shield_mode",               1)
menu.use_ghost_wolf             = proxy("use_ghost_wolf",            true)
menu.debug                      = proxy("debug",                     false)

-- ============================================================================
-- NATIVE ELEMENTS & RENDER HOOKS  (added by EAX v4 patch)
-- These are required by main.lua:
--   core.register_on_render_callback(menu.on_render)
--   core.register_on_render_menu_callback(menu.on_menu_render)
-- ============================================================================

-- Native keybind for enable toggle (persisted by PS, shown in control panel)
-- Value 7 = "Unbound". main.lua uses get_state() / set() on this.
local _enabled_keybind  = core.menu.keybind(7, false, "eax_shaman_enhancement_enabled_kb")
local _toggle_key_elem  = core.menu.keybind(107, false, "eax_shaman_enhancement_toggle_key")

-- Wrap keybind as menu.enabled so existing proxy is overridden with the real element
menu.enabled   = _enabled_keybind
menu.toggle_key = _toggle_key_elem

-- Native tree_node for the PS main menu entry
local _menu_tree = core.menu.tree_node()

-- on_menu_render: called by core.register_on_render_menu_callback
-- Renders a collapsible node in the PS main menu.
function menu.on_menu_render()
    _menu_tree:render("EAX Enhancement", function()
        _enabled_keybind:render("Enable EAX Enhancement", "Toggle rotation on/off")
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

-- Register render callbacks (required for menu rendering)
core.register_on_render_callback(menu.on_render)
core.register_on_render_menu_callback(menu.on_menu_render)

return menu
