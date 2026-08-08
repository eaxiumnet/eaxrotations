-- test_opener_elite_regression.lua — pins the lanes unblocked by the
-- ranked #6-8 battery upgrades (2026-08-07):
--   warrior/protection  Taunt          (elite_target scenario)
--   warrior/protection  TauntSecondary (elite_taunt_cd scenario)
--   rogue/combat        Garrote        (stealth_opener scenario)
--   rogue/subtlety      CheapShot      (stealth_opener scenario)
-- WHAT:  behavioral_audit.lua now (a) adds target_classification and
--        target_get_target to the known override passthrough, (b) builds
--        visible-enemy mocks for the protection threat scan (fed by a
--        core.object_manager.get_visible_objects stub + core.time wired to
--        the advancing _battery_now), (c) seeds WarriorSpells.Taunt (355) so
--        on_cd can put Taunt on CD, (d) stubs stealth_helper scenario-driven
--        (the real module cached the first-loaded spec's NS, making rogue
--        stealth reads stale and scenario-order-dependent), and (e) adds the
--        elite_target / elite_taunt_cd / stealth_opener scenarios.
--        Bonus (legit, same gates): warrior MockingBlow + ChallengingShout
--        also clear via the elite classification / un-tanked-target gates.
-- WHEN:  rotation suite execution.
-- WHY:   a future battery edit could silently re-hide these lanes; this test
--        fails if any stops firing in its scenario or leaks into others.
-- SAFETY: Pure unit test with the behavioral_audit mock; no game data.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local aud = require("tests.behavioral_audit")

local function assert_true(v, label)
    if not v then error(label or "assert_true failed", 2) end
end

-- lane -> the single scenario it must fire in (all four are exclusive).
local CLEARED = {
    { "warrior", "protection", "Taunt",          "elite_target" },
    { "warrior", "protection", "TauntSecondary", "elite_taunt_cd" },
    { "rogue",   "combat",     "Garrote",        "stealth_opener" },
    { "rogue",   "subtlety",   "CheapShot",      "stealth_opener" },
}

-- ============================================================================
-- End-to-end: run the real battery per affected spec; every cleared lane must
-- (a) not be never-firing, (b) fire in its scenario, and (c) fire in exactly
-- ONE scenario (exclusivity — these lanes must not light up elsewhere).
-- ============================================================================
local done = {}
for _, c in ipairs(CLEARED) do
    local class_key, spec, lane, scenario = c[1], c[2], c[3], c[4]
    local key = class_key .. "/" .. spec
    if not done[key] then
        local report = aud.run_spec(class_key, spec)
        assert_true(report ~= nil, "battery run for " .. key .. " failed")
        assert_true(#report.dispatch_errors == 0,
            key .. " battery dispatch errors: " .. table.concat(report.dispatch_errors, "; "))
        done[key] = report
    end
    local report = done[key]
    local is_never = false
    for _, name in ipairs(report.never) do
        if name == lane then is_never = true end
    end
    assert_true(not is_never, "battery still reports " .. key .. " " .. lane .. " as never-firing")
    local fi = report.fires_in[lane]
    assert_true(type(fi) == "table" and fi[scenario] == true,
        key .. " " .. lane .. " must fire in the " .. scenario .. " scenario")
    local count = 0
    for _ in pairs(fi) do count = count + 1 end
    assert_true(count == 1,
        key .. " " .. lane .. " must fire ONLY in " .. scenario .. ", got " .. count .. " scenarios")
end
print("PASS: end-to-end battery check (4 lanes, exclusive firing)")

-- ============================================================================
-- Cross-scenario negatives: each lane must stay SILENT in the other lanes'
-- scenarios (no leakage between the two elite states or into buffs_up).
-- ============================================================================
local prot = done["warrior/protection"]
assert_true(not prot.fires_in["Taunt"]["elite_taunt_cd"],
    "warrior/protection Taunt must NOT fire when Taunt is on CD (elite_taunt_cd)")
assert_true(not prot.fires_in["TauntSecondary"]["elite_target"],
    "warrior/protection TauntSecondary must NOT fire when Taunt is ready (elite_target)")
local combat = done["rogue/combat"]
assert_true(not combat.fires_in["Garrote"]["buffs_up"] and not combat.fires_in["Garrote"]["burst"],
    "rogue/combat Garrote must NOT fire from the buffs_up fallback alone (needs a casting target)")
print("PASS: cross-scenario negatives (no leakage)")

-- ============================================================================
-- Mechanism pins — elite context drives Taunt / TauntSecondary:
--   1. elite_target: target_classification 1 + un-tanked target (get_target
--      nil) -> Taunt matches.
--   2. elite_taunt_cd: on_cd[355] makes taunt_ready false AND the visible-
--      objects threat scan sets no_threat_target -> TauntSecondary matches.
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

local elite = scenario_by_name("elite_target")
assert_true(elite ~= nil, "elite_target scenario missing")
local ctx = aud.build_context_for("warrior", elite)
aud.apply_battery_state(ns, ctx, "warrior")
assert_true(ctx.target_classification == 1,
    "ctx.target_classification must be 1 in elite_target, got " .. tostring(ctx.target_classification))
assert_true(ctx.target_get_target == false,
    "ctx.target_get_target must be false in elite_target")
local st = result.build_state(ctx)
local taunt = strategy_by_name(result.strategies or result, "Taunt")
assert_true(st.taunt_ready == true, "taunt_ready must be true in elite_target (Taunt off CD)")
local ok_m, m = pcall(taunt.matches, ctx, st)
assert_true(ok_m and m, "warrior/protection Taunt must match in elite_target context")

local elite_cd = scenario_by_name("elite_taunt_cd")
local ctx2 = aud.build_context_for("warrior", elite_cd)
aud.apply_battery_state(ns, ctx2, "warrior")
local st2 = result.build_state(ctx2)
assert_true(st2.taunt_ready == false,
    "taunt_ready must be false in elite_taunt_cd (on_cd { [355] = 6 }), got "
        .. tostring(st2.taunt_ready))
assert_true(st2.no_threat_target ~= nil,
    "elite_taunt_cd must set no_threat_target via the visible-objects threat scan")
local taunt_sec = strategy_by_name(result.strategies or result, "TauntSecondary")
local ok_s, ms = pcall(taunt_sec.matches, ctx2, st2)
assert_true(ok_s and ms, "warrior/protection TauntSecondary must match in elite_taunt_cd context")
print("PASS: mechanism pins (elite classification, un-tanked target, threat scan, Taunt on CD)")

-- ============================================================================
-- Mechanism pins — stealth opener drives combat Garrote + subtlety CheapShot:
--   buff_remains_map [1784] (Stealth) -> is_stealthed/stealth_up true;
--   target_is_casting -> combat Garrote's caster gate; opener_preference
--   "cheap_shot" -> subtlety CheapShot's opt-in.
-- ============================================================================
local opt = scenario_by_name("stealth_opener")
assert_true(opt ~= nil, "stealth_opener scenario missing")
local ctx3 = aud.build_context_for("rogue", opt)
aud.apply_battery_state(ns, ctx3, "rogue")
assert_true(type(ctx3.buff_remains_map) == "table" and ctx3.buff_remains_map[1784] == 10,
    "stealth_opener must carry the Stealth buff map entry 1784")
assert_true(ctx3.target_is_casting == true, "stealth_opener must have a casting target")
assert_true(ctx3.settings.opener_preference == "cheap_shot",
    "stealth_opener must set opener_preference = cheap_shot")

local c_result, c_err, c_ns = aud.load_spec("rogue", "combat")
assert_true(c_result ~= nil, "load rogue/combat failed: " .. tostring(c_err))
local c_ctx = aud.build_context_for("rogue", opt)
aud.apply_battery_state(c_ns, c_ctx, "rogue")
local c_st = c_result.build_state(c_ctx)
assert_true(c_st.is_stealthed == true,
    "rogue/combat build_state must report is_stealthed in stealth_opener")
local garrote = strategy_by_name(c_result.strategies or c_result, "Garrote")
local ok_g, mg = pcall(garrote.matches, c_ctx, c_st)
assert_true(ok_g and mg, "rogue/combat Garrote must match in stealth_opener context")

local s_result, s_err, s_ns = aud.load_spec("rogue", "subtlety")
assert_true(s_result ~= nil, "load rogue/subtlety failed: " .. tostring(s_err))
local s_ctx = aud.build_context_for("rogue", opt)
aud.apply_battery_state(s_ns, s_ctx, "rogue")
local s_st = s_result.build_state(s_ctx)
assert_true(s_st.stealth_up == true, "rogue/subtlety build_state must report stealth_up in stealth_opener")
local cheap = strategy_by_name(s_result.strategies or s_result, "CheapShot")
local ok_c, mc = pcall(cheap.matches, s_ctx, s_st)
assert_true(ok_c and mc, "rogue/subtlety CheapShot must match in stealth_opener context")
print("PASS: mechanism pins (stealth map, casting target, opener_preference)")

-- ============================================================================
-- Ranked #8: rogue/subtlety Preparation — needs hp <= 40 (subtlety_prep_hp)
-- AND a major CD burned (vanish_cd/sprint_cd/evasion_cd from state, derived
-- from the now bank-aware NS.get_spell_cd). prep_ready (hp 15 + Vanish on CD
-- via on_cd { [1856] = 60 }) must be its only firing scenario.
-- ============================================================================
local subtlety_report = aud.run_spec("rogue", "subtlety")
assert_true(#subtlety_report.dispatch_errors == 0,
    "rogue/subtlety battery dispatch errors: " .. table.concat(subtlety_report.dispatch_errors, "; "))
local prep_never = false
for _, name in ipairs(subtlety_report.never) do
    if name == "Preparation" then prep_never = true end
end
assert_true(not prep_never, "battery still reports rogue/subtlety Preparation as never-firing")
local prep_fi = subtlety_report.fires_in["Preparation"]
assert_true(type(prep_fi) == "table" and prep_fi.prep_ready == true,
    "rogue/subtlety Preparation must fire in the prep_ready scenario")
local prep_count = 0
for _ in pairs(prep_fi) do prep_count = prep_count + 1 end
assert_true(prep_count == 1,
    "rogue/subtlety Preparation must fire ONLY in prep_ready, got " .. prep_count .. " scenarios")
print("PASS: ranked #8 Preparation (exclusive in prep_ready)")

local prep_sc = scenario_by_name("prep_ready")
assert_true(prep_sc ~= nil, "prep_ready scenario missing")
-- Reuse the subtlety ns/build_state captured by the stealth_opener pin above:
-- apply_battery_state rewrites ns._battery per call, so the same instance is
-- valid here (mirrors the file's established load-once pattern).
local prep_ctx = aud.build_context_for("rogue", prep_sc)
aud.apply_battery_state(s_ns, prep_ctx, "rogue")
local prep_st = s_result.build_state(prep_ctx)
assert_true(prep_st.hp == 15, "prep_ready must set hp 15, got " .. tostring(prep_st.hp))
assert_true((prep_st.vanish_cd or 0) > 0,
    "prep_ready must leave Vanish on CD (vanish_cd > 0 via bank-aware get_spell_cd)")
local prep_strat = strategy_by_name(s_result.strategies or s_result, "Preparation")
local ok_p, mp = pcall(prep_strat.matches, prep_ctx, prep_st)
assert_true(ok_p and mp, "rogue/subtlety Preparation must match in prep_ready context")
print("PASS: mechanism pin (low HP + Vanish on CD reach Preparation)")

print("ALL PASS: ranked #6-8 opener/elite/prep regression")
