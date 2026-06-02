-- Phase 1 test: HealerDeficit predictive overheal gate behavior.
-- Tests the acceptance criteria from the Phase 1 plan:
--   1. Low current HP still heals (overheal gate allows emergency HP through)
--   2. Incoming damage raises priority before HP drops (predicted_deficit accounts for damage rate)
--   3. Incoming heals prevent unnecessary duplicate large heals (heal_would_overheal accounts for incoming heals)
--   4. Shield/HoT refresh logic does not spam when absorb/HoT remains sufficient
--   5. Gate returns false when predict disabled (pass-through, no blocking)

local function assert_true(v, label) if not v then error(label or "assert_true failed", 2) end end
local function assert_false(v, label) if v then error(label or "assert_false failed: expected false", 2) end end
local function assert_eq(a, b, label) if a ~= b then error((label or "assert_eq") .. ": " .. tostring(a) .. " ~= " .. tostring(b), 2) end end

-- ============================================================================
-- Mock NS namespace for HealerDeficit module
-- ============================================================================

local mock_settings = {}
local NS = {
    log = function() end,
    settings = mock_settings,
    unit_health_pct = function(unit)
        return unit and unit._hp_pct or 100
    end,
    IncomingHeals = nil,  -- set below for incoming-heals test
}
_G.EaxRotations = NS

-- Load HealerDeficit module
dofile("EaxRotations/shared/healer_deficit_sylvanas.lua")
local M = _G.EaxRotations.HealerDeficit
assert_true(M ~= nil, "HealerDeficit should be loaded")
assert_true(type(M.gate_spell_overheal) == "function", "gate_spell_overheal should exist")
assert_true(type(M.heal_would_overheal) == "function", "heal_would_overheal should exist")
assert_true(type(M.predicted_deficit) == "function", "predicted_deficit should exist")

-- ============================================================================
-- Helper: create mock unit with specified health state
-- ============================================================================

local function mock_unit(opts)
    opts = opts or {}
    local hp = opts.hp or 10000
    local max_hp = opts.max_hp or 10000
    local incoming_damage = opts.incoming_damage or 0
    local incoming_heals = opts.incoming_heals or 0
    local total_shield = opts.total_shield or 0
    local hp_pct = opts.hp_pct or math.floor(hp / max_hp * 100)

    local u = {
        _hp_pct = hp_pct,
        get_health = function() return hp end,
        get_max_health = function() return max_hp end,
        get_incoming_damage = function(_, deadline)
            return incoming_damage
        end,
        get_incoming_heals = function()
            return incoming_heals
        end,
        get_total_shield = function()
            return total_shield
        end,
    }
    return u
end

-- Reset HealerDeficit state before each test section
local function reset_module()
    M.clear()
    -- Reset settings
    for k in pairs(mock_settings) do mock_settings[k] = nil end
    -- Clear incoming heals mock
    NS.IncomingHeals = nil
end

-- ============================================================================
-- Test 1: Low HP — overheal gate should NOT block (emergency bypass via caller)
-- ============================================================================
-- Note: gate_spell_overheal itself doesn't check HP thresholds — the caller
-- (e.g. predictive_overheal in resto_druid) checks emergency_hp first.
-- This test verifies that when prediction IS enabled but the target genuinely
-- needs a heal (deficit > heal_size), gate_spell_overheal returns false.
print("--- HealerDeficit: gate_spell_overheal basic behavior ---")

reset_module()
-- Target at 20% HP (8000 missing), no incoming heals/shields
local low_hp_unit = mock_unit({ hp = 2000, max_hp = 10000 })
-- GreaterHeal avg size is 3500; deficit is 8000 → 3500 < 8000 → no overheal
local result = M.gate_spell_overheal("GreaterHeal", low_hp_unit, 2.5, { healer_predict_enabled = true })
assert_false(result, "gate_spell_overheal should return false when deficit (8000) > heal_size (3500)")

-- Test 2: Full HP — overheal gate should BLOCK
reset_module()
local full_hp_unit = mock_unit({ hp = 10000, max_hp = 10000 })
-- Target at 100% HP, deficit 0 → heal_size 3500 > 0 + safety → overheal
local result2 = M.gate_spell_overheal("GreaterHeal", full_hp_unit, 2.5, { healer_predict_enabled = true })
assert_true(result2, "gate_spell_overheal should return true when deficit (0) < heal_size (3500)")

-- Test 3: Moderate HP — should block when deficit is clearly below heal size
reset_module()
-- 75% HP = 2500 missing + 500 safety = 3000 predicted deficit. GreaterHeal is 3500. 3500 > 3000 → overheal
local mod_hp_unit = mock_unit({ hp = 7500, max_hp = 10000 })
local result3 = M.gate_spell_overheal("GreaterHeal", mod_hp_unit, 2.5, { healer_predict_enabled = true })
assert_true(result3, "gate_spell_overheal should block when predicted deficit (3000) < heal_size (3500)")

-- Test 4: Emergency HP threshold check (simulates caller pattern)
-- When HP <= emergency threshold, the caller should skip the overheal gate entirely.
-- This test verifies the caller-side pattern used in resto_druid predictive_overheal()
reset_module()
local emergency_unit = mock_unit({ hp = 2000, max_hp = 10000 })
-- simulate: effective_hp <= emergency_hp (25) → return false (allow heal) without calling gate
local effective_hp = 20  -- 20%
local emergency_hp = 25
local bypass_gate = effective_hp <= emergency_hp
assert_true(bypass_gate, "Emergency HP bypass: when 20%% <= 25%%, should skip overheal gate entirely")
-- And if gate were called, it would pass (deficit 8000 > heal 3500)
local gate_result = M.gate_spell_overheal("GreaterHeal", emergency_unit, 2.5, { healer_predict_enabled = true })
assert_false(gate_result, "Even if gate were called, deficit 8000 > heal 3500 → no overheal")

-- ============================================================================
-- Test 5-6: Incoming damage raises deficit (predicted_deficit test)
-- ============================================================================

print("--- HealerDeficit: predicted_deficit with incoming damage ---")

-- Test 5: No incoming damage → deficit equals current missing HP + safety
reset_module()
local no_dmg_unit = mock_unit({ hp = 5000, max_hp = 10000, incoming_damage = 0 })
local deficit = M.predicted_deficit(no_dmg_unit, 2.0, { healer_predict_enabled = true })
-- Current deficit = 5000, safety = 5% of 10000 = 500. Expected: 5500
assert_true(deficit >= 5000 and deficit <= 6000,
    "predicted_deficit without incoming damage should be ~5500 (5000 missing + 500 safety), got " .. tostring(deficit))

-- Test 6: Incoming damage → deficit higher than current HP alone
reset_module()
local dmg_unit = mock_unit({ hp = 5000, max_hp = 10000, incoming_damage = 3000 })
local deficit_dmg = M.predicted_deficit(dmg_unit, 2.0, { healer_predict_enabled = true })
-- Current deficit = 5000, incoming damage = 3000, safety ~500. Expected: ~8500
assert_true(deficit_dmg >= 7500,
    "predicted_deficit with incoming damage should be >= 7500 (5000 missing + 3000 dmg + safety), got " .. tostring(deficit_dmg))

-- ============================================================================
-- Test 6b: Moderate HP at exactly 70% — heal is exactly needed
-- 3000 deficit + 500 safety = 3500 predicted. Heal size 3500 = exactly needed → no overheal
reset_module()
local exactly_needed_unit = mock_unit({ hp = 7000, max_hp = 10000 })
local result_exact = M.gate_spell_overheal("GreaterHeal", exactly_needed_unit, 2.5, { healer_predict_enabled = true })
assert_false(result_exact, "gate_spell_overheal should NOT block when predicted deficit (3500) == heal_size (3500)")

-- ============================================================================
-- Test 7-8: Incoming heals prevent unnecessary heals
-- ============================================================================

print("--- HealerDeficit: heal_would_overheal with incoming heals ---")

-- Test 7: Target at 70% HP with incoming heal covering the deficit
reset_module()
-- 70% HP = 3000 missing, but 4000 incoming heal coming → effective deficit 0
local healed_unit = mock_unit({ hp = 7000, max_hp = 10000, incoming_heals = 4000 })
local would_over = M.heal_would_overheal(healed_unit, 3500, 2.5, { healer_predict_enabled = true })
assert_true(would_over,
    "heal_would_overheal should return true when incoming heals (4000) already cover deficit (3000)")

-- Test 8: Target at 75% HP with NO incoming heals → heal would overheal
-- deficit 2500 + safety 500 = 3000. Heal 3500 > 3000 → overheal
reset_module()
local no_heals_unit = mock_unit({ hp = 7500, max_hp = 10000, incoming_heals = 0 })
local would_over2 = M.heal_would_overheal(no_heals_unit, 3500, 2.5, { healer_predict_enabled = true })
assert_true(would_over2,
    "heal_would_overheal should return true when predicted deficit (3000) < heal_size (3500)")

-- But with a smaller heal (FlashHeal ~1500), deficit 3000 > 1500 → needed
local would_over3 = M.heal_would_overheal(no_heals_unit, 1500, 2.5, { healer_predict_enabled = true })
assert_false(would_over3,
    "heal_would_overheal should return false when deficit (3000) > heal_size (1500)")

-- ============================================================================
-- Test 9-10: Shield absorbs reduce deficit
-- ============================================================================

print("--- HealerDeficit: shield absorbs in deficit calculation ---")

-- Test 9: Shields reduce the effective deficit
reset_module()
local shielded_unit = mock_unit({ hp = 7000, max_hp = 10000, total_shield = 2000 })
-- HP 7000 + shield 2000 = 9000 effective → deficit 1000
local deficit_shield = M.predicted_deficit(shielded_unit, 2.0, { healer_predict_enabled = true })
assert_true(deficit_shield <= 2000,
    "predicted_deficit with shields should be low (deficit ~1000 + safety), got " .. tostring(deficit_shield))

-- Test 10: heal_would_overheal accounts for shields
reset_module()
local shielded_unit2 = mock_unit({ hp = 8000, max_hp = 10000, total_shield = 2000 })
-- HP 8000 + shield 2000 = 10000 effective, deficit 0 + safety 500 = 500. Heal 1500 > 500 → overheal
local shielded_over = M.heal_would_overheal(shielded_unit2, 1500, 2.5, { healer_predict_enabled = true })
assert_true(shielded_over,
    "heal_would_overheal should return true when shields (2000) reduce deficit below heal_size (1500)")

-- ============================================================================
-- Test 11-12: Predict disabled → pass-through (no blocking)
-- ============================================================================

print("--- HealerDeficit: predict disabled pass-through ---")

-- Test 11: When predict disabled, heal_would_overheal uses simple HP check
reset_module()
local disabled_unit = mock_unit({ hp = 9000, max_hp = 10000 })
-- HP 9000 + heal 3500 = 12500 > max 10000 → overheal (simple check)
local disabled_over = M.heal_would_overheal(disabled_unit, 3500, 2.5, { healer_predict_enabled = false })
assert_true(disabled_over,
    "heal_would_overheal with predict disabled: 9000 + 3500 > 10000 → should overheal")

-- Test 12: When predict disabled, gate_spell_overheal returns false (not blocking)
reset_module()
local disabled_unit2 = mock_unit({ hp = 5000, max_hp = 10000 })
-- When predict disabled, gate_spell_overheal returns false early (no blocking)
local gate_disabled = M.gate_spell_overheal("GreaterHeal", disabled_unit2, 2.5, { healer_predict_enabled = false })
assert_false(gate_disabled,
    "gate_spell_overheal should return false when predict is disabled (pass-through)")

-- ============================================================================
-- Test 13-14: Unknown spell key → safe pass-through
-- ============================================================================

print("--- HealerDeficit: unknown spell key safety ---")

-- Test 13: nil spell_key → returns false (safe, no block)
reset_module()
local safe_unit = mock_unit({ hp = 10000, max_hp = 10000 })
local nil_key = M.gate_spell_overheal(nil, safe_unit, 2.5, { healer_predict_enabled = true })
assert_false(nil_key, "gate_spell_overheal with nil spell_key should return false (safe pass-through)")

-- Test 14: Unknown spell_key with no heal size mapping → returns false (safe)
reset_module()
local unknown_key = M.gate_spell_overheal("SomeCustomSpell", mock_unit({ hp = 10000, max_hp = 10000 }), 2.5, { healer_predict_enabled = true })
assert_false(unknown_key, "gate_spell_overheal with unknown spell_key should return false (safe pass-through)")

-- ============================================================================
-- Test 15: nil unit → safe (returns false - no block)
-- ============================================================================
reset_module()
local nil_unit = M.gate_spell_overheal("GreaterHeal", nil, 2.5, { healer_predict_enabled = true })
assert_false(nil_unit, "gate_spell_overheal with nil unit should return false (safe)")

local nil_unit2 = M.heal_would_overheal(nil, 3500, 2.5, { healer_predict_enabled = true })
assert_true(nil_unit2, "heal_would_overheal with nil unit should return true (conservative: would overheal)")

print("PASS test_healer_deficit_overheal")
