-- test_sod_shared_nil.lua - Failure-path contract for shared SoD rotation helpers.
-- WHAT:  rejects nil and malformed action, rune, and phase data.
-- WHEN:  run with the happy-path helper test and before class-specific SoD tests.
-- WHY:   unavailable runtime rune data must never enable rune-only actions.
-- SAFETY: pure deterministic harness; malformed fixtures are local tables only.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;./?.lua;" .. package.path

local spec_kit = require("shared/spec_kit_sylvanas")

local function assert_eq(actual, expected, label)
    if actual ~= expected then
        error((label or "assert_eq") .. ": " .. tostring(actual) .. " ~= " .. tostring(expected), 2)
    end
end

local function assert_false(value, label)
    if value then error(label or "assert_false failed", 2) end
end

local define = spec_kit.define_sod_action_for_class({})
local rune_action = assert(define("GaleWinds", 417135, { rune_id = 417135, min_phase = 4 }))

assert_false(spec_kit.has_sod_rune(nil, 417135), "nil context fails closed")
assert_false(spec_kit.has_sod_rune({}, 417135), "missing rune state fails closed")
assert_false(spec_kit.has_sod_rune({ sod_runes = "417135" }, 417135),
    "malformed rune state fails closed")
assert_false(spec_kit.has_sod_rune({ sod_runes = { [417135] = "yes" } }, 417135),
    "non-boolean rune membership fails closed")
assert_false(spec_kit.sod_action_available({ sod_phase = 8 }, rune_action),
    "missing rune state disables rune-only action")
assert_false(spec_kit.sod_action_available({ sod_phase = "phase 8", sod_runes = { [417135] = true } }, rune_action),
    "malformed explicit phase disables the action")
assert_false(spec_kit.sod_action_available({ sod_phase = 3, sod_runes = { [417135] = true } }, rune_action),
    "phase below minimum disables the action")
assert_false(spec_kit.sod_action_available(nil, nil), "nil descriptor fails closed")

local action, action_error = define("Broken", "417135", {})
assert_eq(action, nil, "string action ID is rejected")
assert_eq(action_error, "invalid action ids", "invalid action reports stable reason")
local rune, rune_error = define("BrokenRune", 417135, { rune_id = "417135" })
assert_eq(rune, nil, "string rune ID is rejected")
assert_eq(rune_error, "invalid rune id", "invalid rune reports stable reason")
local phase, phase_error = define("BrokenPhase", 417135, { min_phase = 9 })
assert_eq(phase, nil, "out-of-range phase is rejected")
assert_eq(phase_error, "invalid phase range", "invalid phase reports stable reason")

print("PASS test_sod_shared_nil (nil/malformed rune, phase, and action data fail closed)")
