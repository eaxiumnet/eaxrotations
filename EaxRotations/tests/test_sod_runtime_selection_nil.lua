-- test_sod_runtime_selection_nil.lua -- SoD malformed and unavailable runtime inputs.
-- WHAT:  verifies fail-closed rune state, phase fallback, and no legacy loader fallback.
-- WHEN:  run standalone or from the rotation suite.
-- WHY:   rune-only actions must stay disabled when runtime state is unavailable.
-- SAFETY: fully mocked; provider errors are contained and module attempts are recorded.

local function assert_eq(actual, expected, label)
    if actual ~= expected then
        error((label or "assert_eq") .. ": " .. tostring(actual) .. " ~= " .. tostring(expected), 2)
    end
end

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;?.lua;" .. package.path

local fixture = require("tests/sod_runtime_fixture")
local NS, context, ok = fixture.boot("SoD", { sod_phase = "bad" }, function()
    error("rune API unavailable")
end)

assert_eq(ok, true, "rune provider failure must not crash")
assert_eq(NS.is_sod(), true, "short SoD identity")
assert_eq(context.sod_phase, 8, "deterministic current-phase fallback")
assert_eq(type(context.sod_runes), "table", "nil-safe rune state")
assert_eq(next(context.sod_runes), nil, "failed rune API enables no runes")

local original_require = require
local attempts = {}
function require(path)
    if path == "shared/class_loader_sylvanas" then return original_require(path) end
    if path:match("^classes/warrior/") then
        attempts[#attempts + 1] = path
        error("module '" .. path .. "' not found", 0)
    end
    return original_require(path)
end

package.loaded["shared/class_loader_sylvanas"] = nil
local loader = require("shared/class_loader_sylvanas")
assert_eq(loader.create_expansion_loader("warrior", "Warrior")("arms", true), nil, "missing optional SoD module")
assert_eq(#attempts, 1, "missing SoD loader attempt count")
assert_eq(attempts[1], "classes/warrior/arms_sod", "missing SoD must not fall back")
require = original_require

local _, nil_context, nil_ok = fixture.boot("Season of Discovery", nil, nil)
assert_eq(nil_ok, true, "nil settings and rune provider must not crash")
assert_eq(nil_context.sod_phase, 8, "nil settings phase fallback")
assert_eq(next(nil_context.sod_runes), nil, "nil rune provider enables no runes")

local legacy_NS, legacy_context, legacy_ok = fixture.boot("Vanilla", { runtime_mode = {} }, nil)
assert_eq(legacy_ok, true, "malformed runtime mode must not crash")
assert_eq(legacy_NS.is_sod(), false, "malformed runtime mode must not select SoD")
assert_eq(legacy_NS.is_vanilla(), true, "malformed runtime mode preserves Vanilla")
assert_eq(legacy_context.sod_phase, nil, "legacy context has no SoD phase")
assert_eq(next(legacy_context.sod_runes), nil, "legacy context enables no SoD runes")

print("PASS test_sod_runtime_selection_nil")
