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
    if izi and type(izi.log_error) == "function" then
        izi.log_error("[EaxRotations] Failed to load IZI SDK from common/izi_sdk: " .. tostring(izi))
    elseif type(core) == "table" and type(core.log_error) == "function" then
        core.log_error("[EaxRotations] Failed to load IZI SDK from common/izi_sdk: " .. tostring(izi))
    end
    return
end

-- (early set_setting calls removed)

-- Get plugin info from header
local header_ok, plugin_info = pcall(require, "header")

if not header_ok or not plugin_info or not plugin_info.load then
    if izi and type(izi.log_warning) == "function" then
        izi.log_warning("[EaxRotations] Plugin not loaded - check header.lua: " .. tostring(plugin_info))
    elseif type(core) == "table" and type(core.log_warning) == "function" then
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
    if izi and type(izi.log) == "function" then
        izi.log("[EaxRotations] Plugin loaded (no player class yet at login screen)")
    else
        core.log("[EaxRotations] Plugin loaded (no player class yet at login screen)")
    end
    return
end

-- Startup summary is printed at end of main.lua (consolidated one-line boot message).

-- Load core framework components in dependency order.
-- The runtime only loads header.lua + main.lua; all framework files must be explicitly require()'d here.
local core_ok, framework_core = pcall(require, "core_sylvanas")
if not core_ok or not framework_core then
    if izi and type(izi.log_error) == "function" then
        izi.log_error("[EaxRotations] Failed to load core_sylvanas: " .. tostring(framework_core))
    elseif type(core) == "table" and type(core.log_error) == "function" then
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
    "shared/melee_combat_math_sylvanas",

    -- PvP support
    "shared/arena_priority_sylvanas",
    "shared/pvp_burst_window_sylvanas",

    -- Supremacy modules: attach to NS.* at load; specs already call them via nil-guards.
    -- Must load BEFORE class modules so register_seals / NS.SwingTimer are available
    -- when arms/fury/ret/enh/hunter_adaptive evaluate at require-time.
    "shared/stopcast_sylvanas",
    "shared/pet_heal_sylvanas",
    "shared/snap_threat_sylvanas",
    "shared/stance_manager_sylvanas",
    "shared/swing_diagnostics_sylvanas",
    "shared/swing_timer_sylvanas",
    "shared/dispel_manager_sylvanas",
    "shared/rage_manager_sylvanas",
    "shared/interrupt_manager_sylvanas",

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
    if izi and type(izi.log_warning) == "function" then
        izi.log_warning("[EaxRotations] common_sylvanas.lua failed to load — shared schema sections will not be injected")
    else
        core.log_warning("[EaxRotations] common_sylvanas.lua failed to load — shared schema sections will not be injected")
    end
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

-- Runtime theme override: recolor the centralized menu palette (purple → blue).
-- The runtime v2 theme table is read-only on disk but reachable at load via
-- require("common/menu/theme"); mutating its T.p in place cascades to every
-- widget. Best-effort at load; retried from render_menu() until it sticks.
local _to_ok, ThemeOverride = pcall(require, "shared/theme_override_sylvanas")
if _to_ok and ThemeOverride and ThemeOverride.apply_once then
    pcall(ThemeOverride.apply_once)
end

-- Declarative _G.menu module: provides retained-mode menu with native collapsibility
-- (section:subsection()). Behind a feature flag (eax_use_declarative_menu, default false).
-- When active, replaces the imperative core.menu.* render + sync path.
-- Phase 1: scaffolding only — imperative menu stays active by default.
local _dm_ok, DeclarativeMenu = pcall(require, "shared/declarative_menu_sylvanas")
if not _dm_ok or type(DeclarativeMenu) ~= "table" then DeclarativeMenu = nil end
local _declarative_menu_active = false

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
-- Track duplicate schema key warnings so we only log once per key per init.
local _warned_duplicate_schema_keys = {}
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
    auto_taunt = true,
}

if class_name then
    local ok, result = pcall(require, "classes/" .. class_name .. "/schema_sylvanas")
    if ok then
        class_schema = result
    else
        core.log_warning("[EaxRotations] Schema require failed for " .. class_name .. ": " .. tostring(result))
    end
end

if NS and type(NS.is_sod) == "function" and NS.is_sod() and type(class_schema) == "table" then
    if not class_schema.__eax_sod_settings_added then
        local sod_settings = {
            { key = "sod_phase", type = "slider", label = "SoD Phase", min = 1, max = 8, default = 8 },
        }
        if type(class_schema[1]) == "table" and class_schema[1].sections then
            class_schema[1].sections[#class_schema[1].sections + 1] = {
                header = "Season of Discovery", settings = sod_settings,
            }
        else
            for _, setting in ipairs(sod_settings) do class_schema[#class_schema + 1] = setting end
        end
        class_schema.__eax_sod_settings_added = true
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

-- Sanitise a string into a stable menu-id fragment (lowercase, [a-z0-9_]).
local function _sanitize_id(s)
    s = tostring(s or ""):lower()
    s = s:gsub("%s+", "_")
    s = s:gsub("[^a-z0-9_]", "")
    s = s:gsub("_+", "_")
    s = s:gsub("^_", ""):gsub("_$", "")
    return s
end

-- Safe tree constructor: pass a UNIQUE id so the PS menu's retained backend
-- keeps each tree_node as a distinct collapsible section/page. Without unique
-- ids every sibling tree_node merges into the last one rendered (all widgets
-- dump into it) — which is exactly the "Auto Consumables has everything" bug.
-- pcall-guarded so old PS builds that ignore extra args are unaffected.
local function make_tree(id)
    if id and type(id) == "string" and #id > 0 then
        local ok, tree = pcall(core.menu.tree_node, id)
        if ok and tree then return tree end
    end
    return core.menu.tree_node()
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
        -- Index-based resolve helper: try 1-based first, then 0-based (some PS builds).
        -- Uses explicit nil-check (NOT `or`) because option values can be 0 or false,
        -- which are falsy in Lua and would fall through `or` to the wrong value.
        local function resolve_index(idx, vals)
            local v = vals[idx]
            if v ~= nil then return v end
            return vals[idx + 1]  -- 0-based fallback
        end
        -- Label-based resolve helper: try exact match, then lowercased.
        -- Uses explicit nil-check (NOT `or`) for the same truthiness reason.
        local function resolve_label(label, by_label)
            local v = by_label[tostring(label)]
            if v ~= nil then return v end
            return by_label[tostring(label):lower()]
        end
        widget.sync = function()
            if not widget.control then return nil end
            local ok, raw_value = pcall(function() return widget.control:get() end)
            if ok and type(raw_value) == "number" then
                return resolve_index(raw_value, widget.option_values)
            end
            if ok and raw_value ~= nil then
                return resolve_label(raw_value, widget.option_values_by_label)
            end
            ok, raw_value = pcall(function()
                return widget.control.get_value and widget.control:get_value() or nil
            end)
            if ok and type(raw_value) == "number" then
                return resolve_index(raw_value, widget.option_values)
            end
            if ok and raw_value ~= nil then
                return resolve_label(raw_value, widget.option_values_by_label)
            end
            ok, raw_value = pcall(function()
                return widget.control.get_selected_text and widget.control:get_selected_text() or nil
            end)
            if ok and raw_value ~= nil then
                return resolve_label(raw_value, widget.option_values_by_label)
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
            sections = {},
        }
        -- Theme: scope this tab to a playstyle if its name matches one (e.g. "Bear", "Arcane").
        -- NOTE: no per-tab tree_node here — the flatten fix (PS menu rework) renders
        -- each section directly under "Class Settings" (2-level nesting) so we never
        -- allocate an orphaned tab-level tree widget.
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

            -- [#4] Pre-allocate a collapsible tree_node for each section.
            -- CRITICAL: each section_tree gets a UNIQUE id so the PS retained menu
            -- keeps them as distinct collapsible cards. Sections are rendered at
            -- DEPTH-1 (directly inside main_tree, NOT nested inside settings_tree)
            -- because depth-2 trees merge in the PS menu rework. Depth-1 trees
            -- (like Quick Toggles) are collapsible and don't merge.
            local _sec_id = "eaxrot_" .. _sanitize_id(_class_key or "class") ..
                "_sec_" .. _sanitize_id(normalized_section.header)
            local section_tree = make_tree(_sec_id)
            section_headers[#section_headers + 1] = section_tree
            normalized_section.section_tree = section_tree

            for _, def in ipairs(section.settings or EMPTY_TABLE) do
                -- Honor the menu API's unique-id contract (core.menu.checkbox/
                -- slider_int(..., id) require a unique id). A schema key can
                -- legitimately appear in multiple tabs/sections — e.g. healer
                -- settings shared across the Discipline+Holy priest tabs, or the
                -- hunter Shot Weaving section duplicated into General + every spec
                -- tab. Creating a second control with the same id collides on the
                -- single settings-store key and can crash menu registration.
                -- Reuse the already-created control so the setting still renders
                -- in each section but is backed by one unique widget.
                local existing = def and def.key and schema_widgets[def.key]
                if existing then
                    -- Warn once about the duplicate so schema authors notice accidental collisions.
                    if core and core.log_warning and not _warned_duplicate_schema_keys[def.key] then
                        _warned_duplicate_schema_keys[def.key] = true
                        core.log_warning("[EaxRotations] Duplicate schema key '" .. tostring(def.key) .. "' in " .. tostring(tab.name or "General") .. "/" .. tostring(section.header or "?") .. "; reusing existing control.")
                    end
                    normalized_section.settings[#normalized_section.settings + 1] = existing
                else
                    local widget = create_schema_widget(def)
                    if widget then
                        normalized_section.settings[#normalized_section.settings + 1] = widget
                        schema_widgets[widget.key] = widget
                    end
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

-- Prefer the live combobox widget (quick toggles) for immediate playstyle feedback.
-- Falls back to settings / framework. Used for labels, roles, and to keep UI responsive
-- even if manager cache or get_setting lags after a user selection.
local function get_active_playstyle()
    -- Declarative menu: read playstyle from _G.menu dropdown when active
    if _declarative_menu_active and DeclarativeMenu then
        local ps_idx = DeclarativeMenu.get_widget_value("playstyle")
        if type(ps_idx) == "number" and playstyle_keys[ps_idx] then
            local v = playstyle_keys[ps_idx]
            if type(v) == "string" and v ~= "" then return v end
        end
    end
    if menu_elements and menu_elements.playstyle_combo then
        local ok, idx = pcall(function() return menu_elements.playstyle_combo:get() end)
        if ok and type(idx) == "number" and playstyle_keys[idx] then
            local v = playstyle_keys[idx]
            if type(v) == "string" and v ~= "" then return v end
        end
    end
    if NS and NS.get_setting then
        local v = NS.get_setting("playstyle", nil) or NS.get_setting("active_playstyle", nil)
        if type(v) == "string" and v ~= "" then return v end
    end
    if framework_core and framework_core.get_setting then
        local v = framework_core.get_setting("active_playstyle", nil) or framework_core.get_setting("playstyle", nil)
        if type(v) == "string" and v ~= "" then return v end
    end
    return (class_config and class_config.default_playstyle) or (playstyle_keys and playstyle_keys[1]) or "auto"
end

local menu_elements = {
    main_tree = make_tree("eaxrot_main"),
    quick_toggles_tree = make_tree("eaxrot_quick_toggles"),
    playstyle_combo = core.menu.combobox(get_initial_playstyle_index(), "eaxrotations_active_playstyle_combo"),
    enable_script_check = core.menu.keybind(999, true, "eax_rotation_enabled_keybind"),
    healing_toggle = core.menu.keybind(999, true, "eax_healing_enabled_keybind"),
    damage_toggle = core.menu.keybind(999, true, "eax_damage_enabled_keybind"),
    cooldowns_toggle = core.menu.keybind(999, true, "eax_cooldowns_enabled_keybind"),
    aoe_toggle = core.menu.keybind(999, true, "eax_aoe_enabled_keybind"),
    interrupts_toggle = core.menu.keybind(999, true, "eax_interrupts_enabled_keybind"),
    utility_toggle = core.menu.keybind(999, true, "eax_utility_enabled_keybind"),
    threat_drop_toggle = core.menu.keybind(999, true, "eax_threat_drop_enabled_keybind"),
    taunt_toggle = core.menu.keybind(999, true, "eax_auto_taunt_keybind"),
    settings_tree = make_tree("eaxrot_class_settings"),
    header_class_settings = core.menu.header(),
    diagnostics_tree = make_tree("eaxrot_diagnostics"),
    dump_spells_btn = core.menu.button("eax_dump_spells"),
    debug_swing_timer_chk = core.menu.checkbox(false, "eax_debug_swing_timer"),
    debug_game_events_chk = core.menu.checkbox(false, "eax_debug_game_events"),
    debug_combo_points_chk = core.menu.checkbox(false, "eax_debug_combo_points"),
    -- Theme customization
    theme_tree = make_tree("eaxrot_theme"),
    theme_enabled_chk = core.menu.checkbox(true, "eax_theme_override_enabled"),
    theme_accent_picker = core.menu.color_picker(color.new(80, 180, 160, 255), "eax_theme_accent_color"),
    -- [#4] Pre-allocated header widgets — created ONCE, not every render frame.
    -- core.menu.header() returns a new widget each call; creating inside render_menu()
    -- leaked instances every frame. Now stored and reused.
    header_class_info = core.menu.header(),
    header_active_playstyle = core.menu.header(),

}

-- Declarative _G.menu initialization: build the page/section/subsection tree when
-- _G.menu is available and the feature flag (eax_use_declarative_menu) is enabled.
-- Phase 1: default OFF — imperative menu stays active. Enable via
-- NS.set_setting("eax_use_declarative_menu", true) then /reload.
if DeclarativeMenu and DeclarativeMenu.is_available and DeclarativeMenu.is_available() then
    local _dm_flag = framework_core and framework_core.get_setting and
        framework_core.get_setting("eax_use_declarative_menu", false) or false
    if _dm_flag then
        local _init_ok, _init_result = pcall(DeclarativeMenu.initialize, DeclarativeMenu,
            class_schema, class_config, MenuTheme, playstyle_keys, playstyle_options,
            QUICK_TOGGLE_SETTING_KEYS, get_active_playstyle)
        if _init_ok and _init_result then
            _declarative_menu_active = true
            core.log("[EaxRotations] Declarative _G.menu initialized (feature flag ON)")
        else
            core.log_warning("[EaxRotations] Declarative _G.menu init failed: " .. tostring(_init_result))
        end
    end
end

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
        capability = "damage",
    },
    {
        key = "use_cooldowns",
        label = "Cooldowns",
        tooltip = "Allow major cooldowns and burst actions.",
        control = menu_elements.cooldowns_toggle,
        default = true,
        capability = "cooldowns",
    },
    {
        key = "aoe_enabled",
        label = "AoE",
        tooltip = "Allow AoE actions that require multiple enemies.",
        control = menu_elements.aoe_toggle,
        default = true,
        capability = "aoe",
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
        capability = "utility",
    },
    {
        key = "use_threat_drop",
        label = "Threat Drops",
        tooltip = "Allow threat-drop abilities when group threat data says they are needed.",
        control = menu_elements.threat_drop_toggle,
        default = true,
        capability = "threat_drop",
    },
    {
        key = "auto_taunt",
        label = "Auto Taunt",
        tooltip = "Allow automatic taunt usage (Taunt/Growl/Righteous Defense). Disable to save taunt for manual pulls.",
        control = menu_elements.taunt_toggle,
        default = true,
        capability = "auto_taunt",
    },
}

local function get_keybind_toggle_state(control, default)
    if not control then return default end
    -- Read the widget's actual toggle state first. The user may have clicked
    -- the UI toggle while leaving the keybind on default (999/unbound).
    local ok, value = pcall(function() return control:get_toggle_state() end)
    if ok and type(value) == "boolean" then return value end
    -- get_toggle_state() returned non-boolean or threw.
    -- CRITICAL: for keybind widgets, get_state() returns KEY PRESS STATE
    -- (is the key currently held?), NOT toggle state.
    -- For no-bind (7/999), force our default.
    local key_ok, key_code = pcall(function() return control:get_key_code() end)
    if key_ok and (key_code == 7 or key_code == 999) then
        return default
    end
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
    if not key_code or key_code == 0 or key_code == 7 or key_code == 999 then
        return "Unbound"
    end
    if key_helper and key_helper.get_key_name then
        local name_ok, name = pcall(function() return key_helper:get_key_name(key_code) end)
        if name_ok and name then return tostring(name) end
    end
    return tostring(key_code)
end

local function sync_quick_toggles()
    -- set_setting removed; no writes for these toggles
end

local _last_playstyle_combo_index = nil

local function sync_playstyle_control()
    if not menu_elements.playstyle_combo then return end
    local ok, combo_index = pcall(function() return menu_elements.playstyle_combo:get() end)
    if not ok or type(combo_index) ~= "number" then return end

    local value = playstyle_keys[combo_index]
    if type(value) ~= "string" or value == "" then return end

    -- Track last seen index ONLY to detect real user changes for logging.
    -- Do NOT read settings here and do NOT call :set() on the widget.
    -- Widget state (from the menu combobox with ID) + per-frame injection from get()
    -- is the single source of truth. Previous back-sync caused jitter/revert on click
    -- because get_setting cache (200ms TTL or manager) could be stale vs the just-changed widget.
    local is_first = (_last_playstyle_combo_index == nil)
    local changed = (not is_first and combo_index ~= _last_playstyle_combo_index)
    if is_first or changed then
        if _last_playstyle_log ~= value then
            _last_playstyle_log = value
            core.log("[EaxRotations] Active playstyle: " .. tostring(value))
        end
        _last_playstyle_combo_index = combo_index
    end
end

local function render_quick_toggles()
    menu_elements.quick_toggles_tree:render("Quick Toggles", function()
        if menu_elements.playstyle_combo and #playstyle_options > 0 then
            menu_elements.playstyle_combo:render("Playstyle", playstyle_options, "Select active " .. (class_config and class_config.class_name or "class") .. " rotation.")
        end

        -- Theme: hide toggles that don't apply to the active playstyle's role.
        -- Mirrors the role-based filtering already used by on_control_panel_render()
        -- so e.g. Cat (dps) never sees Healing or Auto Taunt, Resto (healer) never
        -- sees Threat Drops/Interrupts/Auto Taunt, Bear (tank) never sees Healing.
        -- Leveling (hybrid) keeps everything since the spec may shift mid-run.
        local _caps = nil
        if MenuTheme and _class_key then
            local _active = get_active_playstyle()
            local _role = MenuTheme.role_for_playstyle(_class_key, _active)
            _caps = MenuTheme.capabilities(_role)
        end
        for _, def in ipairs(quick_toggle_defs) do
            -- Role-based visibility: skip toggles that don't make sense for this role.
            -- Same _skip pattern used by on_control_panel_render() so the main menu
            -- and Control Panel stay in sync on which toggles appear per playstyle.
            local _skip = false
            if _caps then
                local cap_key = def.capability or def.key
                if _caps[cap_key] == false then _skip = true end
            end
            if not _skip then
                def.control:render(def.label, def.tooltip)
            end
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
        local _active = get_active_playstyle()
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
        local active_playstyle = get_active_playstyle()

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

        -- [#5] Class Settings — rendered as a header label followed by
        -- collapsible section trees at DEPTH-1 (directly inside main_tree, NOT
        -- nested inside a settings_tree wrapper). Depth-2 trees merge in the PS
        -- menu rework (the "Auto Consumables has everything" bug), but depth-1
        -- trees are collapsible and don't merge — Quick Toggles proves this.
        -- The "Class Settings" label provides visual grouping without an extra
        -- nesting level that would break widget scoping.
        menu_elements.header_class_settings:render("Class Settings", MENU_COLORS.yellow)

        -- Active playstyle label (colored by playstyle signature color)
        local _ps_header_color = MENU_COLORS.white
        if MenuTheme and _class_key then
            local _c = MenuTheme.playstyle_color(_class_key, active_playstyle)
            if _c then _ps_header_color = _c end
        end
        menu_elements.header_active_playstyle:render("Active Playstyle: " .. tostring(active_playstyle), _ps_header_color)

        -- Each schema section is its own collapsible tree at depth-1.
        for _, tab in ipairs(schema_tabs) do
            -- Theme: skip tabs scoped to a different playstyle.
            local _tab_visible = true
            if MenuTheme and tab.playscope then
                _tab_visible = MenuTheme.scope_admits({tab.playscope}, active_playstyle)
            end
            if _tab_visible then
                for _, section in ipairs(tab.sections) do
                    -- Theme: skip sections scoped to a different playstyle.
                    local _sec_visible = true
                    if MenuTheme and section.playscope then
                        _sec_visible = MenuTheme.scope_admits(section.playscope, active_playstyle)
                    end
                    if _sec_visible and #section.settings > 0 then
                        section.section_tree:render(section.header_label or section.header, function()
                            for _, widget in ipairs(section.settings) do
                                if widget and widget.render then
                                    widget.render()
                                end
                            end
                        end)
                    end
                end
            end
        end

        -- [Theme] Accent color picker for the menu theme override
        menu_elements.theme_tree:render("Theme", function()
            menu_elements.theme_enabled_chk:render("Enable Theme Override", "Recolor the EaxRotations menu section with your chosen accent")
            menu_elements.theme_accent_picker:render("Accent Color", "Pick the accent color for the EaxRotations menu")
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
            if menu_elements.debug_combo_points_chk then
                menu_elements.debug_combo_points_chk:render("Debug Combo Points", "Log combo point reads, resolved power-type enums, and min_combo gate rejections")
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
        if menu_elements.debug_combo_points_chk then
            local ok, cp = pcall(function() return menu_elements.debug_combo_points_chk:get_state() end)
            NS._DEBUG_COMBO_POINTS = ok and cp == true
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

    -- Resolve quick toggle states from widgets (injected to settings for gating).
    -- states injected from widgets (no set_setting writes)
    local healing_enabled = get_keybind_toggle_state(menu_elements.healing_toggle, true)
    local damage_enabled = get_keybind_toggle_state(menu_elements.damage_toggle, true)
    local cooldowns_enabled = get_keybind_toggle_state(menu_elements.cooldowns_toggle, true)
    local aoe_enabled = get_keybind_toggle_state(menu_elements.aoe_toggle, true)
    local interrupts_enabled = get_keybind_toggle_state(menu_elements.interrupts_toggle, true)
    local utility_enabled = get_keybind_toggle_state(menu_elements.utility_toggle, true)
    local threat_drop_enabled = get_keybind_toggle_state(menu_elements.threat_drop_toggle, true)
    local auto_taunt_enabled = get_keybind_toggle_state(menu_elements.taunt_toggle, true)

    local st = NS.settings or {}
    st.rotation_enabled = rotation_enabled
    st.healing_enabled = healing_enabled
    st.damage_enabled = damage_enabled
    st.use_cooldowns = cooldowns_enabled
    st.aoe_enabled = aoe_enabled
    st.use_interrupt = interrupts_enabled
    st.utility_enabled = utility_enabled
    st.use_threat_drop = threat_drop_enabled
    st.auto_taunt = auto_taunt_enabled

    -- Playstyle is driven by the Quick Toggles combobox. Inject so that:
    -- * context.settings.playstyle is visible to spec_kit.setting / NS.setting
    -- * dispatcher fallbacks see it when we check context first
    -- Widget state is always the source of truth; this makes changes take effect immediately.
    if menu_elements.playstyle_combo then
        local okp, pidx = pcall(function() return menu_elements.playstyle_combo:get() end)
        if okp and type(pidx) == "number" then
            local pval = playstyle_keys[pidx]
            if type(pval) == "string" and pval ~= "" then
                st.playstyle = pval
                st.active_playstyle = pval
            end
        end
        -- Force settings cache refresh so any fallback get_setting() calls see the
        -- fresh widget value immediately (avoids 200ms TTL staleness that previously
        -- caused back-sync jitter).
        if NS and NS.refresh_settings_cache then
            pcall(NS.refresh_settings_cache)
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

    -- Schema widget sync: read each schema checkbox/slider/dropdown value from
    -- its menu widget and inject into NS.settings so spec_kit.setting_bool /
    -- NS.get_setting see the live user-selected value. Without this, schema
    -- checkboxes like cat_auto_prowl are purely cosmetic — the setting always
    -- returns its default because the widget value never reaches NS.settings.
    -- Skip when declarative menu is active (declarative sync below handles it).
    if not _declarative_menu_active then
        for key, widget in pairs(schema_widgets) do
            if widget and widget.sync then
                local ok, value = pcall(widget.sync)
                if ok and value ~= nil then
                    st[key] = value
                end
            end
        end
    end

    -- Declarative menu sync: when active, read all widget values via menu:get
    -- and write to NS.settings. Replaces the imperative sync loop above.
    if _declarative_menu_active and DeclarativeMenu then
        pcall(DeclarativeMenu.sync_to_settings, DeclarativeMenu, st, playstyle_keys)
        if NS and NS.refresh_settings_cache then
            pcall(NS.refresh_settings_cache)
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
-- Declarative menu: skip imperative render + control panel callbacks when active.
-- The declarative _G.menu renders itself (retained mode); control panel migration
-- is Phase 3 (menu.control_panel.add). The imperative menu stays active by default.
if not _declarative_menu_active then
    if type(core.register_on_render_menu_callback) == "function" then
        pcall(core.register_on_render_menu_callback, render_menu)
    end
    if type(core.register_on_render_control_panel_callback) == "function" then
        pcall(core.register_on_render_control_panel_callback, on_control_panel_render)
    end
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

-- Theme override: continuous global mutation gated by toggle checkbox.
-- Must run every frame because PS resets palette per frame.
if ThemeOverride and ThemeOverride.apply_continuous then
    if type(core.register_on_render_callback) == "function" then
        local _was_active = true  -- track toggle state for restore
        core.register_on_render_callback(function()
            -- Check toggle: get_state() returns boolean for checkboxes
            local chk_ok, chk_val = pcall(function() return menu_elements.theme_enabled_chk:get_state() end)
            if chk_ok and chk_val == false then
                -- One-shot restore on transition from active → inactive
                if _was_active and ThemeOverride.restore_palette then
                    ThemeOverride.restore_palette()
                end
                _was_active = false
                return
            end
            _was_active = true

            -- Read accent from color picker
            if ThemeOverride.set_accent and menu_elements.theme_accent_picker then
                local ok, col = pcall(menu_elements.theme_accent_picker.get, menu_elements.theme_accent_picker)
                if ok and col then
                    local r, g, b
                    -- color object (table with :get() method)
                    if type(col) == "table" and type(col.get) == "function" then
                        local gok, cr, cg, cb = pcall(col.get, col)
                        if gok and type(cr) == "number" then r, g, b = cr, cg, cb end
                    -- userdata color object (C++-backed)
                    elseif type(col) == "userdata" then
                        local gok, cr, cg, cb = pcall(function() return col:get() end)
                        if gok and type(cr) == "number" then r, g, b = cr, cg, cb end
                    -- plain table fallback
                    elseif type(col) == "table" then
                        r = col[1] or col.r
                        g = col[2] or col.g
                        b = col[3] or col.b
                    end
                    if r and g and b then
                        ThemeOverride.set_accent(r, g, b)
                    end
                end
            end

            ThemeOverride.apply_continuous()
        end)
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
