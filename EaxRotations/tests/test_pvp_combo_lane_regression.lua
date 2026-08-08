-- test_pvp_combo_lane_regression.lua — pins the lanes unblocked by the
-- pvp-combo battery upgrade (2026-08-08, warrior/rogue focused triage,
-- ranked one-flag combos).
-- WHAT:  behavioral_audit.lua gained two scenarios:
--          pvp_stealth_opener  { is_pvp = true, buff_remains_map = { [1784] = 10 } }
--          pvp_gap_close       { is_pvp = true, target_distance = 15 }
--        The buff_remains_map is consumed by the map-aware has_player_buff/
--        buff_up (id list normalized via type check, falls back to the
--        buffs_up boolean on map-miss) — assassin's build_state derives
--        state.stealth_active = NS.has_player_buff(STEALTH_BUFF) where
--        STEALTH_BUFF = { 1787, 1786, 1785, 1784 } (assassination:47), so
--        [1784] = 10 flips it on. me.get_distance / context.target_distance
--        is scenario-driven (default 5; pvp_gap_close sets 15).
--        Lanes pinned here (all previously never-firing):
--          rogue/assassination: PvP_CheapShotOpen  (stealth + is_pvp combo)
--          rogue/assassination: PvP_SprintGapClose (is_pvp + dist >= 15)
--          druid/cat:           Dash                (DSL bonus: is_pvp +
--                              range in (5, 25] — the first is_pvp scenario
--                              with a range above melee; the non-pvp gap
--                              scenarios are blocked by range < 25)
--        Note: combat/subtlety Blind were ALREADY cleared and pinned by the
--        defensive-casting upgrade (test_defensive_casting_regression.lua),
--        so no pvp_low_hp scenario was added — it would have broken Blind's
--        fires-in(1) exclusivity pin there.
--        All three lanes fire EXCLUSIVELY in their scenario, so they are
--        pinned with fires-in(1) exclusivity + matcher asserts with sharp
--        negatives + end-to-end never-list checks.
-- WHEN:  rotation suite execution.
-- WHY:   a future battery edit (dropping is_pvp, the stealth buff map, the
--        distance override, or the scenarios) could silently re-hide these
--        3 lanes; this test fails if any stops firing or leaks into another
--        scenario.
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
-- Mechanism pin: the stealth buff map and the distance override reach state.
-- ============================================================================
local pso_ctx = aud.build_context_for("rogue", build_scenario("pvp_stealth_opener"))
assert_true(pso_ctx.is_pvp == true, "pvp_stealth_opener must set is_pvp")
assert_true(pso_ctx.buff_remains_map and pso_ctx.buff_remains_map[1784] == 10,
    "pvp_stealth_opener must carry buff_remains_map [1784] = 10")
local pgc_ctx = aud.build_context_for("rogue", build_scenario("pvp_gap_close"))
assert_true(pgc_ctx.is_pvp == true, "pvp_gap_close must set is_pvp")
assert_true(pgc_ctx.target_distance == 15,
    "pvp_gap_close must set target_distance 15, got " .. tostring(pgc_ctx.target_distance))
local pvp_ctx = aud.build_context_for("rogue", build_scenario("pvp"))
assert_true(pvp_ctx.target_distance == 5,
    "pvp scenario must keep default distance 5, got " .. tostring(pvp_ctx.target_distance))
print("PASS: mechanism — pvp_stealth_opener/pvp_gap_close scenarios wired (map + distance)")

-- ============================================================================
-- rogue/assassination: PvP_CheapShotOpen + PvP_SprintGapClose
-- ============================================================================
local assn, assn_err, assn_ns = aud.load_spec("rogue", "assassination")
assert_true(assn ~= nil, "rogue/assassination load failed: " .. tostring(assn_err))
_G.EaxRotations = assn_ns

-- CheapShot opener: stealth buff via the 1784 map + is_pvp.
local cs_ctx, cs_state = assert_lane(assn, assn_ns, "rogue", "pvp_stealth_opener", "PvP_CheapShotOpen", true,
    "assassination PvP_CheapShotOpen must match in pvp_stealth_opener (stealth map + is_pvp)")
assert_true(cs_state.stealth_active == true,
    "assassination state.stealth_active must be true in pvp_stealth_opener (1784 map), got "
    .. tostring(cs_state.stealth_active))
-- Negative: the stealth_opener scenario has the stealth buffs_up flag but no
-- buff_remains_map AND no is_pvp — both gates must block it there.
assert_lane(assn, assn_ns, "rogue", "stealth_opener", "PvP_CheapShotOpen", false,
    "assassination PvP_CheapShotOpen must NOT match in stealth_opener (is_pvp gate)")
-- Negative: pvp scenario is is_pvp but has no stealth buff map.
assert_lane(assn, assn_ns, "rogue", "pvp", "PvP_CheapShotOpen", false,
    "assassination PvP_CheapShotOpen must NOT match in pvp (no stealth buff — stealth_active false)")
print("PASS: rogue/assassination PvP_CheapShotOpen regression (stealth map + pvp)")

-- Sprint gap close: is_pvp + target_distance >= 15.
assert_lane(assn, assn_ns, "rogue", "pvp_gap_close", "PvP_SprintGapClose", true,
    "assassination PvP_SprintGapClose must match in pvp_gap_close (is_pvp + dist 15)")
-- Negative: gap_close scenario has dist 15 but no is_pvp.
assert_lane(assn, assn_ns, "rogue", "gap_close", "PvP_SprintGapClose", false,
    "assassination PvP_SprintGapClose must NOT match in gap_close (is_pvp gate)")
-- Negative: pvp scenario is is_pvp but dist 5 < 15.
assert_lane(assn, assn_ns, "rogue", "pvp", "PvP_SprintGapClose", false,
    "assassination PvP_SprintGapClose must NOT match in pvp (distance 5 < 15)")
print("PASS: rogue/assassination PvP_SprintGapClose regression (pvp + dist gate)")

-- ============================================================================
-- druid/cat: Dash (DSL bonus lane — is_pvp + range in (5, 25])
-- ============================================================================
local cat, cat_err, cat_ns = aud.load_spec("druid", "cat")
assert_true(cat ~= nil, "druid/cat load failed: " .. tostring(cat_err))
_G.EaxRotations = cat_ns

assert_lane(cat, cat_ns, "druid", "pvp_gap_close", "Dash", true,
    "cat Dash must match in pvp_gap_close (is_pvp + range 15 in (5, 25])")
-- Negative: cat_gap has dist 15 but not pvp — non-pvp Dash needs range >= 25.
assert_lane(cat, cat_ns, "druid", "cat_gap", "Dash", false,
    "cat Dash must NOT match in cat_gap (not pvp + range 15 < 25)")
-- Negative: travel_form has range 28 (> 25 cap) — blocked by the upper bound.
assert_lane(cat, cat_ns, "druid", "travel_form", "Dash", false,
    "cat Dash must NOT match in travel_form (range 28 > 25 cap)")
-- Negative: pvp scenario is is_pvp but range 5 <= MELEE_RANGE — the lower band.
assert_lane(cat, cat_ns, "druid", "pvp", "Dash", false,
    "cat Dash must NOT match in pvp (range 5 <= MELEE_RANGE)")
print("PASS: druid/cat Dash regression (is_pvp + range band)")

-- ============================================================================
-- Exclusivity: all three fire ONLY in their respective scenario.
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
assert_exclusive("rogue", "assassination", "PvP_CheapShotOpen", "pvp_stealth_opener")
assert_exclusive("rogue", "assassination", "PvP_SprintGapClose", "pvp_gap_close")
assert_exclusive("druid", "cat", "Dash", "pvp_gap_close")
print("PASS: exclusivity — PvP_CheapShotOpen / PvP_SprintGapClose / Dash fire only in their scenario")

-- ============================================================================
-- End-to-end: the battery must report none of the 3 lanes as never-firing.
-- ============================================================================
local function assert_lane_fires(class_key, spec, lane)
    local report = aud.run_spec(class_key, spec)
    assert_true(report ~= nil, "battery run for " .. class_key .. "/" .. spec .. " failed")
    for _, name in ipairs(report.never) do
        assert_true(name ~= lane,
            "battery still reports " .. class_key .. "/" .. spec .. " " .. lane .. " as never-firing")
    end
end
assert_lane_fires("rogue", "assassination", "PvP_CheapShotOpen")
assert_lane_fires("rogue", "assassination", "PvP_SprintGapClose")
assert_lane_fires("druid", "cat", "Dash")
print("PASS: battery reports none of the 3 pvp-combo lanes as never-firing")
print("ALL PASS: test_pvp_combo_lane_regression")
