-- EAX Paladin Holy | libraries/menu.lua | Project Sylvanas
local unified = require("EAX_Unified/menu")
if not unified then error("[EAX Paladin Holy] EAX_Unified/menu not found!") end

local ROTATION_KEY = "paladin_holy"
local menu = {}

local MENU_DEF = {
    categories = {
        {
            name = "Healing",
            settings = {
                { key = "use_holy_shock",        type = "checkbox", label = "Holy Shock",         default = true,  tooltip = "Instant heal / offensive tool" },
                { key = "holy_shock_hp",         type = "slider",   label = "Holy Shock HP %",    default = 65, min = 20, max = 95, suffix = "%" },
                { key = "use_flash_of_light",    type = "checkbox", label = "Flash of Light",     default = true,  tooltip = "Fast direct heal" },
                { key = "flash_of_light_hp",     type = "slider",   label = "FoL HP %",           default = 70, min = 20, max = 95, suffix = "%" },
                { key = "holy_light_hp",         type = "slider",   label = "Holy Light HP %",    default = 50, min = 10, max = 85, suffix = "%", tooltip = "Efficient big heal below this HP" },
                { key = "use_lay_on_hands",      type = "checkbox", label = "Lay on Hands",       default = true,  tooltip = "Emergency full-heal" },
                { key = "lay_on_hands_hp",       type = "slider",   label = "LoH HP %",           default = 10, min = 3, max = 30, suffix = "%" },
                { key = "judge_debuff",          type = "combo",    label = "Judgement",          default = 1, options = {"Light", "Wisdom", "Justice"} },
                { key = "use_judgement",         type = "checkbox", label = "Use Judgement",      default = true },
            },
        },
        {
            name = "Blessings",
            settings = {
                { key = "use_blessing_of_kings",  type = "checkbox", label = "Blessing of Kings",  default = true },
                { key = "use_blessing_of_might",  type = "checkbox", label = "Blessing of Might",  default = false },
                { key = "use_blessing_of_wisdom", type = "checkbox", label = "Blessing of Wisdom", default = true },
                { key = "seal_choice",            type = "combo",    label = "Seal",               default = 1, options = {"Seal of Light", "Seal of Wisdom", "Seal of Righteousness"} },
                { key = "ooc_buff",               type = "checkbox", label = "Buff OOC",           default = true, tooltip = "Apply blessings out of combat" },
                { key = "ooc_drink",              type = "checkbox", label = "Drink OOC",          default = true },
            },
        },
        {
            name = "Cooldowns",
            settings = {
                { key = "use_avenging_wrath",       type = "checkbox", label = "Avenging Wrath",       default = true },
                { key = "use_divine_favor",         type = "checkbox", label = "Divine Favor",         default = true,  tooltip = "Guaranteed crit on next spell" },
                { key = "use_divine_illumination",  type = "checkbox", label = "Divine Illumination",  default = true,  tooltip = "50% mana cost reduction" },
                { key = "divine_illumination_pct",  type = "slider",   label = "Div. Illum. Mana %",   default = 30, min = 5, max = 60, suffix = "%" },
                { key = "auto_mana_potion",         type = "checkbox", label = "Auto Mana Potion",     default = true },
            },
        },
        {
            name = "Defensive",
            settings = {
                { key = "use_divine_protection", type = "checkbox", label = "Divine Protection", default = true },
                { key = "divine_protection_hp",  type = "slider",   label = "Div. Prot. HP %",   default = 30, min = 5, max = 60, suffix = "%" },
                { key = "use_divine_shield",     type = "checkbox", label = "Divine Shield",     default = true,  tooltip = "Last resort immunity" },
                { key = "divine_shield_hp",      type = "slider",   label = "Div. Shield HP %",  default = 10, min = 3, max = 30, suffix = "%" },
                { key = "use_cleanse",           type = "checkbox", label = "Cleanse Self",      default = true },
                { key = "use_cleanse_party",     type = "checkbox", label = "Cleanse Party",     default = true },
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
    on_enabled  = function() print("|cFFF5DD77[EAX Holy Paladin]|r Rotation ENABLED") end,
    on_disabled = function() print("|cFFF5DD77[EAX Holy Paladin]|r Rotation disabled") end,
}

unified.register_rotation("Paladin", "Holy", MENU_DEF, callbacks)

function menu.is_enabled()       return unified.is_rotation_active(ROTATION_KEY) end
function menu.get_setting(k, d)  return unified.get_setting(ROTATION_KEY, k, d) end
function menu.set_setting(k, v)  unified.set_setting(ROTATION_KEY, k, v) end
function menu.toggle_menu()      if unified.toggle_menu then unified.toggle_menu() end end

local function proxy(key, default)
    return { is_checked = function() return menu.get_setting(key, default) end,
             get_state  = function() return menu.get_setting(key, default) end,
             get        = function() return menu.get_setting(key, default) end }
end

menu.enabled                   = { is_checked = menu.is_enabled, get_state = menu.is_enabled }
menu.use_holy_shock            = proxy("use_holy_shock",           true)
menu.holy_shock_hp             = proxy("holy_shock_hp",            65)
menu.use_flash_of_light        = proxy("use_flash_of_light",       true)
menu.flash_of_light_hp         = proxy("flash_of_light_hp",        70)
menu.holy_light_hp             = proxy("holy_light_hp",            50)
menu.use_lay_on_hands          = proxy("use_lay_on_hands",         true)
menu.lay_on_hands_hp           = proxy("lay_on_hands_hp",          10)
menu.judge_debuff              = proxy("judge_debuff",             1)
menu.use_judgement             = proxy("use_judgement",            true)
menu.use_blessing_of_kings     = proxy("use_blessing_of_kings",    true)
menu.use_blessing_of_might     = proxy("use_blessing_of_might",    false)
menu.use_blessing_of_wisdom    = proxy("use_blessing_of_wisdom",   true)
menu.seal_choice               = proxy("seal_choice",              1)
menu.ooc_buff                  = proxy("ooc_buff",                 true)
menu.ooc_drink                 = proxy("ooc_drink",                true)
menu.use_avenging_wrath        = proxy("use_avenging_wrath",       true)
menu.use_divine_favor          = proxy("use_divine_favor",         true)
menu.use_divine_illumination   = proxy("use_divine_illumination",  true)
menu.divine_illumination_pct   = proxy("divine_illumination_pct",  30)
menu.auto_mana_potion          = proxy("auto_mana_potion",         true)
menu.use_divine_protection     = proxy("use_divine_protection",    true)
menu.divine_protection_hp      = proxy("divine_protection_hp",     30)
menu.use_divine_shield         = proxy("use_divine_shield",        true)
menu.divine_shield_hp          = proxy("divine_shield_hp",         10)
menu.use_cleanse               = proxy("use_cleanse",              true)
menu.use_cleanse_party         = proxy("use_cleanse_party",        true)
menu.debug                     = proxy("debug",                    false)

-- ============================================================================
-- NATIVE ELEMENTS & RENDER HOOKS  (added by EAX v4 patch)
-- These are required by main.lua:
--   core.register_on_render_callback(menu.on_render)
--   core.register_on_render_menu_callback(menu.on_menu_render)
-- ============================================================================

-- Native keybind for enable toggle (persisted by PS, shown in control panel)
-- Value 7 = "Unbound". main.lua uses get_state() / set() on this.
local _enabled_keybind  = core.menu.keybind(7, false, "eax_paladin_holy_enabled_kb")
local _toggle_key_elem  = core.menu.keybind(107, false, "eax_paladin_holy_toggle_key")

-- Wrap keybind as menu.enabled so existing proxy is overridden with the real element
menu.enabled   = _enabled_keybind
menu.toggle_key = _toggle_key_elem

-- Native tree_node for the PS main menu entry
local _menu_tree = core.menu.tree_node()

-- on_menu_render: called by core.register_on_render_menu_callback
-- Renders a collapsible node in the PS main menu.
function menu.on_menu_render()
    _menu_tree:render("EAX Pala Holy", function()
        _enabled_keybind:render("Enable EAX Pala Holy", "Toggle rotation on/off")
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
