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

-- Schema duplicate detection: shared comparator used by initialize_schema_menu
-- below and by test_schema_duplicate_widget_ids (single source of truth).
local _ok_compat, schema_compat = pcall(require, "shared/schema_def_compat_sylvanas")
local schema_def_conflict = (_ok_compat and schema_compat and schema_compat.incompatibility) or nil

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

-- Control Panel (permashow) subsystem: ONE module owns every piece of the
-- always-on-screen quick-toggle panel — path decision, row set, reconcile,
-- mirror seeding, logs, reset action (shared/control_panel_sylvanas.lua).
-- main.lua stays the composition root: it owns the widgets + quick_toggle_defs
-- (the "what") and hands them to ControlPanel.register(env) at load, before
-- the shared dispatcher registration below.
local _cp_ok, ControlPanel = pcall(require, "shared/control_panel_sylvanas")
if not _cp_ok or type(ControlPanel) ~= "table" then
    core.log_error("[EaxRotations] Failed to load shared/control_panel_sylvanas: " .. tostring(ControlPanel))
    ControlPanel = nil
end

-- Pre-allocated empty table for 'or {}' fallbacks (avoids GC pressure from repeated table creation)
local EMPTY_TABLE = {}

local class_config = NS and NS.rotation_registry and NS.rotation_registry.class_config or nil
local class_schema = nil
local playstyle_options = {}
local playstyle_keys = {}
-- Theme lookups derived from class_config playstyles. Declared here (before
-- refresh_playstyle_state below) because the class module may load late via the
-- on_update retry path, at which point these must be REBUILT, not re-declared.
local _class_key
local _ps_keyset, _ps_n2k
local schema_tabs = {}
local schema_widgets = {}
-- First definition seen per schema key (kept so a later re-declaration can be
-- checked for conflicts before warning — see initialize_schema_menu).
local schema_widget_defs = {}
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
        if NS.common_spell_damage_section then
            table.insert(class_schema[1].sections, NS.common_spell_damage_section())
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
        local spell_damage_section = NS.common_spell_damage_section and NS.common_spell_damage_section()
        if spell_damage_section and spell_damage_section.settings then
            for _, setting in ipairs(spell_damage_section.settings) do
                table.insert(class_schema, setting)
            end
        end
    end
end

-- Playstyle option list + theme lookups derive from class_config, which is nil
-- at boot whenever the class module has not loaded yet (login screen deferral /
-- transient class-module failure handled by the on_update retry). Centralized so
-- the retry can rebuild all of it. Without the rebuild, the playstyle dropdown
-- stays empty and the Control Panel keeps its boot-time rows after a late load.
local function refresh_playstyle_state()
    local next_keys, next_options = {}, {}
    if class_config and type(class_config.playstyles) == "table" then
        for _, playstyle in ipairs(class_config.playstyles) do
            local key = type(playstyle) == "table" and playstyle.name or tostring(playstyle)
            local label = type(playstyle) == "table" and (playstyle.display_name or playstyle.name) or tostring(playstyle)
            if key and label then
                table.insert(next_keys, key)
                table.insert(next_options, label)
            end
        end
    end
    playstyle_keys = next_keys
    playstyle_options = next_options
    _class_key = class_config and class_config.class_key or class_name
    if MenuTheme and #playstyle_keys > 0 then
        _ps_keyset, _ps_n2k = MenuTheme.build_playstyle_lookup(playstyle_keys, playstyle_options)
    else
        _ps_keyset, _ps_n2k = nil, nil
    end
end

refresh_playstyle_state()

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
                    -- An IDENTICAL re-declaration across tabs/sections is the
                    -- sanctioned shared-setting pattern (e.g. healer Smart
                    -- Casting on priest Discipline+Holy, hunter Shot Weaving on
                    -- every spec tab): reuse silently. Only a CONFLICTING
                    -- re-declaration (different type/bounds/default/options) is
                    -- an accidental collision worth warning about, so boots stay
                    -- warning-free for the shared healer sections.
                    local conflict = (schema_def_conflict and schema_widget_defs[def.key]
                        and schema_def_conflict(schema_widget_defs[def.key], def)) or nil
                    if conflict and core and core.log_warning and not _warned_duplicate_schema_keys[def.key] then
                        _warned_duplicate_schema_keys[def.key] = true
                        core.log_warning("[EaxRotations] Conflicting duplicate schema key '" .. tostring(def.key) .. "' in " .. tostring(tab.name or "General") .. "/" .. tostring(section.header or "?") .. " (" .. tostring(conflict) .. "); reusing existing control.")
                    end
                    normalized_section.settings[#normalized_section.settings + 1] = existing
                else
                    local widget = create_schema_widget(def)
                    if widget then
                        normalized_section.settings[#normalized_section.settings + 1] = widget
                        schema_widgets[widget.key] = widget
                        schema_widget_defs[def.key] = def
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

-- menu_elements is created below this function (the literal is assigned after
-- the schema widgets), so it MUST be forward-declared here. Without the
-- declaration, the reference inside get_active_playstyle binds to a GLOBAL
-- named menu_elements (Lua lexical scoping), the live-combobox branch below
-- silently never runs, and playstyle/role reads lag one tick behind the user
-- via the settings fallback — which breaks instant role filtering of the menu
-- Quick Toggles and the Control Panel reconcile.
local menu_elements

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

menu_elements = {
    main_tree = make_tree("eaxrot_main"),
    quick_toggles_tree = make_tree("eaxrot_quick_toggles"),
    playstyle_combo = core.menu.combobox(get_initial_playstyle_index(), "eaxrotations_active_playstyle_combo"),
    -- Quick toggles are keybind widgets (their toggle state persists across
    -- reloads) shown in the perma-show / Control Panel. They default to key code
    -- 7, the engine's "no key / Unbinded" sentinel — the engine only renders a
    -- guaranteed always-on-screen row for a bound key, so unbound toggles rely on
    -- the module's mirror-seeding path (control_panel_sylvanas) to stay visible.
    -- A real-key default was attempted with guessed VK codes (F5-F12/NumPad0) and
    -- crashed the client at load because the engine's key-code numbering was never
    -- validated — reverted to the sentinel until a validated code table exists.
    -- is_unbound_key keeps 0/7/999 for this state.
    --
    -- Permashow clarity: the keybind's native label (the second arg) is what the
    -- engine uses for the key pill. We keep that label as the plain toggle name so
    -- the pill can show "Unbound" without the row implying the pill is a hotkey that
    -- fires the rotation. The human-readable row label (def.control_label) is separate
    -- and says "click to toggle" — identical wording is wired into the declarative
    -- host (shared/declarative_menu_sylvanas.lua) so neither menu host still reads as
    -- a hotkey row.
    enable_script_check = core.menu.keybind(7, true, "eax_rotation_enabled_keybind"),
    healing_toggle = core.menu.keybind(7, true, "eax_healing_enabled_keybind"),
    damage_toggle = core.menu.keybind(7, true, "eax_damage_enabled_keybind"),
    cooldowns_toggle = core.menu.keybind(7, true, "eax_cooldowns_enabled_keybind"),
    aoe_toggle = core.menu.keybind(7, true, "eax_aoe_enabled_keybind"),
    interrupts_toggle = core.menu.keybind(7, true, "eax_interrupts_enabled_keybind"),
    utility_toggle = core.menu.keybind(7, true, "eax_utility_enabled_keybind"),
    threat_drop_toggle = core.menu.keybind(7, true, "eax_threat_drop_enabled_keybind"),
    taunt_toggle = core.menu.keybind(7, true, "eax_auto_taunt_keybind"),
    settings_tree = make_tree("eaxrot_class_settings"),
    header_class_settings = core.menu.header(),
    diagnostics_tree = make_tree("eaxrot_diagnostics"),
    dump_spells_btn = core.menu.button("eax_dump_spells"),
    reset_permashow_btn = core.menu.button("eax_reset_permashow"),
    debug_swing_timer_chk = core.menu.checkbox(false, "eax_debug_swing_timer"),
    debug_game_events_chk = core.menu.checkbox(false, "eax_debug_game_events"),
    debug_combo_points_chk = core.menu.checkbox(false, "eax_debug_combo_points"),

    -- [#P1/3] In-game "why" trace: toggle + action buttons + live readout header.
    trace_casts_chk = core.menu.checkbox(false, "eax_debug_trace_casts"),
    trace_print_btn = core.menu.button("eax_trace_print_casts"),
    trace_clear_btn = core.menu.button("eax_trace_clear_casts"),
    trace_readout = core.menu.header(),
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
            -- Permashow recovery must exist on the retained menu too; the button
            -- lands in Diagnostics once the page is built.
            if DeclarativeMenu.add_diagnostics_button and ControlPanel then
                pcall(DeclarativeMenu.add_diagnostics_button, DeclarativeMenu,
                    "eax_reset_permashow", "Reset Permashow Window", function()
                        if ControlPanel then ControlPanel.reset_permashow() end
                    end)
            end
        else
            core.log_warning("[EaxRotations] Declarative _G.menu init failed: " .. tostring(_init_result))
        end
    end
end

-- section_headers is declared above (before initialize_schema_menu() call)

local quick_toggle_defs = {
    -- Permashow clarity: the keybind widget's own `label` is what the engine uses
    -- for the key pill, so we keep it as the plain toggle name ("Rotation", ...) so
    -- the pill can render "Unbound" without the row implying the pill is a hotkey that
    -- fires the rotation. The human-readable row label lives in `control_label` and is
    -- the same wording the declarative host renders (shared/declarative_menu_sylvanas.lua),
    -- so neither menu host reads as a hotkey row. The pill itself is NOT changed.
    {
        key = "rotation_enabled",
        label = "Rotation",
        tooltip = "Master switch for all rotation execution.",
        control = menu_elements.enable_script_check,
        default = true,
        control_label = "Rotation (click to toggle)",
    },
    {
        key = "healing_enabled",
        label = "Healing",
        tooltip = "Allow healing and shielding actions.",
        control = menu_elements.healing_toggle,
        default = true,
        capability = "healing",
        control_label = "Healing (click to toggle)",
    },
    {
        key = "damage_enabled",
        label = "Damage",
        tooltip = "Allow offensive rotation actions.",
        control = menu_elements.damage_toggle,
        default = true,
        capability = "damage",
        control_label = "Damage (click to toggle)",
    },
    {
        key = "use_cooldowns",
        label = "Cooldowns",
        tooltip = "Allow major cooldowns and burst actions.",
        control = menu_elements.cooldowns_toggle,
        default = true,
        capability = "cooldowns",
        control_label = "Cooldowns (click to toggle)",
    },
    {
        key = "aoe_enabled",
        label = "AoE",
        tooltip = "Allow AoE actions that require multiple enemies.",
        control = menu_elements.aoe_toggle,
        default = true,
        capability = "aoe",
        control_label = "AoE (click to toggle)",
    },
    {
        key = "use_interrupt",
        label = "Interrupts",
        tooltip = "Allow interrupt logic where the class supports it.",
        control = menu_elements.interrupts_toggle,
        default = true,
        capability = "interrupts",
        control_label = "Interrupts (click to toggle)",
    },
    {
        key = "utility_enabled",
        label = "Utility",
        tooltip = "Allow utility middleware such as forms, shouts, dispels, and threat tools.",
        control = menu_elements.utility_toggle,
        default = true,
        capability = "utility",
        control_label = "Utility (click to toggle)",
    },
    {
        key = "use_threat_drop",
        label = "Threat Drops",
        tooltip = "Allow threat-drop abilities when group threat data says they are needed.",
        control = menu_elements.threat_drop_toggle,
        default = true,
        capability = "threat_drop",
        control_label = "Threat Drops (click to toggle)",
    },
    {
        key = "auto_taunt",
        label = "Auto Taunt",
        tooltip = "Allow automatic taunt usage (Taunt/Growl/Righteous Defense). Disable to save taunt for manual pulls.",
        control = menu_elements.taunt_toggle,
        default = true,
        capability = "auto_taunt",
        control_label = "Auto Taunt (click to toggle)",
    },
}


local function get_keybind_toggle_state(control, default)
    if not control then return default end
    -- Read the widget's actual toggle state first. The user may have clicked
    -- the UI toggle while leaving the keybind unbound (7 default; 999 kept as
    -- a legacy sentinel from older EaxRotations builds).
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

-- quick_toggle_by_key maps each quick-toggle setting key to its def so the
-- per-tick gates resolve through read_quick_toggle without scanning the list.
local quick_toggle_by_key = {}
for _, _def in ipairs(quick_toggle_defs) do
    quick_toggle_by_key[_def.key] = _def
end

-- Read one quick-toggle gate. Single source per menu mode:
--  * Imperative: the live widget (keybind toggle state persists across
--    reloads while framework_core settings are ephemeral).
--  * Declarative: the retained _G.menu is the only surface, and its toggles
--    reach NS.settings via sync_to_settings at the end of each tick — read
--    the synced setting, defaulting to the def's default when no sync has
--    landed yet (first ticks of a session). Reading the never-rendered
--    imperative widgets here would report the def's default forever, so the
--    st injection below would clobber the synced value until sync_to_settings
--    rewrote it — an ordering dependency that silently pinned toggles on if
--    the sync were ever removed or renamed.
local function read_quick_toggle(def)
    if not def then return true end
    local default = def.default ~= false
    if _declarative_menu_active then
        local st = NS and NS.settings
        local v = st and st[def.key]
        if v == nil then return default end
        return v == true
    end
    return get_keybind_toggle_state(def.control, default)
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

        -- Role-based visibility: hide toggles that don't apply to the active
        -- playstyle's role (Cat dps never sees Healing/Auto Taunt, Resto never
        -- sees Interrupts/Threat Drops/Auto Taunt, leveling hybrid sees all).
        -- Single policy via MenuTheme.def_allowed — the same predicate the
        -- Control Panel subsystem uses, so menu and panel never disagree.
        local _quick_role = nil
        if MenuTheme and _class_key then
            _quick_role = MenuTheme.role_for_playstyle(_class_key, get_active_playstyle())
        end
        for _, def in ipairs(quick_toggle_defs) do
            if not MenuTheme or MenuTheme.def_allowed(def, _quick_role) then
                -- The keybind widget's own label (second arg) is the plain toggle
                -- name; the human-readable row label (control_label) is what the
                -- perma-show/Control Panel rows carry. Keep them in sync with the
                -- declarative host so neither menu host reads as a hotkey row.
                def.control:render(def.control_label or def.label, def.tooltip)
            end
        end
    end)
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
            -- Permashow / EaxFishing / EaxTheme are expected to be part of the
            -- newest .api update. If your .api is newer, you should already see a
            -- Permashow control. This button is a recovery path for older .api builds
            -- or a hidden panel; confirm with EaxRotations → Diagnostics.
            -- (permashow) window in one click. Action owned by the Control Panel
            -- module (it probes the v2 menu.permashow API and logs the result).
            if menu_elements.reset_permashow_btn:render("Reset Permashow Window", "Restores the always-on-screen Control Panel (permashow) to its default position and makes it visible again if it was hidden") then
                if ControlPanel then
                    ControlPanel.reset_permashow()
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

            -- [#P1/3] In-game "why" trace: while enabled, every executed
            -- rotation cast records the rule that fired + the live state
            -- behind it (bounded to the last 32). Readout updates while
            -- this tree is open; Print writes the history to the log.
            if menu_elements.trace_casts_chk then
                menu_elements.trace_casts_chk:render("Trace Casts", "Record why each rotation cast fired (last 32) so you can inspect the decision behind a spell")
            end
            if menu_elements.trace_print_btn:render("Print Last Casts", "Write the last recorded casts with their state to the log") then
                if NS and NS.CastTrace then NS.CastTrace.print_recent(8) end
            end
            if menu_elements.trace_clear_btn:render("Clear Trace", "Empty the recorded cast history") then
                if NS and NS.CastTrace then NS.CastTrace.clear() end
            end
            if NS and NS.CastTrace then
                local _trace_lines = NS.CastTrace.lines(4)
                if #_trace_lines > 0 then
                    menu_elements.trace_readout:render("Last Casts", table.concat(_trace_lines, "  |  "), MENU_COLORS.yellow)
                else
                    menu_elements.trace_readout:render("Last Casts", "(none recorded - enable Trace Casts and enter combat)")
                end
            end
        end)
    end)

end

-- Control Panel (permashow) registration. One owner
-- (shared/control_panel_sylvanas): it decides v2 vs legacy, seeds the native
-- mirrors, registers its own legacy callback, and logs the chosen path.
-- Callable at boot AND again after a deferred class-module load (on_update
-- retry), when playstyle options/roles finally exist. The module's register()
-- is idempotent: it tears down prior v2 rows and registers the engine callback
-- only once per session.
-- Under the declarative _G.menu, the quick toggles a user sees are retained
-- keybinds owned by shared/declarative_menu_sylvanas (captured at page build).
-- The permashow must toggle THOSE widgets — not the imperative ones that are
-- never rendered — so build the def list from the declarative controls when
-- active, falling back to the imperative widgets otherwise. Role capabilities
-- come from the same quick_toggle_defs so both menus filter identically.
local function control_panel_quick_defs()
    if not (_declarative_menu_active and DeclarativeMenu and DeclarativeMenu.control_panel_defs) then
        return quick_toggle_defs
    end
    local dctl = DeclarativeMenu.control_panel_defs()
    if not dctl then return quick_toggle_defs end        local merged = {}
    for _, def in ipairs(quick_toggle_defs) do
        local control = dctl[def.key] or def.control
        merged[#merged + 1] = {
            key = def.key, label = def.label, tooltip = def.tooltip,
            control = control, capability = def.capability, default = def.default,
            control_label = def.control_label or def.label,
        }
    end
    return merged
end

local function register_control_panel_ui()
    if not ControlPanel then return end
    local cp_defs = control_panel_quick_defs()
    local ps_combo = menu_elements.playstyle_combo
    if _declarative_menu_active and DeclarativeMenu and DeclarativeMenu.playstyle_control then
        local psc = DeclarativeMenu.playstyle_control()
        if psc then ps_combo = psc end
    end
    ControlPanel.register({
        core = core,
        framework_core = framework_core,
        runtime_generation = runtime_generation,
        MenuTheme = MenuTheme,
        class_key = _class_key,
        active_playstyle = get_active_playstyle,
        quick_toggle_defs = cp_defs,
        playstyle_combo = ps_combo,
        playstyle_options = playstyle_options,
        -- schema_widgets is rebuilt by initialize_schema_menu() on late
        -- class load, so hand the module a getter, not a captured table.
        schema_widgets = function() return schema_widgets end,
    })
end

-- ============================================================================
-- UPDATE CALLBACK - Main Execution Loop
-- ============================================================================

local _on_update_tick_count = 0
local _last_tick_log_s = 0
local _on_update_first_print = false
local _on_update_throttle_ms = 0
local ON_UPDATE_INTERVAL_MS = 50

-- Read a Diagnostics debug-toggle from the active menu. Declarative mode: the
-- checkbox lives in the retained page and reaches NS.settings via
-- sync_to_settings (the imperative widget is never rendered there); read the
-- synced setting. Imperative mode: read the live widget. Hoisted OUT of
-- on_update — a per-tick local closure here would allocate every 20Hz tick.
local function read_debug_flag(setting_key, widget)
    if _declarative_menu_active then
        local st = NS and NS.settings
        return (st and st[setting_key]) == true
    end
    if not widget then return false end
    local ok, val = pcall(function() return widget:get_state() end)
    return ok and val == true
end

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
                -- The class module just populated NS.rotation_registry, so the
                -- class_config/playstyle state built from an empty registry at
                -- boot must be refreshed BEFORE the schema menu rebuild (section
                -- playscope rules key off _class_key) and the Control Panel
                -- re-registration (rows were computed with no playstyle known).
                class_config = NS and NS.rotation_registry and NS.rotation_registry.class_config or nil
                refresh_playstyle_state()
                initialize_schema_menu()
                -- Control Panel rows are recomputed against the now-known
                -- playstyle/role state on BOTH menu modes. The retained page
                -- itself cannot gain a playstyle dropdown after being built, so
                -- declarative users get an honest /reload hint instead of a
                -- silently empty dropdown.
                register_control_panel_ui()
                if _declarative_menu_active then
                    core.log_warning("[EaxRotations] Class module loaded after the declarative menu was built — /reload to populate the playstyle selector")
                end
            else
                -- Retry still pending; intentionally silent.
            end
        end
    end

    -- We're now inside the shared ~20Hz dispatcher (see header comment).
    -- The cheap runtime_generation + is_alive + is_ghost guards above run at 20Hz.
    -- Everything below (widget sync, build_context, dispatch) runs at 20Hz.

    -- Sync debug toggles from diagnostics menu checkboxes (see read_debug_flag
    -- above — reads the retained-page setting in declarative mode, the live
    -- checkbox otherwise).
    if NS then
        NS._DEBUG_SWING_TIMER = read_debug_flag("eax_debug_swing_timer", menu_elements.debug_swing_timer_chk)
        NS._DEBUG_GAME_EVENTS = read_debug_flag("eax_debug_game_events", menu_elements.debug_game_events_chk)
        NS._DEBUG_COMBO_POINTS = read_debug_flag("eax_debug_combo_points", menu_elements.debug_combo_points_chk)

        NS._TRACE_CASTS = read_debug_flag("eax_debug_trace_casts", menu_elements.trace_casts_chk)
    end

    -- Keep Control Panel rows in sync when the active playstyle's role changes.
    -- Delegated: the Control Panel module owns the row set + mode and no-ops
    -- cheaply unless it is on the v2 path AND the role actually changed.
    if ControlPanel then
        ControlPanel.reconcile()
    end

    -- [#P1] Resolve the quick-toggle gates BEFORE the expensive widget sync
    -- loop. CRITICAL: framework_core settings are ephemeral (lost on reload);
    -- keybind widget state IS persisted by Sylvanas, so the imperative path
    -- reads the live widgets (see read_quick_toggle). Declarative mode: every
    -- toggle the user flips lives in the retained _G.menu and reaches
    -- NS.settings via sync_to_settings at the end of each tick, while the
    -- imperative widgets are never rendered — so the gates read the synced
    -- settings exactly like the master toggle. The st injection below and the
    -- later declarative sync therefore write the same value (no clobbering).
    local rotation_enabled = read_quick_toggle(quick_toggle_by_key.rotation_enabled)
    if _last_enabled_log ~= rotation_enabled then
        _last_enabled_log = rotation_enabled
        if not rotation_enabled then
            core.log("[EaxRotations] Rotation disabled by quick toggle")
        end
    end

    -- Inject the resolved gate states into settings for rotation gating (no
    -- set_setting writes; declarative sync_to_settings re-writes the same
    -- values later in this tick, so the two always agree).
    local st = NS.settings or {}
    st.rotation_enabled = rotation_enabled
    st.healing_enabled = read_quick_toggle(quick_toggle_by_key.healing_enabled)
    st.damage_enabled = read_quick_toggle(quick_toggle_by_key.damage_enabled)
    st.use_cooldowns = read_quick_toggle(quick_toggle_by_key.use_cooldowns)
    st.aoe_enabled = read_quick_toggle(quick_toggle_by_key.aoe_enabled)
    st.use_interrupt = read_quick_toggle(quick_toggle_by_key.use_interrupt)
    st.utility_enabled = read_quick_toggle(quick_toggle_by_key.utility_enabled)
    st.use_threat_drop = read_quick_toggle(quick_toggle_by_key.use_threat_drop)
    st.auto_taunt = read_quick_toggle(quick_toggle_by_key.auto_taunt)

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

-- Menu render + Control Panel register FIRST, before the shared dispatcher
-- below: the dispatcher's registration probes historically included the menu
-- and control-panel render slots as fallback tick sources, so registering our
-- UI callbacks ahead of it guarantees they keep their slots on every build.
-- Declarative menu: skip the imperative render callback when active — the
-- declarative _G.menu renders itself (retained mode). The Control Panel is
-- registered in BOTH modes: in declarative mode its rows are built from the
-- declarative quick-toggle controls so the permashow toggles the same widgets
-- the user sees in the menu (see control_panel_quick_defs).
if not _declarative_menu_active then
    if type(core.register_on_render_menu_callback) == "function" then
        pcall(core.register_on_render_menu_callback, render_menu)
    end
end
register_control_panel_ui()

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
            -- Check toggle. Declarative mode: the checkbox lives in the retained
            -- page and is synced to NS.settings each tick; the imperative widget
            -- is never rendered there, so reading it would pin the override on.
            local theme_on
            if _declarative_menu_active then
                local _st = NS and NS.settings
                theme_on = not (_st and _st.eax_theme_override_enabled == false)
            else
                local chk_ok, chk_val = pcall(function() return menu_elements.theme_enabled_chk:get_state() end)
                theme_on = not (chk_ok and chk_val == false)
            end
            if theme_on == false then
                -- One-shot restore on transition from active → inactive
                if _was_active and ThemeOverride.restore_palette then
                    ThemeOverride.restore_palette()
                end
                _was_active = false
                return
            end
            _was_active = true

            -- Read accent from color picker (declarative: NS.settings table
            -- {r,g,b,a} synced from the retained picker; else the widget).
            local accent_col
            if _declarative_menu_active then
                accent_col = (NS and NS.settings and NS.settings.eax_theme_accent_color) or nil
            else
                if menu_elements.theme_accent_picker then
                    local ok, col = pcall(menu_elements.theme_accent_picker.get, menu_elements.theme_accent_picker)
                    if ok then accent_col = col end
                end
            end
            if ThemeOverride.set_accent and accent_col then
                local col = accent_col
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
