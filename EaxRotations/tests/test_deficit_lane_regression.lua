-- test_deficit_lane_regression.lua — pins the lane unblocked by the heal-scan
-- deficit fix (2026-08-07, ranked #1 from the focused follow-up triage).
-- WHAT:  behavioral_audit.lua's heal-scan entry builder hardcoded
--        `deficit = 0` / `effective_deficit = 0` even when an entry was
--        injured (effective_hp 70 -> deficit_of -> 0), so every
--        `deficit_of(...) > 0` gate was battery-dead. Real heal modules set
--        `deficit = max_hp - current_hp` (shaman/healing_sylvanas.lua:84,
--        paladin/heal_helper_sylvanas.lua:80). The battery now computes
--        `deficit = max(0, 100 - effective_hp)` (percentage scale, consistent
--        with effective_hp) for both friend and player scan entries.
--        Lane pinned here (was never-firing):
--          paladin/holy: LightGraceBuild
--        Note: LightGraceChain is STILL never — it additionally gates on
--        `lights_grace_remains` in (0, 2.5), which needs the per-buff state
--        scenario (ranked item #2), not the deficit fix.
-- WHEN:  rotation suite execution.
-- WHY:   a future battery edit could silently re-hide this lane; this test
--        fails if it stops firing (state + matcher + end-to-end).
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
-- paladin/holy: LightGraceBuild — gated on deficit_of(tank) > 0, which was
-- battery-dead while the heal-scan entries hardcoded deficit = 0.
-- ============================================================================
local holy, holy_err, holy_ns = aud.load_spec("paladin", "holy")
assert_true(holy ~= nil, "paladin/holy load failed: " .. tostring(holy_err))
-- Re-assert the current spec's ns: DSL condition evaluators (spell_ready /
-- buff) read _G.EaxRotations dynamically, so keep it pointed at holy_ns
-- regardless of assertion order.
_G.EaxRotations = holy_ns

local lg_ctx, lg_state = assert_lane_matches(holy, holy_ns, "paladin", "group_critical", "LightGraceBuild",
    "paladin/holy LightGraceBuild must match in group_critical (injured tank, deficit > 0)")
-- State-fidelity: this is the (deficit-fix) mechanism — the tank entry must
-- carry a positive deficit for the deficit_of(tank) > 0 gate to pass.
assert_true(type(lg_state.tank) == "table" and (lg_state.tank.deficit or 0) > 0,
    "paladin/holy LightGraceBuild needs tank.deficit > 0 (the deficit fix), got "
    .. tostring(lg_state.tank and lg_state.tank.deficit))
-- The build lane also requires Light's Grace NOT be expiring (remains > 5
-- skips); the battery default (0) is in the build band.
assert_true((lg_state.lights_grace_remains or 0) <= 5,
    "paladin/holy LightGraceBuild needs lights_grace_remains <= 5 (build band), got "
    .. tostring(lg_state.lights_grace_remains))
print("PASS: paladin/holy LightGraceBuild regression (1 lane)")

-- ============================================================================
-- End-to-end: the battery must not report the cleared lane as never-firing.
-- ============================================================================
local report = aud.run_spec("paladin", "holy")
assert_true(report ~= nil, "battery run for paladin/holy failed")
for _, name in ipairs(report.never) do
    assert_true(name ~= "LightGraceBuild",
        "battery still reports paladin/holy LightGraceBuild as never-firing")
end
print("PASS: battery reports LightGraceBuild as firing")
