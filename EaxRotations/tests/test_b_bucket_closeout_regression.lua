-- test_b_bucket_closeout_regression.lua — pins the TBC category-(b)
-- close-out (2026-08-10). The scorecard's LANE_CLASS classified 43 (b) lanes
-- as PvP / out-of-combat / situational; the audit triaged 28 as
-- fixture-modelable and this battery-fixture campaign cleared 27 of them
-- (the 28th, smite DevouringPlague, binds _player_race at require time and
-- needs a second race-5 load — pinned with rationale in LANE_CLASS). TBC
-- never-count drops 46 → 19 (b=16: 9 correctly-silent + 5 threat-family +
-- EncounterReactions + DevouringPlague; c=3 unchanged) with ZERO spec-file
-- edits. This test pins the clears so a future battery edit can't silently
-- re-hide them.
-- WHAT:  the 27 lanes by spec (all battery-fixture, no matcher/order changes):
--   druid/balance   3: PvP_Cyclone / PvP_EntanglingRoots / PvP_NaturesGrasp
--                      (pvp_melee: is_pvp + enemy_healer / melee_on_you)
--   druid/bear      1: ChallengingRoar (bear_challenging_roar: the dedicated
--                      bear_use_challenging_roar toggle + form=1 + 4 enemies —
--                      re-bucketed from (b) to the (a)-shape and closed)
--   druid/resto     4: BearFormFocusedByMelee / NaturesGraspMelee /
--                      CycloneEnemyHealer / EntanglingRootsMelee
--                      (pvp_pressure_resto: enemies_in_range feeds a new
--                      GetEnemiesInRange stub so scan_pvp_pressure fills
--                      melee_pressure_count / enemy_healer / root_target)
--   hunter/BM       1: Misdirection (bm_misdirection: combat_time ≤ 6 window
--                      + use_misdirection setting)
--   mage/arcane     2: Blink (snare_self: self_rooted_snared), Polymorph
--                      (pvp_melee: is_pvp + cc_target presented as a unit)
--   mage/fire       1: Polymorph (pvp_melee)
--   mage/frost      1: Blink (snare_self)
--   paladin/prot    1: BlessingOfFreedomSnare (snare_self: snared_friend
--                      marks the lowest heal-scan ally is_snared)
--   paladin/ret     3: Ret_BlessingFreedom_Self / Ret_BlessingFreedom_Ally
--                      (snare_self: self_rooted_snared + player-debuff map 122),
--                      Ret_HammerWrath_FleeingPvP (pvp_melee: is_pvp +
--                      target_fleeing + target_hp < 25)
--   priest/shadow   1: SWDCCBreak (shadow_cc_break: player Polymorph 118 in
--                      player_debuff_remains_map → OffensiveDispelDB
--                      is_breakable_cc_active → has_breakable_cc fallback)
--   priest/smite    1: Starshards (require-time race 4 via RACE_OVERRIDES)
--   shaman ×3       3: TremorTotem (fear_nearby ctx key, all three specs)
--   shaman/enh      1: AutoAttack (is_auto_attacking stub flipped to false —
--                      battery artifact only; the live client reports
--                      not-auto-attacking at combat start, so no spec change)
--   warlock/affl    3: CC_HowlOfTerror / PvP_CurseExhaustion / PvP_CurseTongues
--                      (pvp_melee: is_pvp + melee_on_you / enemy_caster)
--   warlock/demo    1: Seduction (pvp_succubus: has_pet + pet_spells Lash of
--                      Pain 27274 → pet_type_succubus)
-- Battery fixtures added: 9 scenarios (pvp_melee, pvp_pressure_resto,
-- fear_nearby, snare_self, shadow_cc_break, bm_misdirection,
-- bear_challenging_roar, enh_autoattack, pvp_succubus), GetEnemiesInRange
-- stub + _battery_enemy factory, is_auto_attacking stub (default true),
-- OffensiveDispelDB.is_breakable_cc_active delegate, pet_spells +
-- me.has_pet/get_pet, debuff_up/debuff_remains player-map branches,
-- snared_friend heal-entry flag, RACE_OVERRIDES, cc_target unit resolution.
-- WHEN:  rotation suite execution (run_rotation_tests.lua).
-- WHY:   a future battery edit could silently re-hide these lanes; this test
--        fails if any stops firing (state + matcher + end-to-end never-list).
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

local function assert_lane_fires(class_key, spec, lane)
    local report = aud.run_spec(class_key, spec)
    assert_true(report ~= nil, "battery run for " .. class_key .. "/" .. spec .. " failed")
    for _, name in ipairs(report.never) do
        assert_true(name ~= lane,
            "tbc battery still reports " .. class_key .. "/" .. spec .. " " .. lane .. " as never-firing")
    end
end

-- ============================================================================
-- druid/balance (3) — PvP lanes: pvp_melee (is_pvp + melee_on_you +
-- enemy_healer).
-- ============================================================================
local bal, bal_err, bal_ns = aud.load_spec("druid", "balance")
assert_true(bal ~= nil, "druid/balance load failed: " .. tostring(bal_err))
_G.EaxRotations = bal_ns

assert_lane_matches(bal, bal_ns, "druid", "PvP_Cyclone", "pvp_melee",
    "druid PvP_Cyclone must match in pvp_melee (is_pvp + enemy_healer)")
print("PASS: balance PvP_Cyclone regression (pvp_melee)")
assert_lane_matches(bal, bal_ns, "druid", "PvP_EntanglingRoots", "pvp_melee",
    "druid PvP_EntanglingRoots must match in pvp_melee (is_pvp + melee_on_you)")
print("PASS: balance PvP_EntanglingRoots regression (pvp_melee)")
assert_lane_matches(bal, bal_ns, "druid", "PvP_NaturesGrasp", "pvp_melee",
    "druid PvP_NaturesGrasp must match in pvp_melee (is_pvp + melee_on_you)")
print("PASS: balance PvP_NaturesGrasp regression (pvp_melee)")

-- ============================================================================
-- druid/bear (1) — ChallengingRoar: dedicated toggle + bear form + 3+ enemies.
-- ============================================================================
local bear, bear_err, bear_ns = aud.load_spec("druid", "bear")
assert_true(bear ~= nil, "druid/bear load failed: " .. tostring(bear_err))
_G.EaxRotations = bear_ns

local cr, crst = assert_lane_matches(bear, bear_ns, "druid", "ChallengingRoar", "bear_challenging_roar",
    "druid ChallengingRoar must match in bear_challenging_roar (toggle + 4 enemies)")
assert_true(crst.use_challenging_roar == true,
    "druid ChallengingRoar needs use_challenging_roar true, got " .. tostring(crst.use_challenging_roar))
assert_true((crst.enemy_count or 0) >= 3,
    "druid ChallengingRoar needs enemy_count >= 3, got " .. tostring(crst.enemy_count))
print("PASS: bear ChallengingRoar regression (bear_challenging_roar)")

-- ============================================================================
-- druid/resto (4) — PvP pressure: enemies_in_range feeds GetEnemiesInRange so
-- melee_pressure_count / enemy_healer / root_target populate.
-- ============================================================================
local resto, resto_err, resto_ns = aud.load_spec("druid", "resto")
assert_true(resto ~= nil, "druid/resto load failed: " .. tostring(resto_err))
_G.EaxRotations = resto_ns

local bf, bfst = assert_lane_matches(resto, resto_ns, "druid", "BearFormFocusedByMelee", "pvp_pressure_resto",
    "druid BearFormFocusedByMelee must match in pvp_pressure_resto (is_pvp + melee pressure + hp <= 35)")
assert_true((bfst.melee_pressure_count or 0) > 0,
    "druid BearFormFocusedByMelee needs melee_pressure_count > 0, got " .. tostring(bfst.melee_pressure_count))
assert_true((bf.hp or 100) <= 35,
    "druid BearFormFocusedByMelee needs ctx.hp <= 35, got " .. tostring(bf.hp))
print("PASS: resto BearFormFocusedByMelee regression (pvp_pressure_resto)")

assert_lane_matches(resto, resto_ns, "druid", "NaturesGraspMelee", "pvp_pressure_resto",
    "druid NaturesGraspMelee must match in pvp_pressure_resto (is_pvp + melee pressure)")
print("PASS: resto NaturesGraspMelee regression (pvp_pressure_resto)")

local ceh, cehst = assert_lane_matches(resto, resto_ns, "druid", "CycloneEnemyHealer", "pvp_pressure_resto",
    "druid CycloneEnemyHealer must match in pvp_pressure_resto (is_pvp + enemy_healer)")
assert_true(cehst.enemy_healer ~= nil,
    "druid CycloneEnemyHealer needs state.enemy_healer populated by the GetEnemiesInRange stub")
print("PASS: resto CycloneEnemyHealer regression (pvp_pressure_resto)")

local er, erst = assert_lane_matches(resto, resto_ns, "druid", "EntanglingRootsMelee", "pvp_pressure_resto",
    "druid EntanglingRootsMelee must match in pvp_pressure_resto (is_pvp + root_target)")
assert_true(erst.root_target ~= nil,
    "druid EntanglingRootsMelee needs state.root_target populated by the GetEnemiesInRange stub")
print("PASS: resto EntanglingRootsMelee regression (pvp_pressure_resto)")

-- ============================================================================
-- hunter/beast_mastery (1) — Misdirection: combat_time <= 6 + setting.
-- ============================================================================
local bm, bm_err, bm_ns = aud.load_spec("hunter", "beast_mastery")
assert_true(bm ~= nil, "hunter/beast_mastery load failed: " .. tostring(bm_err))
_G.EaxRotations = bm_ns

local md, mdst = assert_lane_matches(bm, bm_ns, "hunter", "Misdirection", "bm_misdirection",
    "hunter Misdirection must match in bm_misdirection (combat_time 2 + setting)")
assert_true((md.combat_time or 0) <= 6,
    "hunter Misdirection needs combat_time <= 6, got " .. tostring(md.combat_time))
assert_true(mdst.use_misdirection == true,
    "hunter Misdirection needs use_misdirection true, got " .. tostring(mdst.use_misdirection))
print("PASS: BM Misdirection regression (bm_misdirection)")

-- ============================================================================
-- mage/arcane (2) — Blink (snare_self), Polymorph (pvp_melee); mage/fire (1)
-- Polymorph; mage/frost (1) Blink.
-- ============================================================================
local arc, arc_err, arc_ns = aud.load_spec("mage", "arcane")
assert_true(arc ~= nil, "mage/arcane load failed: " .. tostring(arc_err))
_G.EaxRotations = arc_ns

assert_lane_matches(arc, arc_ns, "mage", "Blink", "snare_self",
    "mage Blink must match in snare_self (self_rooted_snared)")
print("PASS: arcane Blink regression (snare_self)")
assert_lane_matches(arc, arc_ns, "mage", "Polymorph", "pvp_melee",
    "mage Polymorph must match in pvp_melee (is_pvp + cc_target unit)")
print("PASS: arcane Polymorph regression (pvp_melee)")

local fire, fire_err, fire_ns = aud.load_spec("mage", "fire")
assert_true(fire ~= nil, "mage/fire load failed: " .. tostring(fire_err))
_G.EaxRotations = fire_ns

assert_lane_matches(fire, fire_ns, "mage", "Polymorph", "pvp_melee",
    "mage Polymorph must match in pvp_melee (is_pvp + cc_target unit)")
print("PASS: fire Polymorph regression (pvp_melee)")

local frost, frost_err, frost_ns = aud.load_spec("mage", "frost")
assert_true(frost ~= nil, "mage/frost load failed: " .. tostring(frost_err))
_G.EaxRotations = frost_ns

assert_lane_matches(frost, frost_ns, "mage", "Blink", "snare_self",
    "mage Blink must match in snare_self (self_rooted_snared)")
print("PASS: frost Blink regression (snare_self)")

-- ============================================================================
-- paladin/holy (1) — BlessingOfFreedomSnare via the snared_friend
-- heal-entry flag (the lane lives in holy_sylvanas.lua:934, despite the
-- scorecard's LANE_CLASS grouping it under protection); paladin/retribution (3).
-- ============================================================================
local holy, holy_err, holy_ns = aud.load_spec("paladin", "holy")
assert_true(holy ~= nil, "paladin/holy load failed: " .. tostring(holy_err))
_G.EaxRotations = holy_ns

local bof, bofst = assert_lane_matches(holy, holy_ns, "paladin", "BlessingOfFreedomSnare", "snare_self",
    "paladin BlessingOfFreedomSnare must match in snare_self (snared_friend entry)")
assert_true(bofst.freedom_target ~= nil,
    "paladin BlessingOfFreedomSnare needs freedom_target set (snared_friend flag)")
print("PASS: holy BlessingOfFreedomSnare regression (snare_self)")

local ret, ret_err, ret_ns = aud.load_spec("paladin", "retribution")
assert_true(ret ~= nil, "paladin/retribution load failed: " .. tostring(ret_err))
_G.EaxRotations = ret_ns

assert_lane_matches(ret, ret_ns, "paladin", "Ret_BlessingFreedom_Self", "snare_self",
    "paladin Ret_BlessingFreedom_Self must match in snare_self (self_rooted_snared)")
print("PASS: ret Ret_BlessingFreedom_Self regression (snare_self)")
assert_lane_matches(ret, ret_ns, "paladin", "Ret_BlessingFreedom_Ally", "snare_self",
    "paladin Ret_BlessingFreedom_Ally must match in snare_self (player-debuff map 122)")
print("PASS: ret Ret_BlessingFreedom_Ally regression (snare_self)")

local hw, hwst = assert_lane_matches(ret, ret_ns, "paladin", "Ret_HammerWrath_FleeingPvP", "pvp_melee",
    "paladin Ret_HammerWrath_FleeingPvP must match in pvp_melee (is_pvp + fleeing + hp < 25)")
assert_true(hwst.target_fleeing == true,
    "paladin Ret_HammerWrath_FleeingPvP needs target_fleeing, got " .. tostring(hwst.target_fleeing))
assert_true((hwst.target_hp_pct or 100) < 25,
    "paladin Ret_HammerWrath_FleeingPvP needs target_hp < 25, got " .. tostring(hwst.target_hp_pct))
print("PASS: ret Ret_HammerWrath_FleeingPvP regression (pvp_melee)")

-- ============================================================================
-- priest/shadow (1) — SWDCCBreak via the has_breakable_cc fallback path.
-- ============================================================================
local shadow, shadow_err, shadow_ns = aud.load_spec("priest", "shadow")
assert_true(shadow ~= nil, "priest/shadow load failed: " .. tostring(shadow_err))
_G.EaxRotations = shadow_ns

local swd, swdst = assert_lane_matches(shadow, shadow_ns, "priest", "SWDCCBreak", "shadow_cc_break",
    "priest SWDCCBreak must match in shadow_cc_break (player breakable-CC debuff 118)")
assert_true(swdst.has_breakable_cc == true,
    "priest SWDCCBreak needs has_breakable_cc true (player_debuff_remains_map [118]), got "
        .. tostring(swdst.has_breakable_cc))
print("PASS: shadow SWDCCBreak regression (shadow_cc_break)")

-- ============================================================================
-- priest/smite (1) — Starshards via require-time race 4 (RACE_OVERRIDES).
-- Fires in the standard scenario (no dedicated scenario needed).
-- ============================================================================
local smite, smite_err, smite_ns = aud.load_spec("priest", "smite")
assert_true(smite ~= nil, "priest/smite load failed: " .. tostring(smite_err))
_G.EaxRotations = smite_ns

assert_lane_matches(smite, smite_ns, "priest", "Starshards", "standard",
    "priest Starshards must match in standard (race 4 night elf binding)")
print("PASS: smite Starshards regression (RACE_OVERRIDES race 4)")

-- ============================================================================
-- shaman (3 TremorTotem + 1 AutoAttack) — fear_nearby / is_auto_attacking.
-- ============================================================================
local ele, ele_err, ele_ns = aud.load_spec("shaman", "elemental")
assert_true(ele ~= nil, "shaman/elemental load failed: " .. tostring(ele_err))
_G.EaxRotations = ele_ns

assert_lane_matches(ele, ele_ns, "shaman", "TremorTotem", "fear_nearby",
    "shaman TremorTotem must match in fear_nearby (ele)")
print("PASS: elemental TremorTotem regression (fear_nearby)")

local enh, enh_err, enh_ns = aud.load_spec("shaman", "enhancement")
assert_true(enh ~= nil, "shaman/enhancement load failed: " .. tostring(enh_err))
_G.EaxRotations = enh_ns

assert_lane_matches(enh, enh_ns, "shaman", "TremorTotem", "fear_nearby",
    "shaman TremorTotem must match in fear_nearby (enh)")
print("PASS: enhancement TremorTotem regression (fear_nearby)")

local aa, aast = assert_lane_matches(enh, enh_ns, "shaman", "AutoAttack", "enh_autoattack",
    "shaman AutoAttack must match in enh_autoattack (is_auto_attacking false)")
assert_true(aa.is_auto_attacking == false,
    "shaman AutoAttack needs is_auto_attacking false (stub flip), got " .. tostring(aa.is_auto_attacking))
print("PASS: enhancement AutoAttack regression (enh_autoattack)")

local sh_resto, shresto_err, shresto_ns = aud.load_spec("shaman", "restoration")
assert_true(sh_resto ~= nil, "shaman/restoration load failed: " .. tostring(shresto_err))
_G.EaxRotations = shresto_ns

assert_lane_matches(sh_resto, shresto_ns, "shaman", "TremorTotem", "fear_nearby",
    "shaman TremorTotem must match in fear_nearby (resto)")
print("PASS: restoration TremorTotem regression (fear_nearby)")

-- ============================================================================
-- warlock/affliction (3) + warlock/demonology (1).
-- ============================================================================
local affl, affl_err, affl_ns = aud.load_spec("warlock", "affliction")
assert_true(affl ~= nil, "warlock/affliction load failed: " .. tostring(affl_err))
_G.EaxRotations = affl_ns

assert_lane_matches(affl, affl_ns, "warlock", "CC_HowlOfTerror", "pvp_melee",
    "warlock CC_HowlOfTerror must match in pvp_melee (is_pvp + melee_on_you)")
print("PASS: affliction CC_HowlOfTerror regression (pvp_melee)")
assert_lane_matches(affl, affl_ns, "warlock", "PvP_CurseExhaustion", "pvp_melee",
    "warlock PvP_CurseExhaustion must match in pvp_melee (is_pvp + melee_on_you)")
print("PASS: affliction PvP_CurseExhaustion regression (pvp_melee)")
assert_lane_matches(affl, affl_ns, "warlock", "PvP_CurseTongues", "pvp_melee",
    "warlock PvP_CurseTongues must match in pvp_melee (is_pvp + enemy_caster)")
print("PASS: affliction PvP_CurseTongues regression (pvp_melee)")

local demo, demo_err, demo_ns = aud.load_spec("warlock", "demonology")
assert_true(demo ~= nil, "warlock/demonology load failed: " .. tostring(demo_err))
_G.EaxRotations = demo_ns

local sed, sedst = assert_lane_matches(demo, demo_ns, "warlock", "Seduction", "pvp_succubus",
    "warlock Seduction must match in pvp_succubus (is_pvp + succubus pet)")
assert_true(sedst.pet_type_succubus == true,
    "warlock Seduction needs pet_type_succubus true (pet_spells Lash of Pain 27274)")
print("PASS: demonology Seduction regression (pvp_succubus)")

-- ============================================================================
-- End-to-end: the TBC-era battery must report none of the pinned lanes as
-- never-firing.
-- ============================================================================
local FIRES = {
    { "druid", "balance", "PvP_Cyclone" },
    { "druid", "balance", "PvP_EntanglingRoots" },
    { "druid", "balance", "PvP_NaturesGrasp" },
    { "druid", "bear", "ChallengingRoar" },
    { "druid", "resto", "BearFormFocusedByMelee" },
    { "druid", "resto", "NaturesGraspMelee" },
    { "druid", "resto", "CycloneEnemyHealer" },
    { "druid", "resto", "EntanglingRootsMelee" },
    { "hunter", "beast_mastery", "Misdirection" },
    { "mage", "arcane", "Blink" },
    { "mage", "arcane", "Polymorph" },
    { "mage", "fire", "Polymorph" },
    { "mage", "frost", "Blink" },
    { "paladin", "holy", "BlessingOfFreedomSnare" },
    { "paladin", "retribution", "Ret_BlessingFreedom_Self" },
    { "paladin", "retribution", "Ret_BlessingFreedom_Ally" },
    { "paladin", "retribution", "Ret_HammerWrath_FleeingPvP" },
    { "priest", "shadow", "SWDCCBreak" },
    { "priest", "smite", "Starshards" },
    { "shaman", "elemental", "TremorTotem" },
    { "shaman", "enhancement", "TremorTotem" },
    { "shaman", "enhancement", "AutoAttack" },
    { "shaman", "restoration", "TremorTotem" },
    { "warlock", "affliction", "CC_HowlOfTerror" },
    { "warlock", "affliction", "PvP_CurseExhaustion" },
    { "warlock", "affliction", "PvP_CurseTongues" },
    { "warlock", "demonology", "Seduction" },
}
for _, f in ipairs(FIRES) do
    assert_lane_fires(f[1], f[2], f[3])
end
print("PASS: tbc battery reports none of the 27 (b) lanes as never-firing")
