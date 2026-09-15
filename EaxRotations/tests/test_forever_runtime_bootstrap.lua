-- test_forever_runtime_bootstrap.lua -- Production-entry Forever mode reachability.
-- WHAT:  boots main.lua with empty NS.settings and a persisted runtime mode.
-- WHEN:  run before class modules resolve during addon bootstrap.
-- WHY:   prevents synthetic fixture injection from hiding an unreachable Forever
--        path (World of Warcraft: Forever, beta 2026-09-17 / launch 2026-11-04).
--        Mirrors test_sod_runtime_bootstrap case-for-case, plus the era contract:
--        Forever is a vanilla SUPERSET — the class path must resolve _vanilla
--        (no _forever spec files exist yet) and NS.is_vanilla() must stay TRUE.
-- SAFETY: real main.lua/core/settings/class-loader ordering; class files are local stubs.

local function assert_eq(actual, expected, label)
    if actual ~= expected then
        error((label or "assert_eq") .. ": " .. tostring(actual) .. " ~= " .. tostring(expected), 2)
    end
end

local function assert_true(actual, label)
    if not actual then
        error((label or "assert_true") .. ": expected true, got " .. tostring(actual), 2)
    end
end

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;?.lua;" .. package.path
local fixture = require("tests/sod_runtime_fixture")

local NS, observed, attempts, ok, result = fixture.production_boot("WoW Forever", {
    runtime_mode = "forever",
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
assert_eq(NS.is_forever(), true, "persisted runtime_mode must select Forever before class resolution")
assert_eq(NS.is_vanilla(), true, "Forever is a vanilla superset: is_vanilla() stays TRUE")
assert_eq(NS.get_expansion_max_level(), 60, "Forever caps at 60")
assert_eq(observed.selected.runtime, "vanilla", "Forever class path resolves the _vanilla fallback (no _forever file yet)")
assert_eq(#attempts, 2, "Forever must attempt _forever first, then fall back to _vanilla")
assert_eq(attempts[1], "classes/rogue/combat_forever", "Forever chain must try _forever first")
assert_eq(attempts[2], "classes/rogue/combat_vanilla", "Forever chain must fall back to _vanilla")

-- Version-string detection: a Forever client version resolves the era with NO
-- runtime_mode override (pre-seeded detection for the 2.5.x-style beta build).
local version_ns, version_observed, version_attempts, version_ok, version_result =
    fixture.production_boot("WoW Forever", nil)
assert_eq(version_ok, true, "version-detected boot must not fail: " .. tostring(version_result))
assert_eq(version_ns.is_forever(), true, "a Forever version string must auto-select the forever era")
assert_eq(version_observed.selected.runtime, "vanilla", "version-detected Forever still resolves _vanilla")
assert_eq(#version_attempts, 2, "version-detected Forever uses the _forever -> _vanilla chain")

-- Legacy/no-settings boot on a Forever version must still land in the era.
local legacy_ns, legacy_observed, legacy_attempts, legacy_ok, legacy_result =
    fixture.production_boot("WoW Forever", nil)
assert_eq(legacy_ok, true, "nil settings must not fail: " .. tostring(legacy_result))
assert_eq(legacy_ns.is_forever(), true, "version detection does not depend on settings")
assert_eq(legacy_observed.selected.runtime, "vanilla", "Forever legacy path still resolves _vanilla")

-- Malformed runtime_mode on a non-Forever version must fail closed to the
-- legacy vanilla path (never accidentally select Forever).
local malformed_ns, malformed_observed, malformed_attempts, malformed_ok, malformed_result =
    fixture.production_boot("Vanilla", { runtime_mode = {} })
assert_eq(malformed_ok, true, "malformed settings must not fail: " .. tostring(malformed_result))
assert_eq(malformed_ns.is_forever(), false, "malformed runtime_mode must fail closed")
assert_eq(malformed_observed.selected.runtime, "vanilla", "malformed mode legacy path")

-- Noncanonical Forever labels must NOT select the era (same discipline as SoD:
-- "Season of Discovery" as a mode value fails closed). Users get the vanilla
-- fallback lane set, not a half-wired Forever mode.
local misleading_ns, misleading_observed, misleading_attempts, misleading_ok, misleading_result =
    fixture.production_boot("Vanilla", { runtime_mode = "WoW Forever" })
assert_eq(misleading_ok, true, "noncanonical runtime mode must fail safely: " .. tostring(misleading_result))
assert_eq(misleading_ns.is_forever(), false, "noncanonical mode must not select Forever")
assert_eq(misleading_observed.selected.runtime, "vanilla", "noncanonical mode legacy path")
assert_eq(#misleading_attempts, 1, "noncanonical mode must attempt exactly one class path")

-- Current runtime settings beat a stale persisted forever mode (SoD contract).
local stale_ns, stale_observed, stale_attempts, stale_ok, stale_result =
    fixture.production_boot("Vanilla", { runtime_mode = "forever" }, { runtime_mode = "vanilla" })
assert_eq(stale_ok, true, "current runtime settings must beat stale persisted mode: " .. tostring(stale_result))
assert_eq(stale_ns.is_forever(), false, "stale persisted forever mode must not override current legacy mode")
assert_eq(stale_observed.selected.runtime, "vanilla", "current legacy mode path")
assert_eq(#stale_attempts, 1, "stale mode must attempt exactly one class path")

print("PASS test_forever_runtime_bootstrap main.lua Forever/nil/malformed/misleading/stale era contract")
