-- test_control_panel_quick_toggles.lua -- control panel quick toggles tests.
-- WHAT:  control panel quick toggles tests
-- WHEN:  During rotation test suite execution.
-- WHY:   Protects against regressions in rotation logic and state handling.
-- SAFETY: Pure unit tests with mocked API context.

-- static regression checks for global Control Panel quick toggles.

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
local dispatcher = read_file("EaxRotations/main_sylvanas.lua")
local core = read_file("EaxRotations/core_sylvanas.lua")

assert_true(contains(main, "quick_toggles_tree = core.menu.tree_node()"), "main menu should have one Quick Toggles section")
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
assert_true(contains(main, "register_on_render_control_panel_callback") and contains(main, "on_control_panel_render"), "control panel callback should be registered")
assert_true(contains(main, "keybind = def.control"), "control panel should return the same keybind objects rendered in the main menu")
assert_true(contains(main, 'require, "common/utility/control_panel_helper"'), "control panel helper should be loaded from Sylvanas utility API")
assert_true(contains(main, "control_panel_helper:insert_toggle_"), "control panel should use the helper for drag/drop and duplicate handling")
assert_true(contains(main, "control_panel_helper:on_update(menu_elements)"), "control panel helper update should run for drag/drop support")
assert_true(contains(main, 'get_keybind_toggle_state(menu_elements.enable_script_check'), "master rotation toggle should read widget directly for persistence")

assert_true(contains(dispatcher, "strategy_allowed"), "dispatcher should gate strategies from quick toggles")
assert_true(contains(dispatcher, 'not spec_kit.setting_bool(context, "utility_enabled"'), "utility toggle should gate utility rows")
assert_true(contains(dispatcher, 'not spec_kit.setting_bool(context, "healing_enabled"'), "healing toggle should gate healing rows")
assert_true(contains(dispatcher, 'not spec_kit.setting_bool(context, "damage_enabled"'), "damage toggle should gate damage rows")
assert_true(contains(dispatcher, 'not spec_kit.setting_bool(context, "use_cooldowns"'), "cooldowns toggle should gate cooldown rows")
assert_true(contains(dispatcher, '"is_casting", "is_casting_spell"'), "dispatcher should accept base API and IZI casting flags")

assert_true(contains(core, 'spec_kit.setting_bool(context, "aoe_enabled", true) == false') and contains(core, "enemy_count or action.is_aoe"), "AoE toggle should gate action rows with enemy_count/is_aoe")

print("PASS test_control_panel_quick_toggles")
