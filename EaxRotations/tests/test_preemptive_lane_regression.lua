-- test_preemptive_lane_regression.lua — pins the 5 PreHeal / Preemptive*
-- lanes unblocked by the pushback scenario + state.entries fix (2026-08-07).
-- WHAT:  shared/preemptive_heal_sylvanas.lua's PreemptiveHeal.match reads
--        state.entries / state.count, but priest disc+holy and shaman/resto
--        build_state never stored the heal scan — so the prediction lanes
--        were dead in live play too, not just battery-hidden (druid/resto
--        and paladin/holy already store it). The battery also lacked a
--        GetEnemiesInRange stub, so `_check_pushback` was always false and
--        the PreHeal lanes could not fire in any scenario.
--        Fixed: `state.entries`/`state.count` now stored in disc/holy/resto
--        build_state + `pushback` scenario (enemy casting -> _check_pushback
--        true, tank 72 in the [60,95] PreHeal band).
--        Lanes pinned here (all previously never-firing):
--          priest/discipline:  PreHeal, PreemptiveGreaterHeal
--          priest/holy:        PreHeal, PreemptiveGreaterHeal
--          shaman/restoration: PreemptiveChainHeal
-- WHEN:  rotation suite execution.
-- WHY:   a future battery edit or spec refactor could silently re-hide these
--        lanes; this test fails if any of the 5 stops firing (state +
--        matcher + end-to-end battery never-list check).
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

local function build_scenario(class_key, name)
    for _, s in ipairs(aud.SCENARIOS) do
        if s.name == name then return s end
    end
    error("scenario not found: " .. name, 2)
end

local function make_state(spec_mod, ns, class_key, scenario_name)
    local ctx = aud.build_context_for(class_key, build_scenario(class_key, scenario_name))
    aud.apply_battery_state(ns, ctx, class_key)
    if spec_mod.build_state then
        local ok, st = pcall(spec_mod.build_state, ctx)
        assert_true(ok, class_key .. "/" .. scenario_name .. " build_state crashed: " .. tostring(st))
        if type(st) == "table" then return ctx, st end
    end
    return ctx, ctx
end

-- Assert the lane's matcher returns true in `scenario_name`; returns ctx+state
-- from THAT call so state-fidelity asserts are scoped to the right scenario
-- (module-level state tables are mutated in place by later build_state calls).
local function assert_lane_matches(spec_mod, ns, class_key, scenario_name, lane, label)
    local ctx, state = make_state(spec_mod, ns, class_key, scenario_name)
    local s = find_strategy(spec_mod.strategies, lane)
    assert_true(s ~= nil, class_key .. " " .. lane .. " strategy missing")
    local ok, m = pcall(s.matches, ctx, state)
    assert_true(ok, class_key .. " " .. lane .. " matcher crashed: " .. tostring(m))
    assert_true(m == true, label)
    return ctx, state
end

-- PreemptiveHeal.match reads state.entries/state.count; this is the
-- state-fidelity assert proving the (d) fix (storing the scan) is what's
-- driving the lane, not some other gate.
local function assert_entries_present(state, spec_label)
    assert_true(type(state.entries) == "table" and #state.entries >= 1,
        spec_label .. " state.entries must be a non-empty scan table (the (d) fix), got "
        .. tostring(state.entries))
    assert_true((state.count or 0) >= 1,
        spec_label .. " state.count must be >= 1, got " .. tostring(state.count))
end

-- ============================================================================
-- priest/holy: PreHeal (pushback-only) + PreemptiveGreaterHeal (entries-driven)
-- ============================================================================
local holy, holy_err, holy_ns = aud.load_spec("priest", "holy")
assert_true(holy ~= nil, "priest/holy load failed: " .. tostring(holy_err))
-- Re-assert the current spec's ns: DSL condition evaluators (spell_ready /
-- buff) read _G.EaxRotations dynamically, so keep it pointed at holy_ns
-- regardless of assertion order.
_G.EaxRotations = holy_ns

local ph_ctx, ph_state = assert_lane_matches(holy, holy_ns, "priest", "pushback", "PreHeal",
    "holy PreHeal must match in pushback (enemy casting -> _check_pushback true, tank 72 in [60,95])")
assert_entries_present(ph_state, "holy PreHeal")
-- PreHeal must NOT fire in a non-pushback group scenario (that is the point
-- of the new scenario: prediction only while being pushed back).
local calm_ctx, calm_state = make_state(holy, holy_ns, "priest", "group_critical")
local ph_calm = find_strategy(holy.strategies, "PreHeal")
local ok_calm, m_calm = pcall(ph_calm.matches, calm_ctx, calm_state)
assert_true(ok_calm and m_calm ~= true,
    "holy PreHeal must not match in group_critical (no pushback) — pushback gating regression")
local pg_ctx, pg_state = assert_lane_matches(holy, holy_ns, "priest", "group_critical", "PreemptiveGreaterHeal",
    "holy PreemptiveGreaterHeal must match in group_critical (state.entries populated)")
assert_entries_present(pg_state, "holy PreemptiveGreaterHeal")
print("PASS: priest/holy PreHeal + PreemptiveGreaterHeal regression (2 lanes)")

-- ============================================================================
-- priest/discipline: PreHeal (pushback-only) + PreemptiveGreaterHeal
-- ============================================================================
local disc, disc_err, disc_ns = aud.load_spec("priest", "discipline")
assert_true(disc ~= nil, "priest/discipline load failed: " .. tostring(disc_err))
_G.EaxRotations = disc_ns

local dp_ctx, dp_state = assert_lane_matches(disc, disc_ns, "priest", "pushback", "PreHeal",
    "discipline PreHeal must match in pushback (enemy casting + tank 72 in [60,95])")
assert_entries_present(dp_state, "discipline PreHeal")
local dg_ctx, dg_state = assert_lane_matches(disc, disc_ns, "priest", "group_critical", "PreemptiveGreaterHeal",
    "discipline PreemptiveGreaterHeal must match in group_critical (state.entries populated)")
assert_entries_present(dg_state, "discipline PreemptiveGreaterHeal")
print("PASS: priest/discipline PreHeal + PreemptiveGreaterHeal regression (2 lanes)")

-- ============================================================================
-- shaman/restoration: PreemptiveChainHeal
-- ============================================================================
local sham, sham_err, sham_ns = aud.load_spec("shaman", "restoration")
assert_true(sham ~= nil, "shaman/restoration load failed: " .. tostring(sham_err))
_G.EaxRotations = sham_ns

local pc_ctx, pc_state = assert_lane_matches(sham, sham_ns, "shaman", "group_light", "PreemptiveChainHeal",
    "shaman/restoration PreemptiveChainHeal must match in group_light (state.entries populated)")
assert_entries_present(pc_state, "shaman/restoration PreemptiveChainHeal")
print("PASS: shaman/restoration PreemptiveChainHeal regression (1 lane)")

-- ============================================================================
-- End-to-end: the battery must report none of the 5 lanes as never-firing.
-- ============================================================================
local function assert_lane_fires(class_key, spec, lane)
    local report = aud.run_spec(class_key, spec)
    assert_true(report ~= nil, "battery run for " .. class_key .. "/" .. spec .. " failed")
    for _, name in ipairs(report.never) do
        assert_true(name ~= lane,
            "battery still reports " .. class_key .. "/" .. spec .. " " .. lane .. " as never-firing")
    end
end
assert_lane_fires("priest", "holy", "PreHeal")
assert_lane_fires("priest", "holy", "PreemptiveGreaterHeal")
assert_lane_fires("priest", "discipline", "PreHeal")
assert_lane_fires("priest", "discipline", "PreemptiveGreaterHeal")
assert_lane_fires("shaman", "restoration", "PreemptiveChainHeal")
print("PASS: battery reports none of the 5 PreHeal/Preemptive lanes as never-firing")
