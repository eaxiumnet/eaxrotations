-- test_cat_vanilla_battery_regression.lua — pins the 19-lane vanilla cat
-- block clear (2026-08-11) and the Powershift defect fix.
-- WHAT:  the vanilla battery previously reported 19 never-firing druid cat
--        lanes. Root cause (probe + evidence): (1) the battery mock's
--        DruidSpells table only defined Moonfire/InsectSwarm/Hurricane, and
--        cat_vanilla is plain-style — it reads SPELLS.CatForm/Shred/Rake/...
--        directly with no define_action_for_class fallback, so every
--        spell-gated lane died on nil (harness gap, same precedent as the
--        Hurricane fix); (2) cat_vanilla hardcoded should_powershift = false,
--        making the Powershift strategy unreachable in LIVE play — a genuine
--        mirror-drift defect vs cat_sylvanas:717-719, fixed by porting the
--        computation; (3) PounceOpener + FaerieFireStealthLock need stealth
--        with the pounce/FF debuffs DOWN — the buffs_up scenario marks every
--        debuff up (remains 20), so a map-aware cat_stealth_clean scenario
--        (buff_remains_map { [9913] = PROWL }) was added.
-- WHEN:  rotation suite execution (run_rotation_tests.lua).
-- WHY:   a future battery edit (dropping a spell entry, removing the
--        cat_stealth_clean scenario, or regressing the powershift computation)
--        must fail loudly instead of silently re-deading 19 lanes.
-- SAFETY: Pure unit test with the behavioral_audit mock; no game data.
-- ORDER: run_all FIRST (guard_shared_virgin needs a virgin shared namespace;
--        run_all self-cleans package.loaded afterward), then load_spec-based
--        matcher assertions run clean.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local aud = require("tests.behavioral_audit")

-- Declared up-front so the helpers below close over the SAME local (no
-- forward-reference shadowing).
local cat_mod, cat_ns

local function assert_true(v, label)
    if not v then error("FAIL: " .. (label or "assert_true"), 2) end
end

local function assert_eq(a, b, label)
    if a ~= b then
        error("FAIL: " .. (label or "assert_eq") .. ": " .. tostring(a) .. " ~= " .. tostring(b), 2)
    end
end

local CAT_LANES = {
    "Barkskin", "CatForm", "ClawFallback", "Dash", "FaerieFireFeral",
    "FaerieFireStealthLock", "FerociousBite", "PounceOpener", "Powershift",
    "Prowl", "Rake", "RakeSnapshot", "RavageOpener", "Rip", "Shred",
    "ShredOmen", "StealthShred", "TigersFury", "TravelForm",
}

-- ============================================================================
-- (1) End-to-end: the vanilla battery must report ZERO never-firing cat lanes,
-- and every one of the 19 previously-pinned lanes must fire somewhere.
-- ============================================================================
local agg = aud.run_all("vanilla")
local cat_rep = nil
for _, rep in ipairs(agg.reports or {}) do
    if rep.class == "druid" and rep.spec == "cat" then cat_rep = rep end
end
assert_true(cat_rep ~= nil, "vanilla battery run_all must include druid/cat")
assert_eq(#cat_rep.never, 0, "druid cat must have 0 never-firing lanes in the vanilla battery")
local cat_never = {}
for _, n in ipairs(cat_rep.never) do cat_never[n] = true end
for _, lane in ipairs(CAT_LANES) do
    assert_true(cat_never[lane] == nil,
        "vanilla battery still reports druid/cat " .. lane .. " as never-firing")
end
print("PASS: all 19 vanilla cat lanes fire (druid/cat never-fires = 0)")

-- ============================================================================
-- (2) Powershift defect-fix non-vacuity (matcher level, mirroring
-- test_fury_vanilla_pummel's fired/silent proof):
--   * cat_emergency (energy 8, cp 2, mana 40, in combat) -> should_powershift
--     true -> Powershift matcher fires
--   * cat_form (energy 60) -> should_powershift false -> matcher silent
--   * cat_powershift_enabled = false (setting gate) + energy 8 -> silent
-- ============================================================================
cat_mod, _, cat_ns = aud.load_spec("druid", "cat", "vanilla")
assert_true(cat_mod ~= nil, "druid/cat vanilla load failed")
local strategies = (type(cat_mod) == "table") and (cat_mod.strategies or cat_mod) or {}

local function make_state(scenario)
    local ctx = aud.build_context_for("druid", scenario)
    aud.apply_battery_state(cat_ns, ctx, "druid")
    local ok, st = pcall(cat_mod.build_state, ctx)
    assert_true(ok, "cat build_state crashed in " .. scenario.name .. ": " .. tostring(st))
    return ctx, st
end

local function lane_matcher(lane)
    for _, s in ipairs(strategies) do
        if s.name == lane then return s end
    end
    error("strategy missing: " .. lane, 2)
end

local function scenario_named(name)
    for _, s in ipairs(aud.SCENARIOS) do
        if s.name == name then return s end
    end
    error("scenario not found: " .. name, 2)
end

local pm = lane_matcher("Powershift")

-- energy 8 -> should_powershift true -> matcher fires
local ctx_em, st_em = make_state(scenario_named("cat_emergency"))
assert_true(st_em.should_powershift == true,
    "cat_emergency (energy 8) must compute should_powershift = true, got " .. tostring(st_em.should_powershift))
local mok, m = pcall(pm.matches, ctx_em, st_em)
assert_true(mok, "Powershift matcher crashed: " .. tostring(m))
assert_true(m == true, "Powershift must fire in cat_emergency (energy 8, cp 2, mana 40)")
print("PASS: Powershift fires when energy <= 25 (cat_emergency)")

-- energy 60 -> should_powershift false -> matcher silent
local ctx_cf, st_cf = make_state(scenario_named("cat_form"))
assert_true(st_cf.should_powershift == false,
    "cat_form (energy 60) must compute should_powershift = false, got " .. tostring(st_cf.should_powershift))
local mok2, m2 = pcall(pm.matches, ctx_cf, st_cf)
assert_true(mok2, "Powershift matcher crashed (cat_form): " .. tostring(m2))
assert_true(m2 ~= true, "Powershift must be silent at energy 60 (no shift window)")
print("PASS: Powershift silent when energy > 25 (cat_form)")

-- setting gate: cat_powershift_enabled = false blocks the computation
local off_sc = {
    name = "cat_powershift_off",
    overrides = { form = 3, energy = 8, combo_points = 2, mana_pct = 40,
                  setting_overrides = { cat_powershift_enabled = false } },
}
local ctx_off, st_off = make_state(off_sc)
assert_true(st_off.should_powershift == false,
    "cat_powershift_enabled = false must block should_powershift, got " .. tostring(st_off.should_powershift))
local mok3, m3 = pcall(pm.matches, ctx_off, st_off)
assert_true(mok3, "Powershift matcher crashed (disabled): " .. tostring(m3))
assert_true(m3 ~= true, "Powershift must be silent when the setting is disabled")
print("PASS: Powershift silent when cat_powershift_enabled = false (setting gate)")

-- ============================================================================
-- (3) Harness-shape pin: the cat_stealth_clean scenario is what makes
-- PounceOpener + FaerieFireStealthLock observable (stealth via the PROWL
-- buff map, pounce/FF remains 0). If a future edit removes or reshapes it,
-- those lanes re-dead — pin the scenario exists with the PROWL map.
-- ============================================================================
local clean = scenario_named("cat_stealth_clean")
assert_true(type(clean.overrides) == "table" and clean.overrides.buff_remains_map
    and clean.overrides.buff_remains_map[9913] ~= nil,
    "cat_stealth_clean must carry buff_remains_map { [9913] = PROWL } (drives stealth via buff_up)")
local ctx_clean, st_clean = make_state(clean)
assert_true(st_clean.is_stealthed == true,
    "cat_stealth_clean must yield is_stealthed = true via the PROWL buff map")
assert_true(st_clean.pounce_remains == 0 and st_clean.faerie_fire_remains == 0,
    "cat_stealth_clean must leave pounce/FF remains at 0 (debuffs NOT up)")
print("PASS: cat_stealth_clean scenario shape pinned (stealth up, debuffs down)")

print("PASS: cat_vanilla battery regression (19 lanes fire, Powershift gate, stealth-clean shape)")
