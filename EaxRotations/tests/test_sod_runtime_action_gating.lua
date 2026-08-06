-- test_sod_runtime_action_gating.lua -- Production SoD action gating.
-- WHAT:  loads the real Rogue SoD class module and evaluates its strategy.
-- WHEN:  run after runtime selection and shared helper tests.
-- WHY:   prevents shared SoD availability APIs from remaining test-only.
-- SAFETY: real production module/registry path with deterministic runtime mocks.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;?.lua;" .. package.path

local function assert_eq(actual, expected, label)
    if actual ~= expected then
        error((label or "assert_eq") .. ": " .. tostring(actual) .. " ~= " .. tostring(expected), 2)
    end
end

local fixture = require("tests/sod_runtime_fixture")
local NS, context, ok = fixture.boot("Vanilla", {
    runtime_mode = "sod",
    sod_phase = 7,
}, function()
    return { [409240] = true }
end)
assert_eq(ok, true, "SoD runtime context must build")

context.target = {}
context.enemy_count = 3
package.loaded["classes/rogue/combat_sod"] = nil
local rotation = require("classes/rogue/combat_sod")
assert_eq(type(rotation), "table", "real SoD class module must load")
assert_eq(NS.rotation_registry.playstyles.combat, rotation.strategies,
    "production class module must register through the real registry")

local strategy = rotation.strategies[1]
assert_eq(strategy.name, "FanOfKnives", "source-backed strategy name")
assert_eq(strategy.matches(context, rotation.build_state(context)), true,
    "equipped rune enables the production strategy")
assert_eq(rotation.action.rune_id, 409240, "FanOfKnives descriptor rune ID")
assert_eq(rotation.action.action._meta.id, 409240, "FanOfKnives resolved action ID")

local original_try_cast = NS.try_cast
local cast_calls = 0
local cast_action
NS.try_cast = function(action, target, reason)
    cast_calls = cast_calls + 1
    cast_action = action
    assert_eq(target, context.target, "execute target")
    assert_eq(reason, "[SOD COMBAT] FanOfKnives", "execute reason")
    return action == rotation.action.action
end
assert_eq(strategy.execute(context), true, "equipped rune execute path")
assert_eq(cast_calls, 1, "execute cast call count")
assert_eq(cast_action, rotation.action.action, "execute passes resolved action")
NS.try_cast = original_try_cast

local without_rune = {}
for key, value in pairs(context) do without_rune[key] = value end
without_rune.sod_runes = {}
assert_eq(strategy.matches(without_rune, rotation.build_state(without_rune)), false,
    "missing rune disables the production strategy")

local wrong_phase = {}
for key, value in pairs(context) do wrong_phase[key] = value end
wrong_phase.sod_phase = "stale phase"
assert_eq(strategy.matches(wrong_phase, rotation.build_state(wrong_phase)), false,
    "malformed phase disables the production strategy")

local nil_context = {}
assert_eq(strategy.matches(nil_context, rotation.build_state(nil_context)), false,
    "nil-like context disables the production strategy")

local legacy = {}
for key, value in pairs(context) do legacy[key] = value end
legacy.is_sod = false
assert_eq(strategy.matches(legacy, rotation.build_state(legacy)), false,
    "legacy runtime cannot execute the SoD strategy")

print("PASS test_sod_runtime_action_gating (real combat_sod module, registry, rune/phase/nil/legacy gates)")
