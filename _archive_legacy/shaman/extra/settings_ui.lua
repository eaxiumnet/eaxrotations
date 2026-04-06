-- =============================================================================
-- SETTINGS UI - Sylvanas Framework Custom Settings Menu
-- Converted from flux/rotation/source/aio/settings.lua (816 lines)
-- Uses Sylvanas core.menu API for widgets and SettingsBridge for persistence
-- =============================================================================

local core = _G.core
local SettingsBridge = require("libraries.settings_bridge")

-- =============================================================================
-- THEME (Matching Flux dark aesthetic from source/settings.lua)
-- =============================================================================
local THEME = {
    bg = { 0.031, 0.031, 0.039, 0.97 },      -- #08080a
    bg_light = { 0.047, 0.047, 0.059, 1 },    -- #0c0c0f
    bg_widget = { 0.059, 0.059, 0.075, 1 },   -- #0f0f13
    bg_hover = { 0.075, 0.075, 0.086, 1 },   -- #131316
    border = { 0.118, 0.118, 0.149, 1 },      -- #1e1e26
    accent = { 0.424, 0.388, 1.0, 1 },        -- #6c63ff
    accent_dim = { 0.255, 0.233, 0.6, 1 },    -- #413b99
    accent_bg = { 0.078, 0.074, 0.154, 1 },   -- accent @ 12%
    text = { 0.863, 0.863, 0.894, 1 },        -- #dcdce4
    text_dim = { 0.580, 0.580, 0.659, 1 },    -- #9494a8
    text_header = { 0.863, 0.863, 0.894, 1 }, -- #dcdce4
}

-- =============================================================================
-- COLOR HELPERS (for Sylvanas menu system)
-- =============================================================================
local function rgba(r, g, b, a)
    return { r = r, g = g, b = b, a = a or 1.0 }
end

local THEME_COLORS = {
    bg = rgba(THEME.bg[1], THEME.bg[2], THEME.bg[3], THEME.bg[4]),
    bg_light = rgba(THEME.bg_light[1], THEME.bg_light[2], THEME.bg_light[3]),
    accent = rgba(THEME.accent[1], THEME.accent[2], THEME.accent[3]),
    accent_dim = rgba(THEME.accent_dim[1], THEME.accent_dim[2], THEME.accent_dim[3]),
    text = rgba(THEME.text[1], THEME.text[2], THEME.text[3]),
    text_dim = rgba(THEME.text_dim[1], THEME.text_dim[2], THEME.text_dim[3]),
}

-- =============================================================================
-- CLASS TITLE COLORS (from Flux source)
-- =============================================================================
local CLASS_TITLE_COLORS = {
    Druid = "7d0a", Hunter = "d473", Mage = "69ccf0", Paladin = "58cba", 
    Priest = "ffffff", Rogue = "fff569", Shaman = "0070dd", Warlock = "9482c9", 
    Warrior = "c79c6e"
}

local function get_class_color()
    local me = izi.me()
    local classFilename = me and me:get_class() or "WARRIOR"
    return CLASS_TITLE_COLORS[classFilename] or "6c63ff"
end

-- =============================================================================
-- MENU ELEMENT IDS (unique prefix to avoid collisions)
-- =============================================================================
local MENU_ID_PREFIX = "flux_settings_"

-- =============================================================================
-- TRINKET OPTIONS (for dropdown/combobox)
-- =============================================================================
local TRINKET_OPTIONS = {
    "Off",
    "Offensive (Burst)",
    "Defensive"
}

-- =============================================================================
-- MENU ELEMENTS REGISTRY (declared outside callback per Sylvanas best practices)
-- =============================================================================
local MenuElements = {}

-- =============================================================================
-- CREATE ALL MENU ELEMENTS
-- =============================================================================
local function create_menu_elements()
    -- Main container node (acts as settings panel header)
    MenuElements.main_node = core.menu.tree_node()
    
    -- Category: General
    MenuElements.general_node = core.menu.tree_node()
    MenuElements.dashboard_show = core.menu.checkbox(false, MENU_ID_PREFIX .. "dashboard.show")
    
    -- Category: Burst Conditions
    MenuElements.burst_node = core.menu.tree_node()
    MenuElements.burst_bloodlust = core.menu.checkbox(false, MENU_ID_PREFIX .. "burst.on_bloodlust")
    MenuElements.burst_pull = core.menu.checkbox(false, MENU_ID_PREFIX .. "burst.on_pull")
    MenuElements.burst_execute = core.menu.checkbox(false, MENU_ID_PREFIX .. "burst.on_execute")
    MenuElements.burst_combat = core.menu.checkbox(false, MENU_ID_PREFIX .. "burst.in_combat")
    
    -- Category: Trinkets & Racial
    MenuElements.trinkets_node = core.menu.tree_node()
    MenuElements.trinket1_mode = core.menu.combobox(1, MENU_ID_PREFIX .. "trinkets.slot1_mode")
    MenuElements.trinket2_mode = core.menu.combobox(1, MENU_ID_PREFIX .. "trinkets.slot2_mode")
    MenuElements.use_racial = core.menu.checkbox(true, MENU_ID_PREFIX .. "trinkets.use_racial")
    
    -- Category: Debug
    MenuElements.debug_node = core.menu.tree_node()
    MenuElements.debug_mode = core.menu.checkbox(true, MENU_ID_PREFIX .. "debug.mode")
    MenuElements.debug_system = core.menu.checkbox(false, MENU_ID_PREFIX .. "debug.system")
    MenuElements.debug_log_context = core.menu.checkbox(false, MENU_ID_PREFIX .. "debug.log_context")
end

-- =============================================================================
-- REGISTER MENU RENDER CALLBACK
-- =============================================================================
local function register_menu_callback()
    core.menu.register_on_render_menu_callback(function()
        -- Render main settings node
        MenuElements.main_node:render("Flux AIO Settings", function()
            -- ================================================
            -- GENERAL CATEGORY
            -- ================================================
            MenuElements.general_node:render("General", function()
                MenuElements.dashboard_show:render(
                    "Show Dashboard",
                    "Display the combat dashboard overlay (/flux status)."
                )
            end)
            
            -- ================================================
            -- BURST CONDITIONS CATEGORY
            -- ================================================
            MenuElements.burst_node:render("Burst Conditions", function()
                MenuElements.burst_bloodlust:render(
                    "During Bloodlust/Heroism",
                    "Auto-burst when Bloodlust or Heroism buff is detected."
                )
                MenuElements.burst_pull:render(
                    "On Pull (first 5s)",
                    "Auto-burst within the first 5 seconds of combat."
                )
                MenuElements.burst_execute:render(
                    "Execute Phase (<20% HP)",
                    "Auto-burst when target is below 20% health."
                )
                MenuElements.burst_combat:render(
                    "Always in Combat",
                    "Always auto-burst when in combat with a valid target (most aggressive)."
                )
            end)
            
            -- ================================================
            -- TRINKETS & RACIAL CATEGORY
            -- ================================================
            MenuElements.trinkets_node:render("Trinkets & Racial", function()
                MenuElements.trinket1_mode:render(
                    "Trinket 1",
                    TRINKET_OPTIONS,
                    "Off = never use. Offensive = fires during burst. Defensive = fires during def."
                )
                MenuElements.trinket2_mode:render(
                    "Trinket 2",
                    TRINKET_OPTIONS,
                    "Off = never use. Offensive = fires during burst. Defensive = fires during def."
                )
                MenuElements.use_racial:render(
                    "Use Racial",
                    "Use racial ability during combat."
                )
            end)
            
            -- ================================================
            -- DEBUG CATEGORY
            -- ================================================
            MenuElements.debug_node:render("Debug", function()
                MenuElements.debug_mode:render(
                    "Debug Mode",
                    "Print rotation debug messages."
                )
                MenuElements.debug_system:render(
                    "Debug System (Advanced)",
                    "Print system debug messages (middleware, strategies)."
                )
                MenuElements.debug_log_context:render(
                    "Log Context",
                    "Print full context state to debug log every 2s during combat."
                )
            end)
        end)
    end)
end

-- =============================================================================
-- VALUE CONVERSION HELPERS
-- =============================================================================

--- Convert trinket setting value to combobox index (1-based)
local function trinket_val_to_idx(val)
    val = val or "off"
    if val == "offensive" then return 2
    elseif val == "defensive" then return 3
    else return 1 end
end

--- Convert combobox index (1-based) to trinket setting value
local function trinket_idx_to_val(idx)
    idx = idx or 1
    if idx == 2 then return "offensive"
    elseif idx == 3 then return "defensive"
    else return "off" end
end

-- =============================================================================
-- SYNC MENU STATE TO SETTINGS BRIDGE
-- Called when menu values change to persist them
-- =============================================================================
local function sync_to_settings()
    -- Dashboard
    SettingsBridge:set("dashboard.show", MenuElements.dashboard_show:get_state())
    
    -- Burst Conditions
    SettingsBridge:set("burst.on_bloodlust", MenuElements.burst_bloodlust:get_state())
    SettingsBridge:set("burst.on_pull", MenuElements.burst_pull:get_state())
    SettingsBridge:set("burst.on_execute", MenuElements.burst_execute:get_state())
    SettingsBridge:set("burst.in_combat", MenuElements.burst_combat:get_state())
    
    -- Trinkets (combobox returns 1-based index)
    SettingsBridge:set("trinkets.slot1_mode", trinket_idx_to_val(MenuElements.trinket1_mode:get()))
    SettingsBridge:set("trinkets.slot2_mode", trinket_idx_to_val(MenuElements.trinket2_mode:get()))
    SettingsBridge:set("trinkets.use_racial", MenuElements.use_racial:get_state())
    
    -- Debug
    SettingsBridge:set("debug.mode", MenuElements.debug_mode:get_state())
    SettingsBridge:set("debug.system", MenuElements.debug_system:get_state())
    SettingsBridge:set("debug.log_context", MenuElements.debug_log_context:get_state())
end

-- =============================================================================
-- SYNC SETTINGS BRIDGE TO MENU STATE
-- Called on init to load saved settings into menu
-- =============================================================================
local function sync_from_settings()
    -- Dashboard
    MenuElements.dashboard_show:set(SettingsBridge:get("dashboard.show", false))
    
    -- Burst Conditions
    MenuElements.burst_bloodlust:set(SettingsBridge:get("burst.on_bloodlust", false))
    MenuElements.burst_pull:set(SettingsBridge:get("burst.on_pull", false))
    MenuElements.burst_execute:set(SettingsBridge:get("burst.on_execute", false))
    MenuElements.burst_combat:set(SettingsBridge:get("burst.in_combat", false))
    
    -- Trinkets (convert value to 1-based index for combobox)
    MenuElements.trinket1_mode:set(trinket_val_to_idx(SettingsBridge:get("trinkets.slot1_mode", "off")))
    MenuElements.trinket2_mode:set(trinket_val_to_idx(SettingsBridge:get("trinkets.slot2_mode", "off")))
    MenuElements.use_racial:set(SettingsBridge:get("trinkets.use_racial", true))
    
    -- Debug
    MenuElements.debug_mode:set(SettingsBridge:get("debug.mode", true))
    MenuElements.debug_system:set(SettingsBridge:get("debug.system", false))
    MenuElements.debug_log_context:set(SettingsBridge:get("debug.log_context", false))
end

-- =============================================================================
-- INITIALIZATION
-- =============================================================================
local function init_settings_ui()
    -- Initialize SettingsBridge with file name for persistence
    local bridge_init = SettingsBridge:init("flux_settings")
    if not bridge_init then
        core.log_error("[Flux Settings] Failed to initialize SettingsBridge")
        return false
    end
    
    -- Create all menu elements
    create_menu_elements()
    
    -- Register menu render callback
    register_menu_callback()
    
    -- Sync current settings to menu state
    sync_from_settings()
    
    core.log("[Flux Settings] UI initialized - Use /flux to open settings")
    return true
end

-- =============================================================================
-- PUBLIC API
-- =============================================================================
local SettingsUI = {
    init = init_settings_ui,
    sync_to_settings = sync_to_settings,
    sync_from_settings = sync_from_settings,
}

-- =============================================================================
-- EXPORT
-- =============================================================================
return SettingsUI


