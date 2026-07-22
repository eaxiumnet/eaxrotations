-- test_mock_helper.lua — Regression tests for the shared test Mock helpers.
-- WHAT:  Ensures DefaultMeleeContext returns a usable context and merges overrides
--        without mutating the caller's table.
-- WHEN:  run_rotation_tests.lua.
-- WHY:   Prevents silent regressions in the shared test helper used by specs with
--        centralized generic guards (e.g., cat_sylvanas.lua::base_matches()).
-- SAFETY: Standalone; no live game data required.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local runner = require("EaxRotations/tests/test_runner_lib")
local Mock = runner.Mock

local assert_true = function(v, label) if not v then error(label or "assert_true failed", 2) end end
local assert_eq = function(a, b, label) if a ~= b then error((label or "assert_eq") .. ": " .. tostring(a) .. " ~= " .. tostring(b), 2) end end

print("=== test_mock_helper ===")

-- Default context provides required base_matches guard fields.
local ctx = Mock.DefaultMeleeContext()
assert_true(ctx.in_combat == true, "in_combat should default to true")
assert_true(ctx.has_valid_enemy_target == true, "has_valid_enemy_target should default to true")
assert_true(type(ctx.target) == "table", "target should be a table")
assert_true(ctx.target_ttd == 60, "target_ttd should default to 60")
assert_true(ctx.enemy_count == 1, "enemy_count should default to 1")
assert_true(ctx.combo_points == 0, "combo_points should default to 0")
assert_true(ctx.pooling == false, "pooling should default to false")
assert_true(ctx.is_behind == true, "is_behind should default to true")
assert_true(ctx.is_cat == true, "is_cat should default to true")
assert_true(ctx.stance == 3, "stance should default to 3")
assert_true(ctx.energy == nil, "energy should NOT be defaulted (falls back to me.get_power)")
assert_true(ctx.me.get_power() == 50, "me.get_power should default to 50")
assert_true(ctx.me.get_max_power() == 100, "me.get_max_power should default to 100")
assert_true(ctx.me.get_health_percentage() == 100, "me.get_health_percentage should default to 100")

-- Each call returns a fresh context table to prevent shared-state bugs.
local ctx_b = Mock.DefaultMeleeContext()
assert_true(ctx ~= ctx_b, "DefaultMeleeContext should return a fresh table per call")
assert_true(ctx.target ~= ctx_b.target, "DefaultMeleeContext should return a fresh target table per call")

-- Overrides are applied without mutating the caller's table.
local overrides = { energy = 20, combo_points = 5, me = { get_power = function() return 15 end } }
local original_overrides = { energy = 20, combo_points = 5, me = { get_power = function() return 15 end } }
local ctx2 = Mock.DefaultMeleeContext(overrides)
assert_eq(ctx2.energy, 20, "energy override should be applied")
assert_eq(ctx2.combo_points, 5, "combo_points override should be applied")
assert_eq(ctx2.me.get_power(), 15, "me.get_power override should be merged")
assert_eq(ctx2.me.get_max_power(), 100, "me.get_max_power should still come from default mock")
assert_true(overrides.me ~= nil, "overrides.me should not be mutated (nil-ed)")
assert_eq(overrides.me.get_power(), 15, "overrides.me.get_power should remain unchanged")

print("PASS test_mock_helper")
