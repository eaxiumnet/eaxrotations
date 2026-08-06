-- test_sod_shared.lua - Happy-path contract for shared SoD rotation helpers.
-- WHAT:  proves action descriptors, phase gates, rune gates, and settings precedence.
-- WHEN:  run before adding class-specific Season of Discovery rotations.
-- WHY:   every SoD rotation needs the same fail-closed action availability boundary.
-- SAFETY: pure deterministic harness; no live API, files, or external state.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;./?.lua;" .. package.path

local spec_kit = require("shared/spec_kit_sylvanas")

local function assert_eq(actual, expected, label)
    if actual ~= expected then
        error((label or "assert_eq") .. ": " .. tostring(actual) .. " ~= " .. tostring(expected), 2)
    end
end

local function assert_true(value, label)
    if not value then error(label or "assert_true failed", 2) end
end

local define = spec_kit.define_sod_action_for_class({})
local gale_winds = assert(define("GaleWinds", 417135, {
    rune_id = 417135,
    min_phase = 4,
}))

assert_eq(gale_winds.action, 417135, "Task 1 DBC action ID is retained")
assert_eq(gale_winds.rune_id, 417135, "Task 1 rune ID is retained")
assert_eq(gale_winds.min_phase, 4, "minimum phase is retained")
assert_true(spec_kit.sod_action_available({
    settings = { sod_phase = 8 },
    sod_runes = { [417135] = true },
}, gale_winds), "equipped rune action is available in a supported phase")

assert_eq(spec_kit.sod_phase({ settings = { sod_phase = 6 } }), 6,
    "context setting supplies a valid phase")
assert_eq(spec_kit.sod_phase({ sod_phase = 5, settings = { sod_phase = 6 } }), 5,
    "normalized runtime context wins over settings")
assert_eq(spec_kit.sod_phase({}), spec_kit.SOD_PHASE_DEFAULT,
    "missing phase uses the deterministic current-phase default")
assert_true(spec_kit.has_sod_rune({ sod_runes = { [417135] = true } }, 417135),
    "normalized rune set supports constant-time membership")

local frostbolt = assert(define("Frostbolt", { 10181, 10180 }, { min_phase = 1 }))
assert_true(spec_kit.sod_action_available({ sod_phase = 1 }, frostbolt),
    "non-rune action remains available in its phase")

print("PASS test_sod_shared (action descriptors, phase/settings boundary, rune gate)")
