-- test_intervene_lane_regression.lua — pins the lane unblocked by the
-- close-out triage ranked #3 battery upgrade + a REAL matcher bug fix
-- (2026-08-08):
--   warrior/protection  Intervene  (group_ally_low scenario)
-- WHAT:  behavioral_audit.lua now (a) makes the me + friend mocks'
--        get_position return multi-values (0, 0, 0) like the real API,
--        (b) makes the get_party_members stub scenario-aware — it presents
--        a _friend(30, 5) ally when ctx.party_low_ally is set (prot-only
--        read; priest middleware uses the separate NS.GetPartyMembers stub),
--        (c) adds the is_group/party_low_ally/friend_hp known keys, and
--        (d) adds the group_ally_low scenario ({ is_group = true, is_pvp =
--        true, party_low_ally = true, friend_hp = 30 }).
--        PROTECTION (spec fix): intervene_matches_fn read positions with
--        `local dx, dy = me.get_position and me:get_position()` — the
--        and-form truncates a multi-value call to ONE value, so dy/ay were
--        always nil and `if not (dx and dy and ax and ay)` was always true:
--        Intervene could NEVER fire, even against the real API (a genuine
--        category-(d) dead lane, reclassified from (b) in the triage). The
--        matcher now captures both values with an explicit nil guard.
-- WHEN:  rotation suite execution.
-- WHY:   a future battery edit could silently re-hide this lane, or a
--        re-introduction of the truncating read would dead it again; this
--        test fails on either.
-- SAFETY: Pure unit test with the behavioral_audit mock; no game data.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local aud = require("tests.behavioral_audit")

local function assert_true(v, label)
    if not v then error(label or "assert_true failed", 2) end
end

-- ============================================================================
-- End-to-end: run the real battery; Intervene must (a) not be never-firing,
-- (b) fire in group_ally_low, (c) fire in exactly ONE scenario (exclusivity).
-- ============================================================================
local report = aud.run_spec("warrior", "protection")
assert_true(report ~= nil, "battery run for warrior/protection failed")
assert_true(#report.dispatch_errors == 0,
    "warrior/protection battery dispatch errors: " .. table.concat(report.dispatch_errors, "; "))

local is_never = false
for _, name in ipairs(report.never) do
    if name == "Intervene" then is_never = true end
end
assert_true(not is_never, "battery still reports warrior/protection Intervene as never-firing")

local fi = report.fires_in["Intervene"]
assert_true(type(fi) == "table" and fi["group_ally_low"] == true,
    "warrior/protection Intervene must fire in the group_ally_low scenario")
local count = 0
for _ in pairs(fi) do count = count + 1 end
assert_true(count == 1,
    "warrior/protection Intervene must fire ONLY in group_ally_low, got " .. count .. " scenarios")
print("PASS: end-to-end battery check (Intervene exclusive to group_ally_low)")

-- ============================================================================
-- Cross-scenario negatives: no is_group, or is_group without a low in-range
-- ally, must both block.
-- ============================================================================
assert_true(not report.fires_in["Intervene"]["standard"],
    "Intervene must NOT fire in standard (no is_group)")
assert_true(not report.fires_in["Intervene"]["friends_afflicted"],
    "Intervene must NOT fire in friends_afflicted (afflicted friends but is_group false)")
assert_true(not report.fires_in["Intervene"]["pvp_disarm"],
    "Intervene must NOT fire in pvp_disarm (is_pvp but no is_group)")
assert_true(not report.fires_in["Intervene"]["group_healthy"],
    "Intervene must NOT fire in group_healthy (friends present but is_group false)")
print("PASS: cross-scenario negatives (is_group/ally gates all block)")

-- ============================================================================
-- Mechanism pins — group_ally_low context drives Intervene:
--   1. ctx.is_group true -> state.is_group true (protection:757).
--   2. ctx.party_low_ally true -> get_party_members presents _friend(30, 5)
--      -> the party scan (protection:425-452) populates lowest_allied with
--      effective_hp 30 (below warrior_intervene_hp_threshold default 60) and
--      an in-range position (0,0 vs 0,0 -> dist 0 <= 25yd^2 gate 625).
--   3. ctx.is_pvp true -> warrior_intervene_pvp_only (default true) passes.
--   4. Matcher fix: dx/dy/ax/ay all non-nil (multi-value capture) -> the
--      range gate is actually evaluated instead of short-circuiting.
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

local scen = scenario_by_name("group_ally_low")
assert_true(scen ~= nil, "group_ally_low scenario missing")
local ctx = aud.build_context_for("warrior", scen)
aud.apply_battery_state(ns, ctx, "warrior")
assert_true(ctx.is_group == true, "ctx.is_group must be true in group_ally_low")
assert_true(ctx.is_pvp == true, "ctx.is_pvp must be true in group_ally_low")
assert_true(ctx.party_low_ally == true, "ctx.party_low_ally must be true in group_ally_low")
assert_true(ctx.friend_hp == 30, "ctx.friend_hp must be 30 in group_ally_low")

local st = result.build_state(ctx)
assert_true(st.is_group == true, "state.is_group must be true")
assert_true(st.is_pvp == true, "state.is_pvp must be true")
assert_true(st.in_combat == true, "state.in_combat must be true")
assert_true(st.intervene_ready == true, "intervene_ready must be true (spell_ready stub)")
assert_true((st.rage or 0) >= 10, "rage must be >= 10 for Intervene")
assert_true(st.lowest_allied ~= nil, "lowest_allied must be populated by the party scan")
assert_true(st.lowest_allied.unit ~= nil, "lowest_allied must carry a unit")
assert_true(st.lowest_allied.effective_hp == 30,
    "lowest_allied.effective_hp must be 30 (friend_hp override)")

-- vec3 position capture (contract fix 2026-08-08): get_position returns
-- ONE {x,y,z} table (verified vs auto_loot/targeting/EaxESP) — the matcher
-- and party scan read pos.x/pos.y with an [1]/[2] index fallback. Me + ally
-- must yield non-nil x/y fields.
local me = ctx.me
local me_pos = me.get_position and me:get_position()
assert_true(me_pos ~= nil and me_pos.x ~= nil and me_pos.y ~= nil,
    "me:get_position() must return a vec3 table with x/y")
local ally_pos = st.lowest_allied.unit.get_position and st.lowest_allied.unit:get_position()
assert_true(ally_pos ~= nil and ally_pos.x ~= nil and ally_pos.y ~= nil,
    "ally:get_position() must return a vec3 table with x/y")

local strat = strategy_by_name(result.strategies or result, "Intervene")
assert_true(strat ~= nil, "Intervene strategy not found")
local ok_m, m = pcall(strat.matches, ctx, st)
assert_true(ok_m and m, "warrior/protection Intervene must match in group_ally_low context")

-- Sharp negative: is_group true but NO low ally (party_low_ally unset) ->
-- party scan finds nothing -> lowest_allied nil -> matcher rejects.
local ctx2 = aud.build_context_for("warrior", {
    name = "group_no_ally",
    overrides = { is_group = true, is_pvp = true },
})
aud.apply_battery_state(ns, ctx2, "warrior")
local st2 = result.build_state(ctx2)
assert_true(st2.is_group == true, "state.is_group must be true in the no-ally group context")
assert_true(st2.lowest_allied == nil,
    "lowest_allied must be nil when the party stub presents no ally")
local ok2, m2 = pcall(strat.matches, ctx2, st2)
assert_true(ok2 and not m2, "Intervene must NOT match without a low in-range ally")
print("PASS: mechanism pins (is_group + party_low_ally -> lowest_allied -> match; no ally blocks)")

print("ALL PASS: test_intervene_lane_regression")
