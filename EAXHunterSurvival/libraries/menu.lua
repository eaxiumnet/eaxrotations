-- EAX Hunter Survival | libraries/menu.lua | Project Sylvanas
local unified = require("EAX_Unified/menu")
if not unified then error("[EAX Hunter Survival] EAX_Unified/menu not found!") end

local ROTATION_KEY = "hunter_survival"
local menu = {}

local MENU_DEF = {
    categories = {
        {
            name = "Rotation",
            settings = {
                { key = "use_explosive_shot",    type = "checkbox", label = "Explosive Shot",    default = true,  tooltip = "Primary spender — Black Arrow proc" },
                { key = "use_black_arrow",       type = "checkbox", label = "Black Arrow",       default = true,  tooltip = "DoT + Lock and Load proc" },
                { key = "use_serpent_sting",     type = "checkbox", label = "Serpent Sting",     default = true,  tooltip = "Maintain Serpent Sting" },
                { key = "use_arcane_shot",       type = "checkbox", label = "Arcane Shot",       default = true,  tooltip = "Focus dump" },
                { key = "use_steady_shot",       type = "checkbox", label = "Steady Shot",       default = true,  tooltip = "Focus builder" },
                { key = "use_multi_shot",        type = "checkbox", label = "Multi-Shot",        default = true },
                { key = "use_trap_launcher",     type = "checkbox", label = "Trap Launcher",     default = true,  tooltip = "Auto-launch Immolation Trap for AoE" },
                { key = "aoe_threshold",         type = "slider",   label = "AoE Min Targets",   default = 3, min = 2, max = 8 },
                { key = "use_silencing_shot",    type = "checkbox", label = "Silencing Shot",    default = true },
            },
        },
        {
            name = "Pet",
            settings = {
                { key = "use_mend_pet",    type = "checkbox", label = "Mend Pet",      default = true },
                { key = "mend_pet_hp",     type = "slider",   label = "Mend Pet HP %", default = 50, min = 20, max = 80, suffix = "%" },
            },
        },
        {
            name = "Cooldowns",
            settings = {
                { key = "use_rapid_fire",  type = "checkbox", label = "Rapid Fire",     default = true },
                { key = "use_readiness",   type = "checkbox", label = "Readiness",      default = true },
                { key = "use_racial",      type = "checkbox", label = "Racial Ability", default = true },
                { key = "cd_min_ttd",      type = "slider",   label = "Min TTD for CDs (s)", default = 10, min = 5, max = 30 },
            },
        },
        {
            name = "Defensive",
            settings = {
                { key = "use_feign_death",  type = "checkbox", label = "Feign Death",  default = true },
                { key = "feign_hp",         type = "slider",   label = "Feign HP %",   default = 25, min = 5, max = 50, suffix = "%" },
                { key = "use_disengage",    type = "checkbox", label = "Disengage",    default = true },
                { key = "use_deterrence",   type = "checkbox", label = "Deterrence",   default = true },
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
    on_enabled  = function() print("|cFFE6BB33[EAX Survival]|r Rotation ENABLED") end,
    on_disabled = function() print("|cFFE6BB33[EAX Survival]|r Rotation disabled") end,
}

unified.register_rotation("Hunter", "Survival", MENU_DEF, callbacks)

function menu.is_enabled()       return unified.is_rotation_active(ROTATION_KEY) end
function menu.get_setting(k, d)  return unified.get_setting(ROTATION_KEY, k, d) end
function menu.set_setting(k, v)  unified.set_setting(ROTATION_KEY, k, v) end
function menu.toggle_menu()      if unified.toggle_menu then unified.toggle_menu() end end

local function proxy(key, default)
    return { is_checked = function() return menu.get_setting(key, default) end,
             get_state  = function() return menu.get_setting(key, default) end,
             get        = function() return menu.get_setting(key, default) end }
end

menu.enabled              = { is_checked = menu.is_enabled, get_state = menu.is_enabled }
menu.use_explosive_shot   = proxy("use_explosive_shot",  true)
menu.use_black_arrow      = proxy("use_black_arrow",     true)
menu.use_serpent_sting    = proxy("use_serpent_sting",   true)
menu.use_arcane_shot      = proxy("use_arcane_shot",     true)
menu.use_steady_shot      = proxy("use_steady_shot",     true)
menu.use_multi_shot       = proxy("use_multi_shot",      true)
menu.use_trap_launcher    = proxy("use_trap_launcher",   true)
menu.aoe_threshold        = proxy("aoe_threshold",       3)
menu.use_silencing_shot   = proxy("use_silencing_shot",  true)
menu.use_mend_pet         = proxy("use_mend_pet",        true)
menu.mend_pet_hp          = proxy("mend_pet_hp",         50)
menu.use_rapid_fire       = proxy("use_rapid_fire",      true)
menu.use_readiness        = proxy("use_readiness",       true)
menu.use_racial           = proxy("use_racial",          true)
menu.cd_min_ttd           = proxy("cd_min_ttd",          10)
menu.use_feign_death      = proxy("use_feign_death",     true)
menu.feign_hp             = proxy("feign_hp",            25)
menu.use_disengage        = proxy("use_disengage",       true)
menu.use_deterrence       = proxy("use_deterrence",      true)
menu.debug                = proxy("debug",               false)

-- ============================================================================
-- NATIVE ELEMENTS & RENDER HOOKS  (added by EAX v4 patch)
-- These are required by main.lua:
--   core.register_on_render_callback(menu.on_render)
--   core.register_on_render_menu_callback(menu.on_menu_render)
-- ============================================================================

-- Native keybind for enable toggle (persisted by PS, shown in control panel)
-- Value 7 = "Unbound". main.lua uses get_state() / set() on this.
local _enabled_keybind  = core.menu.keybind(7, false, "eax_hunter_survival_enabled_kb")
local _toggle_key_elem  = core.menu.keybind(107, false, "eax_hunter_survival_toggle_key")

-- Wrap keybind as menu.enabled so existing proxy is overridden with the real element
menu.enabled   = _enabled_keybind
menu.toggle_key = _toggle_key_elem

-- Native tree_node for the PS main menu entry
local _menu_tree = core.menu.tree_node()

-- on_menu_render: called by core.register_on_render_menu_callback
-- Renders a collapsible node in the PS main menu.
function menu.on_menu_render()
    _menu_tree:render("EAX Hunter SV", function()
        _enabled_keybind:render("Enable EAX Hunter SV", "Toggle rotation on/off")
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
