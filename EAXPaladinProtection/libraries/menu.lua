-- EAX Paladin Protection | libraries/menu.lua | Project Sylvanas
local unified = require("EAX_Unified/menu")
if not unified then error("[EAX Paladin Protection] EAX_Unified/menu not found!") end

local ROTATION_KEY = "paladin_protection"
local menu = {}

local MENU_DEF = {
    categories = {
        {
            name = "Rotation",
            settings = {
                { key = "use_consecration",        type = "checkbox", label = "Consecration",       default = true,  tooltip = "Core AoE threat — keep active" },
                { key = "use_holy_shield",         type = "checkbox", label = "Holy Shield",        default = true,  tooltip = "Block + damage — highest priority" },
                { key = "prioritize_holy_shield",  type = "checkbox", label = "Prioritise Holy Shield", default = true },
                { key = "use_hammer_of_wrath",     type = "checkbox", label = "Hammer of Wrath",    default = true,  tooltip = "Execute ranged filler" },
                { key = "use_hammer_of_justice",   type = "checkbox", label = "Hammer of Justice",  default = true,  tooltip = "Stun interrupt" },
                { key = "use_avengers_shield",     type = "checkbox", label = "Avenger's Shield",   default = true,  tooltip = "Pull / silence" },
                { key = "use_exorcism",            type = "checkbox", label = "Exorcism",           default = true,  tooltip = "Undead/Demon burst" },
                { key = "use_judgement",           type = "checkbox", label = "Judgement",          default = true },
                { key = "seal_choice",             type = "combo",    label = "Seal",               default = 1, options = {"Seal of Vengeance", "Seal of Light", "Seal of Wisdom", "Seal of Righteousness"} },
                { key = "use_seal_of_wisdom_low_mana", type = "checkbox", label = "Swap to Wisdom on Low Mana", default = true },
                { key = "seal_of_wisdom_mana_pct", type = "slider",   label = "Wisdom Swap Mana %", default = 30, min = 5, max = 60, suffix = "%" },
                { key = "use_righteous_defense",   type = "checkbox", label = "Righteous Defense",  default = true,  tooltip = "Multi-target taunt" },
                { key = "no_taunt",                type = "checkbox", label = "Disable Taunt",      default = false },
                { key = "use_auto_tab",            type = "checkbox", label = "Auto Tab Target",    default = true },
                { key = "tab_max_mobs",            type = "slider",   label = "Tab Max Mobs",       default = 5, min = 1, max = 10 },
            },
        },
        {
            name = "Blessings",
            settings = {
                { key = "use_blessing_of_kings",     type = "checkbox", label = "Blessing of Kings",     default = true },
                { key = "use_blessing_of_sanctuary", type = "checkbox", label = "Blessing of Sanctuary", default = true, tooltip = "Block + threat — tank-specific" },
                { key = "ooc_buff",                  type = "checkbox", label = "Buff OOC",              default = true },
            },
        },
        {
            name = "Defensive",
            settings = {
                { key = "use_divine_shield",    type = "checkbox", label = "Divine Shield",     default = true },
                { key = "divine_shield_hp",     type = "slider",   label = "Div. Shield HP %",  default = 10, min = 3, max = 30, suffix = "%" },
                { key = "use_lay_on_hands",     type = "checkbox", label = "Lay on Hands",      default = true },
                { key = "lay_on_hands_hp",      type = "slider",   label = "LoH HP %",          default = 10, min = 3, max = 30, suffix = "%" },
                { key = "use_cleanse",          type = "checkbox", label = "Cleanse Self",      default = true },
                { key = "auto_combat_potions",  type = "checkbox", label = "Auto Combat Potions",default = true },
            },
        },
        {
            name = "Cooldowns",
            settings = {
                { key = "use_avenging_wrath", type = "checkbox", label = "Avenging Wrath", default = true },
                { key = "use_racial",         type = "checkbox", label = "Racial Ability", default = true },
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
    on_enabled  = function() print("|cFFF58BAC[EAX Prot Paladin]|r Rotation ENABLED") end,
    on_disabled = function() print("|cFFF58BAC[EAX Prot Paladin]|r Rotation disabled") end,
}

unified.register_rotation("Paladin", "Protection", MENU_DEF, callbacks)

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
menu.use_consecration              = proxy("use_consecration",          true)
menu.use_holy_shield               = proxy("use_holy_shield",           true)
menu.prioritize_holy_shield        = proxy("prioritize_holy_shield",    true)
menu.use_hammer_of_wrath           = proxy("use_hammer_of_wrath",       true)
menu.use_hammer_of_justice         = proxy("use_hammer_of_justice",     true)
menu.use_avengers_shield           = proxy("use_avengers_shield",       true)
menu.use_exorcism                  = proxy("use_exorcism",              true)
menu.use_judgement                 = proxy("use_judgement",             true)
menu.seal_choice                   = proxy("seal_choice",               1)
menu.use_seal_of_wisdom_low_mana   = proxy("use_seal_of_wisdom_low_mana",true)
menu.seal_of_wisdom_mana_pct       = proxy("seal_of_wisdom_mana_pct",   30)
menu.use_righteous_defense         = proxy("use_righteous_defense",     true)
menu.no_taunt                      = proxy("no_taunt",                  false)
menu.use_auto_tab                  = proxy("use_auto_tab",              true)
menu.tab_max_mobs                  = proxy("tab_max_mobs",              5)
menu.use_blessing_of_kings         = proxy("use_blessing_of_kings",     true)
menu.use_blessing_of_sanctuary     = proxy("use_blessing_of_sanctuary", true)
menu.ooc_buff                      = proxy("ooc_buff",                  true)
menu.use_divine_shield             = proxy("use_divine_shield",         true)
menu.divine_shield_hp              = proxy("divine_shield_hp",          10)
menu.use_lay_on_hands              = proxy("use_lay_on_hands",          true)
menu.lay_on_hands_hp               = proxy("lay_on_hands_hp",           10)
menu.use_cleanse                   = proxy("use_cleanse",               true)
menu.auto_combat_potions           = proxy("auto_combat_potions",       true)
menu.use_avenging_wrath            = proxy("use_avenging_wrath",        true)
menu.use_racial                    = proxy("use_racial",                true)
menu.debug                         = proxy("debug",                     false)

-- ============================================================================
-- NATIVE ELEMENTS & RENDER HOOKS  (added by EAX v4 patch)
-- These are required by main.lua:
--   core.register_on_render_callback(menu.on_render)
--   core.register_on_render_menu_callback(menu.on_menu_render)
-- ============================================================================

-- Native keybind for enable toggle (persisted by PS, shown in control panel)
-- Value 7 = "Unbound". main.lua uses get_state() / set() on this.
local _enabled_keybind  = core.menu.keybind(7, false, "eax_paladin_protection_enabled_kb")
local _toggle_key_elem  = core.menu.keybind(107, false, "eax_paladin_protection_toggle_key")

-- Wrap keybind as menu.enabled so existing proxy is overridden with the real element
menu.enabled   = _enabled_keybind
menu.toggle_key = _toggle_key_elem

-- Native tree_node for the PS main menu entry
local _menu_tree = core.menu.tree_node()

-- on_menu_render: called by core.register_on_render_menu_callback
-- Renders a collapsible node in the PS main menu.
function menu.on_menu_render()
    _menu_tree:render("EAX Pala Prot", function()
        _enabled_keybind:render("Enable EAX Pala Prot", "Toggle rotation on/off")
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
