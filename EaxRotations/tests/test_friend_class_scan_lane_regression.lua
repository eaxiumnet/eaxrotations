-- test_friend_class_scan_lane_regression.lua — pins the lane unblocked by the
-- friend class-id scan (2026-08-07, ranked #4 from the focused triage).
-- WHAT:  druid/resto's innervate scan (find_priority_innervate ->
--        is_healer_entry -> unit_class_id -> NS.safe_field(unit, "get_class"))
--        could never find a healer ally: the battery friend mocks had no
--        get_class AND the ns.safe_field stub had the wrong (value, default)
--        shape (it returned the whole unit, so pcall(unit) errored -> nil).
--        Fixed: ns.safe_field now matches shared/safe_helpers_sylvanas.lua
--        (obj, key) semantics; the group scenarios carry `friend_class = 11`
--        which the _friend mock exposes as get_class. mana_tide_window
--        (low mana + healer friends) makes InnervateHealer fire; InnervateSelf
--        stays observable via the class-less low-mana scenarios
--        (low_mana/mana_critical) — no regression.
--        Lane pinned here (was never-firing):
--          druid/resto: InnervateHealer
-- WHEN:  rotation suite execution.
-- WHY:   a future battery edit could silently re-hide this lane; this test
--        fails if it stops firing (state + matcher + negative + end-to-end).
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

local function assert_lane_matches(spec_mod, ns, class_key, scenario_name, lane, label)
    local ctx, state = make_state(spec_mod, ns, class_key, scenario_name)
    local s = find_strategy(spec_mod.strategies, lane)
    assert_true(s ~= nil, class_key .. " " .. lane .. " strategy missing")
    local ok, m = pcall(s.matches, ctx, state)
    assert_true(ok, class_key .. " " .. lane .. " matcher crashed: " .. tostring(m))
    assert_true(m == true, label)
    return ctx, state
end

-- ============================================================================
-- druid/resto: InnervateHealer — gated on a non-self healer ally being found
-- via unit_class_id (get_class). Only mana_tide_window has the low-mana +
-- healer-friend combination.
-- ============================================================================
local resto, resto_err, resto_ns = aud.load_spec("druid", "resto")
assert_true(resto ~= nil, "druid/resto load failed: " .. tostring(resto_err))
-- Re-assert the current spec's ns: DSL condition evaluators (spell_ready /
-- buff) read _G.EaxRotations dynamically, so keep it pointed at resto_ns
-- regardless of assertion order.
_G.EaxRotations = resto_ns

local ih_ctx, ih_state = assert_lane_matches(resto, resto_ns, "druid", "mana_tide_window", "InnervateHealer",
    "druid/resto InnervateHealer must match in mana_tide_window (low-mana healer ally found)")
-- State-fidelity: this is the (class-scan-fix) mechanism — innervate_target
-- must be a healer ally, not the player.
assert_true(ih_state.innervate_target ~= nil,
    "druid/resto InnervateHealer needs state.innervate_target set, got nil")
assert_true(resto_ns.same_unit and not resto_ns.same_unit(ih_state.innervate_target, ih_ctx.me),
    "druid/resto InnervateHealer needs innervate_target to be a NON-self healer (the class scan)")
assert_true(type(ih_state.innervate_target.get_class) == "function"
    and ih_state.innervate_target:get_class() == 11,
    "druid/resto innervate_target must be the friend unit with get_class() == 11 (healer class-id scan)")
-- Negative assert: without healer-class friends (low_mana keeps friends
-- class-less), the scan falls back to self — InnervateHealer must stay silent.
local calm_ctx, calm_state = make_state(resto, resto_ns, "druid", "low_mana")
local ih = find_strategy(resto.strategies, "InnervateHealer")
local ok_calm, m_calm = pcall(ih.matches, calm_ctx, calm_state)
assert_true(ok_calm and m_calm ~= true,
    "druid/resto InnervateHealer must not match in low_mana (no healer-class friends) — class-scan gating regression")
print("PASS: druid/resto InnervateHealer regression (1 lane)")

-- ============================================================================
-- End-to-end: the battery must not report the cleared lane as never-firing.
-- ============================================================================
local report = aud.run_spec("druid", "resto")
assert_true(report ~= nil, "battery run for druid/resto failed")
for _, name in ipairs(report.never) do
    assert_true(name ~= "InnervateHealer",
        "battery still reports druid/resto InnervateHealer as never-firing")
end
print("PASS: battery reports InnervateHealer as firing")
