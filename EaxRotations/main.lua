-- main.lua — EaxRotations bootstrap and dispatcher for Project Sylvanas.
-- WHAT:  loads shared modules, registers per-class specs, wires on_update/on_combat callbacks.
-- WHEN:  addon load (not per-tick).
-- WHY:   central dispatcher that routes to class-specific rotation files via NS.rotation_registry.
-- SAFETY: no per-frame allocations; all heavy work delegated to spec files; throttled scans only.

-- bootstrap for shared runtime, UI, and class loading.

-- ============================================================================
-- EaxRotations - Main File
-- Project Sylvanas API - Rotation Execution
-- ============================================================================

-- Import core framework
local core = _G.core

-- Import IZI SDK from common folder (as per Project Sylvanas documentation)
local izi_ok, izi = pcall(require, "common/izi_sdk")

if not izi_ok or not izi then
    if type(core) == "table" and type(core.log_error) == "function" then
        core.log_error("[EaxRotations] Failed to load IZI SDK from common/izi_sdk: " .. tostring(izi))
    end
    return
end

-- Get plugin info from header
local header_ok, plugin_info = pcall(require, "header")

if not header_ok or not plugin_info or not plugin_info.load then
    if type(core) == "table" and type(core.log_warning) == "function" then
        core.log_warning("[EaxRotations] Plugin not loaded - check header.lua: " .. tostring(plugin_info))
    end
    return
end

-- ============================================================================
-- FRAMEWORK BOOTSTRAP
-- ============================================================================

if not plugin_info.player_class_name then
    -- At login/character-select screen, player object is not yet available.
    -- header.lua returns early without setting player_class_name.
    -- Exit cleanly; on_update will fire after UI loads with a real player.
    core.log("[EaxRotations] Plugin loaded (no player class yet at login screen)")
    return
end

-- Startup summary is printed at end of main.lua (consolidated one-line boot message).

-- Load core framework components in dependency order.
-- The runtime only loads header.lua + main.lua; all framework files must be explicitly require()'d here.
local core_ok, framework_core = pcall(require, "core_sylvanas")
if not core_ok or not framework_core then
    if type(core) == "table" and type(core.log_error) == "function" then
        core.log_error("[EaxRotations] Failed to load core_sylvanas: " .. tostring(framework_core))
    end
    return
end
framework_core.core = core
framework_core.izi = izi
local runtime_generation = framework_core.runtime_generation

local function load_modules(modules)
    for i = 1, #modules do
        local ok, err = pcall(require, modules[i])
        if not ok and type(core) == "table" and type(core.log_warning) == "function" then
            core.log_warning("[EaxRotations] Failed to load " .. modules[i] .. ": " .. tostring(err))
        end
    end
end

load_modules({
    "helpers_sylvanas",
})

load_modules({
    -- Runtime services
    "shared/combat_log_parser_sylvanas",
    "shared/aura_probe_sylvanas",

    -- Data and pure helpers
    "gear_sets_sylvanas",
    "shared/mf_tick_compute_sylvanas",
    "shared/cast_bar_overlay_sylvanas",
    "shared/execute_phase_sylvanas",
    "shared/dot_refresh_sylvanas",

    -- PvP support
    "shared/arena_priority_sylvanas",
    "shared/pvp_burst_window_sylvanas",

    -- Rotation and profile support
    -- Metrics and utility support
    "shared/combat_stats_sylvanas",
    "shared/gear_score_sylvanas",
    "shared/weapon_imbue_sylvanas",
    "shared/spell_validation_sylvanas",
    "shared/talent_inference_sylvanas",
    "shared/ttd_tracker_sylvanas",
    "shared/ttd_ema_tracker_sylvanas",
    "shared/incoming_heal_predictor_sylvanas",
    "shared/healer_deficit_sylvanas",
    "shared/triage_sylvanas",
    "shared/hot_tick_tracker_sylvanas",
})

-- Load shared schema helpers before class schemas so injection factories are available.
local common_ok = pcall(require, "common_sylvanas")
if not common_ok then
    core.log_warning("[EaxRotations] common_sylvanas.lua failed to load — shared schema sections will not be injected")
end

local framework_main = require("main_sylvanas")           -- Dispatcher; class modules register below

-- Load class-specific module
-- Guard: player_class_name may be nil at login screen (header.lua returns early without class detection)
-- CRITICAL: Do NOT hard-return on nil/unknown class, or callbacks never register and plugin stays dead.
-- Instead, set a flag so the rest of setup runs unconditionally.
local class_name = plugin_info.player_class_name and plugin_info.player_class_name:lower() or nil
local class_module_loaded = false
local KNOWN_CLASSES = {
    druid = true, hunter = true, mage = true, paladin = true,
    priest = true, rogue = true, shaman = true, warlock = true, warrior = true,
}

if KNOWN_CLASSES[class_name] then
    local class_module_ok, class_module = pcall(require, "classes/" .. class_name .. "/class_sylvanas")
    if class_module_ok and class_module then
        class_module_loaded = true
        -- class_sylvanas.lua prints its own "X class module loaded" log;
        -- avoid duplicating it here.
    else
        core.log_error("[EaxRotations] Failed to load class module for " .. tostring(plugin_info.player_class_name) .. ": " .. tostring(class_module))
    end
else
    -- Login-screen deferral: intentionally silent (no player class yet).
end

local format = string.format
local color_ok, color = pcall(require, "common/color")
if not color_ok or type(color) ~= "table" then
    -- Fallback color table if common/color is unavailable
    local _noop = function() return { r = 255, g = 255, b = 255, a = 255 } end
    color = { yellow = _noop, white = _noop, green = _noop, red = _noop }
end
local key_helper_ok, key_helper = pcall(require, "common/utility/key_helper")
if not key_helper_ok then key_helper = nil end
local control_panel_helper_ok, control_panel_helper = pcall(require, "common/utility/control_panel_helper")
if not control_panel_helper_ok then control_panel_helper = nil end
local NS = _G.EaxRotations

if NS then
    NS.player_class_name = plugin_info.player_class_name
    NS.player_class_id = plugin_info.player_class_id
end

-- [#23] Pre-allocated menu colors — created once at module level, not inside render_menu().
-- Previously used izi.color.*() which doesn't exist on the izi namespace;
-- the color module is require("common/color") (same as dashboard_sylvanas.lua).
-- Pre-allocating avoids both the runtime nil error AND per-frame color object creation.
local MENU_COLORS = {
    yellow = color.yellow(),
    white = color.white(),
    green = color.green(),
    red = color.red(),
}

-- Theme module: playstyle colors, role/capability maps, section scoping.
local _mt_ok, MenuTheme = pcall(require, "shared/menu_theme_sylvanas")
if not _mt_ok or type(MenuTheme) ~= "table" then MenuTheme = nil end

-- Pre-allocated empty table for 'or {}' fallbacks (avoids GC pressure from repeated table creation)
local EMPTY_TABLE = {}

local class_config = NS and NS.rotation_registry and NS.rotation_registry.class_config or nil
local class_schema = nil
local playstyle_options = {}
local playstyle_keys = {}
local schema_tabs = {}
local schema_widgets = {}
-- [#11] Cache last synced values per widget key to avoid redundant set_setting calls every frame.
local schema_widget_last_values = {}
-- [#5] Section headers created once per schema tab/section at init time.
-- Must be declared BEFORE initialize_schema_menu() which populates it.
local section_headers = {}
local _last_playstyle_log = nil
local _last_enabled_log = nil
local _last_disabled_log_ms = -10000
local _last_sync_error_ms = -10000

-- Throttling note: NS.register_on_update_callback (see core_sylvanas.lua) registers
-- our callback into a shared ~20Hz dispatcher (skip 2 of 3 frames). The old
-- internal _frame_counter / ROTATION_FRAME_SKIP=5 (~12Hz) throttle was
-- originally needed to drop the per-frame on_update entry point from 60Hz.
-- With the shared dispatcher, that layer is redundant and over-throttling
-- (~4Hz) would make the rotation feel laggy — so it's been removed.

-- Shared toggles live as keybind widgets so the main menu and Control Panel
-- use the exact same menu element. Schema checkboxes with these keys are
-- intentionally skipped below to avoid competing widgets writing the same
-- setting in opposite states.
local QUICK_TOGGLE_SETTING_KEYS = {
    use_cooldowns = true,
    use_interrupt = true,
    use_threat_drop = true,
}

if class_name then
    local ok, result = pcall(require, "classes/" .. class_name .. "/schema_sylvanas")
    if ok then
        class_schema = result
    else
        core.log_warning("[EaxRotations] Schema require failed for " .. class_name .. ": " .. tostring(result))
    end
end

-- Inject shared quick-win schema sections into every class schema.
-- This adds Auto-AoE and Force Command toggles without touching individual class files.
if class_schema and NS and NS.common_auto_aoe_section then
    if type(class_schema) == "table" and #class_schema > 0 and type(class_schema[1]) == "table" and class_schema[1].sections then
        -- Tabs format: append sections to the first tab
        table.insert(class_schema[1].sections, NS.common_auto_aoe_section())
        if NS.common_interrupt_humanize_section then
            table.insert(class_schema[1].sections, NS.common_interrupt_humanize_section())
        end
        if NS.common_ttd_section then
            table.insert(class_schema[1].sections, NS.common_ttd_section())
        end
        if NS.common_predictive_healing_section then
            table.insert(class_schema[1].sections, NS.common_predictive_healing_section())
        end
    elseif type(class_schema) == "table" then
        -- Flat format: append individual settings directly
        local auto_aoe = NS.common_auto_aoe_section()
        if auto_aoe and auto_aoe.settings then
            for _, setting in ipairs(auto_aoe.settings) do
                table.insert(class_schema, setting)
            end
        end
        local humanize = NS.common_interrupt_humanize_section and NS.common_interrupt_humanize_section()
        if humanize and humanize.settings then
            for _, setting in ipairs(humanize.settings) do
                table.insert(class_schema, setting)
            end
        end
        local ttd_section = NS.common_ttd_section and NS.common_ttd_section()
        if ttd_section and ttd_section.settings then
            for _, setting in ipairs(ttd_section.settings) do
                table.insert(class_schema, setting)
            end
        end
        local predict_section = NS.common_predictive_healing_section and NS.common_predictive_healing_section()
        if predict_section and predict_section.settings then
            for _, setting in ipairs(predict_section.settings) do
                table.insert(class_schema, setting)
            end
        end
    end
end

if class_config and type(class_config.playstyles) == "table" then
    for _, playstyle in ipairs(class_config.playstyles) do
        local key = type(playstyle) == "table" and playstyle.name or tostring(playstyle)
        local label = type(playstyle) == "table" and (playstyle.display_name or playstyle.name) or tostring(playstyle)
        if key and label then
            table.insert(playstyle_keys, key)
            table.insert(playstyle_options, label)
        end
    end
end

-- Theme lookups derived from class_config playstyles (built once at init).
local _class_key = class_config and class_config.class_key or class_name
local _ps_keyset, _ps_n2k
if MenuTheme and #playstyle_keys > 0 then
    _ps_keyset, _ps_n2k = MenuTheme.build_playstyle_lookup(playstyle_keys, playstyle_options)
end

local function normalize_schema_tabs(schema)
    if type(schema) ~= "table" or #schema == 0 then
        return {}
    end

    if type(schema[1]) == "table" and schema[1].sections then
        return schema
    end

    return {
        {
            name = "General",
            sections = {
                {
                    header = "Settings",
                    settings = schema,
                },
            },
        },
    }
end

local function create_schema_widget(def)
    if not def or not def.key or not def.type then
        return nil
    end
    if def.key == "playstyle" or QUICK_TOGGLE_SETTING_KEYS[def.key] then
        return nil
    end

    local widget = {
        key = def.key,
        type = def.type,
        default = def.default,
        label = def.label or def.key,
        tooltip = def.tooltip,
        options = def.options,
    }

    local stored_value = framework_core and framework_core.get_setting and framework_core.get_setting(def.key, def.default) or def.default

    if def.type == "checkbox" or def.type == "toggle" then
        widget.control = core.menu.checkbox(stored_value == true, def.key)
        widget.render = function()
            widget.control:render(widget.label, widget.tooltip)
        end
        widget.sync = function()
            return widget.control and widget.control:get_state()
        end
    elseif def.type == "slider" then
        local min_value = def.min or 0
        local max_value = def.max or 100
        local default_value = stored_value ~= nil and stored_value or def.default or min_value
        widget.control = core.menu.slider_int(min_value, max_value, default_value, def.key)
        widget.render = function()
            widget.control:render(widget.label, widget.tooltip)
        end
        widget.sync = function()
            return widget.control and widget.control:get()
        end
    elseif def.type == "dropdown" then
        local option_labels = {}
        local option_values = {}
        local option_values_by_label = {}
        local selected_index = 1

        for index, option in ipairs(def.options or EMPTY_TABLE) do
            local label = option.text or tostring(option.value)
            local value = option.value
            option_labels[index] = label
            option_values[index] = value
            option_values_by_label[label] = value
            option_values_by_label[tostring(label):lower()] = value
            option_values_by_label[tostring(value)] = value
            option_values_by_label[tostring(value):lower()] = value
            if option.value == stored_value then
                selected_index = index
            end
        end

        widget.option_values = option_values
        widget.option_values_by_label = option_values_by_label
        widget.control = core.menu.combobox(selected_index, def.key)
        if widget.control and widget.control.set_items then
            pcall(function() widget.control:set_items(option_labels) end)
        end
        widget.render = function()
            widget.control:render(widget.label, option_labels, widget.tooltip)
        end
        widget.sync = function()
            if not widget.control then return nil end
            local ok, raw_value = pcall(function() return widget.control:get() end)
            if ok and type(raw_value) == "number" then
                return widget.option_values[raw_value] or widget.option_values[raw_value + 1]
            end
            if ok and raw_value ~= nil then
                return widget.option_values_by_label[tostring(raw_value)] or widget.option_values_by_label[tostring(raw_value):lower()]
            end
            ok, raw_value = pcall(function()
                return widget.control.get_value and widget.control:get_value() or nil
            end)
            if ok and type(raw_value) == "number" then
                return widget.option_values[raw_value] or widget.option_values[raw_value + 1]
            end
            if ok and raw_value ~= nil then
                return widget.option_values_by_label[tostring(raw_value)] or widget.option_values_by_label[tostring(raw_value):lower()]
            end
            ok, raw_value = pcall(function()
                return widget.control.get_selected_text and widget.control:get_selected_text() or nil
            end)
            if ok and raw_value ~= nil then
                return widget.option_values_by_label[tostring(raw_value)] or widget.option_values_by_label[tostring(raw_value):lower()]
            end
            return nil
        end
    end

    return widget
end

local function initialize_schema_menu()
    schema_tabs = {}
    schema_widgets = {}
    -- [#11] Clear cached values when schema is rebuilt
    for k in pairs(schema_widget_last_values) do
        schema_widget_last_values[k] = nil
    end
    -- [#4] Clear stale section headers on schema rebuild
    for k in pairs(section_headers) do
        section_headers[k] = nil
    end

    for tab_index, tab in ipairs(normalize_schema_tabs(class_schema)) do
        local normalized_tab = {
            name = tab.name or ("Tab " .. tostring(tab_index)),
            tree = core.menu.tree_node(),
            sections = {},
        }
        -- Theme: scope this tab to a playstyle if its name matches one (e.g. "Bear", "Arcane").
        if MenuTheme and _ps_n2k then
            normalized_tab.playscope = MenuTheme.tab_playscope(normalized_tab.name, _ps_n2k)
        end

        for section_index, section in ipairs(tab.sections or EMPTY_TABLE) do
            local normalized_section = {
                header = section.header or ("Section " .. tostring(section_index)),
                settings = {},
            }

            -- Theme: scope this section to playstyle(s) via curated map / class rules.
            if MenuTheme and _class_key then
                local rules = MenuTheme.CLASS_SECTION_RULES[_class_key]
                normalized_section.playscope = MenuTheme.section_playscope(
                    _class_key, normalized_section.header, section.playstyles, _ps_keyset, rules)
                local cat_color = MenuTheme.category_color(normalized_section.header)
                normalized_section.header_color = cat_color
                normalized_section.header_label = MenuTheme.format_section_header(normalized_section.header)
            else
                normalized_section.header_label = normalized_section.header
            end

            -- [#4] Pre-allocate section header — created once, reused every render frame.
            local section_header = core.menu.header()
            section_headers[#section_headers + 1] = section_header
            normalized_section.header_widget = section_header

            for _, def in ipairs(section.settings or EMPTY_TABLE) do
                local widget = create_schema_widget(def)
                if widget then
                    normalized_section.settings[#normalized_section.settings + 1] = widget
                    schema_widgets[widget.key] = widget
                end
            end

            normalized_tab.sections[#normalized_tab.sections + 1] = normalized_section
        end

        schema_tabs[#schema_tabs + 1] = normalized_tab
    end
end

initialize_schema_menu()

-- ============================================================================
-- MENU SETUP (IZI SDK Style)
-- ============================================================================

local function get_playstyle_index(value)
    local wanted = tostring(value or ""):lower()
    for i = 1, #playstyle_keys do
        if tostring(playstyle_keys[i]):lower() == wanted then
            return i
        end
    end
    return 1
end

local function get_initial_playstyle_index()
    local selected = framework_core and framework_core.get_setting and (
        framework_core.get_setting("playstyle", nil)
        or framework_core.get_setting("active_playstyle", nil)
    ) or nil
    return get_playstyle_index(selected or (class_config and class_config.default_playstyle) or playstyle_keys[1])
end

local menu_elements = {
    main_tree = core.menu.tree_node(),
    quick_toggles_tree = core.menu.tree_node(),
    playstyle_combo = core.menu.combobox(get_initial_playstyle_index(), "eaxrotations_active_playstyle_combo"),
    enable_script_check = core.menu.keybind(7, true, "eax_rotation_enabled_keybind"),
    healing_toggle = core.menu.keybind(7, true, "eax_healing_enabled_keybind"),
    damage_toggle = core.menu.keybind(7, true, "eax_damage_enabled_keybind"),
    cooldowns_toggle = core.menu.keybind(7, true, "eax_cooldowns_enabled_keybind"),
    aoe_toggle = core.menu.keybind(7, true, "eax_aoe_enabled_keybind"),
    interrupts_toggle = core.menu.keybind(7, true, "eax_interrupts_enabled_keybind"),
    utility_toggle = core.menu.keybind(7, true, "eax_utility_enabled_keybind"),
    threat_drop_toggle = core.menu.keybind(7, true, "eax_threat_drop_enabled_keybind"),
    settings_tree = core.menu.tree_node(),
    diagnostics_tree = core.menu.tree_node(),
    dump_spells_btn = core.menu.button("eax_dump_spells"),
    debug_swing_timer_chk = core.menu.checkbox(false, "eax_debug_swing_timer"),
    debug_game_events_chk = core.menu.checkbox(false, "eax_debug_game_events"),
    -- [#4] Pre-allocated header widgets — created ONCE, not every render frame.
    -- core.menu.header() returns a new widget each call; creating inside render_menu()
    -- leaked instances every frame. Now stored and reused.
    header_class_info = core.menu.header(),
    header_active_playstyle = core.menu.header(),

}



-- section_headers is declared above (before initialize_schema_menu() call)

local quick_toggle_defs = {
    {
        key = "rotation_enabled",
        label = "Rotation",
        tooltip = "Master switch for all rotation execution.",
        control = menu_elements.enable_script_check,
        default = true,
    },
    {
        key = "healing_enabled",
        label = "Healing",
        tooltip = "Allow healing and shielding actions.",
        control = menu_elements.healing_toggle,
        default = true,
        capability = "healing",
    },
    {
        key = "damage_enabled",
        label = "Damage",
        tooltip = "Allow offensive rotation actions.",
        control = menu_elements.damage_toggle,
        default = true,
    },
    {
        key = "use_cooldowns",
        label = "Cooldowns",
        tooltip = "Allow major cooldowns and burst actions.",
        control = menu_elements.cooldowns_toggle,
        default = true,
    },
    {
        key = "aoe_enabled",
        label = "AoE",
        tooltip = "Allow AoE actions that require multiple enemies.",
        control = menu_elements.aoe_toggle,
        default = true,
    },
    {
        key = "use_interrupt",
        label = "Interrupts",
        tooltip = "Allow interrupt logic where the class supports it.",
        control = menu_elements.interrupts_toggle,
        default = true,
        capability = "interrupts",
    },
    {
        key = "utility_enabled",
        label = "Utility",
        tooltip = "Allow utility middleware such as forms, shouts, dispels, and threat tools.",
        control = menu_elements.utility_toggle,
        default = true,
    },
    {
        key = "use_threat_drop",
        label = "Threat Drops",
        tooltip = "Allow threat-drop abilities when group threat data says they are needed.",
        control = menu_elements.threat_drop_toggle,
        default = true,
        capability = "threat_drop",
    },
}

local function get_keybind_toggle_state(control, default)
    if not control then return default end
    -- Read the widget's actual toggle state first. The user may have clicked
    -- the UI toggle while leaving the keybind on the default key (7).
    local ok, value = pcall(function() return control:get_toggle_state() end)
    if ok and type(value) == "boolean" then return value end
    -- get_toggle_state() returned non-boolean or threw.
    -- CRITICAL: for keybind widgets, get_state() returns KEY PRESS STATE
    -- (is the key currently held?), NOT toggle state. When the key is not
    -- pressed it returns false, which would falsely disable rotation.
    -- Only fall back to get_state() for non-keybind widgets (checkboxes).
    local key_ok = pcall(function() return control:get_key_code() end)
    if not key_ok then
        -- Not a keybind (checkbox/toggle) — get_state() is safe
        ok, value = pcall(function() return control:get_state() end)
        if ok and type(value) == "boolean" then return value end
    end
    return default
end

local function get_keybind_name(control)
    if not control then return "Unbound" end
    local ok, key_code = pcall(function() return control:get_key_code() end)
    if not ok then return "Unbound" end
    if key_helper and key_helper.get_key_name then
        local name_ok, name = pcall(function() return key_helper:get_key_name(key_code) end)
        if name_ok and name then return tostring(name) end
    end
    return tostring(key_code or 7)
end

local function sync_quick_toggles()
    if not (framework_core and framework_core.set_setting) then return end
    for _, def in ipairs(quick_toggle_defs) do
        local value = get_keybind_toggle_state(def.control, def.default ~= false)
        framework_core.set_setting(def.key, value)
    end
end

local _last_playstyle_combo_index = nil

local function sync_playstyle_control()
    if not (framework_core and framework_core.set_setting and menu_elements.playstyle_combo) then return end
    local ok, combo_index = pcall(function() return menu_elements.playstyle_combo:get() end)
    if not ok or type(combo_index) ~= "number" then return end

    if _last_playstyle_combo_index == nil then
        _last_playstyle_combo_index = combo_index
        local value = playstyle_keys[combo_index]
        if type(value) == "string" and value ~= "" then
            framework_core.set_setting("playstyle", value)
            framework_core.set_setting("active_playstyle", value)
            if _last_playstyle_log ~= value then
                _last_playstyle_log = value
                core.log("[EaxRotations] Active playstyle: " .. tostring(value))
            end
        end
        return
    end

    local current_playstyle = framework_core.get_setting and framework_core.get_setting("active_playstyle", nil)

    -- Detect if user changed the combobox (index changed since last read)
    if combo_index ~= _last_playstyle_combo_index then
        -- User clicked the combobox — write selection to settings
        local value = playstyle_keys[combo_index]
        if type(value) == "string" and value ~= "" then
            framework_core.set_setting("playstyle", value)
            framework_core.set_setting("active_playstyle", value)
            if _last_playstyle_log ~= value then
                _last_playstyle_log = value
                core.log("[EaxRotations] Active playstyle: " .. tostring(value))
            end
        end
        _last_playstyle_combo_index = combo_index
        return
    end

    if current_playstyle then
        local setting_index = get_playstyle_index(current_playstyle)
        if setting_index ~= combo_index then
            pcall(function() menu_elements.playstyle_combo:set(setting_index) end)
            _last_playstyle_combo_index = setting_index
        end
    end
end

local function render_quick_toggles()
    menu_elements.quick_toggles_tree:render("Quick Toggles", function()
        if menu_elements.playstyle_combo and #playstyle_options > 0 then
            menu_elements.playstyle_combo:render("Playstyle", playstyle_options, "Select active " .. (class_config and class_config.class_name or "class") .. " rotation.")
        end
        for _, def in ipairs(quick_toggle_defs) do
            def.control:render(def.label, def.tooltip)
        end
    end)
end

local function on_control_panel_render()
    if framework_core.runtime_generation ~= runtime_generation then return {} end
    local control_panel_elements = {}

    -- Theme: filter control panel toggles by active playstyle role.
    local _role = "hybrid"
    local _caps = nil
    if MenuTheme and _class_key then
        local _active = framework_core and framework_core.get_setting and framework_core.get_setting("active_playstyle") or nil
        _role = MenuTheme.role_for_playstyle(_class_key, _active)
        _caps = MenuTheme.capabilities(_role)
    end

    for _, def in ipairs(quick_toggle_defs) do
        -- Role-based visibility: skip toggles that don't make sense for this role.
        local _skip = false
        if _caps then
            local cap_key = def.capability or def.key
            if _caps[cap_key] == false then _skip = true end
        end
        if not _skip then
            local label = format("[Eax] %s (%s) ", def.label, get_keybind_name(def.control))
            local inserted = false
            if control_panel_helper and control_panel_helper.insert_toggle_ then
                local ok, result = pcall(function()
                    return control_panel_helper:insert_toggle_(control_panel_elements, label, def.control, false, true)
                end)
                inserted = ok and result == true
            end
            if not inserted then
                control_panel_elements[#control_panel_elements + 1] = {
                    name = label,
                    keybind = def.control,
                }
            end
        end
    end

    -- Expose key schema checkbox settings on the control panel
    local CP_SCHEMA_KEYS = { "disc_shield_tank_only" }
    for _, key in ipairs(CP_SCHEMA_KEYS) do
        local widget = schema_widgets[key]
        if widget and widget.control then
            local label = "[Eax] " .. (widget.label or key)
            local inserted = false
            if control_panel_helper and control_panel_helper.insert_toggle_ then
                local ok, result = pcall(function()
                    return control_panel_helper:insert_toggle_(control_panel_elements, label, widget.control, false, true)
                end)
                inserted = ok and result == true
            end
            if not inserted then
                control_panel_elements[#control_panel_elements + 1] = {
                    name = label,
                    keybind = widget.control,
                }
            end
        end
    end

    return control_panel_elements
end

-- ============================================================================
-- MENU RENDER FUNCTION
-- ============================================================================

local function render_menu()
    if framework_core.runtime_generation ~= runtime_generation then return end
    -- [#5] All subtrees rendered INSIDE main_tree so they appear as children,
    -- not orphaned top-level trees floating independently.
    menu_elements.main_tree:render("EaxRotations", function()
        local active_playstyle = framework_core and framework_core.get_setting and framework_core.get_setting("active_playstyle") or playstyle_options[1] or "unknown"

        -- [#4] Use pre-allocated header instead of core.menu.header() per frame
        local rotation_state = framework_core and framework_core.get_setting and framework_core.get_setting("rotation_enabled", true) ~= false
        -- Title Case: "PALADIN" -> "Paladin", "protection" -> "Protection" (via playstyle_options display_name)
        local class_label = plugin_info.player_class_name and plugin_info.player_class_name:gsub("^%u", string.lower):gsub("^%l", string.upper) or "Unknown"
        local playstyle_label = playstyle_options[get_playstyle_index(active_playstyle)] or tostring(active_playstyle)
        local state_label = rotation_state and "Enabled" or "Disabled"
        -- Theme: color the title header with the active playstyle's signature color,
        -- falling back to green/red based on rotation state.
        local _title_color = rotation_state and MENU_COLORS.green or MENU_COLORS.red
        if MenuTheme and _class_key then
            local _ps_color = MenuTheme.playstyle_color(_class_key, active_playstyle)
            if _ps_color then _title_color = _ps_color end
        end
        menu_elements.header_class_info:render(class_label .. " / " .. playstyle_label .. " / " .. state_label, _title_color)

        render_quick_toggles()

        -- [#5] Settings subtree nested inside main_tree
        menu_elements.settings_tree:render("Class Settings", function()
            -- Reuse active_playstyle from outer closure (no shadowing issue)
            -- Theme: color the active-playstyle header with the playstyle signature color.
            local _ps_header_color = MENU_COLORS.white
            if MenuTheme and _class_key then
                local _c = MenuTheme.playstyle_color(_class_key, active_playstyle)
                if _c then _ps_header_color = _c end
            end
            menu_elements.header_active_playstyle:render("Active Playstyle: " .. tostring(active_playstyle), _ps_header_color)

            for _, tab in ipairs(schema_tabs) do
                -- Theme: skip tabs scoped to a different playstyle.
                local _tab_visible = true
                if MenuTheme and tab.playscope then
                    _tab_visible = MenuTheme.scope_admits({tab.playscope}, active_playstyle)
                end
                if _tab_visible then
                    -- Count visible sections so we don't render an empty tab tree.
                    local _has_visible = false
                    if MenuTheme then
                        for _, section in ipairs(tab.sections) do
                            if MenuTheme.scope_admits(section.playscope, active_playstyle) then
                                _has_visible = true; break
                            end
                        end
                    else
                        _has_visible = true
                    end
                    if _has_visible then
                        tab.tree:render(tab.name, function()
                            for _, section in ipairs(tab.sections) do
                                -- Theme: skip sections scoped to a different playstyle.
                                local _sec_visible = true
                                if MenuTheme and section.playscope then
                                    _sec_visible = MenuTheme.scope_admits(section.playscope, active_playstyle)
                                end
                                if _sec_visible then
                                    -- [#4] Use pre-allocated section header with themed color.
                                    section.header_widget:render(section.header_label or section.header, section.header_color or MENU_COLORS.white)
                                    for _, widget in ipairs(section.settings) do
                                        -- [#6] Guard against nil widgets (e.g. unsupported schema type)
                                        if widget and widget.render then
                                            widget.render()
                                        end
                                    end
                                end
                            end
                        end)
                    end
                end
            end
        end)

        -- [#5] Diagnostics subtree nested inside main_tree
        menu_elements.diagnostics_tree:render("Diagnostics", function()
            if menu_elements.dump_spells_btn:render("Dump Learned Spells", "Writes every known spell for this class to the console log") then
                local raw = plugin_info.player_class_name
                if raw and NS and NS.dump_class_spells then
                    local name = raw:sub(1,1):upper() .. raw:sub(2):lower()
                    NS.dump_class_spells(name)
                end
            end
            -- Debug toggles for runtime diagnostics (visible in console log)
            if menu_elements.debug_swing_timer_chk then
                menu_elements.debug_swing_timer_chk:render("Debug Swing Timer", "Log addon vs fallback path decisions")
            end
            if menu_elements.debug_game_events_chk then
                menu_elements.debug_game_events_chk:render("Debug Game Events", "Log event dispatcher registration and dispatch")
            end
        end)
    end)
end

-- ============================================================================
-- UPDATE CALLBACK - Main Execution Loop
-- ============================================================================

local _on_update_tick_count = 0
local _last_tick_log_s = 0
local _on_update_first_print = false
local _on_update_throttle_ms = 0
local ON_UPDATE_INTERVAL_MS = 50
local function on_update()
    local now_ms = core.game_time and core.game_time() or 0
    if now_ms - _on_update_throttle_ms < ON_UPDATE_INTERVAL_MS then
        return
    end
    _on_update_throttle_ms = now_ms
    _on_update_tick_count = _on_update_tick_count + 1
    -- Removed FIRST on_update / HEARTBEAT one-shot logs. They were useful during
    -- development (v2.0) but now generate noise on every /reload. Use the
    -- consolidated boot summary or enable debug mode (set eax_rotations_debug
    -- setting) for verbose startup diagnostics.
    if framework_core.runtime_generation ~= runtime_generation then
        local now_s = NS and NS.time_now and NS.time_now() or 0
        if now_s - (_last_gen_mismatch_log or 0) > 3 then
            print("[EaxRotations:main] EXIT: gen mismatch local=" .. tostring(runtime_generation) .. " core=" .. tostring(framework_core.runtime_generation))
            core.log("[EaxRotations:main] EXIT: gen mismatch local=" .. tostring(runtime_generation) .. " core=" .. tostring(framework_core.runtime_generation))
            _last_gen_mismatch_log = now_s
        end
        return
    end
    local player = core.object_manager and core.object_manager.get_local_player()
    if not player then
        if not _guard2_logged then
            _guard2_logged = true
        end
        return
    end
    local alive_ok, alive = pcall(function() return player:is_alive() end)
    if alive_ok and alive == false then
        if not _guard3_logged then
            _guard3_logged = true
        end
        return
    end
    -- Guard against ghost form (dead spirit walking). is_alive() returns true
    -- for ghosts on some engine builds, so we need an explicit ghost check.
    local ghost_ok, is_ghost = pcall(function() return player:is_ghost() end)
    if ghost_ok and is_ghost then
        if not _guard3b_logged then
            _guard3b_logged = true
        end
        return
    end

    -- ========================================================================
    -- RETRY DEFERRED CLASS MODULE LOADING
    -- If class module failed to load at boot (login screen, race condition),
    -- retry now that we have a confirmed alive, valid player object.
    -- ========================================================================
    if not class_module_loaded then
        local retry_name = class_name
        if not retry_name then
            local CLASS_ID_TO_NAME = {
                [1] = "warrior", [2] = "paladin", [3] = "hunter", [4] = "rogue",
                [5] = "priest", [7] = "shaman", [8] = "mage", [9] = "warlock", [11] = "druid",
            }
            local cls_ok, cls_id = pcall(function() return player:get_class() end)
            if cls_ok and type(cls_id) == "number" then
                retry_name = CLASS_ID_TO_NAME[cls_id]
            end
        end
        if retry_name and KNOWN_CLASSES[retry_name] then
            local mod_ok, mod_val = pcall(require, "classes/" .. retry_name .. "/class_sylvanas")
            if mod_ok and mod_val then
                class_module_loaded = true
                class_name = retry_name
                if plugin_info then
                    plugin_info.player_class_name = retry_name:upper()
                end
                if NS then
                    NS.player_class_name = retry_name:upper()
                end
                local schema_ok, schema_val = pcall(require, "classes/" .. retry_name .. "/schema_sylvanas")
                if schema_ok then
                    class_schema = schema_val
                end
                initialize_schema_menu()
            else
                -- Retry still pending; intentionally silent.
            end
        end
    end

    -- We're now inside the shared ~20Hz dispatcher (see header comment).
    -- The cheap runtime_generation + is_alive + is_ghost guards above run at 20Hz.
    -- Everything below (widget sync, build_context, dispatch) runs at 20Hz.

    -- Sync debug toggles from diagnostics menu checkboxes
    if NS then
        if menu_elements.debug_swing_timer_chk then
            local ok, st = pcall(function() return menu_elements.debug_swing_timer_chk:get_state() end)
            NS._DEBUG_SWING_TIMER = ok and st == true
        end
        if menu_elements.debug_game_events_chk then
            local ok, ge = pcall(function() return menu_elements.debug_game_events_chk:get_state() end)
            NS._DEBUG_GAME_EVENTS = ok and ge == true
        end
    end

    -- [#P1] Resolve rotation_enabled BEFORE the expensive widget sync loop.
    -- CRITICAL: framework_core settings are ephemeral (lost on reload).
    -- The keybind widget state IS persisted by Sylvanas. Read the widget
    -- directly so the toggle survives reloads without flip-flopping.
    local rotation_enabled = get_keybind_toggle_state(menu_elements.enable_script_check, true)
    if _last_enabled_log ~= rotation_enabled then
        _last_enabled_log = rotation_enabled
        if not rotation_enabled then
            core.log("[EaxRotations] Rotation disabled by quick toggle")
        end
    end

    if control_panel_helper and control_panel_helper.on_update then
        local cp_ok, cp_err = pcall(function() control_panel_helper:on_update(menu_elements) end)
        if not cp_ok then
            local now_ms = core.game_time and core.game_time() or 0
            if now_ms - _last_sync_error_ms > 5000 then
                _last_sync_error_ms = now_ms
                core.log_warning("[EaxRotations] Control panel update failed: " .. tostring(cp_err))
            end
        end
    end

    sync_quick_toggles()
    sync_playstyle_control()

    if framework_core and framework_core.set_setting then
        if rotation_enabled then
            for key, widget in pairs(schema_widgets) do
                local sync_ok, value = pcall(function()
                    return widget.sync and widget.sync() or nil
                end)
                if not sync_ok then
                    local now_ms = core.game_time and core.game_time() or 0
                    if now_ms - _last_sync_error_ms > 5000 then
                        _last_sync_error_ms = now_ms
                        core.log_warning("[EaxRotations] Setting sync failed for " .. tostring(key) .. ": " .. tostring(value))
                    end
                    value = nil
                end
                if value ~= nil then
                    local last_val = schema_widget_last_values[key]
                    if value ~= last_val then
                        schema_widget_last_values[key] = value
                        framework_core.set_setting(key, value)
                    end
                end
            end
        end
    end

    -- Check if script is enabled after menu settings are synchronized.
    -- rotation_enabled already resolved above (before widget sync) to allow
    -- skipping the bulk schema widget sync loop when disabled.
    if not rotation_enabled then
        if not _guard4_logged then
            _guard4_logged = true
            core.log_warning("[EaxRotations] Rotation disabled by quick toggle")
        end
        return
    end

    -- Let main_sylvanas own all combat/target gating. The dispatcher's
    -- OOC manager + unified fall-through handles OOC buffs, self-buffs,
    -- and auto-target acquisition. No pre-gate needed here.
    local me = framework_core and framework_core.GetPlayer and framework_core.GetPlayer() or nil
    if not me then
        if not _guard5_logged then
            _guard5_logged = true
        end
        -- Workaround: fall back to direct OM if GetPlayer caches nothing
        local fallback_ok, fallback_me = pcall(function()
            return core and core.object_manager and core.object_manager.get_local_player
                and core.object_manager:get_local_player()
        end)
        if fallback_ok and fallback_me then
            me = fallback_me
        else
            return -- No player unit available
        end
    end
    -- Guard against stale/invalid player objects (loading screens, death, zone transitions)
    local pcall_ok, player_valid = pcall(function() return me:is_valid() end)
    if not pcall_ok or player_valid == false then
        if not _guard6_logged then
            _guard6_logged = true
        end
        return -- Player object is garbage-collected / invalid
    end

    if not _post_guards_logged then
        _post_guards_logged = true
    end
    if framework_main and framework_main.on_rotation_update then
        local success, err = pcall(framework_main.on_rotation_update)
        if not success then
            core.log_error("[EaxRotations] Rotation error: " .. tostring(err))
        end
    end
end

-- ============================================================================
-- REGISTER CALLBACKS
-- ============================================================================

-- Register main rotation callback through the throttled shared dispatcher
-- (NS.register_on_update_callback in core_sylvanas.lua). The shared dispatcher:
--   1. Throttles to ~20Hz (skip 2 of 3 frames)
--   2. Performs the runtime_generation check (bails on /reload)
--   3. Wraps the callback in pcall so a single bad tick doesn't crash the game
-- Registering through it cuts the engine C→Lua entry point count from N+1 down
-- to 1 for the whole plugin, removing the previous 60Hz no-op spam that
-- caused measurable FPS drops on weak CPUs.
if NS and NS.register_on_update_callback then
    local _reg_ok = NS.register_on_update_callback(on_update)
    if not _reg_ok then
        core.log_error("[EaxRotations:main] FAIL: NS.register_on_update_callback returned false -- on_update will NEVER fire")
    end
else
    core.log_error("[EaxRotations:main] FAIL: NS.register_on_update_callback is nil -- PS build missing API")
end
if type(core.register_on_render_menu_callback) == "function" then
    pcall(core.register_on_render_menu_callback, render_menu)
end
if type(core.register_on_render_control_panel_callback) == "function" then
    pcall(core.register_on_render_control_panel_callback, on_control_panel_render)
end

-- Movement handler render callback: required for pause/face delays and auto-resume.
-- Loaded here so movement_handler:on_render() fires every render frame.
-- Gated on rotation_enabled — render callbacks fire at 60fps+ (un-throttled), so
-- skipping when rotation is off saves a per-frame C->Lua crossing.
do
    local _ma_ok, _movement_assist = pcall(require, "shared/movement_assist_sylvanas")
    if _ma_ok and type(_movement_assist) == "table" and _movement_assist.on_render then
        if type(core.register_on_render_callback) == "function" then
            core.register_on_render_callback(function()
                local _roten = framework_core and framework_core.get_setting
                    and framework_core.get_setting("rotation_enabled", true) ~= false
                if not _roten then return end
                _movement_assist.on_render()
            end)
        end
    end
end

-- Consolidated startup summary (replaces 4 verbose lines).
local _rot_count = 0
if NS and NS.rotation_registry and NS.rotation_registry.playstyles then
    for _ in pairs(NS.rotation_registry.playstyles) do _rot_count = _rot_count + 1 end
end
core.log("[EaxRotations] v" .. tostring(plugin_info.version or "?") .. " loaded for " .. tostring(plugin_info.player_class_name or "?")
    .. " (core+izi_sdk, 20Hz dispatcher)")
core.log("[EaxRotations] Class module: " .. tostring(plugin_info.player_class_name or "?")
    .. " (" .. tostring(_rot_count) .. " rotation" .. (_rot_count == 1 and "" or "s") .. " registered)")
