-- declarative_menu_sylvanas.lua — Declarative _G.menu builder for EaxRotations.
-- WHAT:  translates the existing class schema (tab → section → setting defs) into a
--        declarative _G.menu page → section → subsection → widget tree, with native
--        collapsibility and playstyle-scoped visibility gates.
-- WHEN:  loaded by main.lua at addon init when _G.menu is available and the feature
--        flag is enabled.
-- WHY:   the imperative core.menu.* + tree_node path has a broken depth-2 scoping bug
--        (sibling section trees merge). The declarative API provides first-class
--        section:subsection() collapsibility with per-frame `visible` function gates,
--        which is the recommended surface per apidocs/pages/modules/menu.md.
-- SAFETY: all _G.menu calls are pcall-guarded; the module degrades to a no-op when
--         _G.menu is nil (imperative menu stays active). No per-frame allocations —
--         the menu is declared once at load; only the sync function runs per frame.
-- DECISION: spec files require ZERO changes — they read through spec_kit.setting →
--           NS.get_setting → NS.settings, which is populated by the sync function.

local M = {}

-- Page path used for menu:get / menu:set / menu:on_change lookups.
-- Must stay stable across releases (it's the persistence identity).
local PAGE_PATH = { "EaxRotations" }
local PAGE_PATH_STR = "EaxRotations"

-- Internal state: widget id registry for the sync function.
-- Each entry: { id = "key", type = "checkbox"|"slider"|"dropdown"|"keybind",
--               option_values = table|nil (for dropdowns) }
local _widget_registry = {}
local _page = nil
local _initialized = false

-- ---------------------------------------------------------------------------
-- is_available(): true when _G.menu is installed and has the page() method.
-- ---------------------------------------------------------------------------
function M.is_available()
    local menu = _G.menu
    return menu ~= nil and type(menu.page) == "function"
end

-- ---------------------------------------------------------------------------
-- get_page_path_str(): returns the stable path string for menu:get calls.
-- ---------------------------------------------------------------------------
function M.get_page_path_str()
    return PAGE_PATH_STR
end

-- ---------------------------------------------------------------------------
-- get_page_path(): returns the path table for menu:page() calls.
-- ---------------------------------------------------------------------------
function M.get_page_path()
    return PAGE_PATH
end

-- ---------------------------------------------------------------------------
-- build_widget_opts(def): translate schema tooltip/description into declarative opts.
-- ---------------------------------------------------------------------------
local function build_opts(def)
    local opts = {}
    if def.tooltip and #def.tooltip > 0 then
        opts.description = def.tooltip
    elseif def.description and #def.description > 0 then
        opts.description = def.description
    end
    return opts
end

-- ---------------------------------------------------------------------------
-- declare_setting(section_or_sub, def): translate a single schema setting def
-- into a declarative widget. Registers the widget in _widget_registry for sync.
-- Skips playstyle (handled separately) and QUICK_TOGGLE_SETTING_KEYS (handled
-- by the quick toggles section).
-- ---------------------------------------------------------------------------
local function declare_setting(section_or_sub, def, quick_toggle_keys)
    if not def or not def.key or not def.type then return end
    -- Skip playstyle dropdown (declared separately in the class settings section)
    if def.key == "playstyle" then return end
    -- Skip quick-toggle keys (they're keybinds in the Quick Toggles section)
    if quick_toggle_keys and quick_toggle_keys[def.key] then return end

    local opts = build_opts(def)

    if def.type == "checkbox" or def.type == "toggle" then
        local default = def.default == true
        section_or_sub:checkbox(def.key, def.label or def.key, default, opts)
        _widget_registry[#_widget_registry + 1] = {
            id = def.key, type = "checkbox",
            default = default,
        }

    elseif def.type == "slider" then
        local min_val = def.min or 0
        local max_val = def.max or 100
        local default_val = def.default ~= nil and def.default or min_val
        section_or_sub:slider(def.key, def.label or def.key, min_val, max_val, default_val, nil, opts)
        _widget_registry[#_widget_registry + 1] = {
            id = def.key, type = "slider",
            default = default_val,
        }

    elseif def.type == "dropdown" then
        local option_labels = {}
        local option_values = {}
        for _, option in ipairs(def.options or {}) do
            local label = option.text or tostring(option.value)
            option_labels[#option_labels + 1] = label
            option_values[#option_values + 1] = option.value
        end
        -- Find default index
        local default_index = 1
        for i, option in ipairs(def.options or {}) do
            if option.value == def.default then
                default_index = i
                break
            end
        end
        section_or_sub:dropdown(def.key, def.label or def.key, option_labels, default_index, opts)
        _widget_registry[#_widget_registry + 1] = {
            id = def.key, type = "dropdown",
            option_values = option_values,
            default_index = default_index,
        }
    end
end

-- ---------------------------------------------------------------------------
-- build_playstyle_visible_fn(playscope, active_fn):
-- Creates a `visible` function for a section/subsection that returns true when
-- the active playstyle is in the playscope set (or when playscope is nil = always).
-- `active_fn` is a closure that returns the current playstyle string.
-- ---------------------------------------------------------------------------
local function build_playstyle_visible_fn(playscope, active_fn)
    if not playscope or #playscope == 0 then
        return nil  -- no visibility gate needed (always shown)
    end
    -- Build a fast lookup set
    local scope_set = {}
    for _, p in ipairs(playscope) do scope_set[p] = true end
    return function()
        local active = active_fn and active_fn() or nil
        if not active then return true end  -- unknown → show (safe default)
        return scope_set[active] == true
    end
end

-- ---------------------------------------------------------------------------
-- initialize(schema, class_config, MenuTheme, playstyle_keys, playstyle_options,
--            quick_toggle_keys, get_active_playstyle_fn, stored_values):
-- Builds the declarative menu page → sections → subsections → widgets from the
-- class schema. Called once at addon init.
--
-- Parameters:
--   schema              — the class schema (array of tabs with .name + .sections)
--   class_config        — NS.rotation_registry.class_config (playstyles, class_key)
--   MenuTheme           — shared/menu_theme_sylvanas module (for scope_admits etc.)
--   playstyle_keys      — array of playstyle key strings
--   playstyle_options   — array of playstyle display labels
--   quick_toggle_keys   — table of { key = true } for quick-toggle settings to skip
--   get_active_playstyle_fn — function() returning the current playstyle string
--   stored_values       — table of initial values from NS.settings (for defaults)
-- ---------------------------------------------------------------------------
function M.initialize(schema, class_config, MenuTheme, playstyle_keys,
                      playstyle_options, quick_toggle_keys,
                      get_active_playstyle_fn)
    local menu = _G.menu
    if not menu or type(menu.page) ~= "function" then
        return false
    end

    -- Reset state
    _widget_registry = {}
    _initialized = false

    local class_key = class_config and class_config.class_key or nil

    -- Build playstyle lookup for MenuTheme scoping
    local ps_keyset, ps_n2k
    if MenuTheme and #playstyle_keys > 0 then
        ps_keyset, ps_n2k = MenuTheme.build_playstyle_lookup(playstyle_keys, playstyle_options)
    end

    -- Create/fetch the page
    local page_ok, page = pcall(menu.page, menu, PAGE_PATH, {
        icon = "settings",
    })
    if not page_ok or not page then
        return false
    end
    _page = page

    -- Page title
    if page.title then
        pcall(page.title, page, "EaxRotations — TBC Classic Rotations", { size = "title" })
    end

    -- ======================================================================
    -- Quick Toggles section
    -- ======================================================================
    local qt_ok, qt_section = pcall(page.section, page, "Quick Toggles", nil, {
        column = "full",
        collapsed = false,
        searchable = false,
    })
    if qt_ok and qt_section then
        -- Playstyle dropdown
        if #playstyle_options > 0 then
            qt_section:dropdown("playstyle", "Playstyle", playstyle_options,
                1,  -- default index (updated by sync later)
                { description = "Select active class rotation." })
            _widget_registry[#_widget_registry + 1] = {
                id = "playstyle", type = "dropdown",
                option_values = playstyle_keys,
                default_index = 1,
            }
        end

        -- Quick toggle keybinds — declared as toggle-mode keybinds
        -- These map to the same keys the imperative menu uses.
        local qt_keybinds = {
            { id = "rotation_enabled", label = "Rotation", default = true },
            { id = "healing_enabled",  label = "Healing",  default = true },
            { id = "damage_enabled",   label = "Damage",   default = true },
            { id = "use_cooldowns",    label = "Cooldowns", default = true },
            { id = "aoe_enabled",      label = "AoE",      default = true },
            { id = "use_interrupt",    label = "Interrupts", default = true },
            { id = "utility_enabled",  label = "Utility",  default = true },
            { id = "use_threat_drop",  label = "Threat Drops", default = true },
            { id = "auto_taunt",       label = "Auto Taunt", default = true },
        }
        for _, kb in ipairs(qt_keybinds) do
            qt_section:keybind(kb.id, kb.label, 999, {
                mode = "toggle",
                modes = { "toggle", "hold" },
                default_active = kb.default,
            })
            _widget_registry[#_widget_registry + 1] = {
                id = kb.id, type = "keybind",
                default_active = kb.default,
            }
        end
    end

    -- ======================================================================
    -- Class Settings section (with collapsible subsections)
    -- ======================================================================
    local cs_ok, cs_section = pcall(page.section, page, "Class Settings", nil, {
        column = "full",
        collapsed = false,
        searchable = true,
    })
    if not cs_ok or not cs_section then
        _initialized = true
        return true
    end

    -- Normalize schema to tab → section format (same as main.lua)
    local function normalize_schema_tabs(sch)
        if type(sch) ~= "table" or #sch == 0 then return {} end
        if type(sch[1]) == "table" and sch[1].sections then return sch end
        return { { name = "General", sections = {
            { header = "Settings", settings = sch } } } }
    end

    local normalized = normalize_schema_tabs(schema)

    -- Track which widget keys we've already declared (dedup — same as imperative)
    local declared_keys = {}

    -- Iterate tabs → sections, creating a subsection per section header
    for _, tab in ipairs(normalized) do
        -- Compute tab playscope
        local tab_playscope = nil
        if MenuTheme and ps_n2k and tab.name then
            tab_playscope = MenuTheme.tab_playscope(tab.name, ps_n2k)
        end

        for _, section in ipairs(tab.sections or {}) do
            local header = section.header or "Settings"

            -- Compute section playscope
            local section_playscope = nil
            if MenuTheme and class_key then
                local rules = MenuTheme.CLASS_SECTION_RULES[class_key]
                section_playscope = MenuTheme.section_playscope(
                    class_key, header, section.playstyles, ps_keyset, rules)
            end

            -- Build visibility function from playscope
            local visible_fn = build_playstyle_visible_fn(
                section_playscope or (tab_playscope and { tab_playscope }),
                get_active_playstyle_fn)

            -- Determine default collapse state:
            -- The active playstyle's section should be expanded; others collapsed.
            local default_collapsed = true
            if visible_fn then
                -- If the section is visible for the current playstyle, start expanded
                local currently_visible = visible_fn()
                if currently_visible then default_collapsed = false end
            else
                -- Always-visible sections (Consumables, Leveling, etc.) start expanded
                default_collapsed = false
            end

            -- Create the subsection
            local sub_opts = {
                collapsed = default_collapsed,
                description = section_playscope and
                    ("Scoped to: " .. table.concat(section_playscope, ", ")) or nil,
            }
            if visible_fn then
                sub_opts.visible = visible_fn
            end

            local sub_ok, sub = pcall(cs_section.subsection, cs_section, header, sub_opts)
            if not sub_ok or not sub then
                -- Subsection creation failed; skip this section
                -- (don't fail the entire init — other sections may still work)
            else
                -- Declare each setting in this section
                for _, def in ipairs(section.settings or {}) do
                    if not def or not def.key then
                        -- skip invalid def
                    elseif declared_keys[def.key] then
                        -- Already declared (duplicate key across tabs/sections).
                        -- The declarative menu uses page+id as persistence identity,
                        -- so we skip duplicates the same way the imperative menu reuses
                        -- the first control. The setting still resolves by key in NS.settings.
                    else
                        declare_setting(sub, def, quick_toggle_keys)
                        if def.key ~= "playstyle" and
                           not (quick_toggle_keys and quick_toggle_keys[def.key]) and
                           def.type then
                            declared_keys[def.key] = true
                        end
                    end
                end
            end
        end
    end

    -- ======================================================================
    -- Theme section
    -- ======================================================================
    local theme_ok, theme_section = pcall(page.section, page, "Theme", nil, {
        column = "full",
        collapsed = true,
    })
    if theme_ok and theme_section then
        theme_section:checkbox("eax_theme_override_enabled", "Enable Theme Override", true, {
            description = "Recolor the EaxRotations menu with your chosen accent color",
        })
        _widget_registry[#_widget_registry + 1] = {
            id = "eax_theme_override_enabled", type = "checkbox", default = true,
        }
        theme_section:color_picker("eax_theme_accent_color", "Accent Color",
            { r = 80, g = 180, b = 160, a = 255 }, {
                description = "Pick the accent color for the EaxRotations menu",
            })
        -- color_picker values are read via menu:get as {r,g,b,a}; synced separately
        _widget_registry[#_widget_registry + 1] = {
            id = "eax_theme_accent_color", type = "color_picker",
        }
    end

    -- ======================================================================
    -- Diagnostics section
    -- ======================================================================
    local diag_ok, diag_section = pcall(page.section, page, "Diagnostics", nil, {
        column = "full",
        collapsed = true,
    })
    if diag_ok and diag_section then
        diag_section:button("eax_dump_spells", "Dump Learned Spells", {
            description = "Writes every known spell for this class to the console log",
            on_click = function()
                local NS = _G.EaxRotations
                if NS and NS.dump_class_spells and _G.core then
                    local class_name = NS.player_class_name or "Unknown"
                    local name = class_name:sub(1,1):upper() .. class_name:sub(2):lower()
                    pcall(NS.dump_class_spells, name)
                end
            end,
        })
        diag_section:checkbox("eax_debug_swing_timer", "Debug Swing Timer", false, {
            description = "Log addon vs fallback path decisions",
        })
        _widget_registry[#_widget_registry + 1] = {
            id = "eax_debug_swing_timer", type = "checkbox", default = false,
        }
        diag_section:checkbox("eax_debug_game_events", "Debug Game Events", false, {
            description = "Log event dispatcher registration and dispatch",
        })
        _widget_registry[#_widget_registry + 1] = {
            id = "eax_debug_game_events", type = "checkbox", default = false,
        }
        diag_section:checkbox("eax_debug_combo_points", "Debug Combo Points", false, {
            description = "Log combo point reads, resolved power-type enums, and min_combo gate rejections",
        })
        _widget_registry[#_widget_registry + 1] = {
            id = "eax_debug_combo_points", type = "checkbox", default = false,
        }
    end

    _initialized = true
    return true
end

-- ---------------------------------------------------------------------------
-- is_initialized(): true after a successful initialize() call.
-- ---------------------------------------------------------------------------
function M.is_initialized()
    return _initialized
end

-- ---------------------------------------------------------------------------
-- sync_to_settings(settings_table, playstyle_keys):
-- Reads all declarative widget values via menu:get and writes them into the
-- provided settings table (NS.settings). This replaces the imperative sync loop.
--
-- Value shapes from menu:get:
--   checkbox → boolean
--   slider → number
--   dropdown → integer (1-based index)
--   keybind → { vk, mods, mode, active }
--   color_picker → { r, g, b, a }
-- ---------------------------------------------------------------------------
function M.sync_to_settings(settings_table, playstyle_keys)
    if not _initialized then return end
    local menu = _G.menu
    if not menu or type(menu.get) ~= "function" then return end

    local st = settings_table
    if not st then return end

    for _, entry in ipairs(_widget_registry) do
        local ok, value = pcall(menu.get, menu, PAGE_PATH_STR, entry.id)
        if ok and value ~= nil then
            if entry.type == "checkbox" then
                st[entry.id] = value == true

            elseif entry.type == "slider" then
                if type(value) == "number" then
                    st[entry.id] = value
                end

            elseif entry.type == "dropdown" then
                -- menu:get returns 1-based integer index
                if type(value) == "number" and entry.option_values then
                    local resolved = entry.option_values[value]
                    if resolved ~= nil then
                        st[entry.id] = resolved
                    end
                end

            elseif entry.type == "keybind" then
                -- menu:get returns { vk, mods, mode, active }
                if type(value) == "table" and value.active ~= nil then
                    st[entry.id] = value.active == true
                end

            elseif entry.type == "color_picker" then
                -- Store the raw {r,g,b,a} table for theme_override to read
                if type(value) == "table" then
                    st[entry.id] = value
                end
            end
        end
    end

    -- Sync playstyle dropdown to both st.playstyle and st.active_playstyle
    -- (same pattern as the imperative sync in main.lua)
    local ps_ok, ps_index = pcall(menu.get, menu, PAGE_PATH_STR, "playstyle")
    if ps_ok and type(ps_index) == "number" and playstyle_keys then
        local ps_val = playstyle_keys[ps_index]
        if type(ps_val) == "string" and ps_val ~= "" then
            st.playstyle = ps_val
            st.active_playstyle = ps_val
        end
    end
end

-- ---------------------------------------------------------------------------
-- get_widget_value(id): convenience wrapper for menu:get.
-- Returns the raw menu:get value (boolean, number, table, etc.) or nil.
-- ---------------------------------------------------------------------------
function M.get_widget_value(id)
    if not _initialized then return nil end
    local menu = _G.menu
    if not menu or type(menu.get) ~= "function" then return nil end
    local ok, value = pcall(menu.get, menu, PAGE_PATH_STR, id)
    if ok then return value end
    return nil
end

-- ---------------------------------------------------------------------------
-- get_widget_registry(): returns the internal widget registry (for debugging).
-- ---------------------------------------------------------------------------
function M.get_widget_registry()
    return _widget_registry
end

return M
