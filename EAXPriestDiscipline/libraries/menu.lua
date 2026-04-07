-- EAX Priest Discipline | libraries/menu.lua | Project Sylvanas
local unified = require("EAX_Unified/menu")
if not unified then error("[EAX Priest Discipline] EAX_Unified/menu not found!") end

local ROTATION_KEY = "priest_discipline"
local menu = {}

local MENU_DEF = {
    categories = {
        {
            name = "Healing",
            settings = {
                { key = "disc_use_shield",            type = "checkbox", label = "Power Word: Shield",   default = true,  tooltip = "Core absorb — high priority" },
                { key = "disc_shield_hp",             type = "slider",   label = "Shield HP %",          default = 90, min = 20, max = 100, suffix = "%" },
                { key = "disc_shield_tank_only",      type = "checkbox", label = "Shield Tank Only",     default = false, tooltip = "Only shield the main tank" },
                { key = "disc_use_renew",             type = "checkbox", label = "Renew",                default = true,  tooltip = "HoT maintenance" },
                { key = "disc_renew_hp",              type = "slider",   label = "Renew HP %",           default = 80, min = 20, max = 100, suffix = "%" },
                { key = "disc_flash_heal_hp",         type = "slider",   label = "Flash Heal HP %",      default = 60, min = 10, max = 90, suffix = "%" },
                { key = "disc_emergency_hp",          type = "slider",   label = "Emergency Heal HP %",  default = 30, min = 5, max = 60, suffix = "%" },
                { key = "disc_use_prayer_of_mending", type = "checkbox", label = "Prayer of Mending",    default = true,  tooltip = "Bouncing heal — apply on cooldown" },
                { key = "disc_use_prayer_of_healing", type = "checkbox", label = "Prayer of Healing",    default = true,  tooltip = "AoE heal when multiple injured" },
                { key = "disc_aoe_count",             type = "slider",   label = "AoE Heal Count",       default = 3, min = 2, max = 8, tooltip = "Use PoH when this many injured" },
                { key = "disc_prepull_shield",        type = "checkbox", label = "Pre-Pull Shield",      default = true },
                { key = "disc_prepull_renew",         type = "checkbox", label = "Pre-Pull Renew",       default = true },
            },
        },
        {
            name = "Cooldowns",
            settings = {
                { key = "disc_use_pain_suppression",  type = "checkbox", label = "Pain Suppression",     default = true },
                { key = "disc_pain_suppression_hp",   type = "slider",   label = "Pain Supp. HP %",      default = 30, min = 5, max = 60, suffix = "%" },
                { key = "disc_use_power_infusion",    type = "checkbox", label = "Power Infusion",       default = true },
                { key = "disc_use_inner_focus",       type = "checkbox", label = "Inner Focus",          default = true,  tooltip = "Free cast — use on big heal" },
                { key = "use_shadowfiend",            type = "checkbox", label = "Shadowfiend",          default = true },
                { key = "shadowfiend_pct",            type = "slider",   label = "Shadowfiend Mana %",   default = 30, min = 5, max = 60, suffix = "%" },
            },
        },
        {
            name = "Buffs / Utility",
            settings = {
                { key = "use_fortitude",      type = "checkbox", label = "Power Word: Fortitude", default = true },
                { key = "use_divine_spirit",  type = "checkbox", label = "Divine Spirit",         default = true },
                { key = "use_inner_fire",     type = "checkbox", label = "Inner Fire",            default = true },
                { key = "use_fear_ward",      type = "checkbox", label = "Fear Ward",             default = true,  tooltip = "Apply to tank" },
                { key = "use_fade",           type = "checkbox", label = "Fade",                  default = true,  tooltip = "Drop threat" },
                { key = "use_racial",         type = "checkbox", label = "Racial Ability",        default = true },
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
    on_enabled  = function() print("|cFFCCCCFF[EAX Discipline]|r Rotation ENABLED") end,
    on_disabled = function() print("|cFFCCCCFF[EAX Discipline]|r Rotation disabled") end,
}

unified.register_rotation("Priest", "Discipline", MENU_DEF, callbacks)

function menu.is_enabled()       return unified.is_rotation_active(ROTATION_KEY) end
function menu.get_setting(k, d)  return unified.get_setting(ROTATION_KEY, k, d) end
function menu.set_setting(k, v)  unified.set_setting(ROTATION_KEY, k, v) end
function menu.toggle_menu()      if unified.toggle_menu then unified.toggle_menu() end end

local function proxy(key, default)
    return { is_checked = function() return menu.get_setting(key, default) end,
             get_state  = function() return menu.get_setting(key, default) end,
             get        = function() return menu.get_setting(key, default) end }
end

menu.enabled                      = { is_checked = menu.is_enabled, get_state = menu.is_enabled }
menu.disc_use_shield              = proxy("disc_use_shield",             true)
menu.disc_shield_hp               = proxy("disc_shield_hp",              90)
menu.disc_shield_tank_only        = proxy("disc_shield_tank_only",       false)
menu.disc_use_renew               = proxy("disc_use_renew",              true)
menu.disc_renew_hp                = proxy("disc_renew_hp",               80)
menu.disc_flash_heal_hp           = proxy("disc_flash_heal_hp",          60)
menu.disc_emergency_hp            = proxy("disc_emergency_hp",           30)
menu.disc_use_prayer_of_mending   = proxy("disc_use_prayer_of_mending",  true)
menu.disc_use_prayer_of_healing   = proxy("disc_use_prayer_of_healing",  true)
menu.disc_aoe_count               = proxy("disc_aoe_count",              3)
menu.disc_prepull_shield          = proxy("disc_prepull_shield",         true)
menu.disc_prepull_renew           = proxy("disc_prepull_renew",          true)
menu.disc_use_pain_suppression    = proxy("disc_use_pain_suppression",   true)
menu.disc_pain_suppression_hp     = proxy("disc_pain_suppression_hp",    30)
menu.disc_use_power_infusion      = proxy("disc_use_power_infusion",     true)
menu.disc_use_inner_focus         = proxy("disc_use_inner_focus",        true)
menu.use_shadowfiend              = proxy("use_shadowfiend",             true)
menu.shadowfiend_pct              = proxy("shadowfiend_pct",             30)
menu.use_fortitude                = proxy("use_fortitude",               true)
menu.use_divine_spirit            = proxy("use_divine_spirit",           true)
menu.use_inner_fire               = proxy("use_inner_fire",              true)
menu.use_fear_ward                = proxy("use_fear_ward",               true)
menu.use_fade                     = proxy("use_fade",                    true)
menu.use_racial                   = proxy("use_racial",                  true)
menu.debug                        = proxy("debug",                       false)

-- ============================================================================
-- NATIVE ELEMENTS & RENDER HOOKS  (added by EAX v4 patch)
-- These are required by main.lua:
--   core.register_on_render_callback(menu.on_render)
--   core.register_on_render_menu_callback(menu.on_menu_render)
-- ============================================================================

-- Native keybind for enable toggle (persisted by PS, shown in control panel)
-- Value 7 = "Unbound". main.lua uses get_state() / set() on this.
local _enabled_keybind  = core.menu.keybind(7, false, "eax_priest_discipline_enabled_kb")
local _toggle_key_elem  = core.menu.keybind(107, false, "eax_priest_discipline_toggle_key")

-- Wrap keybind as menu.enabled so existing proxy is overridden with the real element
menu.enabled   = _enabled_keybind
menu.toggle_key = _toggle_key_elem

-- Native tree_node for the PS main menu entry
local _menu_tree = core.menu.tree_node()

-- on_menu_render: called by core.register_on_render_menu_callback
-- Renders a collapsible node in the PS main menu.
function menu.on_menu_render()
    _menu_tree:render("EAX Disc", function()
        _enabled_keybind:render("Enable EAX Disc", "Toggle rotation on/off")
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
