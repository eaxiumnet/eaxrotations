-- test_pvp_disarm_regression.lua — pins the lane unblocked by the
-- close-out triage ranked #2 battery upgrade (2026-08-08):
--   warrior/protection  Disarm  (pvp_disarm scenario)
-- WHAT:  behavioral_audit.lua now (a) adds a scenario-conditional
--        target:get_class() (only when ctx.target_class is set — mirrors the
--        friend_class pattern, so warlock ShadowWard {5,9} and hunter
--        ViperSting middleware class reads are untouched), (b) adds the
--        target_class known key, and (c) adds the pvp_disarm scenario
--        ({ is_pvp = true, target_class = 1, setting_overrides = {
--        disarm_trigger = "always" } }). prot Disarm (protection:731)
--        needs is_pvp (ACTIONS requires_pvp) + disarm_class_ok — which
--        pcall's target:get_class() (protection:358) and requires a melee id
--        in DISARM_CLASS_IDS {1,2,4,7} (class 1 = warrior). The on_burst
--        trigger (default) needs disarm_burst_name from enemy_buffed, so we
--        use the cheaper disarm_trigger = "always" setting override — no
--        enemy_buffed, therefore no purge-buffed lane collateral (purge_buffed
--        keeps its exclusivity, verified by the other 27 battery suites).
-- WHEN:  rotation suite execution.
-- WHY:   a future battery edit could silently re-hide this lane; this test
--        fails if Disarm stops firing in pvp_disarm or leaks into others.
-- SAFETY: Pure unit test with the behavioral_audit mock; no game data.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local aud = require("tests.behavioral_audit")

local function assert_true(v, label)
    if not v then error(label or "assert_true failed", 2) end
end

-- ============================================================================
-- End-to-end: run the real battery; Disarm must (a) not be never-firing,
-- (b) fire in pvp_disarm, (c) fire in exactly ONE scenario (exclusivity).
-- ============================================================================
local report = aud.run_spec("warrior", "protection")
assert_true(report ~= nil, "battery run for warrior/protection failed")
assert_true(#report.dispatch_errors == 0,
    "warrior/protection battery dispatch errors: " .. table.concat(report.dispatch_errors, "; "))

local is_never = false
for _, name in ipairs(report.never) do
    if name == "Disarm" then is_never = true end
end
assert_true(not is_never, "battery still reports warrior/protection Disarm as never-firing")

local fi = report.fires_in["Disarm"]
assert_true(type(fi) == "table" and fi["pvp_disarm"] == true,
    "warrior/protection Disarm must fire in the pvp_disarm scenario")
local count = 0
for _ in pairs(fi) do count = count + 1 end
assert_true(count == 1,
    "warrior/protection Disarm must fire ONLY in pvp_disarm, got " .. count .. " scenarios")
print("PASS: end-to-end battery check (Disarm exclusive to pvp_disarm)")

-- ============================================================================
-- Cross-scenario negatives: is_pvp without a melee class, and melee class
-- without is_pvp, must both block.
-- ============================================================================
assert_true(not report.fires_in["Disarm"]["defensive_casting"],
    "Disarm must NOT fire in defensive_casting (is_pvp but no target_class -> disarm_class_ok false)")
assert_true(not report.fires_in["Disarm"]["pvp_gap_close"],
    "Disarm must NOT fire in pvp_gap_close (is_pvp but no target_class)")
assert_true(not report.fires_in["Disarm"]["purge_buffed"],
    "Disarm must NOT fire in purge_buffed (enemy_buffed but no melee class + on_burst trigger default)")
print("PASS: cross-scenario negatives (is_pvp-only and melee-class-only both block)")

-- ============================================================================
-- Mechanism pins — pvp_disarm context drives Disarm:
--   1. ctx.is_pvp true -> state.is_pvp true (ACTIONS requires_pvp passes).
--   2. ctx.target_class 1 -> target:get_class() = 1 -> disarm_class_ok true.
--   3. setting_overrides disarm_trigger "always" -> matcher skips the
--      on_burst burst-name gate.
-- ============================================================================
local result, load_err, ns = aud.load_spec("warrior", "protection")
assert_true(result ~= nil, "load warrior/protection failed: " .. tostring(load_err))
local function scenario_by_name(name)
    for _, s in ipairs(aud.SCENARIOS) do
        if s.name == name then return s end
    end
end
local function strategy_by_name(strats, name)
    for _, s in ipairs(strats) do
        if s.name == name then return s end
    end
end

local scen = scenario_by_name("pvp_disarm")
assert_true(scen ~= nil, "pvp_disarm scenario missing")
local ctx = aud.build_context_for("warrior", scen)
aud.apply_battery_state(ns, ctx, "warrior")
assert_true(ctx.is_pvp == true, "ctx.is_pvp must be true in pvp_disarm")
assert_true(ctx.target_class == 1, "ctx.target_class must be 1 in pvp_disarm")
assert_true(ctx.settings and ctx.settings.disarm_trigger == "always",
    "ctx.settings.disarm_trigger must be 'always' in pvp_disarm")

local st = result.build_state(ctx)
assert_true(st.is_pvp == true, "state.is_pvp must be true")
assert_true(st.disarm_ready == true, "disarm_ready must be true (spell_ready stub)")
assert_true(st.disarm_class_ok == true,
    "disarm_class_ok must be true (target:get_class() = 1 in DISARM_CLASS_IDS)")
local strat = strategy_by_name(result.strategies or result, "Disarm")
assert_true(strat ~= nil, "Disarm strategy not found")
local ok_m, m = pcall(strat.matches, ctx, st)
assert_true(ok_m and m, "warrior/protection Disarm must match in pvp_disarm context")

-- Sharp negative: same context, but target_class absent -> get_class missing
-- -> disarm_class_ok false -> matcher rejects (the defensive_casting shape).
local ctx2 = aud.build_context_for("warrior", scenario_by_name("defensive_casting"))
aud.apply_battery_state(ns, ctx2, "warrior")
local st2 = result.build_state(ctx2)
assert_true(st2.disarm_class_ok == false,
    "disarm_class_ok must be false without target_class (get_class absent)")
local ok2, m2 = pcall(strat.matches, ctx2, st2)
assert_true(ok2 and not m2, "Disarm must NOT match in defensive_casting (no melee class)")
print("PASS: mechanism pins (is_pvp + target_class 1 + trigger always -> match; no class blocks)")

print("ALL PASS: test_pvp_disarm_regression")
