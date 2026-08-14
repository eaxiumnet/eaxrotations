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

-- W5.1 regression pin: the class-table shadow is REMOVED for SoD actions.
-- A same-named TBC class-table entry (Envenom/Mutilate/Lifebloom shape) must
-- NOT replace the explicit SoD ids passed to define_sod_action_for_class —
-- W4.2 unwrapped rich class entries for validation but still resolved the
-- action through the class table, so rogue SoD Envenom 399963 was silently
-- cast as TBC 32684 and druid SoD Lifebloom 409824 as TBC 33763.
local shadow_define = spec_kit.define_sod_action_for_class({
    Envenom = { _meta = { ids = { 32684, 32645 } }, ids = { 32684, 32645 } },
    Lifebloom = { 33763, 33762 },
    Mutilate = 34413,
})
local sod_envenom = assert(shadow_define("Envenom", 399963, { rune_id = 399963 }, "Envenom"))
assert_eq(sod_envenom.action, 399963,
    "explicit SoD rune id wins over same-named TBC class-table entry (rich form)")
local sod_lifebloom = assert(shadow_define("Lifebloom", 409824, { rune_id = 409824 }, "Lifebloom"))
assert_eq(sod_lifebloom.action, 409824,
    "explicit SoD rune id wins over same-named TBC class-table entry (ladder form)")
local sod_mutilate = assert(shadow_define("Mutilate", 399956, { rune_id = 399956 }, "Mutilate"))
assert_eq(sod_mutilate.action, 399956,
    "explicit SoD rune id wins over scalar TBC class-table entry")

print("PASS test_sod_shared (action descriptors, phase/settings boundary, rune gate, class-table shadow)")
