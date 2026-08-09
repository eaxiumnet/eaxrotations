-- test_a_optin_closeout_regression.lua — pins the TBC category-(a) opt-in
-- close-out (2026-08-10). The scorecard's LANE_CLASS classified 14 remaining
-- (a) lanes as opt-in-setting-gated; a battery-fixture campaign (one scenario
-- per lane driving each spec's own setting via the setting_overrides merge,
-- plus an energy_time_to_x scenario stub for cat ShredTrick and
-- spell_action-object normalization in the buff/debuff stubs for enh
-- GraceOfAirTotemTwist) cleared all 14, dropping the TBC era never-count from
-- 60 to 46 with ZERO spec-file edits. This test pins the clears so a future
-- battery edit can't silently re-hide them.
-- WHAT:  the 14 lanes by spec (all battery-fixture, no matcher/order changes):
--   druid/balance    1: MoonkinForm (moonkin_form_optin: balance_moonkin_auto
--                       + OOC — DSL `in_combat invert` at balance:695)
--   druid/bear       1: Barkskin (bear_barkskin: bear_use_barkskin + caster
--                       form + hp 40 in (15,55] — TBC casts it OUT of bear)
--   druid/cat        2: RipTrick (cat_rip_trick: setting + combo 1 + energy 35
--                       in the [30,40) window + ttd 30), ShredTrick
--                       (cat_shred_trick: setting + behind + rip-up bleed +
--                       energy 80 + energy_time_to_x 2.0 for the next_tick > 1
--                       gate + combo 2)
--   mage/frost       3: FireBlast / Scorch / ArcaneMissiles (frost_*_optin:
--                       pure setting toggles, no state shape)
--   paladin/prot     4: AvengerShield (setting + normal in-combat mode),
--                       HammerOfWrath (DSL setting + target_hp 15 <= 20),
--                       Judgement (setting + Seal of Righteousness 27155 up ->
--                       damage mode), SealOfCommandAoE (setting + 4 enemies +
--                       no seal up)
--   paladin/retri    2: Consecration (setting + 4 enemies + mana 60),
--                       Ret_Consecration_ManaDump (setting + mana 80)
--   shaman/enh       1: GraceOfAirTotemTwist (enh_goa_twist: WF-buff 25587 up
--                       > 2s + GoA 25359 expiring < 5s; the battery
--                       buff_remains/buff_up/debuff_* stubs now normalize
--                       spell_action objects so ACTION.* lookups resolve)
-- Battery fixtures added: 14 scenarios, energy_time_to_x ctx key + _scenario_me
-- override, normalize_ids() shared by every map-aware id stub.
-- WHEN:  rotation suite execution (run_rotation_tests.lua).
-- WHY:   a future battery edit could silently re-hide these lanes; this test
--        fails if any stops firing (state + matcher + end-to-end never-list
--        via the TBC-era battery run).
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
-- druid/balance (1) — MoonkinForm needs balance_moonkin_auto + OUT of combat
-- (DSL in_combat invert) + the form spell ready.
-- ============================================================================
local bal, bal_err, bal_ns = aud.load_spec("druid", "balance")
assert_true(bal ~= nil, "druid/balance load failed: " .. tostring(bal_err))
_G.EaxRotations = bal_ns

local mk, mkst = assert_lane_matches(bal, bal_ns, "druid", "MoonkinForm", "moonkin_form_optin",
    "druid MoonkinForm must match in moonkin_form_optin (auto setting + OOC)")
assert_true(mk.in_combat == false,
    "druid MoonkinForm needs ctx.in_combat false, got " .. tostring(mk.in_combat))
assert_true(mk.settings and mk.settings.balance_moonkin_auto == true,
    "druid MoonkinForm needs the balance_moonkin_auto setting, got " .. tostring(mk.settings and mk.settings.balance_moonkin_auto))
print("PASS: balance MoonkinForm regression (moonkin_form_optin)")

-- ============================================================================
-- druid/bear (1) — Barkskin needs bear_use_barkskin + in combat + NOT bear
-- form (TBC breaks the form) + hp in (15, 55] + no existing barkskin buff.
-- ============================================================================
local bear, bear_err, bear_ns = aud.load_spec("druid", "bear")
assert_true(bear ~= nil, "druid/bear load failed: " .. tostring(bear_err))
_G.EaxRotations = bear_ns

local bs, bsst = assert_lane_matches(bear, bear_ns, "druid", "Barkskin", "bear_barkskin",
    "druid Barkskin must match in bear_barkskin (setting + caster form + hp 40)")
assert_true((bsst.hp or 100) > 15 and (bsst.hp or 100) <= (bsst.barkskin_hp or 55),
    "druid Barkskin needs hp in (15, barkskin_hp], got " .. tostring(bsst.hp))
print("PASS: bear Barkskin regression (bear_barkskin)")

-- ============================================================================
-- druid/cat (2) — RipTrick (setting + combo >= 1 + rip down + energy window
-- [30,40)); ShredTrick (setting + behind + bleed up + energy >= 42 +
-- next_tick > 1.0 via energy_time_to_x + combo < 5).
-- ============================================================================
local cat, cat_err, cat_ns = aud.load_spec("druid", "cat")
assert_true(cat ~= nil, "druid/cat load failed: " .. tostring(cat_err))
_G.EaxRotations = cat_ns

local rt, rtst = assert_lane_matches(cat, cat_ns, "druid", "RipTrick", "cat_rip_trick",
    "druid RipTrick must match in cat_rip_trick (setting + combo 1 + energy 35)")
assert_true((rtst.energy or 0) >= 30 and (rtst.energy or 0) < 40,
    "druid RipTrick needs energy in [30,40), got " .. tostring(rtst.energy))
assert_true((rtst.combo_points or 0) >= 1,
    "druid RipTrick needs combo_points >= 1, got " .. tostring(rtst.combo_points))
print("PASS: cat RipTrick regression (cat_rip_trick)")

local st2, st2st = assert_lane_matches(cat, cat_ns, "druid", "ShredTrick", "cat_shred_trick",
    "druid ShredTrick must match in cat_shred_trick (setting + bleed + energy 80)")
assert_true((st2st.next_tick_in or 0) > 1.0,
    "druid ShredTrick needs next_tick_in > 1.0 (energy_time_to_x stub), got " .. tostring(st2st.next_tick_in))
assert_true((st2st.energy or 0) >= 42,
    "druid ShredTrick needs energy >= SHRED_COST, got " .. tostring(st2st.energy))
print("PASS: cat ShredTrick regression (cat_shred_trick)")

-- ============================================================================
-- mage/frost (3) — pure setting toggles (frost:400/432/440 read
-- context.settings.<key> == true directly).
-- ============================================================================
local frost, frost_err, frost_ns = aud.load_spec("mage", "frost")
assert_true(frost ~= nil, "mage/frost load failed: " .. tostring(frost_err))
_G.EaxRotations = frost_ns

assert_lane_matches(frost, frost_ns, "mage", "FireBlast", "frost_fire_blast",
    "mage FireBlast must match in frost_fire_blast (setting on)")
print("PASS: frost FireBlast regression (frost_fire_blast)")

assert_lane_matches(frost, frost_ns, "mage", "Scorch", "frost_scorch",
    "mage Scorch must match in frost_scorch (setting on)")
print("PASS: frost Scorch regression (frost_scorch)")

assert_lane_matches(frost, frost_ns, "mage", "ArcaneMissiles", "frost_arcane_missiles",
    "mage ArcaneMissiles must match in frost_arcane_missiles (setting on)")
print("PASS: frost ArcaneMissiles regression (frost_arcane_missiles)")

-- ============================================================================
-- paladin/protection (4) — AvengerShield (setting + in-combat mode + ready);
-- HammerOfWrath (DSL setting + execute hp); Judgement (setting + damage seal
-- up -> damage mode); SealOfCommandAoE (setting + 4 enemies + no seal).
-- ============================================================================
local prot, prot_err, prot_ns = aud.load_spec("paladin", "protection")
assert_true(prot ~= nil, "paladin/protection load failed: " .. tostring(prot_err))
_G.EaxRotations = prot_ns

assert_lane_matches(prot, prot_ns, "paladin", "AvengerShield", "prot_avenger_shield",
    "paladin AvengerShield must match in prot_avenger_shield (setting + combat)")
print("PASS: prot AvengerShield regression (prot_avenger_shield)")

local hw, hwst = assert_lane_matches(prot, prot_ns, "paladin", "HammerOfWrath", "prot_hammer_wrath",
    "paladin HammerOfWrath must match in prot_hammer_wrath (setting + execute hp)")
assert_true((hwst.target_hp_pct or 100) <= 20,
    "paladin HammerOfWrath needs target_hp <= 20, got " .. tostring(hwst.target_hp_pct))
print("PASS: prot HammerOfWrath regression (prot_hammer_wrath)")

local jd, jdst = assert_lane_matches(prot, prot_ns, "paladin", "Judgement", "prot_judgement",
    "paladin Judgement must match in prot_judgement (setting + seal up)")
assert_true(jdst.has_seal or jdst.has_seal_command,
    "paladin Judgement damage mode needs a damage seal up (has_seal/has_seal_command)")
print("PASS: prot Judgement regression (prot_judgement)")

local sc, scst = assert_lane_matches(prot, prot_ns, "paladin", "SealOfCommandAoE", "prot_seal_command",
    "paladin SealOfCommandAoE must match in prot_seal_command (setting + 4 enemies)")
assert_true((scst.enemy_count or 0) >= 3,
    "paladin SealOfCommandAoE needs enemy_count >= 3, got " .. tostring(scst.enemy_count))
print("PASS: prot SealOfCommandAoE regression (prot_seal_command)")

-- ============================================================================
-- paladin/retribution (2) — Consecration (setting + aoe + mana); mana dump
-- (setting + high mana, single-target).
-- ============================================================================
local ret, ret_err, ret_ns = aud.load_spec("paladin", "retribution")
assert_true(ret ~= nil, "paladin/retribution load failed: " .. tostring(ret_err))
_G.EaxRotations = ret_ns

assert_lane_matches(ret, ret_ns, "paladin", "Consecration", "ret_consecration",
    "paladin Consecration must match in ret_consecration (setting + aoe + mana)")
print("PASS: ret Consecration regression (ret_consecration)")

assert_lane_matches(ret, ret_ns, "paladin", "Ret_Consecration_ManaDump", "ret_consec_dump",
    "paladin Ret_Consecration_ManaDump must match in ret_consec_dump (setting + mana 80)")
print("PASS: ret Ret_Consecration_ManaDump regression (ret_consec_dump)")

-- ============================================================================
-- shaman/enhancement (1) — GraceOfAirTotemTwist: WF buff up (>2s) + GoA buff
-- expiring (<5s) + mana >= 40 + not moving + GoA ready + no recent GoA cast.
-- The buff map supplies both totem auras; spell_action-object normalization
-- in the battery's buff_remains/buff_up stubs makes ACTION.* lookups resolve.
-- ============================================================================
local enh, enh_err, enh_ns = aud.load_spec("shaman", "enhancement")
assert_true(enh ~= nil, "shaman/enhancement load failed: " .. tostring(enh_err))
_G.EaxRotations = enh_ns

local goa, goast = assert_lane_matches(enh, enh_ns, "shaman", "GraceOfAirTotemTwist", "enh_goa_twist",
    "shaman GraceOfAirTotemTwist must match in enh_goa_twist (WF buff up + GoA expiring)")
assert_true((goast.mana_pct or 0) >= 40,
    "shaman GraceOfAirTotemTwist needs mana >= 40, got " .. tostring(goast.mana_pct))
print("PASS: enh GraceOfAirTotemTwist regression (enh_goa_twist)")

-- ============================================================================
-- End-to-end: the TBC-era battery must report none of the pinned lanes as
-- never-firing (mirrors the batch-2 regression's assert_lane_fires).
-- ============================================================================
local function assert_lane_fires(class_key, spec, lane)
    local report = aud.run_spec(class_key, spec)
    assert_true(report ~= nil, "battery run for " .. class_key .. "/" .. spec .. " failed")
    for _, name in ipairs(report.never) do
        assert_true(name ~= lane,
            "tbc battery still reports " .. class_key .. "/" .. spec .. " " .. lane .. " as never-firing")
    end
end
assert_lane_fires("druid", "balance", "MoonkinForm")
assert_lane_fires("druid", "bear", "Barkskin")
assert_lane_fires("druid", "cat", "RipTrick")
assert_lane_fires("druid", "cat", "ShredTrick")
assert_lane_fires("mage", "frost", "FireBlast")
assert_lane_fires("mage", "frost", "Scorch")
assert_lane_fires("mage", "frost", "ArcaneMissiles")
assert_lane_fires("paladin", "protection", "AvengerShield")
assert_lane_fires("paladin", "protection", "HammerOfWrath")
assert_lane_fires("paladin", "protection", "Judgement")
assert_lane_fires("paladin", "protection", "SealOfCommandAoE")
assert_lane_fires("paladin", "retribution", "Consecration")
assert_lane_fires("paladin", "retribution", "Ret_Consecration_ManaDump")
assert_lane_fires("shaman", "enhancement", "GraceOfAirTotemTwist")
print("PASS: tbc battery reports none of the 14 (a) lanes as never-firing")
