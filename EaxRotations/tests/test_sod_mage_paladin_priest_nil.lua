-- test_sod_mage_paladin_priest_nil.lua -- Task 5 fail-closed rotation coverage.
-- WHAT: exercises malformed phase, absent rune, target, health, and healer state.
-- WHEN: run with the Task 5 happy-path suite.
-- WHY: prevents stale or incomplete runtime context from enabling SoD actions.
-- SAFETY: every production match function is invoked under pcall.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;?.lua;" .. package.path

local function assert_eq(actual, expected, label)
    if actual ~= expected then
        error((label or "assert_eq") .. ": " .. tostring(actual) .. " ~= " .. tostring(expected), 2)
    end
end

local fixture = require("tests/sod_runtime_fixture")
local _, context, ok = fixture.boot("Vanilla", {
    runtime_mode = "sod",
    sod_phase = 8,
}, function() return {} end)
assert_eq(ok, true, "SoD context must build")

local paths = {
    "classes/mage/dps_mage_sod",
    "classes/paladin/protection_sod",
    "classes/paladin/retribution_sod",
    "classes/priest/healing_sod",
    "classes/priest/shadow_sod",
}

for i = 1, #paths do
    package.loaded[paths[i]] = nil
    local rotation = require(paths[i])
    local empty_state = rotation.build_state(nil)
    for j = 1, #rotation.strategies do
        local passed, matched = pcall(rotation.strategies[j].matches, nil, empty_state)
        assert_eq(passed, true, paths[i] .. " nil match must not throw")
        assert_eq(matched, false, paths[i] .. " nil match must fail closed")
    end

    local malformed = {
        is_sod = true,
        in_combat = true,
        target = {},
        hp = nil,
        mana_pct = nil,
        sod_phase = "stale",
        sod_runes = {},
        lowest = nil,
    }
    local malformed_state = rotation.build_state(malformed)
    for j = 1, #rotation.strategies do
        local passed, matched = pcall(rotation.strategies[j].matches, malformed, malformed_state)
        assert_eq(passed, true, paths[i] .. " malformed match must not throw")
        assert_eq(matched, false, paths[i] .. " malformed phase must fail closed")
    end
end

print("PASS test_sod_mage_paladin_priest_nil (nil/malformed/absent-rune paths fail closed)")
