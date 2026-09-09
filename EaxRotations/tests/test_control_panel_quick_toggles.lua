-- test_control_panel_quick_toggles.lua -- control panel quick toggles tests.
-- WHAT:  control panel quick toggles tests
-- WHEN:  During rotation test suite execution.
-- WHY:   Protects against regressions in rotation logic and state handling.
-- SAFETY: Pure unit tests with mocked API context.
-- STRUCTURE (architecture pass 2026-09-06): the Control Panel row logic moved
-- from main.lua into shared/control_panel_sylvanas.lua. main.lua still owns
-- the quick_toggle_defs (widgets + labels) and the in-menu rendering; role
-- visibility policy lives in shared/menu_theme_sylvanas.lua (def_allowed).
-- Assertions below are split across those three files accordingly.

local function assert_true(v, label)
    if not v then error(label or "assert_true failed", 2) end
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

local main = read_file("EaxRotations/main.lua")
local cp = read_file("EaxRotations/shared/control_panel_sylvanas.lua")
local dispatcher = read_file("EaxRotations/main_sylvanas.lua")
local core = read_file("EaxRotations/core_sylvanas.lua")
local menu_theme = read_file("EaxRotations/shared/menu_theme_sylvanas.lua")

assert_true(contains(main, 'quick_toggles_tree = make_tree("eaxrot_quick_toggles")'), "main menu should have one Quick Toggles section")
assert_true(contains(main, "enable_script_check = core.menu.keybind"), "rotation enable should be a keybind toggle, not a separate checkbox")
assert_true(contains(main, 'key = "rotation_enabled"'), "rotation toggle should sync rotation_enabled")
assert_true(contains(main, 'key = "healing_enabled"'), "healing toggle should sync healing_enabled")
assert_true(contains(main, 'key = "damage_enabled"'), "damage toggle should sync damage_enabled")
assert_true(contains(main, 'key = "use_cooldowns"'), "cooldowns toggle should reuse use_cooldowns")
assert_true(contains(main, 'key = "aoe_enabled"'), "AoE toggle should sync aoe_enabled")
assert_true(contains(main, 'key = "use_interrupt"'), "interrupt toggle should reuse use_interrupt")
assert_true(contains(main, 'key = "utility_enabled"'), "utility toggle should sync utility_enabled")
assert_true(contains(main, 'key = "use_threat_drop"'), "threat drop toggle should reuse use_threat_drop")
assert_true(contains(main, "QUICK_TOGGLE_SETTING_KEYS") and contains(main, "return nil"), "schema widgets for quick-toggle keys should be skipped")
assert_true(contains(main, "local function read_quick_toggle"),
    "quick-toggle gates should resolve through one per-menu-mode helper")
assert_true(contains(main, "return get_keybind_toggle_state(def.control, default)"),
    "imperative-mode gate must still read the keybind widget directly for persistence")
assert_true(contains(main, "st[def.key]"),
    "declarative-mode gate must read the synced NS.settings value (imperative widgets are never rendered there)")

-- Control Panel row logic lives in shared/control_panel_sylvanas.lua and must
-- (a) register the legacy per-frame callback, (b) return rows that reference
-- the same keybind objects rendered in the main menu, and (c) use the helper
-- for drag/drop + duplicate handling. main.lua hands quick_toggle_defs to
-- ControlPanel.register(env) at load.
assert_true(contains(cp, "register_on_render_control_panel_callback") and contains(cp, "ControlPanel.render_legacy_rows"),
    "control panel callback should be registered by the control panel module")
assert_true(contains(cp, "keybind = def.control"), "control panel should return the same keybind objects rendered in the main menu")
assert_true(contains(cp, 'require, "common/utility/control_panel_helper"'), "control panel helper should be loaded from Sylvanas utility API")
assert_true(contains(cp, "control_panel_helper:insert_toggle_"), "control panel should use the helper for drag/drop and duplicate handling")
assert_true(contains(main, "control_panel_helper:on_update(menu_elements)"), "control panel helper update should run for drag/drop support")
assert_true(contains(main, "ControlPanel.register("), "main should hand the quick toggles to the control panel module at load")

-- Quick Toggles role-based visibility: the main-menu Quick Toggles must filter
-- toggles by the active playstyle's role, mirroring the Control Panel rows.
-- Otherwise a Cat (feral DPS) druid would see Healing and Auto Taunt, which it
-- can never use. Single policy: MenuTheme.def_allowed (menu_theme) consumed by
-- BOTH main.lua and shared/control_panel_sylvanas.lua.
assert_true(contains(main, 'capability = "auto_taunt"'), "auto_taunt quick toggle should declare a capability key")
-- Every role-filterable toggle must declare an explicit capability key that maps
-- to a ROLE_CAPABILITIES entry; otherwise the def.key fallback misses and the
-- toggle silently stays visible for roles that should hide it.
assert_true(contains(main, 'capability = "healing"'), "healing toggle should declare capability = healing")
assert_true(contains(main, 'capability = "damage"'), "damage toggle should declare capability = damage")
assert_true(contains(main, 'capability = "cooldowns"'), "cooldowns toggle should declare capability = cooldowns")
assert_true(contains(main, 'capability = "aoe"'), "aoe toggle should declare capability = aoe")
assert_true(contains(main, 'capability = "interrupts"'), "interrupts toggle should declare capability = interrupts")
assert_true(contains(main, 'capability = "utility"'), "utility toggle should declare capability = utility")
assert_true(contains(main, 'capability = "threat_drop"'), "threat drop toggle should declare capability = threat_drop")
assert_true(contains(menu_theme, "function MenuTheme.def_allowed("), "role-visibility policy should live in a single MenuTheme.def_allowed predicate")
assert_true(contains(menu_theme, "ROLE_CAPABILITIES[role]"), "def_allowed should resolve capabilities from ROLE_CAPABILITIES by role")
assert_true(contains(main, "MenuTheme.def_allowed(def, _quick_role)"), "main menu quick toggles should use MenuTheme.def_allowed")
assert_true(contains(cp, "MenuTheme.def_allowed(def, role)"), "control panel rows should use the same MenuTheme.def_allowed predicate")
-- menu_theme must expose auto_taunt in every role capability table so both the
-- main menu and Control Panel hide it for dps/healer and show it for tank/hybrid.
assert_true(contains(menu_theme, 'auto_taunt = false'), "ROLE_CAPABILITIES should disable auto_taunt for healer/dps roles")
assert_true(contains(menu_theme, 'auto_taunt = true'), "ROLE_CAPABILITIES should enable auto_taunt for tank/hybrid roles")

assert_true(contains(dispatcher, "strategy_allowed"), "dispatcher should gate strategies from quick toggles")
assert_true(contains(dispatcher, 'not spec_kit.setting_bool(context, "utility_enabled"'), "utility toggle should gate utility rows")
assert_true(contains(dispatcher, 'not spec_kit.setting_bool(context, "healing_enabled"'), "healing toggle should gate healing rows")
assert_true(contains(dispatcher, 'not spec_kit.setting_bool(context, "damage_enabled"'), "damage toggle should gate damage rows")
assert_true(contains(dispatcher, 'not spec_kit.setting_bool(context, "use_cooldowns"'), "cooldowns toggle should gate cooldown rows")
assert_true(contains(dispatcher, '"is_casting", "is_casting_spell"'), "dispatcher should accept base API and IZI casting flags")

assert_true(contains(core, 'spec_kit.setting_bool(context, "aoe_enabled", true) == false') and contains(core, "enemy_count or action.is_aoe"), "AoE toggle should gate action rows with enemy_count/is_aoe")

print("PASS test_control_panel_quick_toggles")
