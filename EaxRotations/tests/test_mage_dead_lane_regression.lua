-- test_mage_dead_lane_regression.lua — regression for the mage dead-lane bugs
-- found by the behavioral battery audit triage (2026-08-07).
-- WHAT:  three sylvanas mage specs had build_state fields that were never
--        assigned, so lanes gated on them could never fire in live play:
--          * fire   — state.hp_pct never written (schema default 100 forever)
--                     → Healthstone (hp<=28), IceBarrier (hp<=60), ManaShield
--                       (hp<=40) all dead.
--          * arcane — state.healthstone_ready never written (stayed 0)
--                     → Healthstone dead.
--          * frost  — state.mana_gem_available never written (stayed false)
--                     → ManaGem dead (ManaGemConjure's "!available" gate
--                       conjured instead of ever using one).
-- WHEN:  rotation suite execution.
-- WHY:   behavioral_audit.lua reported these lanes never-firing even in the
--        low-self / low-mana scenarios; the state fields were never written.
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
-- fire: hp_pct must reach the strategy gates (Healthstone/IceBarrier/ManaShield)
-- ============================================================================
local fire, fire_err, fire_ns = aud.load_spec("mage", "fire")
assert_true(fire ~= nil, "mage/fire load failed: " .. tostring(fire_err))
-- Re-assert the current spec's ns: DSL condition evaluators (spell_ready /
-- buff) read _G.EaxRotations dynamically, so keep it pointed at fire_ns
-- regardless of assertion order.
_G.EaxRotations = fire_ns

local low_self = aud.build_context_for("mage", {
    name = "low_self",
    overrides = { hp = 15, player_hp = 15, has_potions = true },
})
aud.apply_battery_state(fire_ns, low_self, "mage")
local ok, st = pcall(fire.build_state, low_self)
assert_true(ok, "fire build_state crashed: " .. tostring(st))
local state = ok and st or low_self
assert_true((state.hp_pct or 100) <= 28,
    "fire state.hp_pct must reflect low self HP, got " .. tostring(state.hp_pct))

local lanes = { "Healthstone", "IceBarrier", "ManaShield" }
for _, name in ipairs(lanes) do
    local s = find_strategy(fire.strategies, name)
    assert_true(s ~= nil, "fire " .. name .. " strategy missing")
    local mok, m = pcall(s.matches, low_self, state)
    assert_true(mok, "fire " .. name .. " matcher crashed: " .. tostring(m))
    assert_true(m == true, "fire " .. name .. " must match at hp_pct<=28 in low-self context")
end
print("PASS: mage/fire dead-lane regression (Healthstone + IceBarrier + ManaShield via hp_pct)")

-- ============================================================================
-- arcane: healthstone_ready must reach the Healthstone gate
-- ============================================================================
local arc, arc_err, arc_ns = aud.load_spec("mage", "arcane")
assert_true(arc ~= nil, "mage/arcane load failed: " .. tostring(arc_err))
_G.EaxRotations = arc_ns

local arc_ctx = aud.build_context_for("mage", {
    name = "low_self",
    overrides = { hp = 15, player_hp = 15, has_potions = true },
})
aud.apply_battery_state(arc_ns, arc_ctx, "mage")
local aok, ast = pcall(arc.build_state, arc_ctx)
assert_true(aok, "arcane build_state crashed: " .. tostring(ast))
local arc_state = aok and ast or arc_ctx
assert_true((arc_state.healthstone_ready or 0) > 0,
    "arcane healthstone_ready must be > 0 when a healthstone is ready, got " .. tostring(arc_state.healthstone_ready))
assert_true((arc_state.hp_pct or 100) <= 28,
    "arcane state.hp_pct must reflect low self HP, got " .. tostring(arc_state.hp_pct))

local ahs = find_strategy(arc.strategies, "Healthstone")
assert_true(ahs ~= nil, "arcane Healthstone strategy missing")
local amok, am = pcall(ahs.matches, arc_ctx, arc_state)
assert_true(amok, "arcane Healthstone matcher crashed: " .. tostring(am))
assert_true(am == true, "arcane Healthstone must match at hp<=28 with healthstone ready")
print("PASS: mage/arcane dead-lane regression (Healthstone via healthstone_ready)")

-- ============================================================================
-- frost: mana_gem_available must reach the ManaGem gate
-- ============================================================================
local fro, fro_err, fro_ns = aud.load_spec("mage", "frost")
assert_true(fro ~= nil, "mage/frost load failed: " .. tostring(fro_err))
_G.EaxRotations = fro_ns

local low_mana = aud.build_context_for("mage", {
    name = "low_mana",
    overrides = { mana_pct = 10, player_mana = 300, player_mana_pct = 10, has_potions = true },
})
aud.apply_battery_state(fro_ns, low_mana, "mage")
local fok, fst = pcall(fro.build_state, low_mana)
assert_true(fok, "frost build_state crashed: " .. tostring(fst))
local fro_state = fok and fst or low_mana
assert_true(fro_state.mana_gem_available == true,
    "frost mana_gem_available must be true when a gem is ready")
assert_true((fro_state.mana_pct or 100) <= 70,
    "frost state.mana_pct must reflect low mana, got " .. tostring(fro_state.mana_pct))

local gem = find_strategy(fro.strategies, "ManaGem")
assert_true(gem ~= nil, "frost ManaGem strategy missing")
local gmok, gm = pcall(gem.matches, low_mana, fro_state)
assert_true(gmok, "frost ManaGem matcher crashed: " .. tostring(gm))
assert_true(gm == true, "frost ManaGem must match at mana<=70 with gem available")
print("PASS: mage/frost dead-lane regression (ManaGem via mana_gem_available)")

-- ============================================================================
-- End-to-end: the battery must no longer report these lanes as never-firing.
-- ============================================================================
local function assert_lane_fires(spec, lane)
    local report = aud.run_spec("mage", spec)
    assert_true(report ~= nil, "battery run for mage/" .. spec .. " failed")
    for _, name in ipairs(report.never) do
        assert_true(name ~= lane,
            "battery still reports mage/" .. spec .. " " .. lane .. " as never-firing")
    end
end
assert_lane_fires("fire", "Healthstone")
assert_lane_fires("fire", "IceBarrier")
assert_lane_fires("fire", "ManaShield")
assert_lane_fires("arcane", "Healthstone")
assert_lane_fires("frost", "ManaGem")
print("PASS: battery no longer reports any of the 5 mage dead lanes as never-firing")
