-- test_c_batch2_closeout_regression.lua — pins the TBC category-(c) batch-2
-- close-out (2026-08-09). The scorecard's LANE_CLASS classified 21 remaining
-- (c) lanes as battery-mock-limitation-but-modelable; a battery-fixture
-- campaign (new scenario banks + debuff map-awareness + find_dead + trinket
-- stub + target get_cast_pct) cleared 18, dropping the TBC era never-count
-- from 78 to 60 with one genuine spec-file dead-lane fix (BM Trinket's
-- is_item_ready forward-declaration shadowing). This test pins the clears so
-- a future battery edit can't silently re-hide them.
-- WHAT:  the 18 lanes by spec, mirroring test_healer_c_closeout_regression.lua:
--   druid/balance    2: HurricaneAoE (hurricane_aoe), RebirthBattleRez
--                       (rebirth_dead_ally dead-ally bank + find_dead stub)
--   druid/bear       2: Swipe (bear_swipe_aoe form=1 aoe rage short-ttd),
--                       EnrageCombat (bear_enrage rage-starved single)
--   druid/cat        2: ClawFallback (cat_claw_fallback Mangle unlearned),
--                       MangleFiller (cat_mangle_filler not behind)
--   hunter/BM        1: Trinket (bm_trinket has_trinket + trinket stub +
--                       is_item_ready spec fix)
--   hunter/MM        1: InCombatAimedShot (mm_aimed_opener combat_time 0.2)
--   paladin/prot     2: AvengingWrath (prot_cd_window), LayOnHands
--                       (prot_low_self hp 5)
--   paladin/retri    3: Ret_Cleanse_Self / Ret_Purify_SelfFallback /
--                       Ret_Cleanse_Ally (ret_cleanse_self player-debuff map)
--   shaman/elem      3: ChainHeal (elem_group_injured), ElementalMastery
--                       (elem_burst_cd), TotemicCall (elem_totemic_call)
--   shaman/enh       2: EarthShock (enh_interrupt target cast pct),
--                       ShamanisticRage (enh_low_mana + cd setting)
--   Battery fixtures added: DruidSpells.Hurricane + find_dead_party_ally
--   stubs, map-aware has_player_debuff / has_target_debuff (player-debuff
--   map), TrinketManager.get_equipped_trinkets (has_trinket), scenario-target
--   get_cast_pct, has_trinket/is_behind/group_injured/has_totems/dead_ally
--   ctx keys, and the 16 batch-2 scenarios above.
--   Genuine dead-lane fix (not a fixture): beast_mastery_sylvanas.lua line 78
--   `local is_item_ready` was shadowed by line 458 `local function
--   is_item_ready(...)` (a second local), so build_state's safe_any received
--   nil and trinket_1_ready was always false in LIVE game too — Trinket could
--   never fire anywhere. Changed 458 to an assignment so the line-78 local is
--   populated.
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
-- druid/balance (2) — HurricaneAoE needs aoe + mana + Barkskin active so the
-- ready-Barkskin deferral gate passes; RebirthBattleRez needs a dead ally via
-- find_dead_party_ally (dead_ally bank).
-- ============================================================================
local bal, bal_err, bal_ns = aud.load_spec("druid", "balance")
assert_true(bal ~= nil, "druid/balance load failed: " .. tostring(bal_err))
_G.EaxRotations = bal_ns

local hctx, hst = assert_lane_matches(bal, bal_ns, "druid", "HurricaneAoE",
    "hurricane_aoe", "druid HurricaneAoE must match in hurricane_aoe (aoe + mana + barkskin)")
assert_true((hst.enemy_count or 0) >= 4,
    "druid HurricaneAoE needs enemy_count >= 4, got " .. tostring(hst.enemy_count))
print("PASS: balance HurricaneAoE regression (hurricane_aoe)")

assert_lane_matches(bal, bal_ns, "druid", "RebirthBattleRez", "rebirth_dead_ally",
    "druid RebirthBattleRez must match in rebirth_dead_ally (dead player ally)")
print("PASS: balance RebirthBattleRez regression (rebirth_dead_ally)")

-- ============================================================================
-- druid/bear (2) — Swipe needs bear form (form=1) + aoe + rage + short TTD so
-- the Lacerate pre-stack gate passes; EnrageCombat needs rage-starved single.
-- ============================================================================
local bear, bear_err, bear_ns = aud.load_spec("druid", "bear")
assert_true(bear ~= nil, "druid/bear load failed: " .. tostring(bear_err))
_G.EaxRotations = bear_ns

assert_lane_matches(bear, bear_ns, "druid", "Swipe", "bear_swipe_aoe",
    "druid Swipe must match in bear_swipe_aoe (bear form + aoe + rage + short ttd)")
print("PASS: bear Swipe regression (bear_swipe_aoe)")

local ec, est = assert_lane_matches(bear, bear_ns, "druid", "EnrageCombat", "bear_enrage",
    "druid EnrageCombat must match in bear_enrage (rage-starved single)")
assert_true((est.rage or 0) <= 30,
    "druid EnrageCombat needs rage <= 30, got " .. tostring(est.rage))
print("PASS: bear EnrageCombat regression (bear_enrage)")

-- ============================================================================
-- druid/cat (2) — ClawFallback needs Mangle unlearned; MangleFiller needs not
-- behind so the Shred-preference gate passes. (RakeSnapshot/RipSnapshot stay
-- (c)-pinned unpinnable: module-local snapshot_state, no battery reach.)
-- ============================================================================
local cat, cat_err, cat_ns = aud.load_spec("druid", "cat")
assert_true(cat ~= nil, "druid/cat load failed: " .. tostring(cat_err))
_G.EaxRotations = cat_ns

local cf, cfst = assert_lane_matches(cat, cat_ns, "druid", "ClawFallback", "cat_claw_fallback",
    "druid ClawFallback must match in cat_claw_fallback (Mangle unlearned)")
-- spell_exists is a battery stub driven by the not_learned bank (33983 = Mangle
-- Cat rank); ClawFallback's gate is `if spell_exists(ACTION.MangleCat) then
-- return false end`, so the scenario must present Mangle as unlearned.
assert_true(cat_ns._bstate("not_learned", nil) and cat_ns._bstate("not_learned", nil)[33983],
    "druid ClawFallback needs the not_learned bank to mark Mangle 33983 unlearned")
assert_true(cat_ns.spell_exists({ ids = { 33983 } }) == false,
    "druid ClawFallback needs spell_exists(Mangle) false via the not_learned stub")
print("PASS: cat ClawFallback regression (cat_claw_fallback)")

assert_lane_matches(cat, cat_ns, "druid", "MangleFiller", "cat_mangle_filler",
    "druid MangleFiller must match in cat_mangle_filler (not behind, shred not usable)")
print("PASS: cat MangleFiller regression (cat_mangle_filler)")

-- ============================================================================
-- hunter/BM (1) — Trinket needs in-combat + an equipped trinket (has_trinket
-- bank via TrinketManager stub) + trinket_mode slot1 + the is_item_ready spec
-- fix (without it, trinket_1_ready was always false in live too).
-- ============================================================================
local bm, bm_err, bm_ns = aud.load_spec("hunter", "beast_mastery")
assert_true(bm ~= nil, "hunter/beast_mastery load failed: " .. tostring(bm_err))
_G.EaxRotations = bm_ns

local tr, trst = assert_lane_matches(bm, bm_ns, "hunter", "Trinket", "bm_trinket",
    "hunter Trinket must match in bm_trinket (combat + slot1 + equipped trinket)")
assert_true(trst.trinket_1_id ~= nil,
    "hunter Trinket needs trinket_1_id (equipped trinket stub), got " .. tostring(trst.trinket_1_id))
assert_true(trst.trinket_1_ready == true,
    "hunter Trinket needs trinket_1_ready true (is_item_ready spec fix), got " .. tostring(trst.trinket_1_ready))
print("PASS: BM Trinket regression (bm_trinket + is_item_ready fix)")

-- ============================================================================
-- hunter/MM (1) — InCombatAimedShot needs the fresh-combat opener (combat_time
-- 0.2) so the Serpent Sting setup gate is skipped.
-- ============================================================================
local mm, mm_err, mm_ns = aud.load_spec("hunter", "marksmanship")
assert_true(mm ~= nil, "hunter/marksmanship load failed: " .. tostring(mm_err))
_G.EaxRotations = mm_ns

local ai, aist = assert_lane_matches(mm, mm_ns, "hunter", "InCombatAimedShot", "mm_aimed_opener",
    "hunter InCombatAimedShot must match in mm_aimed_opener (fresh combat)")
-- combat_time is read from context.combat_time (mm:467), not build_state.
assert_true((ai.combat_time or 99) < 1,
    "hunter InCombatAimedShot needs ctx.combat_time < 1, got " .. tostring(ai.combat_time))
print("PASS: MM InCombatAimedShot regression (mm_aimed_opener)")

-- ============================================================================
-- paladin/protection (2) — AvengingWrath needs use_cooldowns + ttd above the
-- 15s expiry gate; LayOnHands needs self below the 10% threshold.
-- ============================================================================
local prot, prot_err, prot_ns = aud.load_spec("paladin", "protection")
assert_true(prot ~= nil, "paladin/protection load failed: " .. tostring(prot_err))
_G.EaxRotations = prot_ns

assert_lane_matches(prot, prot_ns, "paladin", "AvengingWrath", "prot_cd_window",
    "paladin AvengingWrath must match in prot_cd_window (cds enabled, long ttd)")
print("PASS: prot AvengingWrath regression (prot_cd_window)")

local lh, lhst = assert_lane_matches(prot, prot_ns, "paladin", "LayOnHands", "prot_low_self",
    "paladin LayOnHands must match in prot_low_self (hp 5)")
assert_true((lhst.hp_pct or 100) < 15,
    "paladin LayOnHands needs hp_pct < 15, got " .. tostring(lhst.hp_pct))
print("PASS: prot LayOnHands regression (prot_low_self)")

-- ============================================================================
-- paladin/retribution (3) — cleanse/purify lanes need the map-aware
-- has_player_debuff (player_debuff_remains_map) to gate honestly; without it
-- the catch-all always-true masked the lanes (and would re-hide them if a
-- future battery edit drops the map).
-- ============================================================================
local ret, ret_err, ret_ns = aud.load_spec("paladin", "retribution")
assert_true(ret ~= nil, "paladin/retribution load failed: " .. tostring(ret_err))
_G.EaxRotations = ret_ns

assert_lane_matches(ret, ret_ns, "paladin", "Ret_Cleanse_Self", "ret_cleanse_self",
    "paladin Ret_Cleanse_Self must match in ret_cleanse_self (player debuff map)")
print("PASS: ret Ret_Cleanse_Self regression (ret_cleanse_self)")

assert_lane_matches(ret, ret_ns, "paladin", "Ret_Purify_SelfFallback", "ret_cleanse_self",
    "paladin Ret_Purify_SelfFallback must match in ret_cleanse_self (player debuff map)")
print("PASS: ret Ret_Purify_SelfFallback regression (ret_cleanse_self)")

assert_lane_matches(ret, ret_ns, "paladin", "Ret_Cleanse_Ally", "ret_cleanse_self",
    "paladin Ret_Cleanse_Ally must match in ret_cleanse_self (player debuff map)")
print("PASS: ret Ret_Cleanse_Ally regression (ret_cleanse_self)")

-- ============================================================================
-- shaman/elemental (3) — ChainHeal needs a group-injured friend; ElementalMastery
-- needs burst + the per-CD setting; TotemicCall needs moving + totems up.
-- ============================================================================
local elem, elem_err, elem_ns = aud.load_spec("shaman", "elemental")
assert_true(elem ~= nil, "shaman/elemental load failed: " .. tostring(elem_err))
_G.EaxRotations = elem_ns

assert_lane_matches(elem, elem_ns, "shaman", "ChainHeal", "elem_group_injured",
    "shaman ChainHeal must match in elem_group_injured (group injured)")
print("PASS: elem ChainHeal regression (elem_group_injured)")

assert_lane_matches(elem, elem_ns, "shaman", "ElementalMastery", "elem_burst_cd",
    "shaman ElementalMastery must match in elem_burst_cd (burst + setting)")
print("PASS: elem ElementalMastery regression (elem_burst_cd)")

assert_lane_matches(elem, elem_ns, "shaman", "TotemicCall", "elem_totemic_call",
    "shaman TotemicCall must match in elem_totemic_call (moving + totems)")
print("PASS: elem TotemicCall regression (elem_totemic_call)")

-- ============================================================================
-- shaman/enhancement (2) — EarthShock needs the target casting in the kick
-- window (get_cast_pct 40..80); ShamanisticRage needs low mana + the per-CD
-- toggle setting (DSL condition requires it).
-- ============================================================================
local enh, enh_err, enh_ns = aud.load_spec("shaman", "enhancement")
assert_true(enh ~= nil, "shaman/enhancement load failed: " .. tostring(enh_err))
_G.EaxRotations = enh_ns

local es, esst = assert_lane_matches(enh, enh_ns, "shaman", "EarthShock", "enh_interrupt",
    "shaman EarthShock must match in enh_interrupt (target casting in kick window)")
assert_true((esst.target_cast_pct or 0) >= 40 and (esst.target_cast_pct or 0) <= 80,
    "shaman EarthShock needs target_cast_pct in 40..80, got " .. tostring(esst.target_cast_pct))
print("PASS: enh EarthShock regression (enh_interrupt)")

assert_lane_matches(enh, enh_ns, "shaman", "ShamanisticRage", "enh_low_mana",
    "shaman ShamanisticRage must match in enh_low_mana (low mana + cd toggle)")
print("PASS: enh ShamanisticRage regression (enh_low_mana)")

-- ============================================================================
-- End-to-end: the TBC-era battery must report none of the pinned lanes as
-- never-firing (mirrors the healer regression's assert_lane_fires).
-- ============================================================================
local function assert_lane_fires(class_key, spec, lane)
    local report = aud.run_spec(class_key, spec)
    assert_true(report ~= nil, "battery run for " .. class_key .. "/" .. spec .. " failed")
    for _, name in ipairs(report.never) do
        assert_true(name ~= lane,
            "tbc battery still reports " .. class_key .. "/" .. spec .. " " .. lane .. " as never-firing")
    end
end
assert_lane_fires("druid", "balance", "HurricaneAoE")
assert_lane_fires("druid", "balance", "RebirthBattleRez")
assert_lane_fires("druid", "bear", "Swipe")
assert_lane_fires("druid", "bear", "EnrageCombat")
assert_lane_fires("druid", "cat", "ClawFallback")
assert_lane_fires("druid", "cat", "MangleFiller")
assert_lane_fires("hunter", "beast_mastery", "Trinket")
assert_lane_fires("hunter", "marksmanship", "InCombatAimedShot")
assert_lane_fires("paladin", "protection", "AvengingWrath")
assert_lane_fires("paladin", "protection", "LayOnHands")
assert_lane_fires("paladin", "retribution", "Ret_Cleanse_Self")
assert_lane_fires("paladin", "retribution", "Ret_Purify_SelfFallback")
assert_lane_fires("paladin", "retribution", "Ret_Cleanse_Ally")
assert_lane_fires("shaman", "elemental", "ChainHeal")
assert_lane_fires("shaman", "elemental", "ElementalMastery")
assert_lane_fires("shaman", "elemental", "TotemicCall")
assert_lane_fires("shaman", "enhancement", "EarthShock")
assert_lane_fires("shaman", "enhancement", "ShamanisticRage")
print("PASS: tbc battery reports none of the 18 batch-2 (c) lanes as never-firing")
