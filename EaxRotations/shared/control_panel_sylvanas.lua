-- control_panel_sylvanas.lua — EaxRotations Control Panel (permashow) subsystem.
-- WHAT:  single owner of the always-on-screen quick-toggle panel: the legacy
--        per-frame callback rows, the v2 menu.control_panel.add rows, the
--        native mirror seeding, role reconciliation, the path decision, the
--        one-shot diagnostics logs, and the permashow window recovery action.
-- WHEN:  ControlPanel.register(env) is called once from main.lua at addon load,
--        BEFORE the shared rotation dispatcher so the panel callbacks keep
--        their engine slots; ControlPanel.reconcile() runs from main.lua's
--        on_update (~20Hz); the engine calls ControlPanel.render_legacy_rows()
--        through a callback registered inside register().
-- WHY:   main.lua stays a composition root + menu renderer. The panel row set,
--        its mode, and its logs have exactly one owner here; role visibility
--        policy lives in MenuTheme.def_allowed (menu_theme_sylvanas.lua).
-- SAFETY: every engine call is pcall/nil-guarded; degrades to legacy rows when
--         the v2 host is absent. No per-frame allocations beyond the fresh
--         row table the legacy callback already returned every frame.
-- STRUCTURE NOTE (architecture pass 2026-09-06): do not push Control Panel
-- state or rendering back into main.lua. main.lua owns widgets + defs (the
-- "what"), MenuTheme owns role policy (the "who"), this module owns the panel
-- (the "where"). The mode decision, row inventory, role cache and logs live
-- only here.

local ControlPanel = {}

local format = string.format

-- Optional engine helpers (best-effort; nil when the build lacks them).
local key_helper
local control_panel_helper
do
    local ok_h, h = pcall(require, "common/utility/key_helper")
    if ok_h then key_helper = h end
    local ok_c, c = pcall(require, "common/utility/control_panel_helper")
    if ok_c then control_panel_helper = c end
end

-- Setting that forces the legacy callback path (debug / compatibility).
local SETTING_MODE = "eax_use_cp_v2"

-- Schema checkbox rows that have no menu.control_panel.add equivalent (that
-- API accepts keybinds/combos only), so they always come from the callback.
local SCHEMA_CP_KEYS = { "disc_shield_tank_only" }

-- ---------------------------------------------------------------------------
-- Owned state — the ONLY state for the Control Panel subsystem.
-- ---------------------------------------------------------------------------
local env = nil            -- captured at register(): engine refs + defs + getters
local mode = nil           -- nil (unresolved) | "v2" | "legacy"
local rows = {}            -- def.key -> row table handed to control_panel.add (v2)
local playstyle_row = nil  -- combobox row table (v2, added once at setup)
local role_cache = nil     -- last role used to reconcile v2 rows
-- Legacy per-frame row cache: steady-state frames return the cached
-- row array instead of rebuilding it (zero per-frame allocation);
-- rebuilt only when a rendered input actually changes (mode, role,
-- bound key codes, or the schema-widgets table identity).
local legacy_rows_cache = nil
local legacy_rows_mode = nil
local legacy_rows_role = nil
local legacy_rows_codes = nil  -- per-def last key code
local legacy_rows_schema = nil -- last schema_widgets() table identity
local path_logged = false  -- one-shot mode log
local legacy_rows_logged = false -- one-shot legacy row-count log
local engine_cb_registered = false -- engine callback registered once per session
local legacy_cb_missing_logged = false -- one-shot "callback missing" error

-- ---------------------------------------------------------------------------
-- Logging (mirrors core.log / core.log_warning / core.log_error prefixes).
-- ---------------------------------------------------------------------------
local function log(level, msg)
    local core = env and env.core
    if not core then return end
    local fn = level == "error" and core.log_error
        or (level == "warning" and core.log_warning or core.log)
    if type(fn) == "function" then
        fn("[EaxRotations] " .. msg)
    end
end

-- ---------------------------------------------------------------------------
-- Key-code helpers.
-- ---------------------------------------------------------------------------

-- A keybind is "unbound" when the engine never registered a real key. The
-- engine's documented "Unbinded" sentinel is 7 (modules/control-panel); newer
-- builds also treat 0/999 as unbound (.api: "0 or 999 = unbound"). 999 is kept
-- here as a legacy sentinel for toggles saved by older EaxRotations builds.
local function is_unbound_key(key_code)
    return not key_code or key_code == 0 or key_code == 7 or key_code == 999
end

local function get_keybind_name(control)
    if not control then return "Unbound" end
    local ok, key_code = pcall(function() return control:get_key_code() end)
    if not ok or is_unbound_key(key_code) then return "Unbound" end
    if key_helper and key_helper.get_key_name then
        local name_ok, name = pcall(function() return key_helper:get_key_name(key_code) end)
        if name_ok and name then return tostring(name) end
    end
    return tostring(key_code)
end

-- ---------------------------------------------------------------------------
-- v2 host probe + row builders (menu.control_panel.add, retained _G.menu host).
-- ---------------------------------------------------------------------------
local function cp_v2_panel()
    local m = _G.menu
    if type(m) ~= "table" then return nil end
    local cp = m.control_panel
    if type(cp) ~= "table" then return nil end
    return cp
end

-- One role read per caller; role then feeds MenuTheme.def_allowed + capabilities.
local function current_role()
    if not (env and env.MenuTheme and env.class_key) then return nil end
    return env.MenuTheme.role_for_playstyle(env.class_key, env.active_playstyle())
end

-- Quick-toggle row WITHOUT a key suffix: the v2 host renders the keybind's own
-- key pill, and unbound rows must not carry "(Unbound)" as literal text.
local function quick_toggle_row(def)
    -- The row's human-readable label is the toggle's control_label (e.g.
    -- "Rotation (click to toggle)"), identical to the main-menu host's wording.
    -- The keybind widget itself keeps its plain toggle name for the key pill.
    return { name = format("[Eax] %s", def.control_label or def.label), keybind = def.control }
end

-- Register every role-visible quick toggle (+ the playstyle combobox) once at
-- setup via the retained API. Returns true when v2 should stay active; false
-- rolls back any partial rows so the legacy callback path starts clean (e.g.
-- the host rejected the native widgets handed to control_panel.add).
local function register_v2_rows()
    local cp = cp_v2_panel()
    if not cp or type(cp.add) ~= "function" then return false end

    local role = current_role()
    local added = {}
    local ok_all = true

    for _, def in ipairs(env.quick_toggle_defs) do
        if env.MenuTheme.def_allowed(def, role) then
            local row = quick_toggle_row(def)
            local ok = pcall(function() cp.add(row, false) end)
            if ok then
                added[#added + 1] = row
                rows[def.key] = row
            else
                ok_all = false
            end
        end
    end

    -- Playstyle combobox: normalize its items once so the panel can render it
    -- without waiting for the main-menu render pass.
    if ok_all and env.playstyle_combo and #env.playstyle_options > 0 then
        local combo = env.playstyle_combo
        if type(combo.set_items) == "function" then
            pcall(combo.set_items, combo, env.playstyle_options)
        end
        local combo_row = { name = "[Eax] Playstyle", combobox = combo }
        local ok = pcall(function() cp.add(combo_row, false) end)
        if ok then
            playstyle_row = combo_row
        else
            ok_all = false
        end
    end

    if not ok_all then
        if type(cp.remove) == "function" then
            for _, row in ipairs(added) do
                pcall(function() cp.remove(row) end)
            end
            if playstyle_row then
                pcall(function() cp.remove(playstyle_row) end)
            end
        end
        rows = {}
        playstyle_row = nil
        return false
    end
    return true
end

-- Reconcile v2 rows when the active playstyle's role changes (run from
-- main.lua's on_update). Mirrors the legacy per-frame role filter so both
-- paths present the same toggle set. No-op when the role has not changed.
local function reconcile_rows()
    if mode ~= "v2" then return end
    local cp = cp_v2_panel()
    if not cp then return end

    local role = current_role()
    if role == role_cache then return end
    role_cache = role

    for _, def in ipairs(env.quick_toggle_defs) do
        local visible = env.MenuTheme.def_allowed(def, role)
        local row = rows[def.key]
        if visible and not row then
            row = quick_toggle_row(def)
            local ok = pcall(function() cp.add(row, false) end)
            if ok then rows[def.key] = row end
        elseif not visible and row then
            if type(cp.remove) == "function" then
                pcall(function() cp.remove(row) end)
            end
            rows[def.key] = nil
        end
    end
end

-- ---------------------------------------------------------------------------
-- Native mirror seeding (docs.project-sylvanas.net/modules/control-panel): the
-- engine only guarantees an always-on-screen row for a keybind that is bound
-- or was user-drag-added, so unbound quick toggles must be seeded. Mark every
-- toggle as "showing on the control panel" and make it draggable (users can
-- then also drag/remove rows freely). pcall-guarded for older builds.
-- ---------------------------------------------------------------------------
local function seed_native_mirror()
    for _, def in ipairs(env.quick_toggle_defs) do
        local el = def.control
        if el then
            if type(el.set_is_showing_on_control_panel) == "function" then
                pcall(function() el:set_is_showing_on_control_panel() end)
            end
            if type(el.set_draggable_state) == "function" then
                pcall(function() el:set_draggable_state(true) end)
            end
        end
    end
end

-- ---------------------------------------------------------------------------
-- Legacy per-frame rows (core.register_on_render_control_panel_callback).
-- ---------------------------------------------------------------------------

-- Schema checkbox rows (only mechanism available for them on every host).
-- Takes the already-fetched schema-widget table so the caller's snapshot and
-- the rendered rows always agree (the render cache keys on the same table
-- identity).
local function append_schema_rows(out, widgets)
    for _, key in ipairs(SCHEMA_CP_KEYS) do
        local widget = widgets and widgets[key]
        if widget and widget.control then
            local label = "[Eax] " .. (widget.label or key)
            local inserted = false
            if control_panel_helper and control_panel_helper.insert_toggle_ then
                local ok, result = pcall(function()
                    return control_panel_helper:insert_toggle_(out, label, widget.control, false)
                end)
                inserted = ok and result == true
            end
            if not inserted then
                out[#out + 1] = {
                    name = label,
                    keybind = widget.control,
                }
            end
        end
    end
end

-- Cache key for a rendered row set: the inputs that can change the rows the
-- engine shows are (a) the mode, (b) the role (visibility filter), (c) each
-- quick-toggle keybind's key code (the label shows the bound key; an
-- unbound→bound change switches the row shape), and (d) the schema-widget
-- table identity (rebuilt on a late class load). When all are unchanged the
-- rendered row array is identical to the last frame, so steady-state frames
-- return the cached array instead of rebuilding it — the engine treats the
-- callback's return as the full panel content each frame (sibling-plugin
-- pattern: EAXFishing returns a fresh element array per frame; ours is
-- cached until its inputs change).
local function legacy_rows_unchanged(role, schema_tbl, key_codes)
    if legacy_rows_mode ~= mode or legacy_rows_role ~= role then return false end
    -- Schema contribution changes only when a CP schema key gains/loses a
    -- widget control. Compare the signature (control presence per key), NOT
    -- table identity: in production the getter returns one stable table, but
    -- signature equality also stays correct for hosts that hand back a fresh
    -- wrapper table each frame while the widgets inside are unchanged.
    for _, key in ipairs(SCHEMA_CP_KEYS) do
        local widget = schema_tbl and schema_tbl[key]
        local has = (widget and widget.control) ~= nil
        if legacy_rows_schema[key] ~= has then return false end
    end
    if not key_codes then return false end
    -- Hot path: this runs EVERY render frame, so it must not allocate. A pcall
    -- closure per def would create fresh closures per frame (measured ~240
    -- B/frame churn on a 3-toggle panel); a DIRECT method read allocates
    -- nothing. Direct reads are safe here: every control in this loop was
    -- already queried successfully when the cached row array was built — if a
    -- control's get_key_code could throw, the cache would never have been
    -- populated. (The defensive pcall stays on the one-time build path where
    -- a fresh closure per def is irrelevant.)
    for i = 1, #env.quick_toggle_defs do
        local def = env.quick_toggle_defs[i]
        if env.MenuTheme.def_allowed(def, role) then
            local code = key_codes[i]
            if code == nil then return false end
            local key_code = def.control:get_key_code()
            if key_code ~= code then return false end
        end
    end
    return true
end

-- Build the cached row array for the CURRENT mode. v2 mode contributes only
-- the schema-checkbox rows (quick toggles are retained by the v2 host);
-- legacy mode builds the full row set.
local function build_cached_rows(schema_tbl)
    local out = {}
    if mode ~= "v2" then
        local role = legacy_rows_role
        for _, def in ipairs(env.quick_toggle_defs) do
            -- Role-based visibility: single policy shared with the main-menu
            -- Quick Toggles (MenuTheme.def_allowed).
            if env.MenuTheme.def_allowed(def, role) then
                local key_code = nil
                local kc_ok, kc = pcall(function() return def.control:get_key_code() end)
                if kc_ok then key_code = kc end

                if is_unbound_key(key_code) then
                    -- Unbound toggle: the legacy helper only inserts rows for REAL
                    -- keys (and updated builds treat 0/999 as unbound), so players
                    -- who never bound keys would get a blank panel. Push the
                    -- explicit-name row directly — the engine renders it regardless
                    -- of key state, and the toggle still flips via the widget.
                    out[#out + 1] = quick_toggle_row(def)
                else
                    -- Bound key: the row label is the toggle's control_label; the
                    -- key pill still shows the real bound key via get_keybind_name.
                    -- Both are kept separate so the pill never implies the rotation is
                    -- keyed to that hotkey.
                    local label = format("[Eax] %s (%s) ", def.control_label or def.label, get_keybind_name(def.control))
                    local inserted = false
                    if control_panel_helper and control_panel_helper.insert_toggle_ then
                        local ok, result = pcall(function()
                            return control_panel_helper:insert_toggle_(out, label, def.control, false)
                        end)
                        inserted = ok and result == true
                    end
                    if not inserted then
                        out[#out + 1] = {
                            name = label,
                            keybind = def.control,
                        }
                    end
                end
            end
        end
    end

    append_schema_rows(out, schema_tbl)

    -- One-shot diagnostics so future "my Control Panel is empty" reports
    -- have a log line explaining what the plugin thinks it rendered.
    if not legacy_rows_logged then
        legacy_rows_logged = true
        local n = #out
        if n == 0 then
            log("warning", "Control Panel (legacy) rendered 0 rows — role filter or keybinds hid every toggle")
        else
            log("info", "Control Panel (legacy) first render: " .. tostring(n) .. " row(s)")
        end
    end
    return out
end

-- Callback body returned to the engine every control-panel render frame.
-- Steady-state frames return the cached row array for the current mode — the
-- row set is rebuilt only when the mode, the role, a quick-toggle key code,
-- or the schema-widget table identity actually changes (see
-- legacy_rows_unchanged). Zero per-frame row/string allocation on the hot
-- path.
function ControlPanel.render_legacy_rows()
    if not env then return {} end
    if env.framework_core and env.framework_core.runtime_generation ~= env.runtime_generation then
        return {}
    end

    -- v2 mode: quick toggles were registered once via control_panel.add and are
    -- rendered by the retained host, so the callback contributes only the
    -- schema-checkbox rows. Legacy mode: full row set.
    local role = current_role()
    local schema_tbl = env.schema_widgets and env.schema_widgets() or nil

    if legacy_rows_cache ~= nil and legacy_rows_unchanged(role, schema_tbl, legacy_rows_codes) then
        return legacy_rows_cache
    end

    -- Cache miss (first render or a rendered input changed): snapshot the
    -- inputs, read the per-def key codes, rebuild, and cache.
    legacy_rows_mode = mode
    legacy_rows_role = role
    local schema_sig = {}
    for _, key in ipairs(SCHEMA_CP_KEYS) do
        local widget = schema_tbl and schema_tbl[key]
        schema_sig[key] = (widget and widget.control) ~= nil
    end
    legacy_rows_schema = schema_sig
    local key_codes = {}
    if mode ~= "v2" then
        for i = 1, #env.quick_toggle_defs do
            local def = env.quick_toggle_defs[i]
            if env.MenuTheme.def_allowed(def, role) then
                local key_code = nil
                local ok, kc = pcall(function() return def.control:get_key_code() end)
                if ok then key_code = kc end
                key_codes[i] = key_code
            end
        end
    end
    legacy_rows_codes = key_codes
    legacy_rows_cache = build_cached_rows(schema_tbl)
    return legacy_rows_cache
end

-- ---------------------------------------------------------------------------
-- register(env) — decide the path and register the legacy callback.
-- Called from main.lua BEFORE NS.register_on_update_callback so our UI
-- callbacks claim their engine slots ahead of the shared dispatcher's
-- fallback registration probes.
--
-- env fields (main.lua is the composition root):
--   core                  engine core (logging + callback registration)
--   framework_core        core_sylvanas module (live runtime_generation)
--   runtime_generation    const captured at main.lua load
--   MenuTheme             shared/menu_theme (role policy + colors)
--   class_key             class_config.class_key (role resolution)
--   active_playstyle      function() -> current playstyle key
--   quick_toggle_defs     array of { key, label, control, capability }
--   playstyle_combo       combobox widget (v2 playstyle row)
--   playstyle_options     labels for playstyle_combo
--   schema_widgets        function() -> current schema_widgets map (re-read
--                         because main.lua rebuilds it on late class load)
-- ---------------------------------------------------------------------------
function ControlPanel.register(e)
    if type(e) ~= "table" then return end

    -- Idempotent re-register (main.lua calls this again after a deferred class
    -- module load lands in on_update): tear down rows an earlier v2 registration
    -- added so re-adding below never duplicates rows on the retained host.
    local prev_cp = cp_v2_panel()
    if mode == "v2" and prev_cp and type(prev_cp.remove) == "function" then
        for _, row in pairs(rows) do
            pcall(function() prev_cp.remove(row) end)
        end
        if playstyle_row then
            pcall(function() prev_cp.remove(playstyle_row) end)
        end
    end
    rows = {}
    playstyle_row = nil
    role_cache = nil
    legacy_rows_cache = nil
    legacy_rows_mode = nil
    legacy_rows_role = nil
    legacy_rows_codes = nil
    legacy_rows_schema = nil
    mode = nil
    -- Re-register (late class load) recomputes the row set, so let the next
    -- register log the corrected inventory instead of the stale boot numbers.
    path_logged = false
    legacy_rows_logged = false

    env = e

    -- Mirror seeding is unconditional: it covers both hosts and is idempotent.
    seed_native_mirror()

    -- Setting: eax_use_cp_v2 — nil/"auto" = v2 when the host supports it,
    -- false forces the legacy callback path (debug / compatibility).
    local force_legacy = false
    if e.framework_core and e.framework_core.get_setting then
        if e.framework_core.get_setting(SETTING_MODE, nil) == false then
            force_legacy = true
        end
    end

    local cp = cp_v2_panel()
    if cp and type(cp.add) == "function" and not force_legacy then
        if register_v2_rows() then
            mode = "v2"
        end
    end
    if mode ~= "v2" then mode = "legacy" end

    -- The legacy callback is registered in BOTH modes: under v2 it contributes
    -- only the schema-checkbox rows (see render_legacy_rows). Registered ONCE per
    -- session — re-register (late class load) must not stack a second callback
    -- that would render every row twice.
    local reg = e.core and e.core.register_on_render_control_panel_callback
    if type(reg) == "function" then
        if not engine_cb_registered then
            engine_cb_registered = true
            pcall(reg, function()
                return ControlPanel.render_legacy_rows()
            end)
        end
    elseif mode == "legacy" then
        if not legacy_cb_missing_logged then
            legacy_cb_missing_logged = true
            log("error", "register_on_render_control_panel_callback missing on this build — Control Panel (permashow) unavailable")
        end
    end

    if not path_logged then
        path_logged = true
        if mode == "v2" then
            local n = 0
            for _ in pairs(rows) do n = n + 1 end
            log("info", "Control Panel path: v2 menu.control_panel.add (" .. tostring(n) .. " quick toggles")
        else
            log("info", "Control Panel path: legacy per-frame callback rows")
        end
    end
end

-- Keep v2 rows in sync when the active playstyle's role changes. Called from
-- main.lua's on_update; cheap no-op unless the role actually changed.
function ControlPanel.reconcile()
    if mode ~= "v2" then return end
    reconcile_rows()
end

-- Recovery action for the Diagnostics menu: restores an off-screen / hidden
-- always-on-screen panel to its default position and forces it visible.
-- Uses the v2 menu.permashow API when present; logs otherwise.
function ControlPanel.reset_permashow()
    local pm = nil
    local m = _G.menu
    if m and type(m.permashow) == "table" then pm = m.permashow end
    if not pm and type(_G.permashow) == "table" then pm = _G.permashow end

    local reset_ok = false
    if pm then
        if type(pm.reset_position) == "function" then
            reset_ok = pcall(function() pm.reset_position() end)
        end
        if type(pm.set_visible) == "function" then
            pcall(function() pm.set_visible(true) end)
        end
    end

    if reset_ok then
        log("info", "Permashow window reset to default position")
    else
        log("info", "Permashow reset unavailable on this build (menu.permashow API not present)")
    end
end

return ControlPanel
