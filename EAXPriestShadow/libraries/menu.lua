-- EAX Priest Shadow | libraries/menu.lua | Project Sylvanas
local unified = require("EAX_Unified/menu")
if not unified then error("[EAX Priest Shadow] EAX_Unified/menu not found!") end

local ROTATION_KEY = "priest_shadow"
local menu = {}

local MENU_DEF = {
    categories = {
        {
            name = "Rotation",
            settings = {
                { key = "use_vampiric_touch",     type = "checkbox", label = "Vampiric Touch",     default = true,  tooltip = "Core DoT — always maintain" },
                { key = "use_shadow_word_pain",   type = "checkbox", label = "Shadow Word: Pain",  default = true,  tooltip = "Core DoT — always maintain" },
                { key = "use_devouring_plague",   type = "checkbox", label = "Devouring Plague",   default = true,  tooltip = "Core DoT — maintain on target" },
                { key = "use_mind_flay",          type = "checkbox", label = "Mind Flay",          default = true,  tooltip = "Primary filler channel" },
                { key = "use_mind_blast",         type = "checkbox", label = "Mind Blast",         default = true,  tooltip = "Hard-cast on cooldown" },
                { key = "use_shadow_word_death",  type = "checkbox", label = "Shadow Word: Death", default = true,  tooltip = "Execute range filler — careful with backlash" },
                { key = "use_vampiric_embrace",   type = "checkbox", label = "Vampiric Embrace",   default = true,  tooltip = "Maintain VE on self" },
                { key = "use_shadow_form",        type = "checkbox", label = "Maintain Shadowform",default = true,  tooltip = "Auto re-enter Shadowform if dropped" },
            },
        },
        {
            name = "Cooldowns",
            settings = {
                { key = "use_shadowfiend",   type = "checkbox", label = "Shadowfiend",     default = true },
                { key = "shadowfiend_pct",   type = "slider",   label = "Shadowfiend Mana %", default = 30, min = 5, max = 60, suffix = "%" },
                { key = "use_power_infusion",type = "checkbox", label = "Power Infusion",  default = true },
                { key = "use_racial",        type = "checkbox", label = "Racial Ability",  default = true },
                { key = "cd_min_ttd",        type = "slider",   label = "Min TTD for CDs (s)", default = 10, min = 5, max = 30 },
            },
        },
        {
            name = "Defensive",
            settings = {
                { key = "use_power_word_shield", type = "checkbox", label = "PW: Shield",     default = true },
                { key = "shield_hp",             type = "slider",   label = "Shield HP %",    default = 35, min = 5, max = 70, suffix = "%" },
                { key = "use_fade",              type = "checkbox", label = "Fade",           default = true,  tooltip = "Drop threat" },
                { key = "use_dispersion",        type = "checkbox", label = "Dispersion",     default = true,  tooltip = "Emergency 90% DR channel" },
                { key = "dispersion_hp",         type = "slider",   label = "Dispersion HP %",default = 15, min = 3, max = 40, suffix = "%" },
            },
        },
        {
            name = "Buffs",
            settings = {
                { key = "use_fortitude",     type = "checkbox", label = "Power Word: Fortitude", default = true },
                { key = "use_divine_spirit", type = "checkbox", label = "Divine Spirit",         default = true },
                { key = "use_inner_fire",    type = "checkbox", label = "Inner Fire",            default = true },
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
    on_enabled  = function() print("|cFFBB44EE[EAX Shadow]|r Rotation ENABLED") end,
    on_disabled = function() print("|cFFBB44EE[EAX Shadow]|r Rotation disabled") end,
}

unified.register_rotation("Priest", "Shadow", MENU_DEF, callbacks)

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
menu.use_vampiric_touch       = proxy("use_vampiric_touch",     true)
menu.use_shadow_word_pain     = proxy("use_shadow_word_pain",   true)
menu.use_devouring_plague     = proxy("use_devouring_plague",   true)
menu.use_mind_flay            = proxy("use_mind_flay",          true)
menu.use_mind_blast           = proxy("use_mind_blast",         true)
menu.use_shadow_word_death    = proxy("use_shadow_word_death",  true)
menu.use_vampiric_embrace     = proxy("use_vampiric_embrace",   true)
menu.use_shadow_form          = proxy("use_shadow_form",        true)
menu.use_shadowfiend          = proxy("use_shadowfiend",        true)
menu.shadowfiend_pct          = proxy("shadowfiend_pct",        30)
menu.use_power_infusion       = proxy("use_power_infusion",     true)
menu.use_racial               = proxy("use_racial",             true)
menu.cd_min_ttd               = proxy("cd_min_ttd",             10)
menu.use_power_word_shield    = proxy("use_power_word_shield",  true)
menu.shield_hp                = proxy("shield_hp",              35)
menu.use_fade                 = proxy("use_fade",               true)
menu.use_dispersion           = proxy("use_dispersion",         true)
menu.dispersion_hp            = proxy("dispersion_hp",          15)
menu.use_fortitude            = proxy("use_fortitude",          true)
menu.use_divine_spirit        = proxy("use_divine_spirit",      true)
menu.use_inner_fire           = proxy("use_inner_fire",         true)
menu.debug                    = proxy("debug",                  false)

-- ============================================================================
-- NATIVE ELEMENTS & RENDER HOOKS  (added by EAX v4 patch)
-- These are required by main.lua:
--   core.register_on_render_callback(menu.on_render)
--   core.register_on_render_menu_callback(menu.on_menu_render)
-- ============================================================================

-- Native keybind for enable toggle (persisted by PS, shown in control panel)
-- Value 7 = "Unbound". main.lua uses get_state() / set() on this.
local _enabled_keybind  = core.menu.keybind(7, false, "eax_priest_shadow_enabled_kb")
local _toggle_key_elem  = core.menu.keybind(107, false, "eax_priest_shadow_toggle_key")

-- Wrap keybind as menu.enabled so existing proxy is overridden with the real element
menu.enabled   = _enabled_keybind
menu.toggle_key = _toggle_key_elem

-- Native tree_node for the PS main menu entry
local _menu_tree = core.menu.tree_node()

-- on_menu_render: called by core.register_on_render_menu_callback
-- Renders a collapsible node in the PS main menu.
function menu.on_menu_render()
    _menu_tree:render("EAX Shadow", function()
        _enabled_keybind:render("Enable EAX Shadow", "Toggle rotation on/off")
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
