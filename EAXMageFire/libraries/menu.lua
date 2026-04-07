-- EAX Mage Fire | libraries/menu.lua | Project Sylvanas
-- Self-contained: owns its MENU_DEF and self-registers with EAX_Unified.
-- Drop this file into EAXMageFire/libraries/ — no other changes needed.

local unified = require("EAX_Unified/menu")
if not unified then error("[EAX Mage Fire] EAX_Unified/menu not found!") end

local ROTATION_KEY = "mage_fire"
local menu = {}

-- ============================================================================
-- MENU DEFINITION  (single source of truth for all settings)
-- ============================================================================
local MENU_DEF = {
    categories = {
        {
            name = "Rotation",
            settings = {
                { key = "use_fireball",       type = "checkbox", label = "Fireball",         default = true,  tooltip = "Main filler spell" },
                { key = "use_pyroblast",      type = "checkbox", label = "Pyroblast",        default = true,  tooltip = "Opener & Hot Streak proc" },
                { key = "use_scorch",         type = "checkbox", label = "Scorch",           default = true,  tooltip = "Maintain Improved Scorch debuff" },
                { key = "use_fire_blast",     type = "checkbox", label = "Fire Blast",       default = true,  tooltip = "Instant cast filler" },
                { key = "use_living_bomb",    type = "checkbox", label = "Living Bomb",      default = true,  tooltip = "DoT — maintain on target" },
                { key = "use_flamestrike",    type = "checkbox", label = "Flamestrike",      default = true,  tooltip = "AoE ground effect" },
                { key = "aoe_threshold",      type = "slider",   label = "AoE Min Targets",  default = 3, min = 2, max = 10, tooltip = "Use Flamestrike when this many targets clustered" },
            },
        },
        {
            name = "Cooldowns",
            settings = {
                { key = "use_combustion",          type = "checkbox", label = "Combustion",           default = true,  tooltip = "Major DPS cooldown" },
                { key = "use_presence_of_mind",    type = "checkbox", label = "Presence of Mind",     default = true,  tooltip = "Next cast is instant" },
                { key = "use_evocation",           type = "checkbox", label = "Evocation",            default = true,  tooltip = "Mana recovery channel" },
                { key = "evocation_mana_pct",      type = "slider",   label = "Evocation Mana %",     default = 20, min = 5, max = 50, suffix = "%", tooltip = "Evocate below this mana %" },
                { key = "use_racial",              type = "checkbox", label = "Racial Ability",       default = true,  tooltip = "Use class racial on cooldown" },
                { key = "cd_min_ttd",              type = "slider",   label = "Min TTD for CDs (s)",  default = 10, min = 5, max = 30, tooltip = "Don't use big CDs below this time-to-die" },
            },
        },
        {
            name = "Defensive",
            settings = {
                { key = "use_ice_barrier",    type = "checkbox", label = "Ice Barrier",      default = true,  tooltip = "Pre-emptive absorb shield" },
                { key = "ice_barrier_hp",     type = "slider",   label = "Ice Barrier HP %", default = 40, min = 0, max = 100, suffix = "%", tooltip = "Cast when HP drops below this %" },
                { key = "use_ice_block",      type = "checkbox", label = "Ice Block",        default = true,  tooltip = "Last-resort immunity" },
                { key = "ice_block_hp",       type = "slider",   label = "Ice Block HP %",   default = 20, min = 0, max = 100, suffix = "%", tooltip = "Cast when HP drops below this %" },
            },
        },
        {
            name = "System",
            settings = {
                { key = "debug", type = "checkbox", label = "Debug Mode", default = false, tooltip = "Print verbose log to console" },
            },
        },
    },
}

-- ============================================================================
-- CALLBACKS
-- ============================================================================
local callbacks = {
    on_enabled  = function() print("|cFFFF8000[EAX Fire]|r Rotation ENABLED") end,
    on_disabled = function() print("|cFFFF8000[EAX Fire]|r Rotation disabled") end,
    is_valid    = function()
        local me = core.object_manager and core.object_manager.get_local_player()
        if not me then return false end
        return me:get_class() == 8  -- Mage
    end,
}

-- ============================================================================
-- REGISTRATION
-- ============================================================================
unified.register_rotation("Mage", "Fire", MENU_DEF, callbacks)

-- ============================================================================
-- SETTING ACCESS API  (used by main.lua)
-- ============================================================================
function menu.is_enabled()       return unified.is_rotation_active(ROTATION_KEY) end
function menu.get_setting(k, d)  return unified.get_setting(ROTATION_KEY, k, d) end
function menu.set_setting(k, v)  unified.set_setting(ROTATION_KEY, k, v) end
function menu.toggle_menu()      if unified.toggle_menu then unified.toggle_menu() end end

local function proxy(key, default)
    return {
        is_checked  = function() return menu.get_setting(key, default) end,
        get_state   = function() return menu.get_setting(key, default) end,
        get_value   = function() return menu.get_setting(key, default) end,
        get         = function() return menu.get_setting(key, default) end,
    }
end

menu.enabled                = { is_checked = menu.is_enabled, get_state = menu.is_enabled }
menu.use_fireball           = proxy("use_fireball",        true)
menu.use_pyroblast          = proxy("use_pyroblast",       true)
menu.use_scorch             = proxy("use_scorch",          true)
menu.use_fire_blast         = proxy("use_fire_blast",      true)
menu.use_living_bomb        = proxy("use_living_bomb",     true)
menu.use_flamestrike        = proxy("use_flamestrike",     true)
menu.aoe_threshold          = proxy("aoe_threshold",       3)
menu.use_combustion         = proxy("use_combustion",      true)
menu.use_presence_of_mind   = proxy("use_presence_of_mind",true)
menu.use_evocation          = proxy("use_evocation",       true)
menu.evocation_mana_pct     = proxy("evocation_mana_pct",  20)
menu.use_racial             = proxy("use_racial",          true)
menu.cd_min_ttd             = proxy("cd_min_ttd",          10)
menu.use_ice_barrier        = proxy("use_ice_barrier",     true)
menu.ice_barrier_hp         = proxy("ice_barrier_hp",      40)
menu.use_ice_block          = proxy("use_ice_block",       true)
menu.ice_block_hp           = proxy("ice_block_hp",        20)
menu.debug                  = proxy("debug",               false)

-- ============================================================================
-- NATIVE ELEMENTS & RENDER HOOKS  (added by EAX v4 patch)
-- These are required by main.lua:
--   core.register_on_render_callback(menu.on_render)
--   core.register_on_render_menu_callback(menu.on_menu_render)
-- ============================================================================

-- Native keybind for enable toggle (persisted by PS, shown in control panel)
-- Value 7 = "Unbound". main.lua uses get_state() / set() on this.
local _enabled_keybind  = core.menu.keybind(7, false, "eax_mage_fire_enabled_kb")
local _toggle_key_elem  = core.menu.keybind(107, false, "eax_mage_fire_toggle_key")

-- Wrap keybind as menu.enabled so existing proxy is overridden with the real element
menu.enabled   = _enabled_keybind
menu.toggle_key = _toggle_key_elem

-- Native tree_node for the PS main menu entry
local _menu_tree = core.menu.tree_node()

-- on_menu_render: called by core.register_on_render_menu_callback
-- Renders a collapsible node in the PS main menu.
function menu.on_menu_render()
    _menu_tree:render("EAX Fire", function()
        _enabled_keybind:render("Enable EAX Fire", "Toggle rotation on/off")
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
