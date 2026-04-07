-- EAX Rogue Subtlety | libraries/menu.lua | Project Sylvanas
local unified = require("EAX_Unified/menu")
if not unified then error("[EAX Rogue Subtlety] EAX_Unified/menu not found!") end

local ROTATION_KEY = "rogue_subtlety"
local menu = {}

local MENU_DEF = {
    categories = {
        {
            name = "Rotation",
            settings = {
                { key = "use_ambush",            type = "checkbox", label = "Ambush",            default = true,  tooltip = "Stealth opener" },
                { key = "use_garrote",           type = "checkbox", label = "Garrote",           default = true,  tooltip = "Stealth silence + bleed" },
                { key = "use_hemorrhage",        type = "checkbox", label = "Hemorrhage",        default = true,  tooltip = "Primary builder — Sanguinary Vein debuff" },
                { key = "use_backstab",          type = "checkbox", label = "Backstab",          default = true,  tooltip = "Behind-target builder" },
                { key = "use_sinister_strike",   type = "checkbox", label = "Sinister Strike",   default = true,  tooltip = "Front-target fallback" },
                { key = "use_rupture",           type = "checkbox", label = "Rupture",           default = true },
                { key = "rupture_combo_points",  type = "slider",   label = "Rupture Min CP",    default = 5, min = 1, max = 5 },
                { key = "rupture_refresh_seconds",type = "slider",  label = "Rupture Refresh (s)",default = 3, min = 1, max = 6 },
                { key = "use_eviscerate",        type = "checkbox", label = "Eviscerate",        default = true },
                { key = "eviscerate_combo_points",type = "slider",  label = "Eviscerate Min CP", default = 5, min = 1, max = 5 },
                { key = "use_slice_and_dice",    type = "checkbox", label = "Slice and Dice",    default = true },
                { key = "snd_combo_points",      type = "slider",   label = "SnD Min CP",        default = 1, min = 1, max = 5 },
                { key = "use_shadowstep",        type = "checkbox", label = "Shadowstep",        default = true,  tooltip = "Gap closer + positional reset" },
                { key = "use_premeditation",     type = "checkbox", label = "Premeditation",     default = true,  tooltip = "Free combo points before opener" },
                { key = "use_ghostly_strike",    type = "checkbox", label = "Ghostly Strike",    default = true,  tooltip = "Dodge buff + builder" },
                { key = "use_expose_armor",      type = "checkbox", label = "Expose Armor",      default = false },
                { key = "expose_armor_combo_points",type = "slider",label = "EA Min CP",         default = 5, min = 1, max = 5 },
            },
        },
        {
            name = "Cooldowns",
            settings = {
                { key = "use_cold_blood",        type = "checkbox", label = "Cold Blood",        default = true },
                { key = "use_cheap_shot",        type = "checkbox", label = "Cheap Shot",        default = true },
                { key = "use_kidney_shot",       type = "checkbox", label = "Kidney Shot",       default = true },
                { key = "kidney_shot_combo_points",type = "slider", label = "KS Min CP",         default = 5, min = 1, max = 5 },
                { key = "use_interrupt",         type = "checkbox", label = "Kick",              default = true },
            },
        },
        {
            name = "Defensive",
            settings = {
                { key = "use_evasion",         type = "checkbox", label = "Evasion",         default = true },
                { key = "evasion_hp_pct",      type = "slider",   label = "Evasion HP %",    default = 30, min = 5, max = 60, suffix = "%" },
                { key = "use_feint",           type = "checkbox", label = "Feint",           default = true },
                { key = "feint_aoe_threshold", type = "slider",   label = "Feint AoE Min",   default = 3, min = 2, max = 8 },
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
    on_enabled  = function() print("|cFF9999CC[EAX Subtlety]|r Rotation ENABLED") end,
    on_disabled = function() print("|cFF9999CC[EAX Subtlety]|r Rotation disabled") end,
}

unified.register_rotation("Rogue", "Subtlety", MENU_DEF, callbacks)

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
menu.use_ambush                 = proxy("use_ambush",                true)
menu.use_garrote                = proxy("use_garrote",               true)
menu.use_hemorrhage             = proxy("use_hemorrhage",            true)
menu.use_backstab               = proxy("use_backstab",              true)
menu.use_sinister_strike        = proxy("use_sinister_strike",       true)
menu.use_rupture                = proxy("use_rupture",               true)
menu.rupture_combo_points       = proxy("rupture_combo_points",      5)
menu.rupture_refresh_seconds    = proxy("rupture_refresh_seconds",   3)
menu.use_eviscerate             = proxy("use_eviscerate",            true)
menu.eviscerate_combo_points    = proxy("eviscerate_combo_points",   5)
menu.use_slice_and_dice         = proxy("use_slice_and_dice",        true)
menu.snd_combo_points           = proxy("snd_combo_points",          1)
menu.use_shadowstep             = proxy("use_shadowstep",            true)
menu.use_premeditation          = proxy("use_premeditation",         true)
menu.use_ghostly_strike         = proxy("use_ghostly_strike",        true)
menu.use_expose_armor           = proxy("use_expose_armor",          false)
menu.expose_armor_combo_points  = proxy("expose_armor_combo_points", 5)
menu.use_cold_blood             = proxy("use_cold_blood",            true)
menu.use_cheap_shot             = proxy("use_cheap_shot",            true)
menu.use_kidney_shot            = proxy("use_kidney_shot",           true)
menu.kidney_shot_combo_points   = proxy("kidney_shot_combo_points",  5)
menu.use_interrupt              = proxy("use_interrupt",             true)
menu.use_evasion                = proxy("use_evasion",               true)
menu.evasion_hp_pct             = proxy("evasion_hp_pct",            30)
menu.use_feint                  = proxy("use_feint",                 true)
menu.feint_aoe_threshold        = proxy("feint_aoe_threshold",       3)
menu.debug                      = proxy("debug",                     false)

-- ============================================================================
-- NATIVE ELEMENTS & RENDER HOOKS  (added by EAX v4 patch)
-- These are required by main.lua:
--   core.register_on_render_callback(menu.on_render)
--   core.register_on_render_menu_callback(menu.on_menu_render)
-- ============================================================================

-- Native keybind for enable toggle (persisted by PS, shown in control panel)
-- Value 7 = "Unbound". main.lua uses get_state() / set() on this.
local _enabled_keybind  = core.menu.keybind(7, false, "eax_rogue_subtlety_enabled_kb")
local _toggle_key_elem  = core.menu.keybind(107, false, "eax_rogue_subtlety_toggle_key")

-- Wrap keybind as menu.enabled so existing proxy is overridden with the real element
menu.enabled   = _enabled_keybind
menu.toggle_key = _toggle_key_elem

-- Native tree_node for the PS main menu entry
local _menu_tree = core.menu.tree_node()

-- on_menu_render: called by core.register_on_render_menu_callback
-- Renders a collapsible node in the PS main menu.
function menu.on_menu_render()
    _menu_tree:render("EAX Subtlety", function()
        _enabled_keybind:render("Enable EAX Subtlety", "Toggle rotation on/off")
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
