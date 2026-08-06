-- test_sod_runtime_bootstrap.lua -- Production-entry SoD mode reachability.
-- WHAT:  boots main.lua with empty NS.settings and a persisted runtime mode.
-- WHEN:  run before class modules resolve during addon bootstrap.
-- WHY:   prevents synthetic fixture injection from hiding an unreachable SoD path.
-- SAFETY: real main.lua/core/settings/class-loader ordering; class files are local stubs.

local function assert_eq(actual, expected, label)
    if actual ~= expected then
        error((label or "assert_eq") .. ": " .. tostring(actual) .. " ~= " .. tostring(expected), 2)
    end
end

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;?.lua;" .. package.path
local fixture = require("tests/sod_runtime_fixture")

local NS, observed, attempts, ok, result = fixture.production_boot("Vanilla", {
    runtime_mode = "sod",
    sod_phase = 3,
})
local function schema_has(schema, key)
    for _, entry in ipairs(schema or {}) do
        if entry.key == key then return true end
        for _, section in ipairs(entry.sections or {}) do
            for _, setting in ipairs(section.settings or {}) do
                if setting.key == key then return true end
            end
        end
    end
    return false
end
assert_eq(ok, true, "real main.lua bootstrap must not fail: " .. tostring(result))
assert_eq(observed.initial_settings_empty, true, "class resolution must see empty initial NS.settings")
assert_eq(NS.is_sod(), true, "persisted runtime_mode must select SoD before class resolution")
assert_eq(schema_has(observed.schema, "sod_phase"), true, "SoD schema exposes phase settings")
assert_eq(observed.selected.runtime, "sod", "SoD class path")
assert_eq(#attempts, 1, "SoD must attempt exactly one class path")
assert_eq(attempts[1], "classes/rogue/combat_sod", "SoD class path must be exclusive")

local legacy_ns, legacy_observed, legacy_attempts, legacy_ok, legacy_result =
    fixture.production_boot("Vanilla", nil)
assert_eq(legacy_ok, true, "nil settings must not fail: " .. tostring(legacy_result))
assert_eq(legacy_ns.is_sod(), false, "nil settings must preserve legacy mode")
assert_eq(schema_has(legacy_observed.schema, "sod_phase"), false, "legacy schema excludes SoD settings")
assert_eq(legacy_observed.selected.runtime, "vanilla", "Vanilla legacy path")
assert_eq(#legacy_attempts, 1, "legacy mode must attempt exactly one class path")
assert_eq(legacy_attempts[1], "classes/rogue/combat_vanilla", "legacy class path must be preserved")

local malformed_ns, malformed_observed, malformed_attempts, malformed_ok, malformed_result =
    fixture.production_boot("Vanilla", { runtime_mode = {} })
assert_eq(malformed_ok, true, "malformed settings must not fail: " .. tostring(malformed_result))
assert_eq(malformed_ns.is_sod(), false, "malformed runtime_mode must fail closed")
assert_eq(malformed_observed.selected.runtime, "vanilla", "malformed mode legacy path")
assert_eq(#malformed_attempts, 1, "malformed mode must attempt exactly one class path")

local stale_ns, stale_observed, stale_attempts, stale_ok, stale_result =
    fixture.production_boot("Vanilla", { runtime_mode = "sod" }, { runtime_mode = "vanilla" })
assert_eq(stale_ok, true, "current runtime settings must beat stale persisted mode: " .. tostring(stale_result))
assert_eq(stale_ns.is_sod(), false, "stale persisted SoD mode must not override current legacy mode")
assert_eq(stale_observed.selected.runtime, "vanilla", "current legacy mode path")
assert_eq(#stale_attempts, 1, "stale mode must attempt exactly one class path")

local misleading_ns, misleading_observed, misleading_attempts, misleading_ok, misleading_result =
    fixture.production_boot("Vanilla", { runtime_mode = "Season of Discovery" })
assert_eq(misleading_ok, true, "noncanonical runtime mode must fail safely: " .. tostring(misleading_result))
assert_eq(misleading_ns.is_sod(), false, "noncanonical runtime mode must not select SoD")
assert_eq(misleading_observed.selected.runtime, "vanilla", "noncanonical mode legacy path")
assert_eq(#misleading_attempts, 1, "noncanonical mode must attempt exactly one class path")

print("PASS test_sod_runtime_bootstrap main.lua empty-settings SoD/nil/malformed/stale/misleading legacy")
