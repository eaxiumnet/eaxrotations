-- EAX Paladin Retribution | libraries/menu.lua | Project Sylvanas
local unified = require("EAX_Unified/menu")
if not unified then error("[EAX Paladin Retribution] EAX_Unified/menu not found!") end

local ROTATION_KEY = "paladin_retribution"
local menu = {}

local MENU_DEF = {
    categories = {
        {
            name = "Rotation",
            settings = {
                { key = "use_crusader_strike",    type = "checkbox", label = "Crusader Strike",    default = true,  tooltip = "Primary melee ability" },
                { key = "use_divine_storm",       type = "checkbox", label = "Divine Storm",       default = true,  tooltip = "AoE + self heal" },
                { key = "use_hammer_of_wrath",    type = "checkbox", label = "Hammer of Wrath",    default = true,  tooltip = "Execute ranged filler" },
                { key = "use_exorcism",           type = "checkbox", label = "Exorcism",           default = true },
                { key = "use_judgement",          type = "checkbox", label = "Judgement",          default = true },
                { key = "use_consecration",       type = "checkbox", label = "Consecration",       default = true },
                { key = "use_hammer_of_justice",  type = "checkbox", label = "Hammer of Justice",  default = true,  tooltip = "Stun interrupt" },
                { key = "seal_choice",            type = "combo",    label = "Seal",               default = 1, options = {"Seal of Vengeance", "Seal of Command", "Seal of Blood", "Seal of the Martyr"} },
                { key = "judge_debuff",           type = "combo",    label = "Judgement Debuff",   default = 1, options = {"Light", "Wisdom", "Justice"} },
            },
        },
        {
            name = "Blessings",
            settings = {
                { key = "use_blessing_of_kings",  type = "checkbox", label = "Blessing of Kings",  default = true },
                { key = "use_blessing_of_might",  type = "checkbox", label = "Blessing of Might",  default = true },
                { key = "ooc_buff",               type = "checkbox", label = "Buff OOC",           default = true },
                { key = "ooc_drink",              type = "checkbox", label = "Drink OOC",          default = true },
            },
        },
        {
            name = "Cooldowns",
            settings = {
                { key = "use_avenging_wrath",    type = "checkbox", label = "Avenging Wrath",    default = true,  tooltip = "30% damage increase" },
                { key = "use_divine_favor",      type = "checkbox", label = "Divine Favor",      default = true },
                { key = "use_racial",            type = "checkbox", label = "Racial Ability",    default = true },
                { key = "cd_min_ttd",            type = "slider",   label = "Min TTD for CDs (s)",default = 10, min = 5, max = 30 },
            },
        },
        {
            name = "Defensive",
            settings = {
                { key = "use_divine_shield",  type = "checkbox", label = "Divine Shield",    default = true },
                { key = "divine_shield_hp",   type = "slider",   label = "Div. Shield HP %", default = 10, min = 3, max = 30, suffix = "%" },
                { key = "use_lay_on_hands",   type = "checkbox", label = "Lay on Hands",     default = true },
                { key = "lay_on_hands_hp",    type = "slider",   label = "LoH HP %",         default = 10, min = 3, max = 30, suffix = "%" },
                { key = "use_cleanse",        type = "checkbox", label = "Cleanse Self",     default = true },
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
    on_enabled  = function() print("|cFFE56699[EAX Retribution]|r Rotation ENABLED") end,
    on_disabled = function() print("|cFFE56699[EAX Retribution]|r Rotation disabled") end,
}

unified.register_rotation("Paladin", "Retribution", MENU_DEF, callbacks)

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
menu.use_crusader_strike      = proxy("use_crusader_strike",   true)
menu.use_divine_storm         = proxy("use_divine_storm",      true)
menu.use_hammer_of_wrath      = proxy("use_hammer_of_wrath",   true)
menu.use_exorcism             = proxy("use_exorcism",          true)
menu.use_judgement            = proxy("use_judgement",         true)
menu.use_consecration         = proxy("use_consecration",      true)
menu.use_hammer_of_justice    = proxy("use_hammer_of_justice", true)
menu.seal_choice              = proxy("seal_choice",           1)
menu.judge_debuff             = proxy("judge_debuff",          1)
menu.use_blessing_of_kings    = proxy("use_blessing_of_kings", true)
menu.use_blessing_of_might    = proxy("use_blessing_of_might", true)
menu.ooc_buff                 = proxy("ooc_buff",              true)
menu.ooc_drink                = proxy("ooc_drink",             true)
menu.use_avenging_wrath       = proxy("use_avenging_wrath",    true)
menu.use_divine_favor         = proxy("use_divine_favor",      true)
menu.use_racial               = proxy("use_racial",            true)
menu.cd_min_ttd               = proxy("cd_min_ttd",            10)
menu.use_divine_shield        = proxy("use_divine_shield",     true)
menu.divine_shield_hp         = proxy("divine_shield_hp",      10)
menu.use_lay_on_hands         = proxy("use_lay_on_hands",      true)
menu.lay_on_hands_hp          = proxy("lay_on_hands_hp",       10)
menu.use_cleanse              = proxy("use_cleanse",           true)
menu.debug                    = proxy("debug",                 false)

-- ============================================================================
-- NATIVE ELEMENTS & RENDER HOOKS  (added by EAX v4 patch)
-- These are required by main.lua:
--   core.register_on_render_callback(menu.on_render)
--   core.register_on_render_menu_callback(menu.on_menu_render)
-- ============================================================================

-- Native keybind for enable toggle (persisted by PS, shown in control panel)
-- Value 7 = "Unbound". main.lua uses get_state() / set() on this.
local _enabled_keybind  = core.menu.keybind(7, false, "eax_paladin_retribution_enabled_kb")
local _toggle_key_elem  = core.menu.keybind(107, false, "eax_paladin_retribution_toggle_key")

-- Wrap keybind as menu.enabled so existing proxy is overridden with the real element
menu.enabled   = _enabled_keybind
menu.toggle_key = _toggle_key_elem

-- Native tree_node for the PS main menu entry
local _menu_tree = core.menu.tree_node()

-- on_menu_render: called by core.register_on_render_menu_callback
-- Renders a collapsible node in the PS main menu.
function menu.on_menu_render()
    _menu_tree:render("EAX Ret", function()
        _enabled_keybind:render("Enable EAX Ret", "Toggle rotation on/off")
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

-- Register render callbacks (required for PS menu integration)
core.register_on_render_callback(menu.on_render)
core.register_on_render_menu_callback(menu.on_menu_render)

return menu
