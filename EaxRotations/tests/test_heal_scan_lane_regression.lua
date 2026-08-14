-- test_heal_scan_lane_regression.lua — pins the 25 heal-scan + affliction
-- lanes unblocked by the healer battery upgrade (2026-08-07, non-DPS triage).
-- WHAT:  behavioral_audit.lua gained state-bank-driven heal-scan stubs (the
--        per-class Healing modules expose scan_healing_targets building
--        entries from the scenario's friends_hp, tank = entry[2], player
--        self-entry), real NS.healing_* rankers, select_heal/get_cleanse_target
--        /all_members_above_hp, per-debuff-type `afflicted` flags
--        (poison/disease/curse/magic), and the group_*/tank_low/
--        mana_tide_window scenarios. Before that the heal/cleanse lanes could
--        never fire (scan stubs returned nil; affliction flags absent).
--        Lanes pinned here (all previously never-firing):
--          priest/holy:      CircleOfHealing, Lightwell, RenewTank,
--                            AbolishDisease, CureDisease, DispelMagic
--          priest/discipline: BindingHeal, GreaterHeal, PrayerOfHealing,
--                            EmergencyPowerWordShield
--          paladin/holy:     PurifySelf, DivineFavorHolyShockCombo
--          druid/resto:      SwiftmendEmergency, TranquilityEmergency,
--                            NaturesSwiftness, NaturesSwiftnessHealingTouch,
--                            LeaveTreeForDirectHeal
--          shaman/restoration: ChainHeal, SmartHeal, Bloodlust,
--                            NaturesSwiftness, CureDisease, CurePoison,
--                            DiseaseCleansingTotem, PoisonCleansingTotem
-- WHEN:  rotation suite execution.
-- WHY:   a future battery edit could silently re-hide these lanes; this test
--        fails if any of the 25 stops firing (state + matcher + end-to-end).
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

-- Assert the lane's matcher returns true in `scenario_name`; returns ctx+state
-- from THAT call so state-fidelity asserts are scoped to the right scenario
-- (module-level state tables are mutated in place by later build_state calls).
local function assert_lane_matches(spec_mod, ns, class_key, scenario_name, lane, label)
    local ctx, state = make_state(spec_mod, ns, class_key, scenario_name)
    local s = find_strategy(spec_mod.strategies, lane)
    assert_true(s ~= nil, class_key .. " " .. lane .. " strategy missing")
    local ok, m = pcall(s.matches, ctx, state)
    assert_true(ok, class_key .. " " .. lane .. " matcher crashed: " .. tostring(m))
    assert_true(m == true, label)
    return ctx, state
end

-- ============================================================================
-- priest/holy: heal-scan (CoH/Lightwell/RenewTank) + affliction cures
-- ============================================================================
local holy, holy_err, holy_ns = aud.load_spec("priest", "holy")
assert_true(holy ~= nil, "priest/holy load failed: " .. tostring(holy_err))
-- Re-assert the current spec's ns: DSL condition evaluators (spell_ready /
-- buff) read _G.EaxRotations dynamically, so keep it pointed at holy_ns
-- regardless of assertion order.
_G.EaxRotations = holy_ns

local gc_ctx, gc_state = assert_lane_matches(holy, holy_ns, "priest", "group_critical", "CircleOfHealing",
    "holy CircleOfHealing must match in group_critical (injured group)")
assert_true((gc_state.lowest_hp or 100) <= 35,
    "holy state.lowest_hp must be injured in group_critical, got " .. tostring(gc_state.lowest_hp))
assert_true((gc_state.group_damaged_count or 0) >= 3,
    "holy CircleOfHealing needs group_damaged_count >= 3, got " .. tostring(gc_state.group_damaged_count))
assert_lane_matches(holy, holy_ns, "priest", "group_critical", "Lightwell",
    "holy Lightwell must match in group_critical (injured group)")
local tl_ctx, tl_state = assert_lane_matches(holy, holy_ns, "priest", "tank_low", "RenewTank",
    "holy RenewTank must match in tank_low (tank entry[2] low HP)")
assert_true((tl_state.tank_hp or 100) <= 35,
    "holy state.tank_hp must be low in tank_low, got " .. tostring(tl_state.tank_hp))
assert_lane_matches(holy, holy_ns, "priest", "friends_afflicted", "AbolishDisease",
    "holy AbolishDisease must match when a friend has a disease")
assert_lane_matches(holy, holy_ns, "priest", "friends_afflicted", "CureDisease",
    "holy CureDisease must match when a friend has a disease")
local aff_ctx, aff_state = assert_lane_matches(holy, holy_ns, "priest", "friends_afflicted", "DispelMagic",
    "holy DispelMagic must match when a friend has a dangerous debuff")
assert_true(aff_state.dispel_magic_ready == true,
    "holy state.dispel_magic_ready must be set in friends_afflicted")
print("PASS: priest/holy heal-scan + affliction regression (6 lanes)")

-- ============================================================================
-- priest/discipline: BH / GH / PoH / EmergencyPWS via group scenarios
-- ============================================================================
local disc, disc_err, disc_ns = aud.load_spec("priest", "discipline")
assert_true(disc ~= nil, "priest/discipline load failed: " .. tostring(disc_err))
_G.EaxRotations = disc_ns

local bh_ctx, bh_state = assert_lane_matches(disc, disc_ns, "priest", "group_critical", "BindingHeal",
    "discipline BindingHeal must match in group_critical (self/ally low)")
assert_true((bh_state.lowest and bh_state.lowest.effective_hp or 100) <= 50,
    "discipline BindingHeal needs lowest.effective_hp <= 50, got "
    .. tostring(bh_state.lowest and bh_state.lowest.effective_hp))
local gh_ctx, gh_state = assert_lane_matches(disc, disc_ns, "priest", "group_light", "GreaterHeal",
    "discipline GreaterHeal must match in group_light (lowest 55-82 band)")
local gh_hp = gh_state.lowest and gh_state.lowest.effective_hp or 0
assert_true(gh_hp >= 55 and gh_hp <= 82,
    "discipline GreaterHeal needs lowest.effective_hp in 55-82, got " .. tostring(gh_hp))
local poh_ctx, poh_state = assert_lane_matches(disc, disc_ns, "priest", "group_aoe", "PrayerOfHealing",
    "discipline PrayerOfHealing must match in group_aoe (4+ injured)")
assert_true((poh_state.group_damaged_count or 0) >= 4,
    "discipline PrayerOfHealing needs group_damaged_count >= 3 (matcher threshold since 2026-08-13); scenario yields >= 4, got "
    .. tostring(poh_state.group_damaged_count))
assert_lane_matches(disc, disc_ns, "priest", "group_critical", "EmergencyPowerWordShield",
    "discipline EmergencyPowerWordShield must match in group_critical")
print("PASS: priest/discipline heal-scan regression (4 lanes)")

-- ============================================================================
-- paladin/holy: PurifySelf (affliction) + DivineFavorHolyShockCombo (emergency)
-- ============================================================================
local pally, pally_err, pally_ns = aud.load_spec("paladin", "holy")
assert_true(pally ~= nil, "paladin/holy load failed: " .. tostring(pally_err))
_G.EaxRotations = pally_ns

assert_lane_matches(pally, pally_ns, "paladin", "friends_afflicted", "PurifySelf",
    "paladin/holy PurifySelf must match when the player has a poison/disease")
local df_ctx, df_state = assert_lane_matches(pally, pally_ns, "paladin", "group_emergency", "DivineFavorHolyShockCombo",
    "paladin/holy DivineFavorHolyShockCombo must match in group_emergency (buffs_up + injured group)")
assert_true(df_state.has_divine_favor == true,
    "paladin/holy DivineFavorHolyShockCombo needs has_divine_favor (buffs_up), got "
    .. tostring(df_state.has_divine_favor))
print("PASS: paladin/holy affliction + emergency regression (2 lanes)")

-- ============================================================================
-- druid/resto: Swiftmend/Tranq/NS/NSHealingTouch/LeaveTree via group scenarios
-- ============================================================================
local resto, resto_err, resto_ns = aud.load_spec("druid", "resto")
assert_true(resto ~= nil, "druid/resto load failed: " .. tostring(resto_err))
_G.EaxRotations = resto_ns

local se_ctx, se_state = assert_lane_matches(resto, resto_ns, "druid", "group_emergency", "SwiftmendEmergency",
    "druid/resto SwiftmendEmergency must match in group_emergency (HoT buffs + hp <= 50)")
assert_true((se_state.lowest_hp_pct or 100) <= 50,
    "druid/resto SwiftmendEmergency needs lowest_hp_pct <= 50, got " .. tostring(se_state.lowest_hp_pct))
local tr_ctx, tr_state = assert_lane_matches(resto, resto_ns, "druid", "group_emergency", "TranquilityEmergency",
    "druid/resto TranquilityEmergency must match in group_emergency (3 targets <= 25)")
assert_true((tr_state.tranquility_count or 0) >= 3,
    "druid/resto TranquilityEmergency needs tranquility_count >= 3, got " .. tostring(tr_state.tranquility_count))
local ns_ctx, ns_state = assert_lane_matches(resto, resto_ns, "druid", "group_critical", "NaturesSwiftness",
    "druid/resto NaturesSwiftness must match in group_critical (short TTD, no buff)")
assert_true((ns_state.lowest_hp_pct or 100) <= 30,
    "druid/resto NaturesSwiftness needs a short-TTD (low hp) target, got " .. tostring(ns_state.lowest_hp_pct))
assert_lane_matches(resto, resto_ns, "druid", "group_emergency", "NaturesSwiftnessHealingTouch",
    "druid/resto NaturesSwiftnessHealingTouch must match in group_emergency")
assert_lane_matches(resto, resto_ns, "druid", "group_emergency", "LeaveTreeForDirectHeal",
    "druid/resto LeaveTreeForDirectHeal must match in group_emergency (should_dance_caster)")
print("PASS: druid/resto heal-scan regression (5 lanes)")

-- ============================================================================
-- shaman/restoration: ChainHeal/SmartHeal/Bloodlust/NS + 4 cleanse lanes
-- ============================================================================
local sham, sham_err, sham_ns = aud.load_spec("shaman", "restoration")
assert_true(sham ~= nil, "shaman/restoration load failed: " .. tostring(sham_err))
_G.EaxRotations = sham_ns

local ch_ctx, ch_state = assert_lane_matches(sham, sham_ns, "shaman", "group_light", "ChainHeal",
    "shaman/restoration ChainHeal must match in group_light (cluster of injured)")
assert_true((ch_state.chain_heal_target_count or 0) >= 2,
    "shaman/restoration ChainHeal needs chain_heal_target_count >= 2, got "
    .. tostring(ch_state.chain_heal_target_count))
assert_lane_matches(sham, sham_ns, "shaman", "group_light", "SmartHeal",
    "shaman/restoration SmartHeal must match in group_light")
local bl_ctx, bl_state = assert_lane_matches(sham, sham_ns, "shaman", "mana_tide_window", "Bloodlust",
    "shaman/restoration Bloodlust must match in mana_tide_window (CD window + healthy low-mana group)")
-- Scenario-fidelity check: mana_tide_window is the scenario that combines a
-- CD window with a low-mana healthy group (Bloodlust also fires in
-- group_healthy, so this pins the mana_tide_window wiring specifically).
assert_true(bl_state.mana_low == true,
    "shaman/restoration mana_tide_window must set mana_low, got " .. tostring(bl_state.mana_low))
assert_lane_matches(sham, sham_ns, "shaman", "group_critical", "NaturesSwiftness",
    "shaman/restoration NaturesSwiftness must match in group_critical (short-TTD target)")
assert_lane_matches(sham, sham_ns, "shaman", "friends_afflicted", "CureDisease",
    "shaman/restoration CureDisease must match when a friend has a disease")
assert_lane_matches(sham, sham_ns, "shaman", "friends_afflicted", "CurePoison",
    "shaman/restoration CurePoison must match when a friend has a poison")
assert_lane_matches(sham, sham_ns, "shaman", "friends_afflicted", "DiseaseCleansingTotem",
    "shaman/restoration DiseaseCleansingTotem must match when a friend has a disease")
assert_lane_matches(sham, sham_ns, "shaman", "friends_afflicted", "PoisonCleansingTotem",
    "shaman/restoration PoisonCleansingTotem must match when a friend has a poison")
local cl_ctx, cl_state = assert_lane_matches(sham, sham_ns, "shaman", "friends_afflicted", "CurePoison",
    "shaman/restoration CurePoison must match when a friend has a poison")
assert_true(cl_state.cleanse_target ~= nil,
    "shaman/restoration state.cleanse_target must be set in friends_afflicted")
print("PASS: shaman/restoration heal-scan + affliction regression (8 lanes)")

-- ============================================================================
-- End-to-end: the battery must report none of the 25 lanes as never-firing.
-- ============================================================================
local function assert_lane_fires(class_key, spec, lane)
    local report = aud.run_spec(class_key, spec)
    assert_true(report ~= nil, "battery run for " .. class_key .. "/" .. spec .. " failed")
    for _, name in ipairs(report.never) do
        assert_true(name ~= lane,
            "battery still reports " .. class_key .. "/" .. spec .. " " .. lane .. " as never-firing")
    end
end
assert_lane_fires("priest", "holy", "CircleOfHealing")
assert_lane_fires("priest", "holy", "Lightwell")
assert_lane_fires("priest", "holy", "RenewTank")
assert_lane_fires("priest", "holy", "AbolishDisease")
assert_lane_fires("priest", "holy", "CureDisease")
assert_lane_fires("priest", "holy", "DispelMagic")
assert_lane_fires("priest", "discipline", "BindingHeal")
assert_lane_fires("priest", "discipline", "GreaterHeal")
assert_lane_fires("priest", "discipline", "PrayerOfHealing")
assert_lane_fires("priest", "discipline", "EmergencyPowerWordShield")
assert_lane_fires("paladin", "holy", "PurifySelf")
assert_lane_fires("paladin", "holy", "DivineFavorHolyShockCombo")
assert_lane_fires("druid", "resto", "SwiftmendEmergency")
assert_lane_fires("druid", "resto", "TranquilityEmergency")
assert_lane_fires("druid", "resto", "NaturesSwiftness")
assert_lane_fires("druid", "resto", "NaturesSwiftnessHealingTouch")
assert_lane_fires("druid", "resto", "LeaveTreeForDirectHeal")
assert_lane_fires("shaman", "restoration", "ChainHeal")
assert_lane_fires("shaman", "restoration", "SmartHeal")
assert_lane_fires("shaman", "restoration", "Bloodlust")
assert_lane_fires("shaman", "restoration", "NaturesSwiftness")
assert_lane_fires("shaman", "restoration", "CureDisease")
assert_lane_fires("shaman", "restoration", "CurePoison")
assert_lane_fires("shaman", "restoration", "DiseaseCleansingTotem")
assert_lane_fires("shaman", "restoration", "PoisonCleansingTotem")
print("PASS: battery reports none of the 25 heal-scan/affliction lanes as never-firing")
