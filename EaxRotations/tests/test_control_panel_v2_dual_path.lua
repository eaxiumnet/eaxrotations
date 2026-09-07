-- test_control_panel_v2_dual_path.lua -- Control Panel (permashow) dual-path tests.
-- WHAT:  static regression checks for the 2.25.0 permashow-visibility fix:
--        unbound quick toggles always produce a row, the v2 menu.control_panel.add
--        path exists with legacy fallback, UI callbacks register before the shared
--        dispatcher, and the dispatcher no longer squats on the control-panel slot.
-- STRUCTURE (architecture pass 2026-09-06): row logic, mode decision, seeding,
-- reconcile and the reset action live in shared/control_panel_sylvanas.lua;
-- main.lua owns the widgets + defs and calls ControlPanel.register(env).
-- WHEN:  During rotation test suite execution.
-- WHY:   Protects the fixes for "players cannot see the permashow menu" reports.
-- SAFETY: Pure static checks on source text (house style); no API calls.

local function assert_true(v, label)
    if not v then error(label or "assert_true failed", 2) end
end

local function assert_false(v, label)
    if v then error(label or "assert_false failed", 2) end
end

local function read_file(path)
    local f = assert(io.open(path, "rb"))
    local data = f:read("*a")
    f:close()
    return data
end

local function contains(data, text)
    return data:find(text, 1, true) ~= nil
end

local function index_of(data, text)
    return data:find(text, 1, true)
end

local main = read_file("EaxRotations/main.lua")
local cp = read_file("EaxRotations/shared/control_panel_sylvanas.lua")
local core = read_file("EaxRotations/core_sylvanas.lua")
local decl = read_file("EaxRotations/shared/declarative_menu_sylvanas.lua")

-- ---------------------------------------------------------------------------
-- 1. Unbound-key sentinel helper + unbound rows always visible (legacy path).
--    Quick toggles are core.menu.keybind(7, ...) — the engine's documented
--    "Unbinded" sentinel (999 is kept as a legacy sentinel in is_unbound_key).
--    Newer PS builds treat 0/999 as unbound too, so the legacy helper can
--    silently drop unbound rows. The control panel module must bypass the
--    helper for unbound toggles and push an explicit-name row directly, plus
--    seed the native mirror flag so hosts that gate rows on keybind-set/drag
--    flows still show them. NOTE: a real-key default (guessed VK codes
--    F5-F12/NumPad0) was attempted and crashed the client at load because the
--    engine's key-code numbering was never validated — defaults remain on the
--    sentinel until a validated code table exists.
-- ---------------------------------------------------------------------------
assert_true(contains(cp, "local function is_unbound_key(key_code)"), "control panel module should define the is_unbound_key sentinel helper")
assert_true(contains(cp, "key_code == 0 or key_code == 7 or key_code == 999"), "is_unbound_key should cover 0/7/999 sentinels")
assert_true(contains(main, 'core.menu.keybind(7, true, "eax_'), "quick toggles should default to the engine's Unbinded sentinel (7)")
assert_true(contains(cp, 'if is_unbound_key(key_code) then'), "legacy row render should branch on unbound keys")
assert_true(contains(cp, 'name = format("[Eax] %s", def.control_label or def.label),'), "unbound toggles should push an explicit-name row (label now carries the click-to-toggle wording)")
assert_true(contains(cp, "keybind = def.control,"), "explicit-name rows must reference the same keybind widget")
assert_true(contains(cp, "control_panel_helper:insert_toggle_"), "bound keys keep the legacy helper path (drag/drop + dedup)")
assert_true(contains(cp, "register_on_render_control_panel_callback") and contains(cp, "ControlPanel.render_legacy_rows"),
    "legacy callback registration must remain for old builds")

-- ---------------------------------------------------------------------------
-- 1b. Native mirror seeding (docs.project-sylvanas.net/modules/control-panel):
--     mark every quick toggle as mirrored on the Control Panel and draggable so
--     the permashow shows all toggles with zero keybinds on the retained host.
-- ---------------------------------------------------------------------------
assert_true(contains(cp, "el:set_is_showing_on_control_panel()"), "control panel module should seed the native showing-on-control-panel flag on quick toggles")
assert_true(contains(cp, "el:set_draggable_state(true)"), "control panel module should make quick toggles draggable on the Control Panel")
-- Hotkey sentinel: the real-key default was attempted with guessed VK codes
    -- (F5-F12/NumPad0) and crashed the client at load because the engine's key-
    -- code numbering was never validated -- reverted to the sentinel until a
    -- validated code table exists. The permashow pill fix is the zero-risk cosmetic
    -- path: keep the sentinel and make the row label carry the truth (click to
    -- toggle) instead of trying to bind real keys.
    assert_true(contains(main, 'core.menu.keybind(7, true, "eax_rotation_enabled_keybind")'), "rotation quick toggle must still default to the 7 sentinel (after the hotkey-crash revert)")
    assert_true(contains(decl, 'keybind(kb.id, kb.label, 999,'), "declarative quick-toggle host must still default to the 999 sentinel")
    assert_false(contains(main, 'control_label = "Rotation (click to toggle)", default = true,'), "main.lua quick_toggle_defs uses the multi-field literal form, not the declarative compact form")

-- ---------------------------------------------------------------------------
-- 2. v2 path (menu.control_panel.add) with legacy fallback, owned by the
--    control panel module; main.lua triggers it via ControlPanel.register(env).
-- ---------------------------------------------------------------------------
assert_true(contains(cp, "menu.control_panel.add"), "control panel module should reference the v2 control panel API surface")
assert_true(contains(cp, "register_v2_rows"), "control panel module should define v2 row registration")
assert_true(contains(cp, "eax_use_cp_v2"), "v2 path must be switchable via the eax_use_cp_v2 setting")
assert_true(contains(cp, "function ControlPanel.reconcile"), "control panel module should own role reconciliation")
assert_true(contains(cp, "combobox = combo"), "v2 path should add the playstyle combobox row")
assert_true(contains(main, "ControlPanel.register("), "main should invoke ControlPanel.register at setup")
assert_true(contains(main, "schema_widgets = function() return schema_widgets end"), "main should hand schema_widgets to the module via a getter")
assert_true(contains(main, "local function register_control_panel_ui"), "main should wrap ControlPanel.register in a reusable helper")
assert_true(contains(main, "register_control_panel_ui()"), "helper should be called at boot AND from the deferred class retry")
assert_true(contains(main, "local function refresh_playstyle_state"), "playstyle options/theme state should be rebuildable")
assert_true(contains(main, "refresh_playstyle_state()"), "playstyle state should be refreshed at boot and after retry")
assert_true(contains(cp, "engine_cb_registered"), "control panel module should register its engine callback only once per session")
assert_true(contains(cp, "Idempotent re-register"), "control panel module should tear down prior v2 rows on re-register")

-- ---------------------------------------------------------------------------
-- 6. Declarative _G.menu mode must not starve the permashow (found by the
--    2026-09-06 declarative playtest): module methods are invoked as
--    pcall(M.<fn>, M, ...), so they MUST be colon-defined — a dot-defined
--    initialize/sync shifts every argument by one (MenuTheme lands in the
--    playstyle_keys slot, sync writes into the module table, and settings
--    never update). CP registration must also run in BOTH menu modes, using
--    the declarative quick-toggle controls so rows toggle the same widgets
--    the user sees in the retained menu.
-- ---------------------------------------------------------------------------
assert_true(contains(decl, "function M:initialize("), "declarative initialize must be colon-defined (self first)")
assert_false(contains(decl, "function M.initialize("), "no dot-defined initialize (argument-shift guard)")
assert_true(contains(decl, "function M:sync_to_settings("), "declarative sync_to_settings must be colon-defined")
assert_true(contains(decl, "function M:add_diagnostics_button("), "diagnostics action button helper must be colon-defined")
-- Call sites must keep passing the module as the first argument (dot-call with
-- the module explicit), matching the colon definitions above — the 2026-09-06
-- bug was a dot-DEFINITION receiving a self-first call, shifting every arg.
assert_true(contains(main, "pcall(DeclarativeMenu.initialize, DeclarativeMenu,"),
    "initialize call site must pass the module first (argument alignment)")
assert_true(contains(main, "pcall(DeclarativeMenu.sync_to_settings, DeclarativeMenu,"),
    "sync_to_settings call site must pass the module first (argument alignment)")
assert_true(contains(main, "pcall(DeclarativeMenu.add_diagnostics_button, DeclarativeMenu,"),
    "add_diagnostics_button call site must pass the module first (argument alignment)")
assert_true(contains(decl, "function M.control_panel_defs"), "declarative module should expose its retained quick-toggle controls")
assert_true(contains(main, "control_panel_quick_defs"), "main should build Control Panel defs from declarative controls when active")
assert_true(contains(main, "add_diagnostics_button"), "main should add the permashow reset action to the retained Diagnostics")
assert_true(contains(main, "reload to populate the playstyle selector"),
    "deferred class load under the declarative menu should log an honest /reload hint")

-- ---------------------------------------------------------------------------
-- 6b. Quick-toggle GATES must read the same source per menu mode (found by
--     the 2026-09-06 adversarial review): the non-master gates used to read
--     the imperative widgets even under the declarative menu, where those
--     widgets are never rendered and would report their defaults forever. The
--     st injection then clobbered the value sync_to_settings wrote, and only
--     the later sync rewrote it back — an ordering dependency that would pin
--     the toggles on if the sync were removed or renamed. All gates must now
--     resolve through one helper: live widgets in imperative mode, synced
--     NS.settings in declarative mode (like the master toggle).
-- ---------------------------------------------------------------------------
assert_true(contains(main, "local function read_quick_toggle"),
    "quick-toggle gates should resolve through a single per-mode helper")
assert_true(contains(main, "st[def.key]"),
    "declarative quick-toggle gate should read the synced NS.settings entry")
assert_false(contains(main, "get_keybind_toggle_state(menu_elements."),
    "no gate may read the imperative widgets directly (declarative mode never renders them)")
assert_true(contains(main, "st.healing_enabled = read_quick_toggle(quick_toggle_by_key.healing_enabled)"),
    "healing gate should resolve via the per-mode helper into settings")
assert_true(contains(main, "st.auto_taunt = read_quick_toggle(quick_toggle_by_key.auto_taunt)"),
    "auto-taunt gate should resolve via the per-mode helper into settings")

-- ---------------------------------------------------------------------------
-- 3. Registration order: menu/control-panel registration happens BEFORE the
--    shared dispatcher so the dispatcher's fallback probes can't claim the
--    control-panel slot first.
-- ---------------------------------------------------------------------------
local cp_reg_pos = index_of(main, "ControlPanel.register(")
local menu_reg_pos = index_of(main, "pcall(core.register_on_render_menu_callback, render_menu)")
local dispatcher_pos = index_of(main, "NS.register_on_update_callback(on_update)")
assert_true(cp_reg_pos ~= nil and dispatcher_pos ~= nil, "ControlPanel.register and dispatcher call should exist")
assert_true(cp_reg_pos < dispatcher_pos, "control panel registration must precede shared dispatcher registration")
assert_true(menu_reg_pos ~= nil and menu_reg_pos < dispatcher_pos, "menu render registration must precede shared dispatcher registration")

-- ---------------------------------------------------------------------------
-- 3b. get_active_playstyle reads menu_elements.playstyle_combo (the live
--     widget) for INSTANT role resolution. menu_elements is created AFTER the
--     function in source, so it must be forward-declared (local menu_elements)
--     ABOVE get_active_playstyle and assigned WITHOUT `local` at the literal.
--     Otherwise the combo read binds to a GLOBAL and silently never runs --
--     playstyle/role then lag one tick behind the user via the settings
--     fallback, which delays Control Panel role reconcile + menu Quick Toggle
--     filtering (regression found by the 2026-09-06 surface playtest).
-- ---------------------------------------------------------------------------
local fwd_decl_pos = index_of(main, "local menu_elements")
local gap_func_pos = index_of(main, "local function get_active_playstyle")
assert_true(fwd_decl_pos ~= nil and gap_func_pos ~= nil, "menu_elements forward declaration + get_active_playstyle should exist")
assert_true(fwd_decl_pos < gap_func_pos, "menu_elements must be forward-declared BEFORE get_active_playstyle (else combo read is a global)")
assert_true(contains(main, "menu_elements = {") and not contains(main, "local menu_elements = {"),
    "menu_elements literal must ASSIGN (no local) the forward-declared variable")

-- ---------------------------------------------------------------------------
-- 4. The shared dispatcher must NOT fall back to the control-panel render
--    slot (that slot belongs to plugin permashow callbacks).
-- ---------------------------------------------------------------------------
assert_false(contains(core, "register_on_render_control_panel_callback"),
    "core dispatcher fallback must not use the control panel render slot")
assert_true(contains(core, "dispatcher claimed fallback source"),
    "core should log which fallback source the dispatcher claimed")

-- ---------------------------------------------------------------------------
-- 5. Diagnostics: one-shot path/row logs + reset-permashow recovery action.
-- ---------------------------------------------------------------------------
assert_true(contains(cp, "Control Panel path:"), "control panel module should log the active control panel path once")
assert_true(contains(cp, "rendered 0 rows"), "control panel module should warn once when the legacy panel renders zero rows")
assert_true(contains(main, 'reset_permashow_btn = core.menu.button("eax_reset_permashow")'), "main should create the reset permashow button")
assert_true(contains(main, "Reset Permashow Window"), "reset button should render in the diagnostics tree")
assert_true(contains(cp, "function ControlPanel.reset_permashow"), "control panel module should own the reset action")
assert_true(contains(cp, "pm.reset_position()"), "reset action should call permashow.reset_position()")
assert_true(contains(cp, "pm.set_visible(true)"), "reset action should force the permashow visible")

-- ---------------------------------------------------------------------------
-- 6. Functional: legacy render caches steady-state rows and rebuilds only when
--    a rendered input changes. Loads the REAL module against a mock env,
--    drives register() + render_legacy_rows(), and asserts table identity is
--    reused (zero per-frame row allocation) until role or a key code changes.
--    This is the behavioral half of the per-frame-allocation fix: the static
--    checks above pin the source patterns; this pins the caching contract.
-- ---------------------------------------------------------------------------
local ok_ctl, ctl_err = pcall(dofile, "EaxRotations/shared/control_panel_sylvanas.lua")
assert_true(ok_ctl and type(ctl_err) == "table", "control panel module dofile loads (err=" .. tostring(ctl_err) .. ")")
local CP_mod = ok_ctl and ctl_err or nil

local function make_cp_env(role)
    local controls = {}
    for i = 1, 3 do
        controls[i] = { get_key_code = function() return 7 end } -- unbound sentinel
    end
    local theme = {
        role_for_playstyle = function() return role end,
        def_allowed = function(def, r)
            if r == "tank" then return true end
            -- dps sees only the first toggle (damage-capable defs)
            return def.capability == "damage"
        end,
    }
    -- menu.control_panel with add but it FAILS (register_v2_rows returns false
    -- on add error) is awkward; simplest: no add -> legacy mode.
    _G.menu = {}
    return {
        core = { register_on_render_control_panel_callback = function() end, log = function() end },
        framework_core = { runtime_generation = 1, get_setting = function() return nil end },
        runtime_generation = 1,
        MenuTheme = theme,
        class_key = "warrior",
        active_playstyle = function() return "arms" end,
        quick_toggle_defs = {
            { key = "t1", label = "Toggle One", capability = "damage", control = controls[1] },
            { key = "t2", label = "Toggle Two", capability = "utility", control = controls[2] },
            { key = "t3", label = "Toggle Three", capability = "defense", control = controls[3] },
        },
        playstyle_combo = {},
        playstyle_options = {},
        schema_widgets = function() return {} end,
    }
end

if CP_mod and type(CP_mod.register) == "function" then
    -- Tank role: all three toggles visible (all unbound -> explicit-name rows).
    local e1 = make_cp_env("tank")
    CP_mod.register(e1)
    local r1 = CP_mod.render_legacy_rows()
    local r1b = CP_mod.render_legacy_rows()
    assert_true(r1 == r1b, "steady-state legacy render returns the SAME cached row array (no per-frame row rebuild)")
    assert_true(#r1 == 3, "tank sees all three quick-toggle rows (got " .. tostring(#r1) .. ")")
    assert_true(r1[1].name:find("Toggle One", 1, true) ~= nil, "unbound row carries the explicit toggle label")
    assert_true(r1[1].keybind ~= nil, "unbound row still references the keybind widget")
    -- The permashow pill/label fix adds a control_label field on every quick-toggle
    -- def so neither menu host still reads as a hotkey row ("Rotation (click to
    -- toggle)" etc.). The row builder renders control_label when present; the
    -- functional harness defs are still label-only so this guard keeps both forms
    -- legal (existing label-only paths keep working, new control_label paths win).
    assert_true(contains(cp, "def.control_label or def.label"), "row builder must prefer control_label while keeping the label-only fallback")
    assert_true(contains(decl, "control_label = \"Rotation (click to toggle)\""), "declarative host must carry the same click-to-toggle wording as main.lua")
    assert_true(contains(main, 'control:render(def.control_label or def.label'), "main-menu quick-toggle render must use the control_label wording")
    assert_true(contains(main, 'control_label = \"Rotation (click to toggle)\",'), "main.lua quick_toggle_defs must carry the click-to-toggle wording")

    -- Role change (dps) hides two toggles -> rebuilt with the smaller set.
    local e2 = make_cp_env("dps")
    CP_mod.register(e2)
    local r2a = CP_mod.render_legacy_rows()
    local r2b = CP_mod.render_legacy_rows()
    assert_true(r2a == r2b, "dps steady state also cached")
    assert_true(#r2a == 1, "dps sees only the damage-capable row (got " .. tostring(#r2a) .. ")")
    assert_true(r2a[1].name:find("Toggle One", 1, true) ~= nil, "remaining row is the damage toggle")

    -- Key-code change (user binds a real key) -> row shape changes -> rebuild.
    local e3 = make_cp_env("tank")
    CP_mod.register(e3)
    local r3a = CP_mod.render_legacy_rows()
    -- Bind the second toggle: 0x31 is a real key code, label gains the key name.
    e3.quick_toggle_defs[2].control = { get_key_code = function() return 49 end }
    local r3b = CP_mod.render_legacy_rows()
    assert_true(r3a ~= r3b, "key-code change rebuilds the cached row array")
    assert_true(#r3b == 3, "rebuild keeps all three rows")
    assert_true(r3b[2].name:find("49", 1, true) ~= nil, "bound row label shows the bound key name")
    assert_true(CP_mod.render_legacy_rows() == r3b, "post-rebuild steady state is cached again")
else
    error("ControlPanel.register missing — module failed to load for functional cache test")
end

print("PASS test_control_panel_v2_dual_path")
