-- test_healer_dead_lane_regression.lua — regression for the healer dead-lane
-- bugs found by the behavioral battery audit triage (2026-08-07, non-DPS).
-- WHAT:  three sylvanas spec files had lanes that could never fire in live
--        play because build_state never populated the field the match read:
--          * priest/holy      — state.mana_pct never written (schema default
--                                100 shadowed context) → ManaPotion dead.
--          * druid/resto      — state.healthstone_ready never written (only
--                                computed inside execute) → Healthstone dead.
--          * hunter/MM        — bestial_wrath_matches hardcoded `return false`
--                                → BestialWrath dead even for mixed builds.
-- WHEN:  rotation suite execution.
-- WHY:   behavioral_audit.lua reported these lanes never-firing; the state
--        fields were never written (or the matcher hardcoded false).
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

-- ============================================================================
-- priest/holy: mana_pct must reach the ManaPotion gate (threshold 20%)
-- ============================================================================
local holy, holy_err, holy_ns = aud.load_spec("priest", "holy")
assert_true(holy ~= nil, "priest/holy load failed: " .. tostring(holy_err))
-- Re-assert the current spec's ns: DSL condition evaluators (spell_ready /
-- buff) read _G.EaxRotations dynamically, so keep it pointed at holy_ns
-- regardless of assertion order.
_G.EaxRotations = holy_ns

local low_mana = aud.build_context_for("priest", {
    name = "low_mana",
    overrides = { mana_pct = 10, player_mana = 300, player_mana_pct = 10, has_potions = true },
})
aud.apply_battery_state(holy_ns, low_mana, "priest")
local ok, st = pcall(holy.build_state, low_mana)
assert_true(ok, "holy build_state crashed: " .. tostring(st))
local hstate = ok and st or low_mana
assert_true((hstate.mana_pct or 100) < 20,
    "holy state.mana_pct must reflect low mana, got " .. tostring(hstate.mana_pct))

local mp = find_strategy(holy.strategies, "ManaPotion")
assert_true(mp ~= nil, "holy ManaPotion strategy missing")
local mmok, mm = pcall(mp.matches, low_mana, hstate)
assert_true(mmok, "holy ManaPotion matcher crashed: " .. tostring(mm))
assert_true(mm == true, "holy ManaPotion must match at mana<20 in low-mana context")
print("PASS: priest/holy dead-lane regression (ManaPotion via state.mana_pct)")

-- ============================================================================
-- druid/resto: healthstone_ready must reach the Healthstone gate (hp<=28)
-- ============================================================================
local resto, resto_err, resto_ns = aud.load_spec("druid", "resto")
assert_true(resto ~= nil, "druid/resto load failed: " .. tostring(resto_err))
_G.EaxRotations = resto_ns

local low_self = aud.build_context_for("druid", {
    name = "low_self",
    overrides = { hp = 15, player_hp = 15, has_potions = true },
})
aud.apply_battery_state(resto_ns, low_self, "druid")
local rok, rst = pcall(resto.build_state, low_self)
assert_true(rok, "resto build_state crashed: " .. tostring(rst))
local rstate = rok and rst or low_self
assert_true((rstate.healthstone_ready or 0) > 0,
    "resto healthstone_ready must be > 0 when a healthstone is ready, got " .. tostring(rstate.healthstone_ready))
assert_true((low_self.hp or 100) <= 28,
    "resto context.hp must reflect low self HP, got " .. tostring(low_self.hp))

local hs = find_strategy(resto.strategies, "Healthstone")
assert_true(hs ~= nil, "resto Healthstone strategy missing")
local hmok, hm = pcall(hs.matches, low_self, rstate)
assert_true(hmok, "resto Healthstone matcher crashed: " .. tostring(hm))
assert_true(hm == true, "resto Healthstone must match at hp<=28 with healthstone ready")
print("PASS: druid/resto dead-lane regression (Healthstone via healthstone_ready)")

-- ============================================================================
-- hunter/marksmanship: BestialWrath must gate on spell_exists, not false
-- ============================================================================
local mm, mm_err, mm_ns = aud.load_spec("hunter", "marksmanship")
assert_true(mm ~= nil, "hunter/marksmanship load failed: " .. tostring(mm_err))
_G.EaxRotations = mm_ns

local std = aud.build_context_for("hunter", { name = "standard" })
aud.apply_battery_state(mm_ns, std, "hunter")
local mok, mst = pcall(mm.build_state, std)
assert_true(mok, "marksmanship build_state crashed: " .. tostring(mst))
local mstate = mok and mst or std

local bw = find_strategy(mm.strategies, "BestialWrath")
assert_true(bw ~= nil, "marksmanship BestialWrath strategy missing")
local bmok, bm = pcall(bw.matches, std, mstate)
assert_true(bmok, "marksmanship BestialWrath matcher crashed: " .. tostring(bm))
assert_true(bm == true, "marksmanship BestialWrath must match when the spell exists")
print("PASS: hunter/marksmanship dead-lane regression (BestialWrath via spell_exists)")

-- ============================================================================
-- End-to-end: the battery must no longer report these lanes as never-firing.
-- ============================================================================
local function assert_lane_fires(class_key, spec, lane)
    local report = aud.run_spec(class_key, spec)
    assert_true(report ~= nil, "battery run for " .. class_key .. "/" .. spec .. " failed")
    for _, name in ipairs(report.never) do
        assert_true(name ~= lane,
            "battery still reports " .. class_key .. "/" .. spec .. " " .. lane .. " as never-firing")
    end
end
assert_lane_fires("priest", "holy", "ManaPotion")
assert_lane_fires("druid", "resto", "Healthstone")
assert_lane_fires("hunter", "marksmanship", "BestialWrath")
print("PASS: battery no longer reports any of the 3 healer dead lanes as never-firing")
