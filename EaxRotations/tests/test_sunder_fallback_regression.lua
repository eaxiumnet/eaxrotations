-- test_sunder_fallback_regression.lua — pins the lane unblocked by the
-- close-out ranked #1 battery upgrade (2026-08-08):
--   warrior/protection  SunderArmor  (sunder_fallback scenario)
-- WHAT:  behavioral_audit.lua (a) seeds `Devastate` in ns.WarriorSpells
--        (ids {30022, 30016, 20243}, mirroring classes/warrior/class_sylvanas.lua)
--        so the spec's `define("Devastate")` resolves real ids — without the
--        seed it fell back to spell_action(nil) -> ids { nil } ->
--        cooldown_remains could never resolve an on_cd key -> dev_ready was
--        true in EVERY scenario -> prot SunderArmor's pre-Devastate fallback
--        (prot:531 `if state.dev_ready then return false end`) never fired;
--        and (b) adds the sunder_fallback scenario
--        ({ stance = 2, rage = 100, on_cd = { [30022] = 6, [30356] = 6,
--        [30357] = 5 } }) — Devastate + ShieldSlam + Revenge on CD -> the
--        filler branch (prot:533) fires.
--        IMPORTANT: the `not_learned` map does NOT drive this lane — it only
--        gates spell_exists/is_spell_learned, while dev_ready comes from the
--        cooldown-only spell_ready mock (audit:295-297). The fix is the id
--        seed + on_cd, not not_learned.
-- WHEN:  rotation suite execution.
-- WHY:   a future battery edit could silently re-hide this lane (e.g. by
--        removing the Devastate seed); this test fails if that happens.
-- SAFETY: Pure unit test with the behavioral_audit mock; no game data.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local aud = require("tests.behavioral_audit")

local function assert_true(v, label)
    if not v then error(label or "assert_true failed", 2) end
end

-- ============================================================================
-- End-to-end: run the real battery; SunderArmor must (a) not be
-- never-firing, (b) fire in sunder_fallback, (c) fire in exactly ONE scenario.
-- ============================================================================
local report = aud.run_spec("warrior", "protection")
assert_true(report ~= nil, "battery run for warrior/protection failed")
assert_true(#report.dispatch_errors == 0,
    "warrior/protection battery dispatch errors: " .. table.concat(report.dispatch_errors, "; "))

local is_never = false
for _, name in ipairs(report.never) do
    if name == "SunderArmor" then is_never = true end
end
assert_true(not is_never, "battery still reports warrior/protection SunderArmor as never-firing")

local fi = report.fires_in["SunderArmor"]
assert_true(type(fi) == "table" and fi["sunder_fallback"] == true,
    "warrior/protection SunderArmor must fire in the sunder_fallback scenario")
local count = 0
for _ in pairs(fi) do count = count + 1 end
assert_true(count == 1,
    "warrior/protection SunderArmor must fire ONLY in sunder_fallback, got " .. count .. " scenarios")
print("PASS: end-to-end battery check (SunderArmor exclusive to sunder_fallback)")

-- Devastate must NOT regress: it fires in EXACTLY prot_filler_cd +
-- cd_pressure, and never in sunder_fallback (dev_ready false there).
local dfi = report.fires_in["Devastate"]
assert_true(type(dfi) == "table" and dfi["prot_filler_cd"] == true and dfi["cd_pressure"] == true,
    "Devastate must still fire in prot_filler_cd and cd_pressure")
assert_true(not dfi["sunder_fallback"],
    "Devastate must NOT fire in sunder_fallback (dev_ready false there by design)")
local dcount = 0
for _ in pairs(dfi) do dcount = dcount + 1 end
assert_true(dcount == 2,
    "Devastate must fire in exactly 2 scenarios (prot_filler_cd + cd_pressure), got " .. dcount)
print("PASS: Devastate not regressed (fires ONLY in prot_filler_cd + cd_pressure)")

-- ============================================================================
-- Cross-scenario negatives: Devastate ready (no [30022] on CD) must block
-- everywhere else — including prot_filler_cd, which already has
-- ShieldSlam+Revenge on CD but NOT Devastate.
-- ============================================================================
assert_true(not report.fires_in["SunderArmor"]["standard"],
    "SunderArmor must NOT fire in standard (Devastate ready)")
assert_true(not report.fires_in["SunderArmor"]["prot_filler_cd"],
    "SunderArmor must NOT fire in prot_filler_cd (ss/rev on CD but Devastate ready -> dev_ready true)")
assert_true(not report.fires_in["SunderArmor"]["cd_pressure"],
    "SunderArmor must NOT fire in cd_pressure (no Devastate on CD)")
print("PASS: cross-scenario negatives (dev_ready blocks everywhere else)")

-- ============================================================================
-- Mechanism pins — the WarriorSpells Devastate seed + sunder_fallback context:
--   1. ns.WarriorSpells.Devastate has real ids (ids[1] = 30022) and
--      cooldown_remains resolves the on_cd key.
--   2. on_cd { [30022]=6, [30356]=6, [30357]=5 } -> dev_ready/ss_ready/
--      revenge_ready all false -> sunder_stacks 0 < 5 -> filler branch fires.
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

local W = ns.WarriorSpells
assert_true(W ~= nil and W.Devastate ~= nil,
    "ns.WarriorSpells.Devastate must be seeded (spec resolve path)")
assert_true(W.Devastate.ids and W.Devastate.ids[1] == 30022,
    "WarriorSpells.Devastate.ids[1] must be 30022 (cooldown_remains resolution)")

local scen = scenario_by_name("sunder_fallback")
assert_true(scen ~= nil, "sunder_fallback scenario missing")
local ctx = aud.build_context_for("warrior", scen)
aud.apply_battery_state(ns, ctx, "warrior")
assert_true(ctx.on_cd and ctx.on_cd[30022] == 6, "ctx.on_cd[30022] must be 6 in sunder_fallback")
assert_true(ns.cooldown_remains(W.Devastate) == 6,
    "cooldown_remains(WarriorSpells.Devastate) must be 6 with [30022] on CD")

local st = result.build_state(ctx)
assert_true(st.dev_ready == false, "dev_ready must be false (Devastate on CD)")
assert_true(st.ss_ready == false, "ss_ready must be false (ShieldSlam on CD)")
assert_true(st.revenge_ready == false, "revenge_ready must be false (Revenge on CD)")
assert_true((st.sunder_stacks or 0) < 5, "sunder_stacks must be below SUNDER_MAX_STACKS (5)")

local strat = strategy_by_name(result.strategies or result, "SunderArmor")
assert_true(strat ~= nil, "SunderArmor strategy not found")
local ok_m, m = pcall(strat.matches, ctx, st)
assert_true(ok_m and m, "warrior/protection SunderArmor must match in sunder_fallback context")

-- Sharp negative: prot_filler_cd (ShieldSlam + Revenge on CD, Devastate
-- ready) -> dev_ready true -> matcher rejects.
local ctx2 = aud.build_context_for("warrior", scenario_by_name("prot_filler_cd"))
aud.apply_battery_state(ns, ctx2, "warrior")
local st2 = result.build_state(ctx2)
assert_true(st2.dev_ready == true, "dev_ready must be true in prot_filler_cd (Devastate not on CD)")
local ok2, m2 = pcall(strat.matches, ctx2, st2)
assert_true(ok2 and not m2, "SunderArmor must NOT match in prot_filler_cd (Devastate ready)")
print("PASS: mechanism pins (Devastate seed + on_cd -> dev_ready false -> match; Devastate ready blocks)")

print("ALL PASS: test_sunder_fallback_regression")
