-- test_lights_grace_lane_regression.lua — pins the lane unblocked by the
-- per-buff state scenario (2026-08-07, ranked #2 from the focused triage).
-- WHAT:  behavioral_audit.lua gained a `buff_remains_map` override mechanism
--        ({ [buff_id] = seconds }) — ns.buff_remains / ns.has_player_buff now
--        honor it before the buffs_up fallback — plus a `lights_grace` scenario
--        setting buff_remains_map = { [31834] = 1.5 } (Light's Grace). paladin
--        holy LightGraceChain gates on `state.lights_grace_remains` in (0, 2.5)
--        (holy_sylvanas.lua:681-682, read via NS.buff_remains at :561); with the
--        default injured group (55/70/85) satisfying the tank-deficit gate, the
--        lane fires ONLY in the lights_grace scenario.
--        Lane pinned here (was never-firing):
--          paladin/holy: LightGraceChain
--        The same mechanism will serve future per-buff lanes (clearcasting,
--        Surge of Light, Inner Focus).
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
-- paladin/holy: LightGraceChain — gated on lights_grace_remains in (0, 2.5),
-- which only the per-buff `lights_grace` scenario provides.
-- ============================================================================
local holy, holy_err, holy_ns = aud.load_spec("paladin", "holy")
assert_true(holy ~= nil, "paladin/holy load failed: " .. tostring(holy_err))
-- Re-assert the current spec's ns: DSL condition evaluators (spell_ready /
-- buff) read _G.EaxRotations dynamically, so keep it pointed at holy_ns
-- regardless of assertion order.
_G.EaxRotations = holy_ns

local lg_ctx, lg_state = assert_lane_matches(holy, holy_ns, "paladin", "lights_grace", "LightGraceChain",
    "paladin/holy LightGraceChain must match in lights_grace (buff at 1.5s, injured tank)")
-- State-fidelity: this is the per-buff mechanism — the scenario's
-- buff_remains_map must land in state.lights_grace_remains within (0, 2.5).
assert_true(type(lg_state.lights_grace_remains) == "number"
    and lg_state.lights_grace_remains > 0 and lg_state.lights_grace_remains < 2.5,
    "paladin/holy LightGraceChain needs lights_grace_remains in (0, 2.5), got "
    .. tostring(lg_state.lights_grace_remains))
assert_true(lg_state.has_lights_grace == true,
    "paladin/holy lights_grace scenario must set has_lights_grace, got "
    .. tostring(lg_state.has_lights_grace))
assert_true(type(lg_state.tank) == "table" and (lg_state.tank.deficit or 0) > 0,
    "paladin/holy LightGraceChain needs tank.deficit > 0 (default injured group), got "
    .. tostring(lg_state.tank and lg_state.tank.deficit))
-- Id-scoping: the map must apply only to the configured buff id — an unrelated
-- id must still see 0 (pins that buff_remains_map is not a blanket "any buff"
-- flag).
assert_true(lg_ctx and holy_ns.buff_remains(holy_ns.PLAYER_UNIT, { 1 }) == 0,
    "buff_remains must return 0 for an unconfigured buff id in the lights_grace scenario")
-- Negative assert: without the per-buff scenario the chain gate (remains > 0)
-- must stay closed — the point of the dedicated scenario.
local calm_ctx, calm_state = make_state(holy, holy_ns, "paladin", "group_critical")
local chain = find_strategy(holy.strategies, "LightGraceChain")
local ok_calm, m_calm = pcall(chain.matches, calm_ctx, calm_state)
assert_true(ok_calm and m_calm ~= true,
    "paladin/holy LightGraceChain must not match in group_critical (no Light's Grace) — per-buff gating regression")
print("PASS: paladin/holy LightGraceChain regression (1 lane)")

-- ============================================================================
-- End-to-end: the battery must not report the cleared lane as never-firing.
-- ============================================================================
local report = aud.run_spec("paladin", "holy")
assert_true(report ~= nil, "battery run for paladin/holy failed")
for _, name in ipairs(report.never) do
    assert_true(name ~= "LightGraceChain",
        "battery still reports paladin/holy LightGraceChain as never-firing")
end
print("PASS: battery reports LightGraceChain as firing")
