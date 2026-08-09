-- test_healer_c_closeout_regression.lua — pins the TBC healer category-(c)
-- close-out (2026-08-09). The non-DPS triage classified 13 healer never-lanes
-- as (c) battery-mock-limitation-but-modelable; a battery-fixture campaign
-- (scenario banks + buff-map + heal-scan + setting overrides) cleared them,
-- dropping the TBC era never-count from 91 to 78 with zero spec-file matcher
-- changes. This test pins the clears so a future battery edit (dropping a
-- scenario, changing an override, or regressing the fixture wiring) can't
-- silently re-hide them.
-- WHAT:  the 13 lanes by spec, mirroring test_phase3_c_fixture_regression.lua:
--   paladin/holy    6: ConsecrationSoloAoE (holy_solo_aoe), HammerOfWrathSolo
--                      (holy_solo_execute), JudgementOfLightBoss (holy_jol_boss),
--                      JudgementOfWisdomBoss (holy_jow_boss),
--                      JudgementSoloRighteousness (holy_solo_judge),
--                      LayOnHandsLastResort (holy_last_resort)
--   priest/smite    2: SoloRenew (smite_solo_renew), InnerFocus (standard)
--   priest/shadow   1: HolyNovaAoE (shadow_holy_nova combat-mode aoe)
--   shaman/resto    2: LightningShield (resto_lightning_shield shield-type
--                      override), ChainLightning (resto_chain_lightning)
--   druid/resto     2: TravelFormReposition (resto_travel_reposition OOC
--                      moving + range), LifebloomLetBloom (resto_lifebloom_bloom
--                      heal-scan + lifebloom bank)
--   Battery fixtures added: buff_up forwarding for import_helpers capturers
--   (smite's has_renew/has_inner_focus were always-true via the catch-all),
--   a lifebloom heal-scan attachment (friends_hp + lifebloom bank), and the
--   12 holy_*/smite_*/shadow_*/resto_* scenarios above.
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
-- paladin/holy (6) — solo-damage lanes need healthy friends (solo context) and
-- Judgement lanes need the seal buff maps (20166 Seal of Wisdom, 20165 Seal of
-- Light, 20154 Seal of Righteousness) + a boss/low-friend target.
-- ============================================================================
local holy, holy_err, holy_ns = aud.load_spec("paladin", "holy")
assert_true(holy ~= nil, "paladin/holy load failed: " .. tostring(holy_err))
_G.EaxRotations = holy_ns

local hctx, hst = assert_lane_matches(holy, holy_ns, "paladin", "LayOnHandsLastResort",
    "holy_last_resort", "holy LayOnHandsLastResort must match in holy_last_resort (lowest friend 10)")
assert_true(hst.lowest ~= nil,
    "holy LayOnHandsLastResort needs the heal-scan lowest unit (friends_hp 10/70/85), got nil")
print("PASS: holy LayOnHandsLastResort regression (holy_last_resort low friend)")

assert_lane_matches(holy, holy_ns, "paladin", "JudgementOfWisdomBoss", "holy_jow_boss",
    "holy JudgementOfWisdomBoss must match in holy_jow_boss (Seal of Wisdom up)")
print("PASS: holy JudgementOfWisdomBoss regression (holy_jow_boss seal map)")

assert_lane_matches(holy, holy_ns, "paladin", "JudgementOfLightBoss", "holy_jol_boss",
    "holy JudgementOfLightBoss must match in holy_jol_boss (Seal of Light up)")
print("PASS: holy JudgementOfLightBoss regression (holy_jol_boss seal map)")

local hex, hest = assert_lane_matches(holy, holy_ns, "paladin", "HammerOfWrathSolo",
    "holy_solo_execute", "holy HammerOfWrathSolo must match in holy_solo_execute (target_hp 8)")
assert_true((hest.target_hp_pct or 100) <= 20,
    "holy HammerOfWrathSolo needs target_hp_pct <= 20, got " .. tostring(hest.target_hp_pct))
print("PASS: holy HammerOfWrathSolo regression (holy_solo_execute)")

assert_lane_matches(holy, holy_ns, "paladin", "JudgementSoloRighteousness", "holy_solo_judge",
    "holy JudgementSoloRighteousness must match in holy_solo_judge (Seal of Righteousness up)")
print("PASS: holy JudgementSoloRighteousness regression (holy_solo_judge seal map)")

assert_lane_matches(holy, holy_ns, "paladin", "ConsecrationSoloAoE", "holy_solo_aoe",
    "holy ConsecrationSoloAoE must match in holy_solo_aoe (4 enemies, solo)")
print("PASS: holy ConsecrationSoloAoE regression (holy_solo_aoe)")

-- ============================================================================
-- priest/smite (2) — SoloRenew + InnerFocus were always-true via the catch-all
-- buff_up (has_renew/has_inner_focus never gated); the buff_up forwarding fix
-- makes the map-aware binding live so the low-self / standard scenarios fire.
-- ============================================================================
local smite, smite_err, smite_ns = aud.load_spec("priest", "smite")
assert_true(smite ~= nil, "priest/smite load failed: " .. tostring(smite_err))
_G.EaxRotations = smite_ns

local sctx, sst = assert_lane_matches(smite, smite_ns, "priest", "SoloRenew",
    "smite_solo_renew", "smite SoloRenew must match in smite_solo_renew (hp 15)")
assert_true((sst.hp_pct or 100) < 30,
    "smite SoloRenew needs hp_pct < 30, got " .. tostring(sst.hp_pct))
assert_true(sst.has_renew == false,
    "smite SoloRenew needs has_renew false (no Renew buff up), got " .. tostring(sst.has_renew))
print("PASS: smite SoloRenew regression (smite_solo_renew hp 15)")

assert_lane_matches(smite, smite_ns, "priest", "InnerFocus", "standard",
    "smite InnerFocus must match in standard (hf/inner_focus ready, no buff)")
print("PASS: smite InnerFocus regression (standard ready no-buff)")

-- ============================================================================
-- priest/shadow (1) — HolyNovaAoE needs the aoe combat-mode setting override.
-- ============================================================================
local shadow, shadow_err, shadow_ns = aud.load_spec("priest", "shadow")
assert_true(shadow ~= nil, "priest/shadow load failed: " .. tostring(shadow_err))
_G.EaxRotations = shadow_ns

local nctx, nst = assert_lane_matches(shadow, shadow_ns, "priest", "HolyNovaAoE",
    "shadow_holy_nova", "shadow HolyNovaAoE must match in shadow_holy_nova (combat-mode aoe)")
assert_true((nst.combat_mode or "") == "aoe",
    "shadow HolyNovaAoE needs combat_mode=aoe, got " .. tostring(nst.combat_mode))
print("PASS: shadow HolyNovaAoE regression (shadow_holy_nova aoe mode)")

-- ============================================================================
-- shaman/restoration (2) — LightningShield needs the shield-type setting
-- override; ChainLightning needs 4 enemies with healthy friends (no heal-priority
-- preemption).
-- ============================================================================
local resto, resto_err, resto_ns = aud.load_spec("shaman", "restoration")
assert_true(resto ~= nil, "shaman/restoration load failed: " .. tostring(resto_err))
_G.EaxRotations = resto_ns

local lctx, lst = assert_lane_matches(resto, resto_ns, "shaman", "LightningShield",
    "resto_lightning_shield", "resto LightningShield must match in resto_lightning_shield (lightning type)")
assert_true(lst.has_lightning_shield == false,
    "resto LightningShield needs has_lightning_shield false (no shield up), got "
    .. tostring(lst.has_lightning_shield))
print("PASS: resto LightningShield regression (resto_lightning_shield type override)")

local cctx, cst = assert_lane_matches(resto, resto_ns, "shaman", "ChainLightning",
    "resto_chain_lightning", "resto ChainLightning must match in resto_chain_lightning (4 enemies)")
assert_true((cst.enemy_count or 0) >= 4,
    "resto ChainLightning needs enemy_count >= 4, got " .. tostring(cst.enemy_count))
print("PASS: resto ChainLightning regression (resto_chain_lightning 4 enemies)")

-- ============================================================================
-- druid/resto (2) — TravelFormReposition needs OOC + moving + out of range;
-- LifebloomLetBloom needs the heal-scan + lifebloom bank (stacks 3, <1s left).
-- ============================================================================
local druid_resto, dr_err, dr_ns = aud.load_spec("druid", "resto")
assert_true(druid_resto ~= nil, "druid/resto load failed: " .. tostring(dr_err))
_G.EaxRotations = dr_ns

local tctx, tst = assert_lane_matches(druid_resto, dr_ns, "druid", "TravelFormReposition",
    "resto_travel_reposition", "druid TravelFormReposition must match in resto_travel_reposition (OOC moving + range)")
assert_true(tst.should_move_form == true,
    "druid TravelFormReposition needs should_move_form true, got " .. tostring(tst.should_move_form))
print("PASS: druid TravelFormReposition regression (resto_travel_reposition)")

local bctx, bst = assert_lane_matches(druid_resto, dr_ns, "druid", "LifebloomLetBloom",
    "resto_lifebloom_bloom", "druid LifebloomLetBloom must match in resto_lifebloom_bloom (lifebloom expiring)")
assert_true(bst.lifebloom_bloom ~= nil,
    "druid LifebloomLetBloom needs the lifebloom_bloom entry (heal-scan + stacks bank)")
assert_true((bst.lifebloom_bloom.lifebloom_stacks or 0) >= 2,
    "druid LifebloomLetBloom entry needs lifebloom_stacks >= 2, got " .. tostring(bst.lifebloom_bloom.lifebloom_stacks))
print("PASS: druid LifebloomLetBloom regression (resto_lifebloom_bloom)")

-- ============================================================================
-- End-to-end: the TBC-era battery must report none of the pinned lanes as
-- never-firing (mirrors the WotLK regression test's assert_lane_fires).
-- ============================================================================
local function assert_lane_fires(class_key, spec, lane)
    local report = aud.run_spec(class_key, spec)
    assert_true(report ~= nil, "battery run for " .. class_key .. "/" .. spec .. " failed")
    for _, name in ipairs(report.never) do
        assert_true(name ~= lane,
            "tbc battery still reports " .. class_key .. "/" .. spec .. " " .. lane .. " as never-firing")
    end
end
assert_lane_fires("paladin", "holy", "ConsecrationSoloAoE")
assert_lane_fires("paladin", "holy", "HammerOfWrathSolo")
assert_lane_fires("paladin", "holy", "JudgementOfLightBoss")
assert_lane_fires("paladin", "holy", "JudgementOfWisdomBoss")
assert_lane_fires("paladin", "holy", "JudgementSoloRighteousness")
assert_lane_fires("paladin", "holy", "LayOnHandsLastResort")
assert_lane_fires("priest", "smite", "SoloRenew")
assert_lane_fires("priest", "smite", "InnerFocus")
assert_lane_fires("priest", "shadow", "HolyNovaAoE")
assert_lane_fires("shaman", "restoration", "LightningShield")
assert_lane_fires("shaman", "restoration", "ChainLightning")
assert_lane_fires("druid", "resto", "TravelFormReposition")
assert_lane_fires("druid", "resto", "LifebloomLetBloom")
print("PASS: tbc battery reports none of the 13 healer (c) lanes as never-firing")
