-- test_fsr_lane_regression.lua — pins the 6 lanes unblocked by the FSR-pause
-- battery scenario (2026-08-07, ranked #6 from the focused triage).
-- WHAT:  behavioral_audit.lua gained a scenario-driven stub for
--        shared/fsr_manager_sylvanas (preloaded in build_ns, backed by the
--        state bank, restored in load_spec) plus an `fsr_pause` scenario
--        (87 total) that sets fsr_inside / fsr_regen_delta / fsr_pause_ok.
--        The scenario is a mid-Five-Second-Rule pause: mana 30 (<= the 35
--        gate, above the emergency floors), healthy group (friends 100s — no
--        triage heal fires first), buffs_up=true (shaman WaterShield /
--        LightningShield and paladin AuraManagement/BlessingRefresh read
--        "already up"), buff_remains_map = { [33076] = 15 } (blocks holy
--        PrayerOfMending via the map-aware ns.has_buff), setting_overrides
--        holy_refresh_enabled=false + holy_blessing_light=false (block the
--        paladin blessing refresh lanes, whose 120s-remaining boundary reads
--        "expiring"), on_cd for ManaTide (16190), Innervate (29166), Rebirth
--        (26994) and Bloodlust (2825) — all would otherwise fire first — and
--        player_mana_pct=30 (holy's context.mana_pct has no NS.unit_mana_pct
--        fallback). Also: ns.buff_stacks added (shaman WaterShield refreshes
--        at 0 charges — without it charges read nil->0), ns.get_setting made
--        scenario-aware (setting_overrides flow through spec_kit.setting).
--        Lanes pinned here (all previously never-firing):
--          priest/holy FSRPause, priest/discipline FSRPause,
--          paladin/holy FSRPause, druid/resto FSRPause,
--          shaman/restoration FSRPause,
--          paladin/retribution Ret_JudgementWisdom_LowMana (incidental —
--            mana 30 <= 45 + buffs_up in the new scenario).
-- WHEN:  rotation suite execution.
-- WHY:   a future battery edit could silently re-hide these lanes; this test
--        fails if any stops firing (state + matcher + negative + end-to-end).
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

local function build_scenario(class_key, name)
    for _, s in ipairs(aud.SCENARIOS) do
        if s.name == name then return s end
    end
    error("scenario not found: " .. name, 2)
end

local function make_state(spec_mod, ns, class_key, scenario_name)
    local ctx = aud.build_context_for(class_key, build_scenario(class_key, scenario_name))
    aud.apply_battery_state(ns, ctx, class_key)
    if spec_mod.build_state then
        local ok, st = pcall(spec_mod.build_state, ctx)
        assert_true(ok, class_key .. "/" .. scenario_name .. " build_state crashed: " .. tostring(st))
        if type(st) == "table" then return ctx, st end
    end
    return ctx, ctx
end

local function assert_lane_matches(spec_mod, ns, class_key, scenario_name, lane, label)
    local ctx, state = make_state(spec_mod, ns, class_key, scenario_name)
    local s = find_strategy(spec_mod.strategies, lane)
    assert_true(s ~= nil, class_key .. " " .. lane .. " strategy missing")
    local ok, m = pcall(s.matches, ctx, state)
    assert_true(ok, class_key .. " " .. lane .. " matcher crashed: " .. tostring(m))
    assert_true(m == true, label)
    return ctx, state
end

local function assert_fsr_state(state, class_key, label_prefix)
    -- The mechanism: the scenario's bank flags must land in build_state.
    assert_true(state.fsr_inside == true,
        label_prefix .. " needs state.fsr_inside = true (fsr_inside bank flag), got " .. tostring(state.fsr_inside))
    assert_true(type(state.fsr_regen_delta) == "number" and state.fsr_regen_delta > 0,
        label_prefix .. " needs state.fsr_regen_delta > 0 (get_regen_delta stub), got "
        .. tostring(state.fsr_regen_delta))
end

-- ============================================================================
-- priest/holy + priest/discipline: FSRPause gates mana <= 35 + fsr_inside +
-- delta + should_pause_for_fsr. holy additionally needed player_mana_pct
-- (context.mana_pct has no unit fallback) and the PoM buff id in the map.
-- ============================================================================
local holy, holy_err, holy_ns = aud.load_spec("priest", "holy")
assert_true(holy ~= nil, "priest/holy load failed: " .. tostring(holy_err))
_G.EaxRotations = holy_ns
local h_ctx, h_state = assert_lane_matches(holy, holy_ns, "priest", "fsr_pause", "FSRPause",
    "priest/holy FSRPause must match in fsr_pause (mana 30, inside FSR, delta 20)")
assert_fsr_state(h_state, "priest", "priest/holy")
assert_true(h_state.mana_pct <= 35,
    "priest/holy FSRPause needs state.mana_pct <= 35 (player_mana_pct=30 must flow into context.mana_pct), got "
    .. tostring(h_state.mana_pct))
-- Mechanism pin: the PoM anti-overwrite gate must see the buff via the map
-- (without it PrayerOfMending@5 would steal the lane before FSRPause@13).
assert_true(holy_ns.has_buff(holy_ns.PLAYER_UNIT, { 33076 }) == true,
    "priest/holy: ns.has_buff must honor buff_remains_map id 33076 in fsr_pause (PoM block)")
assert_true(holy_ns.has_buff(holy_ns.PLAYER_UNIT, { 1 }) == false,
    "priest/holy: ns.has_buff must return false for an unconfigured id (map-only, no buffs_up fallback)")
-- Negative: outside the window the lane stays closed (fsr flags do not leak).
local h_calm_ctx, h_calm_state = make_state(holy, holy_ns, "priest", "mana_critical")
local h_fsr = find_strategy(holy.strategies, "FSRPause")
local ok_h, m_h = pcall(h_fsr.matches, h_calm_ctx, h_calm_state)
assert_true(ok_h and m_h ~= true,
    "priest/holy FSRPause must not match in mana_critical (no FSR window) — fsr flag leak regression")
print("PASS: priest/holy FSRPause regression")

local disc, disc_err, disc_ns = aud.load_spec("priest", "discipline")
assert_true(disc ~= nil, "priest/discipline load failed: " .. tostring(disc_err))
_G.EaxRotations = disc_ns
local d_ctx, d_state = assert_lane_matches(disc, disc_ns, "priest", "fsr_pause", "FSRPause",
    "priest/discipline FSRPause must match in fsr_pause")
assert_fsr_state(d_state, "priest", "priest/discipline")
assert_true(d_state.mana_pct <= 35,
    "priest/discipline FSRPause needs state.mana_pct <= 35, got " .. tostring(d_state.mana_pct))
local d_calm_ctx, d_calm_state = make_state(disc, disc_ns, "priest", "mana_critical")
local d_fsr = find_strategy(disc.strategies, "FSRPause")
local ok_d, m_d = pcall(d_fsr.matches, d_calm_ctx, d_calm_state)
assert_true(ok_d and m_d ~= true,
    "priest/discipline FSRPause must not match in mana_critical (no FSR window)")
print("PASS: priest/discipline FSRPause regression")

-- ============================================================================
-- paladin/holy: FSRPause gates mana <= 35 + fsr state. Blocked by the aura
-- switch (AuraManagement) and blessing refresh lanes (blessings read "up" at
-- exactly the 120s refresh boundary) — buffs_up + setting_overrides fix.
-- ============================================================================
local pholy, pholy_err, pholy_ns = aud.load_spec("paladin", "holy")
assert_true(pholy ~= nil, "paladin/holy load failed: " .. tostring(pholy_err))
_G.EaxRotations = pholy_ns
local ph_ctx, ph_state = assert_lane_matches(pholy, pholy_ns, "paladin", "fsr_pause", "FSRPause",
    "paladin/holy FSRPause must match in fsr_pause")
assert_fsr_state(ph_state, "paladin", "paladin/holy")
assert_true(ph_state.mana_pct <= 35,
    "paladin/holy FSRPause needs state.mana_pct <= 35, got " .. tostring(ph_state.mana_pct))
-- Mechanism pins: aura switch suppressed (auras already up) and blessings
-- disabled via setting_overrides flowing through spec_kit.setting.
assert_true(ph_state.aura_spell == nil,
    "paladin/holy: aura_spell must be nil in fsr_pause (buffs_up -> auras up), got "
    .. tostring(ph_state.aura_spell))
assert_true(ph_state.blessing_spell == nil,
    "paladin/holy: blessing_spell must be nil in fsr_pause (holy_refresh_enabled=false via get_setting), got "
    .. tostring(ph_state.blessing_spell))
local ph_calm_ctx, ph_calm_state = make_state(pholy, pholy_ns, "paladin", "mana_critical")
local ph_fsr = find_strategy(pholy.strategies, "FSRPause")
local ok_ph, m_ph = pcall(ph_fsr.matches, ph_calm_ctx, ph_calm_state)
assert_true(ok_ph and m_ph ~= true,
    "paladin/holy FSRPause must not match in mana_critical (no FSR window)")
print("PASS: paladin/holy FSRPause regression")

-- ============================================================================
-- druid/resto + shaman/restoration: FSRPause gates on fsr state + the stub's
-- should_pause_for_fsr. druid needed Rebirth (26994) + Innervate (29166) on
-- cd (RebirthBattleRez carpet-bombs every in-combat scenario — the battery
-- has no dead-ally model); shaman needed ManaTide (16190) + Bloodlust (2825)
-- on cd and buff_stacks (WaterShield refreshes at 0 charges).
-- ============================================================================
local resto, resto_err, resto_ns = aud.load_spec("druid", "resto")
assert_true(resto ~= nil, "druid/resto load failed: " .. tostring(resto_err))
_G.EaxRotations = resto_ns
local r_ctx, r_state = assert_lane_matches(resto, resto_ns, "druid", "fsr_pause", "FSRPause",
    "druid/resto FSRPause must match in fsr_pause")
assert_fsr_state(r_state, "druid", "druid/resto")
local r_calm_ctx, r_calm_state = make_state(resto, resto_ns, "druid", "mana_critical")
local r_fsr = find_strategy(resto.strategies, "FSRPause")
local ok_r, m_r = pcall(r_fsr.matches, r_calm_ctx, r_calm_state)
assert_true(ok_r and m_r ~= true,
    "druid/resto FSRPause must not match in mana_critical (no FSR window)")
print("PASS: druid/resto FSRPause regression")

local resto_sh, resto_sh_err, resto_sh_ns = aud.load_spec("shaman", "restoration")
assert_true(resto_sh ~= nil, "shaman/restoration load failed: " .. tostring(resto_sh_err))
_G.EaxRotations = resto_sh_ns
local rs_ctx, rs_state = assert_lane_matches(resto_sh, resto_sh_ns, "shaman", "fsr_pause", "FSRPause",
    "shaman/restoration FSRPause must match in fsr_pause")
assert_fsr_state(rs_state, "shaman", "shaman/restoration")
-- Mechanism pin: buff_stacks -> WaterShield charges = 1 (refresh-at-0 gate).
assert_true(rs_state.water_shield_charges == 1,
    "shaman/restoration: water_shield_charges must be 1 in fsr_pause (buff_stacks buffs_up), got "
    .. tostring(rs_state.water_shield_charges))
local rs_calm_ctx, rs_calm_state = make_state(resto_sh, resto_sh_ns, "shaman", "mana_critical")
local rs_fsr = find_strategy(resto_sh.strategies, "FSRPause")
local ok_rs, m_rs = pcall(rs_fsr.matches, rs_calm_ctx, rs_calm_state)
assert_true(ok_rs and m_rs ~= true,
    "shaman/restoration FSRPause must not match in mana_critical (no FSR window)")
print("PASS: shaman/restoration FSRPause regression")

-- ============================================================================
-- paladin/retribution: Ret_JudgementWisdom_LowMana (incidental clear) — the
-- fsr_pause scenario's mana 30 + buffs_up satisfy the mana <= 45 wisdom-seal
-- combo. Pinned so a future scenario edit can't silently re-hide it.
-- ============================================================================
local retri, retri_err, retri_ns = aud.load_spec("paladin", "retribution")
assert_true(retri ~= nil, "paladin/retribution load failed: " .. tostring(retri_err))
_G.EaxRotations = retri_ns
local rj_ctx, rj_state = assert_lane_matches(retri, retri_ns, "paladin", "fsr_pause", "Ret_JudgementWisdom_LowMana",
    "paladin/retribution Ret_JudgementWisdom_LowMana must match in fsr_pause (mana 30 <= 45)")
assert_true((rj_state.mana_pct or 100) <= 45,
    "paladin/retribution needs state.mana_pct <= 45 in fsr_pause, got " .. tostring(rj_state.mana_pct))
print("PASS: paladin/retribution Ret_JudgementWisdom_LowMana regression")

-- ============================================================================
-- End-to-end: the battery must report each cleared lane as firing — and fire
-- FSRPause exactly in the fsr_pause scenario (dispatch-order proof).
-- ============================================================================
local end_to_end = {
    { "priest", "holy" }, { "priest", "discipline" }, { "paladin", "holy" },
    { "druid", "resto" }, { "shaman", "restoration" }, { "paladin", "retribution" },
}
for _, kv in ipairs(end_to_end) do
    local class_key, spec_key = kv[1], kv[2]
    local report = aud.run_spec(class_key, spec_key)
    assert_true(report ~= nil, "battery run for " .. class_key .. "/" .. spec_key .. " failed")
    assert_true(#report.dispatch_errors == 0,
        class_key .. "/" .. spec_key .. " battery dispatch errors: "
        .. table.concat(report.dispatch_errors, "; "))
    for _, name in ipairs(report.never) do
        if spec_key == "retribution" then
            assert_true(name ~= "Ret_JudgementWisdom_LowMana",
                "battery still reports paladin/retribution Ret_JudgementWisdom_LowMana as never-firing")
        else
            assert_true(name ~= "FSRPause",
                "battery still reports " .. class_key .. "/" .. spec_key .. " FSRPause as never-firing")
        end
    end
    local fires_in = report.fires_in and report.fires_in.FSRPause
    if spec_key ~= "retribution" then
        assert_true(type(fires_in) == "table" and fires_in["fsr_pause"] == true,
            class_key .. "/" .. spec_key .. " FSRPause must fire in the fsr_pause scenario")
        local count = 0
        for _ in pairs(fires_in) do count = count + 1 end
        assert_true(count == 1,
            class_key .. "/" .. spec_key .. " FSRPause must fire ONLY in fsr_pause, got " .. count .. " scenarios")
    end
end
print("PASS: end-to-end battery check (6 lanes, exclusive fsr_pause firing)")
