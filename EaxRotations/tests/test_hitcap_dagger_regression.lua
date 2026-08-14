-- test_hitcap_dagger_regression.lua — pins the weapon-mock lane unblocked by
-- the equipped_daggers state-bank flag (2026-08-08 warrior/rogue triage, (c)
-- stat cluster; hit-cap half removed 2026-08-14, see below).
-- WHAT:  equipped_daggers (ctx key → state bank) — the get_equipped_item_id
--        stub returns dagger item id 776 (from shared/dagger_set DAGGER_IDS)
--        for MAIN_HAND/OFF_HAND when the flag is set, so assassination
--        build_state (assn:234-240 — reads both hands + is_dagger map) derives
--        state.has_daggers = true. Mutilate also needs energy_low false
--        (energy 90 default) + should_spend_energy true (default).
--        mutilate_daggers = { equipped_daggers = true }.
--        The lane fires EXCLUSIVELY in its scenario, so it is pinned with
--        fires-in(1) exclusivity + matcher asserts with sharp negatives +
--        end-to-end never-list checks.
-- WHEN:  rotation suite execution.
-- WHY:   a future battery edit (dropping the key, the dagger mock, or the
--        scenario) could silently re-hide the Mutilate lane; this test fails
--        if it stops firing or leaks into another scenario.
--        2026-08-14 (W5.1): the hit_rating half of this test was REMOVED —
--        the HitCapPriority lanes (combat/arms/fury/hunter BM/mage fire/
--        paladin retri) read context.hit_rating, which has NO producer in
--        the engine or API (no current-rating accessor exists in the PS
--        stubs; hit_cap_tracker is a static cap table). The lanes could
--        never fire in production; the battery mock (hit_cap_deficit
--        scenario + hit_rating ctx key) only made them battery-green. Per
--        Pattern 17 the lanes, the scenario, and the ctx key were deleted;
--        the Mutilate dagger mock stays because get_equipped_item_id IS a
--        live API surface the dagger lane can fire on.
-- SAFETY: Pure unit test with the behavioral_audit mock; no game data.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local aud = require("tests.behavioral_audit")

local function assert_true(v, label) if not v then error(label or "assert_true failed", 2) end end

local function find_strategy(strategies, name)
    for _, s in ipairs(strategies) do
        if s.name == name then return s end
    end
    return nil
end

local function build_scenario(name)
    for _, s in ipairs(aud.SCENARIOS) do
        if s.name == name then return s end
    end
    error("scenario not found: " .. name, 2)
end

local function make_state(spec_mod, ns, class_key, scenario_name)
    local ctx = aud.build_context_for(class_key, build_scenario(scenario_name))
    aud.apply_battery_state(ns, ctx, class_key)
    if spec_mod.build_state then
        local ok, st = pcall(spec_mod.build_state, ctx)
        assert_true(ok, class_key .. "/" .. scenario_name .. " build_state crashed: " .. tostring(st))
        if type(st) == "table" then return ctx, st end
    end
    return ctx, ctx
end

local function assert_lane(spec_mod, ns, class_key, scenario_name, lane, want, label)
    local ctx, state = make_state(spec_mod, ns, class_key, scenario_name)
    local s = find_strategy(spec_mod.strategies, lane)
    assert_true(s ~= nil, class_key .. " " .. lane .. " strategy missing")
    local ok, m = pcall(s.matches, ctx, state)
    assert_true(ok, class_key .. " " .. lane .. " matcher crashed: " .. tostring(m))
    assert_true(m == want, label)
    return ctx, state
end

-- ============================================================================
-- Mechanism pin: the equipped_daggers state-bank flag.
-- ============================================================================
local md_ctx = aud.build_context_for("rogue", build_scenario("mutilate_daggers"))
assert_true(md_ctx.equipped_daggers == true, "mutilate_daggers must set equipped_daggers")
print("PASS: mechanism — equipped_daggers flag wired")

-- ============================================================================
-- rogue/assassination: Mutilate (dagger mock)
-- ============================================================================
local assn, assn_err, assn_ns = aud.load_spec("rogue", "assassination")
assert_true(assn ~= nil, "rogue/assassination load failed: " .. tostring(assn_err))
_G.EaxRotations = assn_ns

local mt_ctx, mt_state = assert_lane(assn, assn_ns, "rogue", "mutilate_daggers", "Mutilate", true,
    "assassination Mutilate must match in mutilate_daggers (daggers equipped + energy 90)")
assert_true(mt_state.has_daggers == true,
    "mutilate_daggers must derive state.has_daggers true, got " .. tostring(mt_state.has_daggers))
assert_true(mt_state.energy_low == false,
    "mutilate_daggers must keep energy_low false (energy 90), got " .. tostring(mt_state.energy_low))
-- Negative: standard context has no daggers (get_equipped_item_id returns 0).
assert_lane(assn, assn_ns, "rogue", "standard", "Mutilate", false,
    "assassination Mutilate must NOT match in standard (no daggers)")
print("PASS: rogue/assassination Mutilate regression (dagger mock)")

-- ============================================================================
-- Exclusivity: Mutilate fires ONLY in mutilate_daggers.
-- ============================================================================
local function assert_exclusive(class_key, spec, lane, only_in)
    local report = aud.run_spec(class_key, spec)
    assert_true(report ~= nil, "battery run for " .. class_key .. "/" .. spec .. " failed")
    local fi = report.fires_in[lane]
    assert_true(fi ~= nil, class_key .. "/" .. spec .. " " .. lane .. " missing from fires_in")
    local n = 0
    for k in pairs(fi) do n = n + 1 end
    assert_true(n == 1 and fi[only_in] == true,
        class_key .. "/" .. spec .. " " .. lane .. " must fire ONLY in " .. only_in
        .. ", fired in " .. tostring(n) .. " scenarios")
end
assert_exclusive("rogue", "assassination", "Mutilate", "mutilate_daggers")
print("PASS: exclusivity — Mutilate fires only in mutilate_daggers")

-- ============================================================================
-- End-to-end: the battery must not report Mutilate as never-firing.
-- ============================================================================
local function assert_lane_fires(class_key, spec, lane)
    local report = aud.run_spec(class_key, spec)
    assert_true(report ~= nil, "battery run for " .. class_key .. "/" .. spec .. " failed")
    for _, name in ipairs(report.never) do
        assert_true(name ~= lane,
            "battery still reports " .. class_key .. "/" .. spec .. " " .. lane .. " as never-firing")
    end
end
assert_lane_fires("rogue", "assassination", "Mutilate")
print("PASS: battery does not report the Mutilate lane as never-firing")
print("ALL PASS: test_hitcap_dagger_regression")
