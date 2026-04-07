-- EAX Shaman Elemental | libraries/menu.lua | Project Sylvanas
local unified = require("EAX_Unified/menu")
if not unified then error("[EAX Shaman Elemental] EAX_Unified/menu not found!") end

local ROTATION_KEY = "shaman_elemental"
local menu = {}

local MENU_DEF = {
    categories = {
        {
            name = "Rotation",
            settings = {
                { key = "ele_use_flame_shock",    type = "checkbox", label = "Flame Shock",        default = true,  tooltip = "Maintain Flame Shock DoT" },
                { key = "ele_fs_min_ttd",         type = "slider",   label = "Flame Shock Min TTD (s)", default = 5, min = 3, max = 12, tooltip = "Don't refresh Flame Shock below this TTD" },
                { key = "ele_use_earth_shock",    type = "checkbox", label = "Earth Shock",        default = true,  tooltip = "Lightning Overload dump" },
                { key = "ele_mana_stop_shocks",   type = "slider",   label = "Stop Shocks Mana %", default = 10, min = 5, max = 30, suffix = "%", tooltip = "Stop spamming shocks below this mana" },
                { key = "ele_rotation_type",      type = "combo",    label = "Rotation Type",      default = 1, options = {"LB+FS+ES", "LvB Priority", "CL AoE"}, tooltip = "Core rotation style" },
                { key = "ele_fixed_lb_per_cl",    type = "slider",   label = "LB per CL",          default = 3, min = 1, max = 5, tooltip = "Lightning Bolts between each Chain Lightning" },
                { key = "enable_aoe",             type = "checkbox", label = "Enable AoE",         default = true },
                { key = "aoe_threshold",          type = "slider",   label = "AoE Min Targets",    default = 3, min = 2, max = 8 },
            },
        },
        {
            name = "Totems",
            settings = {
                { key = "ele_fire_totem",   type = "combo", label = "Fire Totem",  default = 1, options = {"Totem of Wrath", "Flametongue", "Magma", "None"} },
                { key = "ele_earth_totem",  type = "combo", label = "Earth Totem", default = 1, options = {"Strength of Earth", "Stoneclaw", "Stoneskin", "None"} },
                { key = "ele_water_totem",  type = "combo", label = "Water Totem", default = 1, options = {"Mana Spring", "Healing Stream", "None"} },
                { key = "ele_air_totem",    type = "combo", label = "Air Totem",   default = 1, options = {"Wrath of Air", "Windfury", "Grounding", "None"} },
                { key = "use_auto_tremor",  type = "checkbox", label = "Auto Tremor Totem",  default = true, tooltip = "Drop Tremor when fear debuff is active" },
            },
        },
        {
            name = "Cooldowns",
            settings = {
                { key = "ele_use_elemental_mastery", type = "checkbox", label = "Elemental Mastery", default = true,  tooltip = "Guaranteed crit cooldown" },
                { key = "ele_em_hold_for_cl",        type = "checkbox", label = "Hold EM for CL",    default = false, tooltip = "Save Elemental Mastery for Chain Lightning" },
                { key = "ele_use_fire_elemental",    type = "checkbox", label = "Fire Elemental",    default = true },
                { key = "cd_min_ttd",                type = "slider",   label = "Min TTD for CDs (s)",default = 10, min = 5, max = 30 },
                { key = "use_racial",                type = "checkbox", label = "Racial Ability",    default = true },
            },
        },
        {
            name = "Utility",
            settings = {
                { key = "shield_mode",        type = "combo",    label = "Shield Mode",     default = 1, options = {"Water Shield", "Lightning Shield", "None"} },
                { key = "use_ghost_wolf",     type = "checkbox", label = "Ghost Wolf OOC",  default = true, tooltip = "Auto Ghost Wolf while out of combat" },
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
    on_enabled  = function() print("|cFF2299FF[EAX Elemental]|r Rotation ENABLED") end,
    on_disabled = function() print("|cFF2299FF[EAX Elemental]|r Rotation disabled") end,
}

unified.register_rotation("Shaman", "Elemental", MENU_DEF, callbacks)

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
menu.ele_use_flame_shock        = proxy("ele_use_flame_shock",      true)
menu.ele_fs_min_ttd             = proxy("ele_fs_min_ttd",           5)
menu.ele_use_earth_shock        = proxy("ele_use_earth_shock",      true)
menu.ele_mana_stop_shocks       = proxy("ele_mana_stop_shocks",     10)
menu.ele_rotation_type          = proxy("ele_rotation_type",        1)
menu.ele_fixed_lb_per_cl        = proxy("ele_fixed_lb_per_cl",      3)
menu.enable_aoe                 = proxy("enable_aoe",               true)
menu.aoe_threshold              = proxy("aoe_threshold",            3)
menu.ele_fire_totem             = proxy("ele_fire_totem",           1)
menu.ele_earth_totem            = proxy("ele_earth_totem",          1)
menu.ele_water_totem            = proxy("ele_water_totem",          1)
menu.ele_air_totem              = proxy("ele_air_totem",            1)
menu.use_auto_tremor            = proxy("use_auto_tremor",          true)
menu.ele_use_elemental_mastery  = proxy("ele_use_elemental_mastery",true)
menu.ele_em_hold_for_cl         = proxy("ele_em_hold_for_cl",       false)
menu.ele_use_fire_elemental     = proxy("ele_use_fire_elemental",   true)
menu.cd_min_ttd                 = proxy("cd_min_ttd",               10)
menu.use_racial                 = proxy("use_racial",               true)
menu.shield_mode                = proxy("shield_mode",              1)
menu.use_ghost_wolf             = proxy("use_ghost_wolf",           true)
menu.debug                      = proxy("debug",                    false)

-- ============================================================================
-- NATIVE ELEMENTS & RENDER HOOKS  (added by EAX v4 patch)
-- These are required by main.lua:
--   core.register_on_render_callback(menu.on_render)
--   core.register_on_render_menu_callback(menu.on_menu_render)
-- ============================================================================

-- Native keybind for enable toggle (persisted by PS, shown in control panel)
-- Value 7 = "Unbound". main.lua uses get_state() / set() on this.
local _enabled_keybind  = core.menu.keybind(7, false, "eax_shaman_elemental_enabled_kb")
local _toggle_key_elem  = core.menu.keybind(107, false, "eax_shaman_elemental_toggle_key")

-- Wrap keybind as menu.enabled so existing proxy is overridden with the real element
menu.enabled   = _enabled_keybind
menu.toggle_key = _toggle_key_elem

-- Native tree_node for the PS main menu entry
local _menu_tree = core.menu.tree_node()

-- on_menu_render: called by core.register_on_render_menu_callback
-- Renders a collapsible node in the PS main menu.
function menu.on_menu_render()
    _menu_tree:render("EAX Elemental", function()
        _enabled_keybind:render("Enable EAX Elemental", "Toggle rotation on/off")
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
