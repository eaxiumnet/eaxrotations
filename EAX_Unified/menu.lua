-- EAX Unified Menu System | Project Sylvanas
-- TAB-BASED navigation for reliability - inspired by AstroUI
-- No expandable sections, just clean tabs and scrollable content

local simple_ui = _G.simple_ui
if not simple_ui then
    error("[EAX Unified Menu] simple_ui library not available!")
end

-- ============================================================================
-- GLOBAL REGISTRY
-- ============================================================================
local _G = _G
_G.EAXRegistry = _G.EAXRegistry or {
    rotations = {},
    active_rotation = nil,
    menu = nil,
    current_specs = nil,
    current_class = nil,
    was_toggled = false,
    last_toggle_time = 0,
    TOGGLE_COOLDOWN = 0.3,
    active_tab = nil,  -- Currently selected settings tab
}

local REG = _G.EAXRegistry
local NS = {}

-- ============================================================================
-- CONFIGURATION
-- ============================================================================
local MENU_WIDTH = 480
local MENU_HEIGHT = 400
local DEFAULT_TOGGLE_KEY = 107
local ITEM_HEIGHT_CHECKBOX = 22
local ITEM_HEIGHT_SLIDER = 32
local TAB_HEIGHT = 28

-- Master enabled in global registry so all copies share state
REG.master_enabled = REG.master_enabled or false

-- Class/spec colors
local CLASS_COLORS = {
    Druid = {1.0, 0.49, 0.04},
    Hunter = {0.67, 0.83, 0.45},
    Mage = {0.25, 0.78, 0.92},
    Paladin = {0.96, 0.55, 0.73},
    Priest = {1.0, 1.0, 1.0},
    Rogue = {1.0, 0.96, 0.41},
    Shaman = {0.0, 0.44, 0.87},
    Warlock = {0.53, 0.53, 0.93},
    Warrior = {0.78, 0.61, 0.43},
}

-- ============================================================================
-- HELPERS
-- ============================================================================
local function table_count(t)
    local count = 0
    for _ in pairs(t) do count = count + 1 end
    return count
end

local function get_player_class()
    local me = core.object_manager and core.object_manager.get_local_player()
    if not me then return nil end
    local class_id = me:get_class()
    local class_names = {
        [1] = "Warrior", [2] = "Paladin", [3] = "Hunter",
        [4] = "Rogue", [5] = "Priest", [6] = "DeathKnight",
        [7] = "Shaman", [8] = "Mage", [9] = "Warlock", [11] = "Druid"
    }
    local class = class_names[class_id]
    return class
end

local function group_by_class()
    local classes = {}
    for key, rot in pairs(REG.rotations) do
        rot.key = key
        classes[rot.class] = classes[rot.class] or {}
        table.insert(classes[rot.class], rot)
    end
    for class, specs in pairs(classes) do
        table.sort(specs, function(a, b) return a.spec < b.spec end)
    end
    return classes
end

-- ============================================================================
-- ROTATION REGISTRATION
-- ============================================================================
function NS.register_rotation(class, spec, menu_def, callbacks)
    local key = class:lower() .. "_" .. spec:lower()

    REG.rotations[key] = {
        class = class,
        spec = spec,
        display_name = spec,
        menu_def = menu_def,
        callbacks = callbacks or {},
        enabled = false,
        values = {},
    }

    print("|cFF00FF00[EAX]|r Registered rotation: " .. class .. " " .. spec)

    -- Auto-rebuild menu when rotations register
    if REG.menu then
        NS.rebuild_menu()
    end

    return key
end

function NS.enable_rotation(key)
    if REG.active_rotation and REG.rotations[REG.active_rotation] then
        local old = REG.rotations[REG.active_rotation]
        old.enabled = false
        if old.callbacks.on_disabled then
            old.callbacks.on_disabled()
        end
    end

    if REG.rotations[key] then
        REG.rotations[key].enabled = true
        REG.active_rotation = key
        -- Reset to first tab when switching rotations
        local rot = REG.rotations[key]
        if rot.menu_def and rot.menu_def.categories and #rot.menu_def.categories > 0 then
            REG.active_tab = 1
        end
        if rot.callbacks.on_enabled then
            rot.callbacks.on_enabled()
        end
    end
end

function NS.is_enabled(rot_key)
    return REG.master_enabled and REG.active_rotation == rot_key
end

function NS.get_setting(rot_key, setting_key, default)
    local rot = REG.rotations[rot_key]
    if not rot then return default end
    if rot.values[setting_key] ~= nil then
        return rot.values[setting_key]
    end
    return default
end

function NS.set_setting(rot_key, setting_key, value)
    local rot = REG.rotations[rot_key]
    if not rot then return false end
    rot.values[setting_key] = value
    return true
end

function NS.is_rotation_system_enabled()
    return REG.master_enabled
end

function NS.is_rotation_active(rot_key)
    return REG.master_enabled and REG.active_rotation == rot_key
end

-- ============================================================================
-- MENU BUILDING - TAB-BASED LAYOUT (AstroUI-inspired)
-- ============================================================================
function NS.rebuild_menu()
    if REG.menu then
        REG.menu = nil
    end

    local player_class = get_player_class()
    local classes = group_by_class()
    local my_specs = player_class and classes[player_class] or {}

    if #my_specs == 0 then
        REG.menu = simple_ui.menu:new("EAX Rotations", MENU_WIDTH, 120, "eax_unified_menu_v12")
        REG.menu:add_label("No rotations for your class", 10, 40, { font_size = 14, color = {1.0, 0.5, 0.5} })
        REG.menu:hide()
        return
    end

    REG.current_specs = my_specs
    REG.current_class = player_class

    REG.menu = simple_ui.menu:new("EAX " .. player_class, MENU_WIDTH, MENU_HEIGHT, "eax_unified_menu_v12")
    local ui = REG.menu
    local class_color = CLASS_COLORS[player_class] or {0.8, 0.8, 0.8}

    local current_y = 10

    -- Master toggle at top
    ui:add_checkbox(
        "Enable Rotation",
        12, current_y,
        REG.master_enabled,
        function(_, checked)
            REG.master_enabled = checked
            if not REG.master_enabled and REG.active_rotation then
                local old = REG.rotations[REG.active_rotation]
                if old and old.callbacks.on_disabled then
                    old.callbacks.on_disabled()
                end
            elseif REG.master_enabled and REG.active_rotation then
                local rot = REG.rotations[REG.active_rotation]
                if rot and rot.callbacks.on_enabled then
                    rot.callbacks.on_enabled()
                end
            end
            NS.rebuild_menu()
            if REG.menu then REG.menu:show() end
        end,
        { font_size = 13, color = {0.2, 1.0, 0.2}, tooltip = "Master enable/disable" }
    )
    current_y = current_y + 30

    -- Separator
    ui:add_separator(12, current_y, { width = MENU_WIDTH - 24, height = 1 })
    current_y = current_y + 8

    -- Spec selection buttons (horizontal row)
    ui:add_label("Select Spec:", 12, current_y, { font_size = 12, color = class_color })
    current_y = current_y + 20

    local num_specs = #my_specs
    local total_spacing = (num_specs - 1) * 4
    local available_width = MENU_WIDTH - 24 - total_spacing
    local button_width = math.floor(available_width / num_specs)
    local start_x = 12

    for i, rot in ipairs(my_specs) do
        local is_selected = REG.active_rotation == rot.key
        local btn_color = is_selected and class_color or {0.3, 0.3, 0.3}
        local text_color = is_selected and {0, 0, 0} or {0.9, 0.9, 0.9}
        local x_pos = start_x + (i-1) * (button_width + 4)

        ui:add_button(
            rot.spec,
            x_pos, current_y,
            button_width, 24,
            function()
                if REG.active_rotation == rot.key then
                    return
                end
                -- Select this rotation but DON'T auto-enable master toggle
                NS.enable_rotation(rot.key)
                NS.rebuild_menu()
                if REG.menu then REG.menu:show() end
            end,
            { font_size = 12, color = text_color, bg_color = btn_color }
        )
    end
    current_y = current_y + 30

    -- Separator
    ui:add_separator(12, current_y, { width = MENU_WIDTH - 24, height = 1 })
    current_y = current_y + 12

    -- Settings panel for selected spec
    if REG.master_enabled and REG.active_rotation then
        local active_rot = REG.rotations[REG.active_rotation]
        if active_rot and active_rot.class == player_class then
            NS.build_settings_tabs(ui, active_rot, current_y, class_color)
        end
    elseif not REG.master_enabled then
        ui:add_label("Enable rotation system above", 12, current_y + 10, { font_size = 12, color = {0.5, 0.5, 0.5} })
    end

    REG.menu:hide()
end

function NS.build_settings_tabs(ui, rot, start_y, class_color)
    local categories = rot.menu_def.categories or {}
    if #categories == 0 then
        ui:add_label("No settings", 12, start_y, { font_size = 11, color = {0.5, 0.5, 0.5} })
        return
    end

    -- Ensure active tab is valid
    if not REG.active_tab or REG.active_tab < 1 or REG.active_tab > #categories then
        REG.active_tab = 1
    end

    local current_y = start_y
    local tab_area_width = MENU_WIDTH - 24
    local tab_width = math.floor(tab_area_width / #categories)

    -- Build tab buttons
    for i, cat in ipairs(categories) do
        local is_active = REG.active_tab == i
        local tab_color = is_active and class_color or {0.25, 0.25, 0.25}
        local text_color = is_active and {0, 0, 0} or {0.7, 0.7, 0.7}
        local x_pos = 12 + (i-1) * tab_width

        ui:add_button(
            cat.name,
            x_pos, current_y,
            tab_width - 2, TAB_HEIGHT,
            function()
                REG.active_tab = i
                NS.rebuild_menu()
                if REG.menu then REG.menu:show() end
            end,
            { font_size = 10, color = text_color, bg_color = tab_color }
        )
    end
    current_y = current_y + TAB_HEIGHT + 8

    -- Build settings for active tab only
    local active_cat = categories[REG.active_tab]
    if active_cat then
        NS.build_settings_for_category(ui, rot, active_cat, current_y)
    end
end

function NS.build_settings_for_category(ui, rot, cat, start_y)
    local current_y = start_y
    local slider_width = MENU_WIDTH - 80

    -- Category title
    ui:add_label(cat.name, 12, current_y, { font_size = 13, color = {0.9, 0.9, 0.9} })
    current_y = current_y + 24

    for _, def in ipairs(cat.settings or {}) do
        if def.type == "checkbox" then
            local saved_value = rot.values[def.key]
            local initial_value = (saved_value ~= nil) and saved_value or def.default

            -- FIX: Capture key in local
            local setting_key = def.key
            local cb = ui:add_checkbox(
                def.label,
                20, current_y,
                initial_value,
                function(_, checked)
                    rot.values[setting_key] = checked
                end,
                { font_size = 11, tooltip = def.tooltip }
            )
            current_y = current_y + ITEM_HEIGHT_CHECKBOX

        elseif def.type == "slider" then
            local saved_value = rot.values[def.key]
            local initial_value = (saved_value ~= nil) and saved_value or def.default

            -- FIX: Capture key in local
            local setting_key = def.key
            local slider = ui:add_slider(
                def.label,
                20, current_y,
                def.min or 0,
                def.max or 100,
                initial_value,
                function(_, value)
                    rot.values[setting_key] = value
                end,
                { font_size = 11, tooltip = def.tooltip, show_value = true, slider_type = "int", width = slider_width }
            )
            current_y = current_y + ITEM_HEIGHT_SLIDER
        end
    end
end

-- ============================================================================
-- INITIALIZATION
-- ============================================================================
function NS.init()
    -- Singleton guard
    if REG.is_initialized then return end
    REG.is_initialized = true

    if REG.menu then return end

    print("|cFF00FF00[EAX]|r Initializing tab-based unified menu system...")

    core.register_on_render_window_callback(function()
        -- Build menu on first render if not built yet
        if not REG.menu then
            NS.rebuild_menu()
            print("|cFF00FF00[EAX]|r Menu built with " .. tostring(table_count(REG.rotations)) .. " rotation(s)")
        end

        if not REG.menu then return end

        local is_down = false

        -- Use core.input.is_key_pressed (Sylvanas native API)
        if core.input and core.input.is_key_pressed then
            is_down = core.input.is_key_pressed(DEFAULT_TOGGLE_KEY)
        end

        local now = core.time and core.time() or 0
        if is_down then
            if not REG.was_toggled and (now - REG.last_toggle_time) > REG.TOGGLE_COOLDOWN then
                REG.menu:toggle_collapse()
                REG.was_toggled = true
                REG.last_toggle_time = now
            end
        else
            REG.was_toggled = false
        end

        -- Always render menu
        REG.menu:update()
        REG.menu:render()
    end)

    print("|cFF00FF00[EAX]|r Menu system ready - Press Numpad + to show/hide")
end

function NS.toggle_menu()
    if REG.menu then
        REG.menu:toggle_collapse()
    end
end

NS.init()

return NS
