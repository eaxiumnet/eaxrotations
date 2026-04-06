-- Flux AIO - AstroUI Settings Menu
-- Uses simple_ui library (api/common/simple_ui.lua)
-- Replaces CreateFrame-based UI with AstroUI components
-- Hotkey toggle only (NUMPAD MULTIPLY default) - no slash commands

-- ============================================================================
-- FRAMEWORK VALIDATION
-- ============================================================================
local _G = _G
local NS = _G.FluxAIO
if not NS then
    print("|cFFFF0000[Flux AIO Menu]|r Core module not loaded!")
    return
end

local A = NS.A
if not A then
    print("|cFFFF0000[Flux AIO Menu]|r Action framework not available!")
    return
end

-- ============================================================================
-- ASTROUI IMPORT
-- ============================================================================
local simple_ui = require("common/simple_ui")
if not simple_ui then
    print("|cFFFF0000[Flux AIO Menu]|r AstroUI (simple_ui) not available!")
    return
end

-- ============================================================================
-- CLASS DETECTION & THEME
-- ============================================================================
local rotation_registry = NS.rotation_registry
local cc = rotation_registry and rotation_registry.class_config

local class_name = cc and cc.name or "Flux"
local version = cc and cc.version or "1.0"

local CLASS_COLORS = {
    Druid = { 1.0, 0.49, 0.04 },
    Hunter = { 0.67, 0.83, 0.45 },
    Mage = { 0.41, 0.8, 0.94 },
    Paladin = { 0.96, 0.55, 0.73 },
    Priest = { 1.0, 1.0, 1.0 },
    Rogue = { 1.0, 0.96, 0.41 },
    Shaman = { 0.0, 0.44, 0.87 },
    Warlock = { 0.58, 0.51, 0.79 },
    Warrior = { 0.78, 0.61, 0.43 },
}

-- ============================================================================
-- SCHEMA ACCESS
-- ============================================================================
local schema = _G.FluxAIO_SETTINGS_SCHEMA
if not schema then
    print("|cFFFF0000[Flux AIO Menu]|r Settings schema not found!")
    return
end

-- ============================================================================
-- MENU STATE
-- ============================================================================
local menu = nil
local hotkey_component = nil
local component_map = {}
local was_toggled = false

-- ============================================================================
-- HELPER FUNCTIONS
-- ============================================================================

-- Convert options array to item strings for combobox
local function options_to_items(options)
    local items = {}
    for _, opt in ipairs(options) do
        table.insert(items, opt.text)
    end
    return items
end

-- Get dropdown index from value
local function get_dropdown_index(options, value)
    for i, opt in ipairs(options) do
        if opt.value == value then
            return i
        end
    end
    return 1
end

-- ============================================================================
-- SETTING ACCESS API (exported for rotation code)
-- ============================================================================

function NS.get_menu_setting(key, default)
    local comp_data = component_map[key]
    if not comp_data then
        return default
    end

    local def = comp_data.def
    local comp = comp_data.component

    if def.type == "checkbox" then
        return comp:is_checked()
    elseif def.type == "slider" then
        return comp:get_value()
    elseif def.type == "dropdown" then
        local idx = comp:get_value()
        local opt = def.options[idx]
        return opt and opt.value or default
    end
    return default
end

function NS.set_menu_setting(key, value)
    local comp_data = component_map[key]
    if not comp_data then
        return false
    end

    local def = comp_data.def
    local comp = comp_data.component

    if def.type == "checkbox" then
        comp:set_value(value and true or false)
        return true
    elseif def.type == "slider" then
        comp:set_value(tonumber(value) or def.default)
        return true
    elseif def.type == "dropdown" then
        for i, opt in ipairs(def.options) do
            if opt.value == value then
                comp:set_value(i)
                return true
            end
        end
    end
    return false
end

-- ============================================================================
-- TOGGLE FUNCTION (exported for external use)
-- ============================================================================
local function toggle_settings()
    if not menu then return end
    menu:toggle()
end

NS.toggle_settings = toggle_settings

-- ============================================================================
-- BUILD MENU
-- ============================================================================
local function build_menu()
    local save_key = "flux_aio_" .. (class_name or "default") .. "_menu_v2"
    menu = simple_ui.menu:new(class_name .. " AIO v" .. version, 550, 500, save_key)

    -- Hotkey toggle at top
    hotkey_component = menu:add_keybind(
        "Toggle Menu (NUMPAD * default)",
        nil, nil,
        106,  -- NUMPAD MULTIPLY
        function(self, key_code)
            -- Key set callback
        end,
        {
            is_toggle = true,
            tooltip = "Press this key to open/close the settings menu."
        }
    )

    menu:add_separator(nil, nil, { height = 8 })

    -- Build tabs as TreeNodes
    for tab_id, tab_def in ipairs(schema) do
        local tab_name = tab_def.name or ("Tab " .. tab_id)

        local tab_node = menu:add_treenode(
            tab_name,
            nil, nil,
            tab_id == 1,
            nil,
            { indent = 15, font_size = 14 }
        )

        if tab_def.sections then
            for _, section in ipairs(tab_def.sections) do
                if section.header then
                    menu:add_header(section.header, nil, nil, { font_size = 12 })
                end

                if section.settings then
                    for _, setting in ipairs(section.settings) do
                        if not setting.hidden then
                            local comp = nil

                            if setting.type == "checkbox" then
                                comp = menu:add_checkbox(
                                    setting.label,
                                    nil, nil,
                                    setting.default or false,
                                    function(self, checked)
                                        if A.SetToggle then
                                            A.SetToggle({2, setting.key, nil, true}, checked)
                                        end
                                    end,
                                    { tooltip = setting.tooltip }
                                )

                            elseif setting.type == "slider" then
                                comp = menu:add_slider(
                                    setting.label,
                                    nil, nil,
                                    setting.min or 0,
                                    setting.max or 100,
                                    setting.default or 0,
                                    function(self, value)
                                        if A.SetToggle then
                                            A.SetToggle({2, setting.key, nil, true}, value)
                                        end
                                    end,
                                    {
                                        tooltip = setting.tooltip,
                                        show_value = true,
                                        slider_type = "int"
                                    }
                                )

                            elseif setting.type == "dropdown" then
                                local items = options_to_items(setting.options)
                                comp = menu:add_combobox(
                                    setting.label,
                                    nil, nil,
                                    items,
                                    get_dropdown_index(setting.options, setting.default),
                                    function(self, index, text)
                                        local opt = setting.options[index]
                                        if opt and A.SetToggle then
                                            A.SetToggle({2, setting.key, nil, true}, opt.value)
                                        end
                                    end,
                                    { tooltip = setting.tooltip }
                                )
                            end

                            if comp then
                                component_map[setting.key] = {
                                    component = comp,
                                    def = setting
                                }

                                -- Sync with GGL framework values
                                if A.GetToggle then
                                    local existing = A.GetToggle(2, setting.key)
                                    if existing ~= nil then
                                        if setting.type == "checkbox" then
                                            comp:set_value(existing and true or false)
                                        elseif setting.type == "slider" then
                                            comp:set_value(tonumber(existing) or setting.default)
                                        elseif setting.type == "dropdown" then
                                            for i, opt in ipairs(setting.options) do
                                                if opt.value == existing then
                                                    comp:set_value(i)
                                                    break
                                                end
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                end

                menu:add_separator(nil, nil, { height = 4 })
            end
        end
    end

    menu:hide()
end

-- Initialize
build_menu()

-- ============================================================================
-- RENDER LOOP
-- ============================================================================
core.register_on_render_window_callback(function()
    if not menu then return end

    -- Check hotkey for toggle (with debounce)
    if hotkey_component then
        local pressed = hotkey_component.check and hotkey_component:check()
        if pressed then
            if not was_toggled then
                menu:toggle()
                was_toggled = true
            end
        else
            was_toggled = false
        end
    end

    if not menu.is_open then return end

    menu:update()
    menu:render()
end)

-- ============================================================================
-- MODULE LOADED
-- ============================================================================
print("|cFF00FF00[Flux AIO]|r AstroUI Settings loaded for " .. class_name)
print("|cFF00FF00[Flux AIO]|r Press NUMPAD MULTIPLY (*) to toggle menu")
