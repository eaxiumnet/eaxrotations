-- EAX Unified Menu System | Project Sylvanas
-- Horizontal spec tabs at top, compact design

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
}

local REG = _G.EAXRegistry
local NS = {}

-- ============================================================================
-- CONFIGURATION
-- ============================================================================
local MENU_WIDTH = 380
local MENU_HEIGHT = 420
local DEFAULT_TOGGLE_KEY = 107

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
local function get_player_class()
    local me = core.object_manager and core.object_manager.get_local_player()
    if not me then return nil end
    local class_id = me:get_class()
    local class_names = {
        [1] = "Warrior", [2] = "Paladin", [3] = "Hunter",
        [4] = "Rogue", [5] = "Priest", [6] = "DeathKnight",
        [7] = "Shaman", [8] = "Mage", [9] = "Warlock", [11] = "Druid"
    }
    return class_names[class_id]
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
        component_map = {},
        values = {},
    }

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
        if REG.rotations[key].callbacks.on_enabled then
            REG.rotations[key].callbacks.on_enabled()
        end
    end
end

function NS.is_enabled(rot_key)
    return REG.active_rotation == rot_key
end

function NS.get_setting(rot_key, setting_key, default)
    local rot = REG.rotations[rot_key]
    if not rot then return default end
    return rot.values[setting_key] or default
end

function NS.set_setting(rot_key, setting_key, value)
    local rot = REG.rotations[rot_key]
    if not rot then return false end
    rot.values[setting_key] = value
    return true
end

-- ============================================================================
-- MENU BUILDING
-- ============================================================================
function NS.rebuild_menu()
    if REG.menu then
        REG.menu = nil
    end

    REG.menu = simple_ui.menu:new("EAX Rotations", MENU_WIDTH, MENU_HEIGHT, "eax_unified_menu_v4")
    local ui = REG.menu

    local player_class = get_player_class()
    local classes = group_by_class()
    local my_specs = player_class and classes[player_class] or {}

    if #my_specs == 0 then
        ui:add_label("No rotations for your class", 10, 40, { font_size = 14, color = {1.0, 0.5, 0.5} })
        REG.menu:hide()
        return
    end

    REG.current_specs = my_specs
    REG.current_class = player_class

    local class_color = CLASS_COLORS[player_class] or {0.8, 0.8, 0.8}

    ui:add_label("Numpad + Toggle", 10, 10, { font_size = 12, color = {0.5, 0.7, 1.0} })
    ui:add_separator(10, 30, { width = MENU_WIDTH - 20, height = 1 })

    ui:add_header(player_class .. " Specs", 10, 36, { font_size = 15, color = class_color })

    local num_specs = #my_specs
    local button_width = math.floor((MENU_WIDTH - 20 - (num_specs - 1) * 4) / num_specs)
    local start_x = 10
    local button_y = 60

    for i, rot in ipairs(my_specs) do
        local is_active = NS.is_enabled(rot.key)
        local btn_color = is_active and {0.2, 0.8, 0.2} or {0.3, 0.3, 0.3}
        local x_pos = start_x + (i-1) * (button_width + 4)

        ui:add_button(
            rot.spec,
            x_pos, button_y,
            button_width, 24,
            function()
                NS.enable_rotation(rot.key)
                NS.rebuild_menu()
                if REG.menu then REG.menu:show() end
            end,
            { font_size = 13, color = is_active and {1,1,1} or {0.7,0.7,0.7}, bg_color = btn_color }
        )
    end

    ui:add_separator(10, button_y + 28, { width = MENU_WIDTH - 20, height = 2 })

    local settings_y = button_y + 36
    if REG.active_rotation then
        local rot = REG.rotations[REG.active_rotation]
        if rot and rot.class == player_class then
            NS.build_settings_panel(ui, rot, settings_y)
        end
    else
        ui:add_label("Click a spec above to enable", 10, settings_y + 20, { font_size = 13, color = {0.7, 0.7, 0.7} })
    end

    REG.menu:hide()
end

function NS.build_settings_panel(ui, rot, start_y)
    rot.component_map = {}
    local current_y = start_y

    ui:add_label("Settings: " .. rot.spec, 10, current_y, { font_size = 13, color = {0.4, 1.0, 0.4} })
    current_y = current_y + 20

    if rot.menu_def and rot.menu_def.categories then
        for _, cat in ipairs(rot.menu_def.categories) do
            ui:add_header(cat.name, 10, current_y, { font_size = 12, color = {0.7, 0.85, 1.0} })
            current_y = current_y + 16

            for _, def in ipairs(cat.settings or {}) do
                if def.type == "checkbox" then
                    local cb = ui:add_checkbox(
                        def.label,
                        10, current_y,
                        rot.values[def.key] or def.default,
                        function(_, checked)
                            rot.values[def.key] = checked
                        end,
                        { font_size = 12, tooltip = def.tooltip }
                    )
                    rot.component_map[def.key] = { component = cb, def = def }
                    current_y = current_y + 20
                elseif def.type == "slider" then
                    local slider = ui:add_slider(
                        def.label,
                        10, current_y,
                        def.min or 0,
                        def.max or 100,
                        rot.values[def.key] or def.default,
                        function(_, value)
                            rot.values[def.key] = value
                        end,
                        { font_size = 12, tooltip = def.tooltip, show_value = true, slider_type = "int" }
                    )
                    rot.component_map[def.key] = { component = slider, def = def }
                    current_y = current_y + 26
                end
            end

            current_y = current_y + 4
        end
    end
end

-- ============================================================================
-- INITIALIZATION
-- ============================================================================
function NS.init()
    if REG.menu then return end

    NS.rebuild_menu()

    core.register_on_render_window_callback(function()
        if not REG.menu then return end

        local is_down = core.input and core.input.is_key_pressed and core.input.is_key_pressed(DEFAULT_TOGGLE_KEY)
        if not is_down then
            local ok, sui = pcall(function() return require("common/simple_ui") end)
            if ok and sui and sui.input and sui.input.is_key_pressed then
                is_down = sui.input.is_key_pressed(DEFAULT_TOGGLE_KEY)
            end
        end

        local now = core.time and core.time() or 0
        if is_down then
            if not REG.was_toggled and (now - REG.last_toggle_time) > REG.TOGGLE_COOLDOWN then
                REG.menu:toggle()
                REG.was_toggled = true
                REG.last_toggle_time = now
            end
        else
            REG.was_toggled = false
        end

        if not REG.menu.is_open then return end
        REG.menu:update()
        REG.menu:render()
    end)

    print("|cFF00FF00[EAX]|r Press Numpad + for rotation settings")
end

function NS.toggle_menu()
    if REG.menu then
        REG.menu:toggle()
    end
end

NS.init()

return NS
