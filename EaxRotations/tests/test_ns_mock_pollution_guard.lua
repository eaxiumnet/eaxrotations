-- test_ns_mock_pollution_guard.lua — negative test for the require-time--        NS-caching fragility (survey item #2, 2026-08-09).
-- WHAT:  79 shared/*_sylvanas.lua modules capture `local NS = _G.EaxRotations`
--        at require() time, and a small set write back into whatever NS is
--        loaded (auto_tremor, dot_refresh [should_refresh_dot, is_dot_active],
--        execute_phase [is_execute_phase], melee_combat_math, combat_forecast_gate,
--        snapshot via the alias form). The dead NS write-backs (PurgeManager,
--        TTDTracker, mf_tick_compute, and the dot_refresh/execute_phase extras)
--        were removed by the never-called NS-member sweep (2026-08-11).
--        If a tool requires those modules while a MOCK NS is installed (the
--        battery's build_ns / apl_status's base_ns), the mock silently captures
--        module instances — the compute()-vs-battery pollution signature that
--        tools/spec_scorecard.lua tracks. The fix: mocks are marked
--        _EAX_MOCK and every write-back gates on `not _EAX_MOCK`, plus the
--        battery exposes a loud load-order guard (guard_shared_virgin) that
--        fails if any shared module was already loaded, and run_all
--        self-cleans so a second run_all in the same process starts virgin.
-- WHEN:  rotation suite execution (run_rotation_tests.lua).
-- WHY:   a future refactor could un-gate a write-back or let a tool preload
--        shared modules before the battery; this test fails loudly on either.
-- SAFETY: Pure unit test; requires two write-back modules under controlled
--        NS states and restores package.loaded via the runner's per-suite
--        snapshot/restore. The run_all self-clean check runs a 1-spec manifest
--        override (fast) and restores the real manifest afterwards.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local aud = require("tests.behavioral_audit")

local function assert_true(v, label) if not v then error(label or "assert_true failed", 2) end end

-- Evict every cached shared module so guard checks see a virgin namespace
-- (build_ns itself requires shared/spec_kit lazily, so evict between steps).
local function evict_shared()
    for k in pairs(package.loaded) do
        if type(k) == "string" and k:find("^shared/", 1) then
            package.loaded[k] = nil
        end
    end
end

-- ============================================================================
-- (1) Mock-NS write-back is HARMLESS: the battery mock (marked _EAX_MOCK) must
-- never receive module instances via require-time write-back. melee_combat_math
-- writes _G.EaxRotations.MeleeCombatMath = M — a field the mock does NOT
-- predefine, so `nil` after require proves the gate held (before the fix the
-- mock would carry the real module table).
-- ============================================================================
evict_shared()
local mock_ns = aud.build_ns("warrior", "sylvanas")
_G.EaxRotations = mock_ns
assert_true(mock_ns._EAX_MOCK == true, "battery mock must carry the _EAX_MOCK marker")

local mm = require("shared/melee_combat_math_sylvanas")
assert_true(type(mm) == "table" and type(mm.glancing_chance) == "function",
    "module must still export its API under a mock NS")
assert_true(mock_ns.MeleeCombatMath == nil,
    "mock NS must NOT capture the module instance via require-time write-back")
assert_true(mock_ns.glancing_chance == nil,
    "mock NS must NOT capture the module's function bindings")
print("PASS: mock-NS write-back is harmless (melee_combat_math skipped under _EAX_MOCK)")

-- ============================================================================
-- (2) Real-NS write-back is UNCHANGED: an unmarked NS (the live engine's table)
-- must still receive the bindings — zero behavioral change on real game paths.
-- ============================================================================
evict_shared()
local real_ns = {}  -- live engine NS: no _EAX_MOCK
_G.EaxRotations = real_ns
local mm2 = require("shared/melee_combat_math_sylvanas")
assert_true(real_ns.MeleeCombatMath == mm2,
    "real (unmarked) NS must still receive the write-back binding")
assert_true(real_ns.glancing_chance == mm2.glancing_chance,
    "real (unmarked) NS must still receive the function bindings")
print("PASS: real-NS write-back unchanged (live engine path intact)")

-- ============================================================================
-- (2b) The 9th write-back (adversarial review): snapshot_sylvanas binds via an
-- ALIAS (`local _G_NS = _G.EaxRotations; if _G_NS then _G_NS.SnapshotHelper = M`)
-- instead of the direct `_G.EaxRotations.FIELD = M` form. It must be gated the
-- same way — a mock NS must not receive SnapshotHelper either.
-- ============================================================================
evict_shared()
local mock2 = aud.build_ns("warrior", "sylvanas")
_G.EaxRotations = mock2
local snap = require("shared/snapshot_sylvanas")
assert_true(type(snap) == "table" and type(snap.should_upgrade) == "function",
    "snapshot_sylvanas must still export its API under a mock NS")
assert_true(mock2.SnapshotHelper == nil,
    "mock NS must NOT capture SnapshotHelper via the alias write-back")
print("PASS: 9th write-back (snapshot alias form) is harmless under _EAX_MOCK")

-- ============================================================================
-- (3) Loud load-order guard: preloading a shared module before the battery
-- fails loudly (pcall -> false + pollution-signature message); a virgin
-- namespace passes.
-- ============================================================================
evict_shared()
local ok_virgin, virgin_err = pcall(aud.guard_shared_virgin)
assert_true(ok_virgin == true, "guard must pass on a virgin namespace: " .. tostring(virgin_err))

local mm3 = require("shared/melee_combat_math_sylvanas")  -- now cached in package.loaded
local ok_pre, pre_err = pcall(aud.guard_shared_virgin)
assert_true(ok_pre == false, "guard must FAIL when a shared module was preloaded")
local msg = tostring(pre_err)
assert_true(msg:find("already loaded", 1, true) ~= nil, "error must name the preload: " .. msg)
assert_true(msg:find("pollution", 1, true) ~= nil, "error must cite the pollution signature: " .. msg)
print("PASS: preloaded shared module fails loudly (load-order guard)")

-- ============================================================================
-- (4) run_all self-cleaning: after a battery run, no shared module leaks into
-- package.loaded and the last mock is dropped from _G — so the scorecard's
-- second run_all('wotlk') in the same process starts virgin, and a later tool
-- can't silently capture a battery mock. Cheap: 1-spec manifest override.
-- ============================================================================
evict_shared()
local real_manifest = aud.ERA_MANIFESTS.sylvanas
-- 1-spec override so the full battery (31 specs) isn't run inside a unit test;
-- the scorecard's double-run pattern is what this exercises, cheaply.
-- The override is applied inside a pcall-protected block and ALWAYS restored,
-- so an assert failure can't leave the shared aud module's manifest mutated
-- for the rest of the runner process (the runner snapshots package.loaded, not
-- module internals, so a leaked override would corrupt subsequent suites).
aud.ERA_MANIFESTS.sylvanas = { warrior = { "arms" } }
local ok, err = pcall(function()
    local agg = aud.run_all("sylvanas")
    assert_true(agg ~= nil and agg.total == 1,
        "1-spec run_all must complete, got total=" .. tostring(agg and agg.total))
    local leaked = 0
    for k in pairs(package.loaded) do
        if type(k) == "string" and k:find("^shared/", 1) then leaked = leaked + 1 end
    end
    assert_true(leaked == 0, "run_all left " .. leaked .. " shared module(s) cached")
    assert_true(_G.EaxRotations == nil or _G.EaxRotations._EAX_MOCK ~= true,
        "run_all must drop the last battery mock from _G.EaxRotations")
    print("PASS: run_all self-cleans (no shared-module leak, mock dropped)")

    -- A second run_all in the same process must still start virgin (the
    -- scorecard runs TBC then WotLK back-to-back). Keep the 1-spec override.
    local agg2 = aud.run_all("sylvanas")
    assert_true(agg2 ~= nil and agg2.total == 1,
        "second in-process run_all must start virgin and complete")
    print("PASS: second run_all starts virgin (double-run scorecard pattern)")
end)
aud.ERA_MANIFESTS.sylvanas = real_manifest
assert_true(ok, "run_all self-clean check failed: " .. tostring(err))

print("ALL PASS: ns mock pollution guard (write-backs gated, guard loud, battery self-cleaning)")
