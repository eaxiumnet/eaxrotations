-- test_wotlk_battery_regression.lua — pins the WotLK-era battery triage clears
-- (2026-08-09). The first WotLK battery inventory reported 149 never-firing
-- lanes across the 41 WotLK files (incl. Death Knight); a battery-fixture
-- campaign (resource/cooldown accessors, scenario banks, DK stub rewiring)
-- cleared the era to 0 never-firing. This test pins the gameplay-critical
-- clears so a future battery edit can't silently re-hide them.
-- WHAT:  two families of lanes, mirroring test_phase3_c_fixture_regression.lua:
--   (1) DK dead-stub masks — lanes gated through the rune_manager /
--       presence_manager / interrupt_manager stubs that previously captured a
--       nil `ns` (installed before build_ns) and fell back to defaults:
--         runic-power:   blood DancingRuneWeapon, unholy DeathCoil
--         presence:      blood Presence, unholy Presence, frost FrostPresence
--         interrupt:     MindFreeze x3 (blood/frost/unholy)
--         runes-depleted: EmpowerRuneWeapon x2 (frost + unholy)
--         disease:       Pestilence x3 (blood/unholy/leveling)
--   (2) resource-accessor clears — lanes gated on me:get_rage() /
--       get_energy() / get_combo_points() / get_runic_power(), which the
--       battery player mock previously lacked (every resource read fell back
--       to 0): arms Execute (rage), combat SinisterStrike/SliceAndDice
--       (energy/combo), assassination Mutilate (energy), cat Shred/Rip
--       (energy/combo) — representative, not every permutation.
--   Scenarios pinned: dk_runic (runic_power 100), dk_boss (is_boss +
--   runic_power), dk_presence (optimal_presence), dk_runes_depleted
--   (rune_state ready all-0), dk_disease (debuff_remains_map 55095/55078 +
--   enemy_count), target_casting (target_is_casting), execute (target_hp 8),
--   standard (default energy 90 / combo 5), cat_form (form 3 + energy 60 +
--   combo 3), mutilate_daggers (equipped daggers).
-- WHEN:  rotation suite execution (run_rotation_tests.lua) + wotlk runner.
-- WHY:   a future battery edit (dropping a scenario, changing an override, or
--        regressing the stub wiring) could silently re-hide these lanes; this
--        test fails if any stops firing (state + matcher + end-to-end
--        never-list via the wotlk-era battery run).
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

local function assert_lane_matches(spec_mod, ns, class_key, lane, scenario, label)
    local ctx, state = make_state(spec_mod, ns, class_key, scenario)
    local s = find_strategy(spec_mod.strategies, lane)
    assert_true(s ~= nil, class_key .. " " .. lane .. " strategy missing")
    local ok, m = pcall(s.matches, ctx, state)
    assert_true(ok, class_key .. " " .. lane .. " matcher crashed: " .. tostring(m))
    assert_true(m == true, label)
    return ctx, state
end

-- ============================================================================
-- (1) DK dead-stub masks — lanes gated through the rewired rune/presence/
-- interrupt manager stubs. All load with era = "wotlk".
-- ============================================================================

-- --- runic-power lanes: DancingRuneWeapon (blood), DeathCoil (unholy) ---
local blood, blood_err, blood_ns = aud.load_spec("deathknight", "blood", "wotlk")
assert_true(blood ~= nil, "deathknight/blood load failed: " .. tostring(blood_err))
_G.EaxRotations = blood_ns

local bctx, bstate = assert_lane_matches(blood, blood_ns, "deathknight", "DancingRuneWeapon",
    "dk_runic", "blood DancingRuneWeapon must match in dk_runic (runic_power 100)")
assert_true((bstate.runic_power or 0) >= 60,
    "blood state.runic_power must be >= 60, got " .. tostring(bstate.runic_power))
assert_true((bstate.target_hp or 0) > 50,
    "blood DancingRuneWeapon needs target_hp > 50, got " .. tostring(bstate.target_hp))
print("PASS: blood DancingRuneWeapon regression (dk_runic runic_power >= 60)")

local unholy, unholy_err, unholy_ns = aud.load_spec("deathknight", "unholy", "wotlk")
assert_true(unholy ~= nil, "deathknight/unholy load failed: " .. tostring(unholy_err))
_G.EaxRotations = unholy_ns

local uctx, ustate = assert_lane_matches(unholy, unholy_ns, "deathknight", "DeathCoil",
    "dk_runic", "unholy DeathCoil must match in dk_runic (runic_power 100)")
assert_true((ustate.runic_power or 0) >= 60,
    "unholy state.runic_power must be >= 60, got " .. tostring(ustate.runic_power))
print("PASS: unholy DeathCoil regression (dk_runic runic_power >= 60)")

-- --- boss-gated: SummonGargoyle (is_boss + runic_power) ---
local bctx2, bstate2 = assert_lane_matches(unholy, unholy_ns, "deathknight", "SummonGargoyle",
    "dk_boss", "unholy SummonGargoyle must match in dk_boss (is_boss + runic_power)")
assert_true(bstate2.is_boss == true,
    "unholy SummonGargoyle needs is_boss, got " .. tostring(bstate2.is_boss))
assert_true((bstate2.runic_power or 0) >= 60,
    "unholy SummonGargoyle needs runic_power >= 60, got " .. tostring(bstate2.runic_power))
print("PASS: unholy SummonGargoyle regression (dk_boss is_boss + runic)")

-- --- presence lanes: blood/unholy Presence, frost FrostPresence ---
local pctx, pstate = assert_lane_matches(blood, blood_ns, "deathknight", "Presence",
    "dk_presence", "blood Presence must match in dk_presence (optimal_presence blood)")
-- The presence lane fires because NO presence buff is up (state.presence nil ->
-- should_switch_presence true) while the scenario's optimal_presence bank key
-- makes the stub pick "blood". Assert nil + the stub's optimal read so a
-- future stub regression (always-nil optimal) can't silently re-hide the lane.
assert_true(pstate.presence == nil,
    "blood state.presence must be nil (no presence buff up -> switch lane live), got "
    .. tostring(pstate.presence))
assert_true(blood_ns._bstate("optimal_presence", nil) == "blood",
    "dk_presence scenario must set optimal_presence=blood for the stub")
print("PASS: blood Presence regression (dk_presence optimal_presence + nil current)")

local upctx, upstate = assert_lane_matches(unholy, unholy_ns, "deathknight", "Presence",
    "dk_presence", "unholy Presence must match in dk_presence (optimal_presence blood)")
assert_true(upstate.presence == nil,
    "unholy state.presence must be nil (no presence buff up -> switch lane live), got "
    .. tostring(upstate.presence))
print("PASS: unholy Presence regression (dk_presence optimal_presence + nil current)")

local frost, frost_err, frost_ns = aud.load_spec("deathknight", "frost", "wotlk")
assert_true(frost ~= nil, "deathknight/frost load failed: " .. tostring(frost_err))
_G.EaxRotations = frost_ns
assert_lane_matches(frost, frost_ns, "deathknight", "FrostPresence", "dk_presence",
    "frost FrostPresence must match in dk_presence (optimal_presence blood)")
print("PASS: frost FrostPresence regression (dk_presence optimal_presence)")

-- --- interrupt lanes: MindFreeze x3 (target_is_casting) ---
for _, spec_key in ipairs({ "blood", "frost", "unholy" }) do
    local mod = spec_key == "blood" and blood or (spec_key == "frost" and frost or unholy)
    local ns = spec_key == "blood" and blood_ns or (spec_key == "frost" and frost_ns or unholy_ns)
    local ctx, state = assert_lane_matches(mod, ns, "deathknight", "MindFreeze", "target_casting",
        "deathknight/" .. spec_key .. " MindFreeze must match in target_casting")
    assert_true(ctx.target_is_casting == true,
        "deathknight/" .. spec_key .. " MindFreeze needs target_is_casting")
    print("PASS: deathknight/" .. spec_key .. " MindFreeze regression (target_casting)")
end

-- --- runes-depleted: EmpowerRuneWeapon x2 (all runes ready == 0) ---
local ectx, est = assert_lane_matches(frost, frost_ns, "deathknight", "EmpowerRuneWeapon",
    "dk_runes_depleted", "frost EmpowerRuneWeapon must match in dk_runes_depleted")
assert_true((est.total_runes_ready or 0) == 0,
    "frost state.total_runes_ready must be 0 in dk_runes_depleted, got " .. tostring(est.total_runes_ready))
print("PASS: frost EmpowerRuneWeapon regression (dk_runes_depleted total 0)")

local ue = assert_lane_matches(unholy, unholy_ns, "deathknight", "EmpowerRuneWeapon",
    "dk_runes_depleted", "unholy EmpowerRuneWeapon must match in dk_runes_depleted")
print("PASS: unholy EmpowerRuneWeapon regression (dk_runes_depleted total 0)")

-- --- disease refresh: Pestilence x3 (frost fever + blood plague up, one < 3s) ---
local dctx, dst = assert_lane_matches(blood, blood_ns, "deathknight", "Pestilence",
    "dk_disease", "blood Pestilence must match in dk_disease")
assert_true((dst.frost_fever_remains or 0) > 0 and (dst.blood_plague_remains or 0) > 0,
    "blood Pestilence needs both diseases up (55095/55078 map), got ff="
    .. tostring(dst.frost_fever_remains) .. " bp=" .. tostring(dst.blood_plague_remains))
print("PASS: blood Pestilence regression (dk_disease both diseases up)")

local ud = assert_lane_matches(unholy, unholy_ns, "deathknight", "Pestilence",
    "dk_disease", "unholy Pestilence must match in dk_disease")
print("PASS: unholy Pestilence regression (dk_disease both diseases up)")

local dk_lvl, dk_lvl_err, dk_lvl_ns = aud.load_spec("deathknight", "leveling", "wotlk")
assert_true(dk_lvl ~= nil, "deathknight/leveling load failed: " .. tostring(dk_lvl_err))
_G.EaxRotations = dk_lvl_ns
local lctx, lst = assert_lane_matches(dk_lvl, dk_lvl_ns, "deathknight", "Pestilence",
    "dk_disease", "deathknight/leveling Pestilence must match in dk_disease")
-- leveling_wotlk derives diseases_up = ff > 0 or bp > 0 from the debuff map
-- (leveling:57-76) and gates Pestilence on it (leveling:129). Assert the
-- POSITIVE condition — a bare `~= nil` check would pass on 0/false.
assert_true(lst.diseases_up == true,
    "deathknight/leveling state.diseases_up must be true (debuff map 55095/55078), got "
    .. tostring(lst.diseases_up))
print("PASS: deathknight/leveling Pestilence regression (dk_disease diseases_up)")

-- ============================================================================
-- (2) resource-accessor clears — me:get_rage()/get_energy()/get_combo_points()
-- were missing from the battery player mock, so every resource read fell back
-- to 0 and these lanes never fired. Now bank-driven (rage 70 / energy 90 /
-- combo 5 defaults, scenario overrides respected).
-- ============================================================================

-- --- warrior arms Execute (rage + execute_ready from target_hp 8) ---
local arms, arms_err, arms_ns = aud.load_spec("warrior", "arms", "wotlk")
assert_true(arms ~= nil, "warrior/arms load failed: " .. tostring(arms_err))
_G.EaxRotations = arms_ns
local ax, ast = assert_lane_matches(arms, arms_ns, "warrior", "Execute", "execute",
    "arms Execute must match in execute (target_hp 8, rage bank)")
assert_true((ast.rage or 0) >= 10,
    "arms state.rage must be >= 10 (bank), got " .. tostring(ast.rage))
assert_true(ast.execute_ready == true,
    "arms state.execute_ready must be true (target_hp 8), got " .. tostring(ast.execute_ready))
print("PASS: arms Execute regression (execute rage + execute_ready)")

-- --- rogue combat SinisterStrike / SliceAndDice (energy/combo bank) ---
local combat, combat_err, combat_ns = aud.load_spec("rogue", "combat", "wotlk")
assert_true(combat ~= nil, "rogue/combat load failed: " .. tostring(combat_err))
_G.EaxRotations = combat_ns
local sctx, sst = assert_lane_matches(combat, combat_ns, "rogue", "SinisterStrike",
    "standard", "combat SinisterStrike must match in standard (energy 90)")
assert_true((sst.energy or 0) >= 45,
    "combat state.energy must be >= 45 (bank), got " .. tostring(sst.energy))
print("PASS: combat SinisterStrike regression (standard energy bank)")
assert_lane_matches(combat, combat_ns, "rogue", "SliceAndDice", "standard",
    "combat SliceAndDice must match in standard (combo bank)")
print("PASS: combat SliceAndDice regression (standard combo bank)")

-- --- rogue assassination Mutilate (energy bank + equipped daggers) ---
local assn, assn_err, assn_ns = aud.load_spec("rogue", "assassination", "wotlk")
assert_true(assn ~= nil, "rogue/assassination load failed: " .. tostring(assn_err))
_G.EaxRotations = assn_ns
local mctx, mst = assert_lane_matches(assn, assn_ns, "rogue", "Mutilate",
    "mutilate_daggers", "assassination Mutilate must match in mutilate_daggers")
assert_true((mst.energy or 0) >= 40,
    "assassination state.energy must be >= 40 (bank), got " .. tostring(mst.energy))
print("PASS: assassination Mutilate regression (mutilate_daggers energy bank)")

-- --- druid cat Shred / Rip (energy/combo bank in cat_form) ---
local cat, cat_err, cat_ns = aud.load_spec("druid", "cat", "wotlk")
assert_true(cat ~= nil, "druid/cat load failed: " .. tostring(cat_err))
_G.EaxRotations = cat_ns
local cctx, cst = assert_lane_matches(cat, cat_ns, "druid", "Shred", "cat_form",
    "cat Shred must match in cat_form (energy 60 + behind)")
assert_true((cst.energy or 0) >= 50,
    "cat state.energy must be >= 50 (bank), got " .. tostring(cst.energy))
assert_true(cst.is_behind == true,
    "cat Shred needs is_behind (battery default true), got " .. tostring(cst.is_behind))
print("PASS: cat Shred regression (cat_form energy bank + behind)")
-- Rip needs combo >= 5 (cat_form caps at 3) + rip_remains < 3 (default 0) —
-- the standard scenario's default combo bank (5) exercises the finisher gate.
assert_lane_matches(cat, cat_ns, "druid", "Rip", "standard",
    "cat Rip must match in standard (combo 5 bank)")
print("PASS: cat Rip regression (standard combo 5 bank)")

-- ============================================================================
-- End-to-end: the WOTLK-era battery must report none of the pinned lanes as
-- never-firing (mirrors the TBC regression test's assert_lane_fires).
-- ============================================================================
local function assert_lane_fires(class_key, spec, lane)
    local report = aud.run_spec(class_key, spec, nil, "wotlk")
    assert_true(report ~= nil, "battery run for " .. class_key .. "/" .. spec .. " failed")
    for _, name in ipairs(report.never) do
        assert_true(name ~= lane,
            "wotlk battery still reports " .. class_key .. "/" .. spec .. " " .. lane .. " as never-firing")
    end
end
assert_lane_fires("deathknight", "blood", "DancingRuneWeapon")
assert_lane_fires("deathknight", "blood", "Presence")
assert_lane_fires("deathknight", "blood", "MindFreeze")
assert_lane_fires("deathknight", "blood", "Pestilence")
assert_lane_fires("deathknight", "frost", "FrostPresence")
assert_lane_fires("deathknight", "frost", "EmpowerRuneWeapon")
assert_lane_fires("deathknight", "frost", "MindFreeze")
assert_lane_fires("deathknight", "unholy", "DeathCoil")
assert_lane_fires("deathknight", "unholy", "SummonGargoyle")
assert_lane_fires("deathknight", "unholy", "Presence")
assert_lane_fires("deathknight", "unholy", "EmpowerRuneWeapon")
assert_lane_fires("deathknight", "unholy", "MindFreeze")
assert_lane_fires("deathknight", "unholy", "Pestilence")
assert_lane_fires("deathknight", "leveling", "Pestilence")
assert_lane_fires("warrior", "arms", "Execute")
assert_lane_fires("rogue", "combat", "SinisterStrike")
assert_lane_fires("rogue", "combat", "SliceAndDice")
assert_lane_fires("rogue", "assassination", "Mutilate")
assert_lane_fires("druid", "cat", "Shred")
assert_lane_fires("druid", "cat", "Rip")
print("PASS: wotlk battery reports none of the pinned lanes as never-firing")
