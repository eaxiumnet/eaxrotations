-- test_ema_ttd_fallback.lua -- time-to-death fallback logic tests.
-- WHAT:  time-to-death fallback logic tests
-- WHEN:  During rotation test suite execution.
-- WHY:   Validates time-to-death gating to avoid clipping DoTs on short-lived targets.
-- SAFETY: Uses synthetic TTD values.

-- ============================================================================
-- Test: EMA TTD nil-fallback path in build_context
--
-- Tests the TTD fallback chain in main_sylvanas.lua build_context():
--
--   1st: EMA TTD  (ttd_ema_tracker_sylvanas)
--   2nd: Regression TTD (ttd_tracker_sylvanas - linear regression)
--   3rd: Engine TTD (target:time_to_die())
--   4th: nil -> ttd=999, ttd_known=false
--
-- Each scenario configures the relevant sources to return nil or a value,
-- then verifies the correct source is selected and context.ttd + ttd_known
-- are set correctly.
-- ============================================================================

local function assert_eq(a, b, label)
    if a ~= b then
        error((label or "assert_eq") .. ": " .. tostring(a) .. " ~= " .. tostring(b), 2)
    end
end
local function assert_true(v, label)
    if not v then error((label or "assert_true") .. ": got " .. tostring(v), 2) end
end
local function assert_near(a, b, tol, label)
    if math.abs(a - b) > tol then
        error((label or "assert_near") .. ": " .. tostring(a) .. " not near " .. tostring(b) .. " (tol=" .. tostring(tol) .. ")", 2)
    end
end

local current_time = 100
local test_target = nil

-- ============================================================================
-- Mock TTD modules (pre-loaded into package.loaded before dispatcher loads)
-- ============================================================================
-- These use mutable shared-state flags so behavior can change between
-- scenarios WITHOUT re-loading the entire dispatcher.

local ema_return_ttd = nil      -- What get_ttd() returns
local ema_hit_count = 0         -- Spy: how many times update/get_ttd called
local regression_return_ttd = nil
local regression_hit_count = 0

local mock_ema = {
    update = function(target, now)
        ema_hit_count = ema_hit_count + 1
        return { incoming_dps = 0, sample_count = 0, elapsed = 0, reliable = false }
    end,
    get_ttd = function(target, now)
        ema_hit_count = ema_hit_count + 1
        return ema_return_ttd
    end,
    get_incoming_dps = function(target) return 0 end,
    clear_all = function() end,
}

local mock_regression = {
    update = function(target, now, settings)
        regression_hit_count = regression_hit_count + 1
        return regression_return_ttd
    end,
    clear_all = function() end,
}

-- ============================================================================
-- Shared mocks
-- ============================================================================
local _player = {
    get_target = function() return test_target end,
    is_in_combat = function() return true end,
    is_alive = function() return true end, is_valid = function() return true end,
    get_level = function() return 70 end,
    get_effective_level = function() return 70 end,
    get_distance = function() return 5 end,
    get_power = function() return 100 end,
    is_moving = function() return false end,
    is_casting = function() return false end,
    is_channeling = function() return false end,
    combo_points_current = function() return 0 end,
}

_G.core = {
    time = function() return current_time / 1000 end,
    game_time = function() current_time = current_time + 0.2; return current_time * 1000 end,
    get_instance_type = function() return "none" end,
    log = function() end, log_warning = function() end, log_error = function() end,
    object_manager = {
        get_local_player = function() return _player end,
        get_visible_objects = function() return {} end,
        get_enemy_list = function() return {} end,
        get_focus_target = function() return nil end,
    },
    spell_book = {
        is_spell_learned = function() return true end,
        get_global_cooldown = function() return 0 end,
        get_spell_cooldown = function() return 0 end,
        get_spell_cooldown_information = function() return { enabled = false } end,
        get_spell_costs = function() return {} end,
        is_spell_in_range = function() return true end,
        cancel_form = function() end,
    },
    input = { cast_target_spell = function() return true end, stop_targeting = function() end },
    graphics = { add_notification = function() end, text_2d = function() end },
    menu = { checkbox = function() return {} end, slider_int = function() return {} end,
        combobox = function() return {} end, keybind = function() return {} end,
        tree_node = function() return {} end, header = function() return {} end,
        window = function() return {} end },
    read_data_file = function() return "{}" end, write_data_file = function() return true end,
    register_on_update_callback = function() end, register_on_render_menu_callback = function() end,
    register_on_render_control_panel_callback = function() end,
    register_on_spell_cast_callback = function() end, register_on_render_window_callback = function() end,
}

-- ============================================================================
-- Helper: create a target object with specified properties
-- ============================================================================
local function make_target(level, is_boss, engine_ttd)
    local t = {
        get_effective_level = function() return level end,
        get_level = function() return level end,
        get_classification = function() return is_boss and 3 or 1 end,
        is_player = function() return false end,
        is_in_melee_range = function() return true end,
        get_guid = function() return "mock_target_guid" end,
        guid = "mock_target_guid",
        id = "mock_target_guid",
        _hp_pct = 100,
    }
    if is_boss then
        t.is_boss = function() return true end
    end
    if engine_ttd ~= nil then
        t.time_to_die = function() return engine_ttd end
        t.get_time_to_death = function() return engine_ttd end
    end
    return t
end

-- ============================================================================
-- Load modules once with pre-loaded mock TTD modules
-- ============================================================================
package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/??.lua;?.lua;" .. package.path

package.loaded["shared/ttd_ema_tracker_sylvanas"] = mock_ema
package.loaded["shared/ttd_tracker_sylvanas"] = mock_regression
package.loaded.core_sylvanas = nil
package.loaded.main_sylvanas = nil
_G.EaxRotations = nil

local NS = require("core_sylvanas")
NS.core = _G.core
NS.izi = {
    on_combat_start = function() end, on_combat_end = function() end,
    spell = function() return {} end, item = function() return {} end,
    ts = function() return {} end, enemies = function() return {} end,
    friends = function() return {} end, any_enemy = function() return false end,
    draw_spell_icon = function() end, draw_icon = function() end,
    draw_circle = function() end, draw_line = function() end,
}
_G.EaxRotations = NS

local disp = dofile("EaxRotations/main_sylvanas.lua")
assert_true(disp ~= nil, "dispatcher should load")

-- Required for valid_enemy() check in build_context
NS.is_hostile_unit = function() return true end

-- ============================================================================
-- Helper: reset counters and run build_context
-- Defined here (after NS is loaded) so the closure captures the local NS.
-- ============================================================================
local function run_build_context(target)
    current_time = 100
    ema_hit_count = 0
    regression_hit_count = 0
    test_target = target
    NS.on_rotation_update()
    local ctx = NS.current_context or {}
    return ctx
end

-- ============================================================================
-- Scenario 1: All sources nil -> ttd=999, ttd_known=false
-- ============================================================================
-- Target: level 72, NOT boss, no engine TTD
-- EMA: returns nil (no combat log data)
-- Regression: NOT attempted (non-boss target)
-- Engine: nil (no time_to_die on target)
-- Expected: ttd = 999, ttd_known = false
ema_return_ttd = nil
regression_return_ttd = nil
test_target = make_target(72, false, nil)  -- non-boss, no engine TTD

local ctx = run_build_context(test_target)
assert_eq(ctx.ttd, 999, "ttd should default to 999 when all sources nil")
assert_eq(ctx.ttd_known, false, "ttd_known should be false when all sources nil")
assert_eq(ctx.ttd_source, "none", "ttd_source should be 'none' when all sources nil")
print("PASS ema_ttd_all_nil_defaults_999")

-- ============================================================================
-- Scenario 2: EMA works -> uses EMA TTD
-- ============================================================================
-- Target: level 72, not boss
-- EMA: returns 45
-- Regression: NOT attempted (non-boss)
-- Engine: nil
-- Expected: ttd = 45, ttd_known = true, source = "ema"
ema_return_ttd = 45
regression_return_ttd = nil
test_target = make_target(72, false, nil)

ctx = run_build_context(test_target)
assert_eq(ctx.ttd, 45, "ttd should be 45 when EMA returns 45")
assert_eq(ctx.ttd_known, true, "ttd_known should be true when EMA has data")
assert_eq(ctx.ttd_source, "ema", "ttd_source should be 'ema'")
assert_true(ema_hit_count > 0, "EMA update should have been called")
print("PASS ema_ttd_ema_source")

-- ============================================================================
-- Scenario 3: EMA nil, regression works (boss target) -> uses regression
-- ============================================================================
-- Target: level 72, IS boss, no engine TTD
-- EMA: nil
-- Regression: attempted (boss), returns 30
-- Engine: nil
-- Expected: ttd = 30, ttd_known = true, source = "regression"
ema_return_ttd = nil
regression_return_ttd = 30
test_target = make_target(72, true, nil)

ctx = run_build_context(test_target)
assert_eq(ctx.ttd, 30, "ttd should be 30 when regression returns 30")
assert_eq(ctx.ttd_known, true, "ttd_known should be true when regression has data")
assert_eq(ctx.ttd_source, "regression", "ttd_source should be 'regression'")
assert_true(regression_hit_count > 0, "Regression update should have been called")
print("PASS ema_ttd_regression_source")

-- ============================================================================
-- Scenario 4: EMA nil, regression nil (but attempted), engine works -> engine
-- ============================================================================
-- Target: level 72, IS boss, engine TTD = 15
-- EMA: nil
-- Regression: attempted (boss), returns nil
-- Engine: 15
-- Expected: ttd = 15, ttd_known = true, source = "engine"
ema_return_ttd = nil
regression_return_ttd = nil
test_target = make_target(72, true, 15)

ctx = run_build_context(test_target)
assert_eq(ctx.ttd, 15, "ttd should be 15 from engine")
assert_eq(ctx.ttd_known, true, "ttd_known should be true when engine has data")
assert_eq(ctx.ttd_source, "engine", "ttd_source should be 'engine'")
print("PASS ema_ttd_engine_source")

-- ============================================================================
-- Scenario 5: EMA nil, regression NOT attempted (equal level non-boss),
--             engine works -> engine used directly
-- ============================================================================
-- Target: level 70 (== player level), NOT boss, engine TTD = 20
-- EMA: nil
-- Regression condition: is_target_boss=false, target_level(70) > player_level(70)=false
--   -> regression NOT attempted
-- Engine: 20
-- Expected: ttd = 20, ttd_known = true, source = "engine"
-- (regression_hit_count is reset to 0 by run_build_context, stays 0 if not called)
ema_return_ttd = nil
regression_return_ttd = nil
test_target = make_target(70, false, 20)

ctx = run_build_context(test_target)
assert_eq(ctx.ttd, 20, "ttd should be 20 from engine")
assert_eq(ctx.ttd_known, true, "ttd_known should be true")
assert_eq(ctx.ttd_source, "engine", "ttd_source should be 'engine'")
-- Regression should NOT have been hit (non-boss, level <= player)
assert_eq(regression_hit_count, 0, "regression should NOT have been called for equal-level non-boss")
print("PASS ema_ttd_engine_non_boss_equal_level")

-- ============================================================================
-- Scenario 6: EMA nil, regression attempted (higher level non-boss) -> regression
-- ============================================================================
-- Target: level 73 (> player 70), NOT boss, no engine TTD
-- EMA: nil
-- Regression condition: is_target_boss=false, target_level(73) > player_level(70)=true
--   -> regression IS attempted
-- Regression: returns 40
-- Engine: nil
-- Expected: ttd = 40, ttd_known = true, source = "regression"
ema_return_ttd = nil
regression_return_ttd = 40
test_target = make_target(73, false, nil)

ctx = run_build_context(test_target)
assert_eq(ctx.ttd, 40, "ttd should be 40 from regression")
assert_eq(ctx.ttd_known, true, "ttd_known should be true")
assert_eq(ctx.ttd_source, "regression", "ttd_source should be 'regression'")
print("PASS ema_ttd_regression_higher_level_non_boss")

-- ============================================================================
-- Scenario 7: ttd_source='none', ttd_known=false, require_ttd=true action
--             -> blocked by action_matches (tier 1: require_ttd + !ttd_known)
--
-- This verifies that when no TTD data is available (all sources nil),
-- strategies with require_ttd=true are correctly suppressed rather than
-- using the 999-second fallback and firing prematurely.
-- ============================================================================
-- Target: level 72, NOT boss, no engine TTD (same as Scenario 1)
-- EMA: nil, Regression: nil, Engine: nil
-- Action: MinTTD=10, RequireTTD=true
-- Expected: action_matches returns false (blocked by require_ttd + ttd_known=false)
ema_return_ttd = nil
regression_return_ttd = nil
local require_ttd_action = {
    name = "TestRequireTTD",
    spell = 12345,
    min_ttd = 10,
    require_ttd = true,
}
test_target = make_target(72, false, nil)

ctx = run_build_context(test_target)
assert_eq(ctx.ttd_source, "none", "ttd_source should be 'none' for S7 precond")
assert_eq(ctx.ttd_known, false, "ttd_known should be false for S7 precond")

local matched = NS.action_matches(ctx, require_ttd_action)
assert_eq(matched, false, "action_matches should return false when require_ttd=true and ttd_known=false")
print("PASS ema_ttd_require_ttd_blocks_on_unknown")

-- ============================================================================
-- Scenario 8: ttd_source='none', ttd=999, ttd_known=false, min_ttd=10
--             WITHOUT require_ttd -> action_matches passes (falls through)
--
-- Positive control: when require_ttd is NOT set, the action should still
-- be executable even when ttd_known=false, because min_ttd=10 and ttd=999
-- means (999 < 10) is false -> tier 2 does not block.
-- ============================================================================
local no_require_ttd_action = {
    name = "TestNoRequireTTD",
    spell = 12345,
    min_ttd = 10,
    -- NO require_ttd --
}

test_target = make_target(72, false, nil)
ctx = run_build_context(test_target)
assert_eq(ctx.ttd_source, "none", "ttd_source should be 'none' for S8 precond")
assert_eq(ctx.ttd_known, false, "ttd_known should be false for S8 precond")

matched = NS.action_matches(ctx, no_require_ttd_action)
assert_eq(matched, true, "action_matches should return true when require_ttd is nil and ttd=999 >= min_ttd=10")
print("PASS ema_ttd_no_require_ttd_allows_999")

-- ============================================================================
-- Done
-- ============================================================================
print("PASS test_ema_ttd_fallback")
