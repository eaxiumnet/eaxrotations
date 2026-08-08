-- test_destro_pet_pref_regression.lua — pins the 4 destro pet-preference
-- lanes in warlock/destruction: the 3 (d) dead-code lanes fixed by the warlock
-- focused-triage (ranked #10, 2026-08-07) — SummonFelhunter,
-- SummonVoidwalker, SummonFelguard — plus the (a) opt-in SummonSuccubus
-- (covered by its own battery scenario, added with the final (a) fixture).
-- WHAT:  The triage found summon_pet_matches (destruction_sylvanas.lua)
--        honored destro_pet_preference only for SummonImp/SummonSuccubus —
--        SummonFelhunter/SummonVoidwalker/SummonFelguard fell through to the
--        unconditional `return false` (line ~414) despite the comment claiming
--        "only if explicitly preferred". Live symptom: a user who sets
--        destro_pet_preference = "felguard" got NO pet at all (even the
--        auto-Imp was suppressed). Fixed by adding the three missing pref
--        branches. The battery then got one OOC no-pet scenario per pref
--        (destro_pet_felhunter / destro_pet_voidwalker / destro_pet_felguard)
--        so each lane is observable; each fires ONLY in its own scenario.
--        Lanes pinned here (all previously never-firing, classified (d)):
--          warlock/destruction SummonFelhunter  (destro_pet_felhunter)
--          warlock/destruction SummonVoidwalker (destro_pet_voidwalker)
--          warlock/destruction SummonFelguard   (destro_pet_felguard)
-- WHEN:  rotation suite execution.
-- WHY:   a future edit to summon_pet_matches or the battery could silently
--        re-hide these lanes (or break the auto-Imp path); this test fails if
--        any lane stops firing, fires in the wrong scenario, or the auto path
--        regresses.
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

local function make_state(spec_mod, ns, scenario_name)
    local ctx = aud.build_context_for("warlock", build_scenario(scenario_name))
    aud.apply_battery_state(ns, ctx, "warlock")
    if spec_mod.build_state then
        local ok, st = pcall(spec_mod.build_state, ctx)
        assert_true(ok, "destruction/" .. scenario_name .. " build_state crashed: " .. tostring(st))
        if type(st) == "table" then return ctx, st end
    end
    return ctx, ctx
end

local function assert_lane_matches(spec_mod, ns, scenario_name, lane, label)
    local ctx, state = make_state(spec_mod, ns, scenario_name)
    local s = find_strategy(spec_mod.strategies, lane)
    assert_true(s ~= nil, "destruction " .. lane .. " strategy missing")
    local ok, m = pcall(s.matches, ctx, state)
    assert_true(ok, "destruction " .. lane .. " matcher crashed: " .. tostring(m))
    assert_true(m, label)
    return ctx, state
end

local function assert_never(spec_mod, ns, scenario_name, lane, label)
    local ctx, state = make_state(spec_mod, ns, scenario_name)
    local s = find_strategy(spec_mod.strategies, lane)
    assert_true(s ~= nil, "destruction " .. lane .. " strategy missing")
    local ok, m = pcall(s.matches, ctx, state)
    assert_true(ok, "destruction " .. lane .. " matcher crashed: " .. tostring(m))
    assert_true(not m, label)
end

local result, load_err, ns = aud.load_spec("warlock", "destruction")
assert_true(result ~= nil, "load destruction failed: " .. tostring(load_err))
local mod = result

-- ============================================================================
-- Matcher pins: each pet-preference summon fires ONLY when its pref is set.
-- ============================================================================

-- SummonFelhunter: fires in destro_pet_felhunter, silent elsewhere.
assert_lane_matches(mod, ns, "destro_pet_felhunter", "SummonFelhunter",
    "warlock/destruction SummonFelhunter must match with destro_pet_preference = felhunter (OOC no-pet)")
assert_never(mod, ns, "destro_pet_voidwalker", "SummonFelhunter",
    "warlock/destruction SummonFelhunter must NOT match with pref = voidwalker")
assert_never(mod, ns, "destro_pet_felguard", "SummonFelhunter",
    "warlock/destruction SummonFelhunter must NOT match with pref = felguard")
assert_never(mod, ns, "pet_absent", "SummonFelhunter",
    "warlock/destruction SummonFelhunter must NOT match on auto pref (no explicit preference)")

-- SummonVoidwalker: fires in destro_pet_voidwalker, silent elsewhere.
assert_lane_matches(mod, ns, "destro_pet_voidwalker", "SummonVoidwalker",
    "warlock/destruction SummonVoidwalker must match with destro_pet_preference = voidwalker (OOC no-pet)")
assert_never(mod, ns, "destro_pet_felhunter", "SummonVoidwalker",
    "warlock/destruction SummonVoidwalker must NOT match with pref = felhunter")
assert_never(mod, ns, "destro_pet_felguard", "SummonVoidwalker",
    "warlock/destruction SummonVoidwalker must NOT match with pref = felguard")
assert_never(mod, ns, "pet_absent", "SummonVoidwalker",
    "warlock/destruction SummonVoidwalker must NOT match on auto pref")

-- SummonFelguard: fires in destro_pet_felguard, silent elsewhere.
assert_lane_matches(mod, ns, "destro_pet_felguard", "SummonFelguard",
    "warlock/destruction SummonFelguard must match with destro_pet_preference = felguard (OOC no-pet)")
assert_never(mod, ns, "destro_pet_felhunter", "SummonFelguard",
    "warlock/destruction SummonFelguard must NOT match with pref = felhunter")
assert_never(mod, ns, "destro_pet_voidwalker", "SummonFelguard",
    "warlock/destruction SummonFelguard must NOT match with pref = voidwalker")
assert_never(mod, ns, "pet_absent", "SummonFelguard",
    "warlock/destruction SummonFelguard must NOT match on auto pref")

-- Auto-pref path intact: SummonImp still fires on auto (pet_dead_ooc / pet_absent)
-- and is NOT hijacked by any explicit pref scenario.
assert_lane_matches(mod, ns, "pet_dead_ooc", "SummonImp",
    "warlock/destruction SummonImp must still match on auto pref in pet_dead_ooc (imp heuristic)")
assert_never(mod, ns, "destro_pet_felhunter", "SummonImp",
    "warlock/destruction SummonImp must NOT match when pref = felhunter (explicit pref suppresses it)")
assert_never(mod, ns, "destro_pet_felguard", "SummonImp",
    "warlock/destruction SummonImp must NOT match when pref = felguard (previously the no-pet-at-all bug)")

-- SummonSuccubus works on its explicit pref via the battery scenario.
assert_lane_matches(mod, ns, "destro_pet_succubus", "SummonSuccubus",
    "warlock/destruction SummonSuccubus must match with destro_pet_preference = succubus (OOC no-pet)")
assert_never(mod, ns, "pet_absent", "SummonSuccubus",
    "warlock/destruction SummonSuccubus must NOT match on auto pref (auto resolves to imp)")
assert_never(mod, ns, "destro_pet_felguard", "SummonSuccubus",
    "warlock/destruction SummonSuccubus must NOT match with pref = felguard")
-- Negative: succubus pref must NOT fire the other summons (guards the missing-
-- branch regression for the mirror case).
assert_never(mod, ns, "destro_pet_succubus", "SummonFelguard",
    "warlock/destruction SummonFelguard must NOT match on succubus pref")
assert_never(mod, ns, "destro_pet_succubus", "SummonImp",
    "warlock/destruction SummonImp must NOT match on succubus pref")
print("PASS: per-lane matcher pins (Felhunter/Voidwalker/Felguard + auto-Imp + Succubus)")

-- ============================================================================
-- End-to-end: the battery must report each cleared lane as firing — and ONLY
-- in its intended scenario (all four are single-scenario exclusive).
-- ============================================================================
local report = aud.run_spec("warlock", "destruction")
assert_true(report ~= nil, "battery run for warlock/destruction failed")
assert_true(#report.dispatch_errors == 0,
    "warlock/destruction battery dispatch errors: " .. table.concat(report.dispatch_errors, "; "))
local end_to_end = {
    { "SummonFelhunter",  "destro_pet_felhunter" },
    { "SummonVoidwalker", "destro_pet_voidwalker" },
    { "SummonFelguard",   "destro_pet_felguard" },
    { "SummonSuccubus",   "destro_pet_succubus" },
}
for _, kv in ipairs(end_to_end) do
    local lane, want = kv[1], kv[2]
    local is_never = false
    for _, name in ipairs(report.never) do
        if name == lane then is_never = true end
    end
    assert_true(not is_never, "battery still reports warlock/destruction " .. lane .. " as never-firing")
    local fi = report.fires_in[lane]
    assert_true(type(fi) == "table" and fi[want] == true,
        "warlock/destruction " .. lane .. " must fire in the " .. want .. " scenario")
    local count = 0
    for _ in pairs(fi) do count = count + 1 end
    assert_true(count == 1,
        "warlock/destruction " .. lane .. " must fire ONLY in " .. want .. ", got " .. count .. " scenarios")
end
-- Auto-Imp end-to-end: still fires in the OOC pet scenarios, not in pref scenarios.
local imp = report.fires_in.SummonImp or {}
assert_true(imp.pet_dead_ooc == true or imp.pet_absent == true,
    "warlock/destruction SummonImp auto path must still fire in an OOC pet scenario")
assert_true(imp.destro_pet_felhunter ~= true and imp.destro_pet_voidwalker ~= true and imp.destro_pet_felguard ~= true,
    "warlock/destruction SummonImp must NOT fire in any explicit-pref scenario")
print("PASS: end-to-end battery check (4 lanes, scenario exclusivity + auto-Imp guard)")
print("ALL PASS: ranked #10 destro pet-preference regression")
