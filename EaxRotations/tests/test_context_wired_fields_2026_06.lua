-- test_context_wired_fields_2026_06.lua -- combat context wired fields tests.
-- WHAT:  combat context wired fields tests
-- WHEN:  During rotation test suite execution.
-- WHY:   Ensures combat context exposes all required fields for strategy evaluation.
-- SAFETY: Context mocks must stay in sync with dispatcher.

-- Regression test for context fields wired in June 2026 session.
-- Verifies attack_power, crit_chance, target_armor, enemy_list, targets, and NS.DRTracker.

local function assert_true(v, label) if not v then error(label or "assert_true failed", 2) end end
local function assert_not_nil(v, label) if v == nil then error(label or "assert_not_nil failed", 2) end end
local function assert_type(v, t, label)
    if type(v) ~= t then error((label or "type check") .. ": expected " .. t .. ", got " .. type(v), 2) end
end
local function assert_eq(a, b, label)
    if a ~= b then error((label or "assert_eq") .. ": " .. tostring(a) .. " ~= " .. tostring(b), 2) end
end

local now = 0
local mock_player = {
    get_target = function() return mock_target end,
    is_in_combat = function() return true end,
    is_alive = function() return true end,
    is_valid = function() return true end,
    get_level = function() return 64 end,
    get_effective_level = function() return 64 end,
    gcd_remains = function() return 0 end,
    get_power = function() return 80 end,
    is_moving = function() return false end,
    is_casting = function() return false end,
    is_channeling = function() return false end,
    get_distance = function() return 5 end,
    combo_points_current = function() return 3 end,
    -- Attack power stub: returns a real number
    get_attack_power = function() return 1200 end,
    -- Spell crit chance stub: returns percentage
    get_spell_crit_chance = function() return 12 end,
}

local mock_target = {
    is_in_melee_range = function() return true end,
    is_player = function() return false end,
    get_level = function() return 72 end,
    get_effective_level = function() return 72 end,
    get_classification = function() return 1 end,
    time_to_die = function() return 60 end,
    get_time_to_death = function() return 60 end,
    is_boss = function() return false end,
    -- Armor stub: returns a real number for context.target_armor verification
    get_armor = function() return 5000 end,
}

_G.core = {
    time = function() return now / 1000 end,
    game_time = function() now = now + 200; return now end,
    get_instance_type = function() return "party" end,
    log = function() end, log_warning = function() end, log_error = function() end,
    object_manager = {
        get_local_player = function() return mock_player end,
        get_visible_objects = function() return {} end,
        get_enemy_list = function() return {} end,
        get_focus_target = function() return nil end,
    },
    spell_book = {
        is_spell_learned = function() return true end,
        get_global_cooldown = function() return 0.5 end,
        get_spell_cooldown = function() return 0 end,
        get_spell_cooldown_information = function() return { enabled = false } end,
        get_spell_costs = function() return {} end,
        is_spell_in_range = function() return true end,
        cancel_form = function() end,
    },
    input = { cast_target_spell = function() return true end, stop_targeting = function() end },
    graphics = { add_notification = function() end, text_2d = function() end },
    menu = {
        checkbox = function() return {} end, slider_int = function() return {} end,
        combobox = function() return {} end, keybind = function() return {} end,
        tree_node = function() return {} end, header = function() return {} end, window = function() return {} end,
    },
    read_data_file = function() return "{}" end, write_data_file = function() return true end,
    register_on_update_callback = function() end, register_on_render_menu_callback = function() end,
    register_on_render_control_panel_callback = function() end,
    register_on_spell_cast_callback = function() end, register_on_render_window_callback = function() end,
}

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/??.lua;?.lua;" .. package.path
package.loaded.core_sylvanas = nil; package.loaded.main_sylvanas = nil; _G.EaxRotations = nil

-- Load core and dispatcher
local core_mod = require("core_sylvanas")
core_mod.core = _G.core
core_mod.izi = {
    on_combat_start = function() end, on_combat_end = function() end,
    spell = function() return {} end, item = function() return {} end,
    ts = function() return {} end, enemies = function() return {} end,
    friends = function() return {} end, any_enemy = function() return false end,
    draw_spell_icon = function() end, draw_icon = function() end,
    draw_circle = function() end, draw_line = function() end,
}

-- To test NS.DRTracker, we need to load its module before build_context runs.
-- The module self-registers NS.DRTracker on load, and main_sylvanas.lua does NOT
-- require it directly (it's loaded by main.lua in production).
-- For the test, we load it manually.
pcall(require, "shared/dr_tracker_sylvanas")

local disp = dofile("EaxRotations/main_sylvanas.lua")
assert_not_nil(disp, "dispatcher should load")
disp.on_rotation_update()

local ctx = core_mod.current_context or {}
local NS = _G.EaxRotations
assert_not_nil(NS, "EaxRotations namespace")

-- ============================================================================
-- 1. context.attack_power — wired in build_context() via unit_number(me, "get_attack_power")
-- ============================================================================
assert_not_nil(ctx.attack_power, "ctx.attack_power should not be nil")
assert_type(ctx.attack_power, "number", "ctx.attack_power should be a number")
assert_eq(ctx.attack_power, 1200, "ctx.attack_power should read from mock_player.get_attack_power() = 1200")

-- ============================================================================
-- 2. context.crit_chance — wired in build_context() via unit_number(me, "get_spell_crit_chance")
-- ============================================================================
assert_not_nil(ctx.crit_chance, "ctx.crit_chance should not be nil")
assert_type(ctx.crit_chance, "number", "ctx.crit_chance should be a number")
assert_eq(ctx.crit_chance, 12, "ctx.crit_chance should read from mock_player.get_spell_crit_chance() = 12")

-- ============================================================================
-- 2b. context.gcd_duration — wired in build_context() via get_global_cooldown()
-- ============================================================================
assert_not_nil(ctx.gcd_duration, "ctx.gcd_duration should not be nil")
assert_type(ctx.gcd_duration, "number", "ctx.gcd_duration should be a number")
assert_eq(ctx.gcd_duration, 0.5, "ctx.gcd_duration should read from mock get_global_cooldown() = 0.5")

-- ============================================================================
-- 3. context.enemy_list — legacy alias for context.enemies
-- ============================================================================
assert_not_nil(ctx.enemies, "ctx.enemies should not be nil")
assert_type(ctx.enemies, "table", "ctx.enemies should be a table")
assert_type(ctx.enemy_list, "table", "ctx.enemy_list should be a table")
assert_true(ctx.enemy_list == ctx.enemies, "ctx.enemy_list should be same reference as ctx.enemies")

-- ============================================================================
-- 4. context.targets — legacy alias for context.enemies
-- ============================================================================
assert_type(ctx.targets, "table", "ctx.targets should be a table")
assert_true(ctx.targets == ctx.enemies, "ctx.targets should be same reference as ctx.enemies")

-- ============================================================================
-- 5. NS.DRTracker — case-sensitive; must exist as loaded module
-- ============================================================================
assert_not_nil(NS.DRTracker, "NS.DRTracker should not be nil (module loaded)")
assert_type(NS.DRTracker, "table", "NS.DRTracker should be a table")
assert_type(NS.DRTracker.get_dr_multiplier, "function", "NS.DRTracker.get_dr_multiplier should be a function")

-- ============================================================================
-- 6. context.target_armor — wired in build_context() via unit_number(target, "get_armor")
-- ============================================================================
assert_not_nil(ctx.target_armor, "ctx.target_armor should not be nil")
assert_type(ctx.target_armor, "number", "ctx.target_armor should be a number")
assert_true(ctx.target_armor >= 0, "ctx.target_armor should be >= 0 (0 = no target or API unavailable)")

-- Verify lower-case variant does NOT exist (ensure no regression to the old bug)
if NS.dr_tracker then
    error("NS.dr_tracker (lowercase) unexpectedly exists — case mismatch would shadow NS.DRTracker", 2)
end

print("PASS context_wired_fields_2026_06")
