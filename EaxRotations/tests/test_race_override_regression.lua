-- test_race_override_regression.lua — pins the era-gated race override /
-- variant machinery that clears the vanilla smite racial lanes (2026-08-11).
-- WHAT:  three mechanisms pinned end-to-end through the behavioral battery:
--   (1) era-scoping — race_maps_for() returns the TBC map for sylvanas, the
--       vanilla map for vanilla, and nil for wotlk (a WotLK smite load must
--       never pick up a TBC/vanilla binding);
--   (2) per-race firing — vanilla smite as night elf (4) fires Starshards
--       only, as undead (5) fires DevouringPlague only, explicit human (1)
--       keeps both dead (the gates exclude every other race);
--   (3) default-race stability — the default override is pinned (smite = NE 4
--       in both eras, variants { 5 }) AND non-override specs keep the race-1
--       default: warrior arms vanilla reports identical never lists with a nil
--       override vs an explicit race 1, so a future change to the default
--       cannot silently shift other specs' lanes.
-- WHEN:  rotation suite execution (run_rotation_tests.lua).
-- WHY:   the probe that proved the fix was deleted, leaving the mechanism
--        covered only by the verify_all pin (never 79 -> 77); this test is the
--        semantic guard so a future era-gating edit can't silently re-dead the
--        smite lanes or change the default race for other specs.
-- SAFETY: Pure unit test with the behavioral_audit mock; no game data.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local aud = require("tests.behavioral_audit")

local function assert_true(v, label)
    if not v then error("FAIL: " .. (label or "assert_true"), 2) end
end

local function assert_false(v, label)
    if v then error("FAIL: " .. (label or "assert_false"), 2) end
end

local function assert_eq(a, b, label)
    if a ~= b then
        error("FAIL: " .. (label or "assert_eq") .. ": " .. tostring(a) .. " ~= " .. tostring(b), 2)
    end
end

local function never_set(report)
    local t = {}
    for _, n in ipairs(report.never) do t[n] = true end
    return t
end

local function fires(report, lane)
    return never_set(report)[lane] == nil
end

-- ============================================================================
-- (1) Era-scoping of race_maps_for
-- ============================================================================
local tbc_o, tbc_v = aud.race_maps_for("sylvanas")
local van_o, van_v = aud.race_maps_for("vanilla")
local wlk_o, wlk_v = aud.race_maps_for("wotlk")

assert_eq(tbc_o, aud.RACE_OVERRIDES, "sylvanas must use the TBC race overrides map")
assert_eq(tbc_v, aud.RACE_VARIANTS, "sylvanas must use the TBC race variants map")
assert_eq(van_o, aud.RACE_OVERRIDES_VANILLA, "vanilla must use its own race overrides map")
assert_eq(van_v, aud.RACE_VARIANTS_VANILLA, "vanilla must use its own race variants map")
assert_false(wlk_o, "wotlk must NOT resolve any race overrides (era-scoped)")
assert_false(wlk_v, "wotlk must NOT resolve any race variants (era-scoped)")

-- Default override values pinned so a future change to the default is a
-- deliberate, reviewed edit rather than a silent shift.
assert_eq(aud.RACE_OVERRIDES.smite, 4, "TBC smite default override must be night elf (4)")
assert_eq(aud.RACE_OVERRIDES_VANILLA.smite, 4, "vanilla smite default override must be night elf (4)")
assert_eq(aud.RACE_VARIANTS.smite[1], 5, "TBC smite variant must be undead (5)")
assert_eq(aud.RACE_VARIANTS_VANILLA.smite[1], 5, "vanilla smite variant must be undead (5)")
print("PASS: race_maps_for era-scoping + default override values pinned")

-- ============================================================================
-- (2) End-to-end first: run_all requires a virgin shared-module namespace
-- (guard_shared_virgin), so it must run BEFORE any run_spec call loads shared
-- modules; run_all self-cleans package.loaded afterward, so the mechanism
-- sections below then load fresh.
-- ============================================================================
local agg = aud.run_all("vanilla")
local smite_found = false
for _, rep in ipairs(agg.reports or {}) do
    if rep.class == "priest" and rep.spec == "smite" then
        smite_found = true
        assert_eq(#rep.never, 0, "vanilla smite must have 0 never-firing lanes (both racials observable)")
    end
end
assert_true(smite_found, "vanilla battery run_all must include priest/smite")
print("PASS: vanilla battery run_all reports smite with 0 never-firing lanes")

-- ============================================================================
-- (3) Per-race firing of the two vanilla smite racial lanes
-- ============================================================================
local rep_ne, err_ne = aud.run_spec("priest", "smite", aud.SCENARIOS, "vanilla", 4)
assert_true(rep_ne ~= nil, "smite vanilla load (race 4) failed: " .. tostring(err_ne))
assert_true(fires(rep_ne, "Starshards"),
    "Starshards must fire as night elf (4) under vanilla")
assert_false(fires(rep_ne, "DevouringPlague"),
    "DevouringPlague must NOT fire as night elf (4) — gate is undead 5")
print("PASS: vanilla smite Starshards fires as NE(4), DevouringPlague stays dead")

local rep_ud, err_ud = aud.run_spec("priest", "smite", aud.SCENARIOS, "vanilla", 5)
assert_true(rep_ud ~= nil, "smite vanilla load (race 5) failed: " .. tostring(err_ud))
assert_true(fires(rep_ud, "DevouringPlague"),
    "DevouringPlague must fire as undead (5) under vanilla")
assert_false(fires(rep_ud, "Starshards"),
    "Starshards must NOT fire as undead (5) — gate is night elf 4")
print("PASS: vanilla smite DevouringPlague fires as undead(5), Starshards stays dead")

local rep_h, err_h = aud.run_spec("priest", "smite", aud.SCENARIOS, "vanilla", 1)
assert_true(rep_h ~= nil, "smite vanilla load (race 1) failed: " .. tostring(err_h))
assert_false(fires(rep_h, "Starshards"), "human smite must NOT fire Starshards")
assert_false(fires(rep_h, "DevouringPlague"), "human smite must NOT fire DevouringPlague")
print("PASS: explicit human (1) keeps both vanilla smite racial lanes dead")

-- TBC smite behaves identically through the same machinery.
local rep_t, err_t = aud.run_spec("priest", "smite", aud.SCENARIOS, "sylvanas", 4)
assert_true(rep_t ~= nil, "smite TBC load (race 4) failed: " .. tostring(err_t))
assert_true(fires(rep_t, "Starshards"), "TBC smite Starshards must fire as NE(4)")
local rep_tud, err_tud = aud.run_spec("priest", "smite", aud.SCENARIOS, "sylvanas", 5)
assert_true(rep_tud ~= nil, "smite TBC load (race 5) failed: " .. tostring(err_tud))
assert_true(fires(rep_tud, "DevouringPlague"), "TBC smite DevouringPlague must fire as undead(5)")
print("PASS: TBC smite lanes fire through the same mechanism")

-- ============================================================================
-- (4) Default-race stability
-- ============================================================================
-- smite default (nil override) applies the era map: NE(4) in both eras.
local rep_dv, err_dv = aud.run_spec("priest", "smite", aud.SCENARIOS, "vanilla", nil)
assert_true(rep_dv ~= nil, "smite vanilla default load failed: " .. tostring(err_dv))
assert_true(fires(rep_dv, "Starshards"),
    "vanilla smite default (nil override) must apply NE(4) and fire Starshards")
assert_false(fires(rep_dv, "DevouringPlague"),
    "vanilla smite default must NOT fire DevouringPlague (variant race 5 only)")
local rep_dt, err_dt = aud.run_spec("priest", "smite", aud.SCENARIOS, "sylvanas", nil)
assert_true(rep_dt ~= nil, "smite TBC default load failed: " .. tostring(err_dt))
assert_true(fires(rep_dt, "Starshards"),
    "TBC smite default (nil override) must apply NE(4) and fire Starshards")
print("PASS: smite default race is NE(4) in both eras (pinned)")

-- Non-override specs keep the race-1 (human) default: arms vanilla must
-- report IDENTICAL never lists with nil override vs explicit race 1. Any
-- future widening of the default (e.g. applying a race to every spec) breaks
-- this equality and fails the test.
local rep_a, err_a = aud.run_spec("warrior", "arms", aud.SCENARIOS, "vanilla", nil)
local rep_a1, err_a1 = aud.run_spec("warrior", "arms", aud.SCENARIOS, "vanilla", 1)
assert_true(rep_a ~= nil, "arms vanilla default load failed: " .. tostring(err_a))
assert_true(rep_a1 ~= nil, "arms vanilla race-1 load failed: " .. tostring(err_a1))
local na, na1 = never_set(rep_a), never_set(rep_a1)
for n in pairs(na) do
    assert_true(na1[n] ~= nil,
        "arms vanilla: default override must not fire lane '" .. n .. "' that race 1 keeps dead")
end
for n in pairs(na1) do
    assert_true(na[n] ~= nil,
        "arms vanilla: default override must keep lane '" .. n .. "' dead that race 1 also keeps dead")
end
print("PASS: non-override specs keep the race-1 default (arms vanilla nil == race 1)")

-- ============================================================================
-- (5) Impossible-by-design pin: warlock RacialArcaneTorrent (blood elves do
-- not exist in vanilla; affliction_vanilla.lua:83 pins ArcaneTorrent = nil).
-- ============================================================================
local rep_w, err_w = aud.run_spec("warlock", "affliction", aud.SCENARIOS, "vanilla", nil)
assert_true(rep_w ~= nil, "affliction vanilla load failed: " .. tostring(err_w))
assert_false(fires(rep_w, "RacialArcaneTorrent"),
    "affliction vanilla RacialArcaneTorrent must stay never-firing (TBC-only blood elf racial)")
print("PASS: warlock RacialArcaneTorrent stays pinned (impossible-by-design)")

print("PASS: race-override regression (era-scoping, per-race firing, default stability)")
