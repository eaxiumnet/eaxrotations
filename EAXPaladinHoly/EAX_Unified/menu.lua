-- EAX Unified Menu System | Project Sylvanas
-- Uses native core.menu API - no external dependencies
-- Tab-based navigation for reliability

-- ============================================================================
-- GLOBAL REGISTRY
-- ============================================================================
local _G = _G
_G.EAXRegistry = _G.EAXRegistry or {
    rotations = {},
    active_rotation = nil,
    menu_open = false,
    current_specs = nil,
    current_class = nil,
    was_toggled = false,
    last_toggle_time = 0,
    TOGGLE_COOLDOWN = 0.3,
    active_tab = nil,
}

local REG = _G.EAXRegistry
local NS = {}

-- ============================================================================
-- CONFIGURATION
-- ============================================================================
local DEFAULT_TOGGLE_KEY = 107  -- Numpad +

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
-- MENU STATE (persisted via core.menu)
-- ============================================================================
local menu_state = {
    master_enabled = core.menu.checkbox(false, "eax_master_enabled"),
    current_rotation = core.menu.combobox(1, "eax_current_rotation"),
    current_tab = core.menu.slider_int(1, 10, 1, "eax_current_tab"),
}

-- ============================================================================
-- ROTATION REGISTRATION
-- ============================================================================
function NS.register_rotation(class, spec, menu_def, callbacks)
    local key = class:lower() .. "_" .. spec:lower()

    -- Create core.menu controls for each setting
    local controls = {}
    if menu_def and menu_def.categories then
        for _, cat in ipairs(menu_def.categories) do
            for _, def in ipairs(cat.settings or {}) do
                if def.type == "checkbox" then
                    controls[def.key] = core.menu.checkbox(def.default or false, "eax_" .. key .. "_" .. def.key)
                elseif def.type == "slider" then
                    controls[def.key] = core.menu.slider_int(def.min or 0, def.max or 100, def.default or 50, "eax_" .. key .. "_" .. def.key)
                end
            end
        end
    end

    REG.rotations[key] = {
        class = class,
        spec = spec,
        display_name = spec,
        menu_def = menu_def,
        callbacks = callbacks or {},
        enabled = false,
        controls = controls,
    }

    print("|cFF00FF00[EAX]|r Registered rotation: " .. class .. " " .. spec)
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
        -- Reset to first tab
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
    local ctrl = rot.controls and rot.controls[setting_key]
    if ctrl then
        return ctrl:get_value()
    end
    return default
end

function NS.set_setting(rot_key, setting_key, value)
    local rot = REG.rotations[rot_key]
    if not rot then return false end
    -- core.menu values are read-only from Lua, can't set directly
    return false
end

function NS.is_rotation_system_enabled()
    return REG.master_enabled
end

function NS.is_rotation_active(rot_key)
    return REG.master_enabled and REG.active_rotation == rot_key
end

-- ============================================================================
-- RENDER MENU
-- ============================================================================

local function render_settings_panel(active_rot, class_color)
    if not active_rot or not active_rot.menu_def then return end
    local categories = active_rot.menu_def.categories or {}
    if #categories == 0 then return end

    -- Ensure active tab is valid
    if not REG.active_tab or REG.active_tab < 1 or REG.active_tab > #categories then
        REG.active_tab = 1
    end

    -- Tab buttons
    core.menu.header("--- Settings ---")
    for i, cat in ipairs(categories) do
        local is_active = REG.active_tab == i
        local label = is_active and ("> " .. cat.name .. " <") or cat.name
        if core.menu.button and core.menu.button(label) then
            REG.active_tab = i
        end
    end

    -- Active tab settings
    local active_cat = categories[REG.active_tab]
    if not active_cat then return end

    core.menu.header("[" .. active_cat.name .. "]")

    for _, def in ipairs(active_cat.settings or {}) do
        local ctrl = active_rot.controls and active_rot.controls[def.key]
        if ctrl then
            -- core.menu controls render automatically when accessed
            local _ = ctrl:get_value()
            -- Show label as header
            core.menu.text(def.label or def.key)
        end
    end
end

-- ============================================================================
-- MAIN RENDER LOOP
-- ============================================================================
local function render_menu()
    local player_class = get_player_class()
    local classes = group_by_class()
    local my_specs = player_class and classes[player_class] or {}

    if #my_specs == 0 then
        core.menu.header("EAX Rotations")
        core.menu.text("No rotations available for your class")
        return
    end

    local class_color = CLASS_COLORS[player_class] or {0.8, 0.8, 0.8}

    -- Title
    core.menu.header("EAX " .. player_class .. " Rotations")

    -- Master toggle
    local master_val = menu_state.master_enabled:get_value()
    if master_val ~= REG.master_enabled then
        REG.master_enabled = master_val
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
    end

    -- Spec selection
    core.menu.header("--- Select Spec ---")
    for i, rot in ipairs(my_specs) do
        local is_selected = REG.active_rotation == rot.key
        local label = is_selected and (">> " .. rot.spec .. " <<") or rot.spec

        -- Render as clickable selection
        if is_selected then
            core.menu.header(label)
        else
            -- Use button if available, otherwise checkbox trick
            if core.menu.button then
                if core.menu.button("Switch to " .. rot.spec) then
                    REG.master_enabled = true
                    menu_state.master_enabled:set(true)
                    NS.enable_rotation(rot.key)
                end
            end
        end
    end

    -- Settings for active rotation
    if REG.master_enabled and REG.active_rotation then
        local active_rot = REG.rotations[REG.active_rotation]
        if active_rot and active_rot.class == player_class then
            render_settings_panel(active_rot, class_color)
        end
    end
end

-- ============================================================================
-- INITIALIZATION
-- ============================================================================
function NS.init()
    if REG.is_initialized then return end
    REG.is_initialized = true

    print("|cFF00FF00[EAX]|r Initializing unified menu system...")
    print("|cFF00FF00[EAX]|r Using core.menu API")

    -- Sync from menu state
    REG.master_enabled = menu_state.master_enabled:get_value()

    core.register_on_render_window_callback(function()
        -- Key toggle
        local is_down = false
        if core.input and core.input.is_key_pressed then
            is_down = core.input.is_key_pressed(DEFAULT_TOGGLE_KEY)
        end

        local now = core.time and core.time() or 0
        if is_down then
            if not REG.was_toggled and (now - REG.last_toggle_time) > REG.TOGGLE_COOLDOWN then
                REG.menu_open = not REG.menu_open
                REG.was_toggled = true
                REG.last_toggle_time = now
                print("|cFF00FF00[EAX]|r Menu " .. (REG.menu_open and "opened" or "closed"))
            end
        else
            REG.was_toggled = false
        end

        -- Render menu if open
        if REG.menu_open then
            render_menu()
        end
    end)

    print("|cFF00FF00[EAX]|r Menu system ready - Press Numpad + to toggle")
end

function NS.toggle_menu()
    REG.menu_open = not REG.menu_open
end

function NS.rebuild_menu()
    -- No-op for core.menu API - menu is rendered dynamically
end

NS.init()

return NS
