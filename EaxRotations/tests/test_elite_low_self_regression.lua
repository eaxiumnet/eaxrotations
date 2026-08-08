-- test_elite_low_self_regression.lua — pins the lane unblocked by the
-- last (c) tank-triage battery upgrade (2026-08-08):
--   warrior/protection  IntimidatingShout  (elite_low_self scenario)
-- WHAT:  behavioral_audit.lua now adds the elite_low_self scenario
--        ({ target_classification = 1, hp = 15, player_hp = 15,
--           enemy_count = 3, enemies_count = 3 }). prot IntimidatingShout
--        needs BOTH min_enemies = 3 (base guard, protection:505, reads
--        s.enemy_count = ctx.enemy_count, prot:306) AND state.hp <= 50
--        (matcher, protection:825, reads s.hp = ctx.hp, prot:303).
--        elite_target has the 3 enemies but hp 100; low_self has hp 15 but
--        only 1 enemy — no other scenario combines enemy_count >= 3 with
--        hp <= 50, so IntimidatingShout fires exclusively in elite_low_self.
--        Taunt/TauntSecondary/MockingBlow/ChallengingShout are untouched.
-- WHEN:  rotation suite execution.
-- WHY:   a future battery edit could silently re-hide this lane; this test
--        fails if it stops firing in its scenario or leaks into others.
-- SAFETY: Pure unit test with the behavioral_audit mock; no game data.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local aud = require("tests.behavioral_audit")

local function assert_true(v, label)
    if not v then error(label or "assert_true failed", 2) end
end

-- ============================================================================
-- End-to-end: run the real battery; IntimidatingShout must (a) not be
-- never-firing, (b) fire in elite_low_self, (c) fire in exactly ONE scenario.
-- ============================================================================
local report = aud.run_spec("warrior", "protection")
assert_true(report ~= nil, "battery run for warrior/protection failed")
assert_true(#report.dispatch_errors == 0,
    "warrior/protection battery dispatch errors: " .. table.concat(report.dispatch_errors, "; "))

local is_never = false
for _, name in ipairs(report.never) do
    if name == "IntimidatingShout" then is_never = true end
end
assert_true(not is_never, "battery still reports warrior/protection IntimidatingShout as never-firing")

local fi = report.fires_in["IntimidatingShout"]
assert_true(type(fi) == "table" and fi["elite_low_self"] == true,
    "warrior/protection IntimidatingShout must fire in the elite_low_self scenario")
local count = 0
for _ in pairs(fi) do count = count + 1 end
assert_true(count == 1,
    "warrior/protection IntimidatingShout must fire ONLY in elite_low_self, got " .. count .. " scenarios")
print("PASS: end-to-end battery check (IntimidatingShout exclusive to elite_low_self)")

-- ============================================================================
-- Cross-scenario negatives: each half of the combo alone must NOT fire it.
-- ============================================================================
assert_true(not report.fires_in["IntimidatingShout"]["elite_target"],
    "IntimidatingShout must NOT fire in elite_target (3 enemies but hp 100 > 50)")
assert_true(not report.fires_in["IntimidatingShout"]["low_self"],
    "IntimidatingShout must NOT fire in low_self (hp 15 but enemy_count 1 < 3)")
assert_true(not report.fires_in["IntimidatingShout"]["aoe"],
    "IntimidatingShout must NOT fire in aoe (4 enemies but hp 100 > 50)")
print("PASS: cross-scenario negatives (enemies-only and low-hp-only both block)")

-- ============================================================================
-- Mechanism pins — elite_low_self context drives IntimidatingShout:
--   1. ctx.hp = 15 -> state.hp 15 (<= 50 matcher gate).
--   2. ctx.enemy_count = 3 -> state.enemy_count 3 (>= min_enemies 3 guard).
--   3. intimidating_shout_ready true (spell_ready stub).
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

local scen = scenario_by_name("elite_low_self")
assert_true(scen ~= nil, "elite_low_self scenario missing")
local ctx = aud.build_context_for("warrior", scen)
aud.apply_battery_state(ns, ctx, "warrior")
assert_true(ctx.hp == 15,
    "ctx.hp must be 15 in elite_low_self, got " .. tostring(ctx.hp))
assert_true(ctx.enemy_count == 3,
    "ctx.enemy_count must be 3 in elite_low_self, got " .. tostring(ctx.enemy_count))
assert_true(ctx.target_classification == 1,
    "ctx.target_classification must be 1 in elite_low_self")

local st = result.build_state(ctx)
assert_true(st.hp == 15, "state.hp must be 15 (ctx.hp), got " .. tostring(st.hp))
assert_true(st.enemy_count == 3,
    "state.enemy_count must be 3 (ctx.enemy_count), got " .. tostring(st.enemy_count))
assert_true(st.intimidating_shout_ready == true,
    "intimidating_shout_ready must be true (spell_ready stub)")
local strat = strategy_by_name(result.strategies or result, "IntimidatingShout")
assert_true(strat ~= nil, "IntimidatingShout strategy not found")
local ok_m, m = pcall(strat.matches, ctx, st)
assert_true(ok_m and m, "warrior/protection IntimidatingShout must match in elite_low_self context")

-- Sharp negative via the matcher directly: same state, hp bumped to 100.
local st_hi = {}
for k, v in pairs(st) do st_hi[k] = v end
st_hi.hp = 100
local ok_hi, m_hi = pcall(strat.matches, ctx, st_hi)
assert_true(ok_hi and not m_hi, "IntimidatingShout must NOT match when state.hp = 100")

-- Sharp negative: enemy_count 1 (the low_self half). NOTE: the raw
-- matcher (protection:823) only checks ready + hp; the min_enemies guard is
-- enforced inside the strategy's `matches` via base_guard_passes
-- (protection:505), which is what makes this block.
local st_lo = {}
for k, v in pairs(st) do st_lo[k] = v end
st_lo.enemy_count = 1
local ok_lo, m_lo = pcall(strat.matches, ctx, st_lo)
assert_true(ok_lo and not m_lo, "IntimidatingShout must NOT match when state.enemy_count = 1")
print("PASS: mechanism pins (hp 15 + enemy_count 3 -> match; each half alone blocks)")

print("ALL PASS: test_elite_low_self_regression")
