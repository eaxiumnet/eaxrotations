-- Readability notes:
--   What: bootstrap for shared runtime, UI, and class loading.
--   When: runs once after the load gate.
--   Why: makes startup order explicit.
--   Safety: only add files with clear dependency order.

-- Decision notes:
--   Bootstrap stays explicit because Sylvanas only loads header.lua and main.lua; internal load-order tables are documentation only.
--   Menu widgets are created once, then synced to NS.settings during update so render code does not allocate combat state.
--   Rotation execution is delegated to main_sylvanas.lua so startup, menu, and combat concerns stay separate.
-- ============================================================================
-- EaxRotations - Main File
-- Project Sylvanas API - Rotation Execution
-- ============================================================================

-- Import core framework
local core = _G.core

-- Import IZI SDK from common folder (as per Project Sylvanas documentation)
local izi = require("common/izi_sdk")

if not izi then
    core.log_error("[EaxRotations] Failed to load IZI SDK from common/izi_sdk")
    return
end

-- Get plugin info from header
local plugin_info = require("header")

if not plugin_info or not plugin_info.load then
    core.log_warning("[EaxRotations] Plugin not loaded - check header.lua")
    return
end

-- ============================================================================
-- FRAMEWORK BOOTSTRAP
-- ============================================================================

core.log("[EaxRotations] Initializing framework for " .. plugin_info.player_class_name)

-- Load core framework components in dependency order (matches load_order_sylvanas.lua)
-- The runtime only loads header.lua + main.lua; SYLVANAS_API_LOAD_ORDER is NOT auto-processed.
-- All framework files must be explicitly require()'d here.
local framework_core = require("core_sylvanas")          -- order 10 (creates _G.EaxRotations namespace)
framework_core.core = core
framework_core.izi = izi
local framework_helpers = require("helpers_sylvanas")     -- order 10.5 (NS.import_helpers)
local explain_helpers = require("explain_helpers_sylvanas") -- order 10.7 (NS.explain_spell_gates, NS.explain_context_gates)
local optimizer = require("optimizer")                   -- order 11 (DecisionCache)
local damage_meter = require("damage_meter_sylvanas")     -- order 12 (DPS tracking)
local dashboard = require("dashboard_sylvanas")           -- order 13 (combat overlay)
local debug_log = require("debug_log_sylvanas")           -- order 14 (debug log frame)
local api_probe = require("api_probe_sylvanas")           -- order 14.5 (API probe diagnostic)
local sim_constants = require("sim_constants_sylvanas")    -- order 15 (sim-derived constants)
local gear_sets = require("gear_sets_sylvanas")            -- order 15.5 (TBC set item IDs + bonus spell IDs)
local mf_tick = require("shared/mf_tick_compute_sylvanas")  -- order 16 (MF tick computation)
local execute_phase = require("shared/execute_phase_sylvanas")  -- order 17 (execute phase gating)
local dot_refresh = require("shared/dot_refresh_sylvanas")      -- order 18 (DoT refresh logic)

-- Tier 2-4 Gap Analysis Features
-- PvP Core Foundation
local dr_tracker = require("shared/dr_tracker_sylvanas")              -- DR tracking
local enemy_cd_tracker = require("shared/enemy_cd_tracker_sylvanas")  -- Enemy CD tracking
local arena_priority = require("shared/arena_priority_sylvanas")      -- Arena target priority
local pvp_burst = require("shared/pvp_burst_window_sylvanas")          -- Burst window scoring

-- Rotation Infrastructure
local strategy_factory = require("shared/strategy_factory_sylvanas")  -- Strategy factory
local custom_rotation = require("shared/custom_rotation_sylvanas")      -- Custom rotation engine

-- Settings & Profiles
local profile_manager = require("shared/profile_manager_sylvanas")      -- Profile management

-- Metrics, Gear, Swing
local combat_stats = require("shared/combat_stats_sylvanas")            -- Combat statistics
local gear_score = require("shared/gear_score_sylvanas")                -- Gear score
local swing_timer = require("shared/swing_timer_sylvanas")              -- Enhanced swing timer
local weapon_imbue = require("shared/weapon_imbue_sylvanas")            -- Weapon imbue tracking

-- UX/Optimization
local spell_validation = require("shared/spell_validation_sylvanas")    -- Spell validation
local talent_inference = require("shared/talent_inference_sylvanas")    -- Talent inference
local idle_suggestion = require("shared/idle_suggestion_sylvanas")      -- Idle suggestions
local benchmarks = require("shared/benchmarks_sylvanas")                -- Performance benchmarks

local framework_main = require("main_sylvanas")           -- Dispatcher; class modules register below

-- Load class-specific module
local class_name = plugin_info.player_class_name:lower()
-- [#10] Guard class module require with pcall + validation against known class names
local KNOWN_CLASSES = {
    druid = true, hunter = true, mage = true, paladin = true,
    priest = true, rogue = true, shaman = true, warlock = true, warrior = true,
}

if not KNOWN_CLASSES[class_name] then
    core.log_error("[EaxRotations] Unknown class: " .. tostring(class_name) .. " — no module to load")
    return
end

local class_module_ok, class_module = pcall(require, "classes/" .. class_name .. "/class_sylvanas")
if not class_module_ok or not class_module then
    core.log_error("[EaxRotations] Failed to load class module for " .. plugin_info.player_class_name .. ": " .. tostring(class_module))
    return
end

core.log("[EaxRotations] Class module loaded: " .. plugin_info.player_class_name)

local format = string.format
local color = require("common/color")
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
-- [PROBE] Guard flag for one-shot API probe trigger from menu checkbox
local _api_probe_triggered = false

-- Shared toggles live as keybind widgets so the main menu and Control Panel
-- use the exact same menu element. Schema checkboxes with these keys are
-- intentionally skipped below to avoid competing widgets writing the same
-- setting in opposite states.
local QUICK_TOGGLE_SETTING_KEYS = {
    use_cooldowns = true,
    use_interrupt = true,
    use_threat_drop = true,
}

do
    local ok, result = pcall(require, "classes/" .. class_name .. "/schema_sylvanas")
    if ok then
        class_schema = result
    else
        core.log_warning("[EaxRotations] Schema require failed for " .. class_name .. ": " .. tostring(result))
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

-- get_default_playstyle_index removed: unused (playstyle selection handled by schema dropdown sync)

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
    if QUICK_TOGGLE_SETTING_KEYS[def.key] then
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
        local selected_index = 1

        for index, option in ipairs(def.options or EMPTY_TABLE) do
            option_labels[index] = option.text or tostring(option.value)
            option_values[index] = option.value
            if option.value == stored_value then
                selected_index = index
            end
        end

        widget.option_values = option_values
        widget.control = core.menu.combobox(selected_index, def.key)
        widget.render = function()
            widget.control:render(widget.label, option_labels, widget.tooltip)
        end
        widget.sync = function()
            local index = widget.control and widget.control:get()
            return widget.option_values[index]
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

        for section_index, section in ipairs(tab.sections or EMPTY_TABLE) do
            local normalized_section = {
                header = section.header or ("Section " .. tostring(section_index)),
                settings = {},
            }

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

local menu_elements = {
    main_tree = core.menu.tree_node(),
    quick_toggles_tree = core.menu.tree_node(),
    enable_script_check = core.menu.keybind(7, true, "eax_rotation_enabled_keybind"),
    healing_toggle = core.menu.keybind(7, true, "eax_healing_enabled_keybind"),
    damage_toggle = core.menu.keybind(7, true, "eax_damage_enabled_keybind"),
    cooldowns_toggle = core.menu.keybind(7, true, "eax_cooldowns_enabled_keybind"),
    aoe_toggle = core.menu.keybind(7, true, "eax_aoe_enabled_keybind"),
    interrupts_toggle = core.menu.keybind(7, true, "eax_interrupts_enabled_keybind"),
    utility_toggle = core.menu.keybind(7, true, "eax_utility_enabled_keybind"),
    threat_drop_toggle = core.menu.keybind(7, true, "eax_threat_drop_enabled_keybind"),
    debug_mode_check = core.menu.checkbox(false, "debug_mode"),
    verbose_trace_check = core.menu.checkbox(false, "verbose_trace"),
    -- NOTE: playstyle combo is removed — the schema dropdown (key="playstyle") in Class Settings
    -- already handles playstyle selection AND syncs active_playstyle every frame.
    -- A second combo here caused a dual-dropdown conflict where both widgets
    -- fought over active_playstyle, with the schema dropdown winning because
    -- it syncs second in the loop. Users should use the schema dropdown only.
    settings_tree = core.menu.tree_node(),
    diagnostics_tree = core.menu.tree_node(),
    debug_log_check = core.menu.checkbox(false, "show_debug_log"),
    api_probe_check = core.menu.checkbox(false, "run_api_probe"),
    -- [#4] Pre-allocated header widgets — created ONCE, not every render frame.
    -- core.menu.header() returns a new widget each call; creating inside render_menu()
    -- leaked instances every frame. Now stored and reused.
    header_class_info = core.menu.header(),
    header_active_playstyle = core.menu.header(),
    header_debugging_note = core.menu.header(),
    header_dc_stats = core.menu.header(),
    header_dc_not_loaded = core.menu.header(),
    header_probe_summary = core.menu.header(),
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
    },
}

local function get_keybind_toggle_state(control, default)
    if not control then return default end
    local ok, value = pcall(function() return control:get_toggle_state() end)
    if ok and type(value) == "boolean" then return value end
    ok, value = pcall(function() return control:get_state() end)
    if ok and type(value) == "boolean" then return value end
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

local function render_quick_toggles()
    menu_elements.quick_toggles_tree:render("Quick Toggles", function()
        for _, def in ipairs(quick_toggle_defs) do
            def.control:render(def.label, def.tooltip)
        end
    end)
end

local function on_control_panel_render()
    local control_panel_elements = {}

    for _, def in ipairs(quick_toggle_defs) do
        local label = format("[Eax] %s (%s) ", def.label, get_keybind_name(def.control))
        if control_panel_helper and control_panel_helper.insert_toggle_ then
            control_panel_helper:insert_toggle_(control_panel_elements, label, def.control, false)
        else
            control_panel_elements[#control_panel_elements + 1] = {
                name = label,
                keybind = def.control,
            }
        end
    end

    return control_panel_elements
end

-- ============================================================================
-- MENU RENDER FUNCTION
-- ============================================================================

local function render_menu()
    -- [#5] All subtrees rendered INSIDE main_tree so they appear as children,
    -- not orphaned top-level trees floating independently.
    menu_elements.main_tree:render("EaxRotations", function()
        local active_playstyle = framework_core and framework_core.get_setting and framework_core.get_setting("active_playstyle") or "unknown"

        -- [#4] Use pre-allocated header instead of core.menu.header() per frame
        menu_elements.header_class_info:render(plugin_info.player_class_name .. " / " .. tostring(active_playstyle), MENU_COLORS.yellow)

        render_quick_toggles()

        -- [#5] Settings subtree nested inside main_tree
        menu_elements.settings_tree:render("Class Settings", function()
            -- Reuse active_playstyle from outer closure (no shadowing issue)
            menu_elements.header_active_playstyle:render("Active Playstyle: " .. tostring(active_playstyle), MENU_COLORS.white)

            for _, tab in ipairs(schema_tabs) do
                tab.tree:render(tab.name, function()
                    for _, section in ipairs(tab.sections) do
                        -- [#4] Use pre-allocated section header
                        section.header_widget:render(section.header, MENU_COLORS.white)
                        for _, widget in ipairs(section.settings) do
                            -- [#6] Guard against nil widgets (e.g. unsupported schema type)
                            if widget and widget.render then
                                widget.render()
                            end
                        end
                    end
                end)
            end
        end)

        -- [#5] Diagnostics subtree nested inside main_tree
        menu_elements.diagnostics_tree:render("Diagnostics", function()
            menu_elements.header_debugging_note:render("Debugging is off by default for FPS.", MENU_COLORS.white)
            menu_elements.debug_mode_check:render("Debug Mode", "Show detailed debug output")
            menu_elements.verbose_trace_check:render("Verbose Trace", "Log decision checks, context, and no-action frames")
            menu_elements.debug_log_check:render("Show Debug Log", "Toggle the debug log window on/off")

            -- API Probe button: checkbox triggers a one-shot probe run
            menu_elements.api_probe_check:render("Run API Probe", "Check to run a one-shot API probe that logs PASS/FAIL for all API functions.")
            if menu_elements.api_probe_check and menu_elements.api_probe_check:get_state() then
                if not _api_probe_triggered then
                    _api_probe_triggered = true
                    if NS.run_api_probe then NS.run_api_probe() end
                end
            else
                _api_probe_triggered = false  -- reset when user unchecks
            end
            -- Show last probe summary if available
            if NS.get_api_probe_results then
                local _, summary, ran, failures = NS.get_api_probe_results()
                if ran and summary then
                    local has_failures = failures and #failures > 0
                    menu_elements.header_probe_summary:render("Probe: " .. summary, has_failures and MENU_COLORS.red or MENU_COLORS.green)
                end
            end

            -- DecisionCache stats
            local dc_stats = optimizer and optimizer.DecisionCache and optimizer.DecisionCache:get_stats() or nil
            if dc_stats then
                menu_elements.header_dc_stats:render(format("DecisionCache: gen=%d age=%.2fs", dc_stats.generation, dc_stats.age), MENU_COLORS.green)
            else
                menu_elements.header_dc_not_loaded:render("DecisionCache: not loaded", MENU_COLORS.red)
            end
        end)
    end)
end

-- ============================================================================
-- UPDATE CALLBACK - Main Execution Loop
-- ============================================================================

local function on_update()
    if control_panel_helper and control_panel_helper.on_update then
        control_panel_helper:on_update(menu_elements)
    end

    -- Sync menu-backed settings even when rotation execution is disabled.
    local debug_mode = menu_elements.debug_mode_check and menu_elements.debug_mode_check:get_state() or false
    local verbose_trace = menu_elements.verbose_trace_check and menu_elements.verbose_trace_check:get_state() or false
    local show_debug_log = menu_elements.debug_log_check and menu_elements.debug_log_check:get_state() or false
    sync_quick_toggles()

    if framework_core and framework_core.set_setting then
        framework_core.set_setting("debug_mode", debug_mode)
        framework_core.set_setting("debug_system", verbose_trace)
        framework_core.set_setting("log_context", verbose_trace)

        -- Sync debug log window visibility
        if NS.SetDebugLogVisible and NS.IsDebugLogVisible then
            if NS.IsDebugLogVisible() ~= show_debug_log then
                NS.SetDebugLogVisible(show_debug_log)
            end
        end

        -- [#11] Only sync settings that actually changed since last frame.
        -- Avoids 30-60+ redundant set_setting calls per frame for unchanged checkboxes/sliders.
        for key, widget in pairs(schema_widgets) do
            local value = widget.sync and widget.sync()
            if value ~= nil then
                local last_val = schema_widget_last_values[key]
                if value ~= last_val then
                    schema_widget_last_values[key] = value
                    framework_core.set_setting(key, value)
                    if key == "playstyle" and type(value) == "string" then
                        framework_core.set_setting("active_playstyle", value)
                    end
                end
            end
        end
    end

    -- Check if script is enabled after menu settings are synchronized.
    if framework_core and framework_core.get_setting and framework_core.get_setting("rotation_enabled", true) == false then
        return
    end

    -- Let main_sylvanas own combat/target gating. The old IZI pre-gate could
    -- reject a selected target before the dispatcher evaluated player:get_target().
    local me = framework_core and framework_core.GetPlayer and framework_core.GetPlayer() or nil
    if not me then
        return -- No player unit available
    end
    -- Guard against stale/invalid player objects (loading screens, death, zone transitions)
    local player_valid = pcall(function() return me:is_valid() end)
    if not player_valid then
        return -- Player object is garbage-collected / invalid
    end

    -- DecisionCache invalidation is handled by main_sylvanas.lua:on_rotation_update()
    -- which calls NS.DecisionCache:check_invalidation(context) with FULL context
    -- (enemies, haste buffs, combat time, etc.). The removed duplicate here only
    -- had partial fields. Running twice per frame is redundant AND lower quality.

    -- Auto-run API probe once on first valid frame (player exists + spell book ready)
    if NS.maybe_auto_run_api_probe then
        NS.maybe_auto_run_api_probe()
    end

    -- Execute rotation via framework
    if framework_main and framework_main.on_rotation_update then
        local success, err = pcall(framework_main.on_rotation_update)
        if not success and debug_mode then
            core.log_error("[EaxRotations] Rotation error: " .. tostring(err))
        end
    end
end

-- ============================================================================
-- REGISTER CALLBACKS
-- ============================================================================

core.register_on_update_callback(on_update)
core.register_on_render_menu_callback(render_menu)
core.register_on_render_control_panel_callback(on_control_panel_render)

core.log("[EaxRotations] Framework initialized successfully!")
core.log("[EaxRotations] Class: " .. plugin_info.player_class_name)
core.log("[EaxRotations] APIs: core, izi_sdk (Project Sylvanas native)")
core.log("[EaxRotations] Optimizations: DecisionCache (state tracking)")
