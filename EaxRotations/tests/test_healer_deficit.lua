-- test_healer_deficit.lua -- Test Healer Deficit tests.
-- WHAT:  Test Healer Deficit tests
-- WHEN:  During rotation test suite execution.
-- WHY:   Protects against regressions in rotation logic and state handling.
-- SAFETY: Pure unit tests with mocked API context.

-- Test: Predictive Healing Deficit Tracker
-- EaxRotations File Version: 1.1.1
local _G = _G
local NS = _G.EaxRotations or {}
_G.EaxRotations = NS

-- Minimal stubs
NS.log = function(msg) end
NS.settings = {}
NS.time_now = function() return _G.mock_now or 10 end
NS.unit_health_pct = function(unit)
    if not unit then return 100 end
    return unit.hp_pct or 100
end

-- Load module under test (use dofile so path resolution works standalone)
local mod_ok, mod_err = pcall(dofile, "EaxRotations/shared/healer_deficit_sylvanas.lua")
if not mod_ok then
    print("FAIL: could not load shared/healer_deficit_sylvanas.lua: " .. tostring(mod_err))
    return
end

local M = NS.HealerDeficit
if not M then
    print("FAIL: NS.HealerDeficit not registered")
    return
end

local function mock_unit(guid, hp_pct, max_hp, current_hp, incoming, absorbs, heal_absorbs)
    return {
        guid = guid,
        hp_pct = hp_pct or 100,
        _max_hp = max_hp or 1000,
        _current_hp = current_hp or 1000,
        _incoming = incoming or 0,
        _absorbs = absorbs or 0,
        _heal_absorbs = heal_absorbs or 0,
        get_guid = function(self) return self.guid end,
        get_max_health = function(self) return self._max_hp end,
        get_health = function(self) return self._current_hp end,
        get_incoming_heals = function(self) return self._incoming end,
        get_total_shield = function(self) return self._absorbs end,
        get_total_heal_absorbs = function(self) return self._heal_absorbs end,
    }
end

local function assert_eq(a, b, msg)
    if a ~= b then
        print("FAIL " .. tostring(msg) .. ": expected " .. tostring(b) .. " got " .. tostring(a))
        return false
    end
    print("PASS " .. tostring(msg))
    return true
end

local function assert_near(a, b, tolerance, msg)
    tolerance = tolerance or 0.001
    if math.abs(a - b) > tolerance then
        print("FAIL " .. tostring(msg) .. ": expected ~" .. tostring(b) .. " got " .. tostring(a))
        return false
    end
    print("PASS " .. tostring(msg))
    return true
end

local function assert_true(cond, msg)
    if not cond then
        print("FAIL " .. tostring(msg))
        return false
    end
    print("PASS " .. tostring(msg))
    return true
end

local function assert_false(cond, msg)
    return assert_true(not cond, msg)
end

local all_pass = true
local function check(result, msg)
    if not result then all_pass = false end
end

-- Reset state
M.clear()

-- Test 1: nil target returns 0
check(assert_eq(M.predicted_deficit(nil, 2, {}), 0, "nil target returns 0"), "t1")

-- Test 2: disabled pass-through returns base deficit
local u2 = mock_unit("u2", 80, 1000, 800, 0, 0)
check(assert_eq(M.predicted_deficit(u2, 2, { healer_predict_enabled = false }), 200, "disabled: returns base deficit 200"), "t2")

-- Test 3: insufficient samples returns base deficit only
local base_time = 100
_G.mock_now = base_time
local u3 = mock_unit("u3", 80, 1000, 800, 0, 0)
M.update(u3, base_time, { healer_predict_sample_interval = 1 })
check(assert_eq(M.predicted_deficit(u3, 2, { healer_predict_enabled = true, healer_predict_safety_pct = 0 }), 200, "insufficient samples: base deficit only"), "t3")

-- Test 4: steady damage increases predicted deficit
M.clear()
local u4 = mock_unit("u4", 100, 1000, 1000, 0, 0)
for i = 1, 5 do
    _G.mock_now = base_time + (i - 1) * 2
    u4._current_hp = 1000 - (i - 1) * 100
    u4.hp_pct = u4._current_hp / 10
    M.update(u4, _G.mock_now, { healer_predict_sample_interval = 1, healer_predict_window = 10 })
end
_G.mock_now = base_time + 8
local pred4 = M.predicted_deficit(u4, 2, { healer_predict_enabled = true, healer_predict_safety_pct = 0, healer_predict_max_mult = 100 })
-- At t=8, HP=600 (40% drop over 8s = 5%/s). From 600 to 0 at 5%/s = 8s. Plus 2s horizon * 50 HP/s = 100 extra.
-- Base deficit = 400. Predicted extra = 100. Total ~500.
check(assert_true(pred4 > 450 and pred4 < 550, "steady damage: predicted deficit ~500 (base 400 + ~100 extra)"), "t4")

-- Test 5: heal_would_overheal blocks when heal exceeds predicted deficit
local would_overheal = M.heal_would_overheal(u4, 600, 2, { healer_predict_enabled = true })
-- Predicted deficit is ~500, heal is 600, so 100 would be waste -> true
check(assert_true(would_overheal, "heal_would_overheal: 600 heal on ~500 deficit is overheal"), "t5")

-- Test 6: heal_would_overheal allows when heal fits inside predicted deficit
local would_overheal_small = M.heal_would_overheal(u4, 200, 2, { healer_predict_enabled = true })
check(assert_false(would_overheal_small, "heal_would_overheal: 200 heal on ~500 deficit is not overheal"), "t6")

-- Test 7: rising HP (healing) returns nil rate and falls back to base deficit
M.clear()
local u7 = mock_unit("u7", 50, 1000, 500, 0, 0)
for i = 1, 5 do
    _G.mock_now = base_time + (i - 1) * 2
    u7._current_hp = 500 + (i - 1) * 50
    u7.hp_pct = u7._current_hp / 10
    M.update(u7, _G.mock_now, { healer_predict_sample_interval = 1, healer_predict_window = 10 })
end
_G.mock_now = base_time + 8
local rate7 = M.get_damage_rate(u7, { healer_predict_min_rate = 1 })
check(assert_eq(rate7, nil, "rising HP: rate is nil (healing, not damage)"), "t7")

-- Test 8: target swap clears old history
M.clear()
local u8a = mock_unit("u8a", 80, 1000, 800, 0, 0)
M.update(u8a, base_time, { healer_predict_sample_interval = 1 })
M.clear()
local u8b = mock_unit("u8b", 60, 1000, 600, 0, 0)
M.update(u8b, base_time + 1, { healer_predict_sample_interval = 1 })
local samples_8a = M.get_damage_rate(u8a, {})
check(assert_eq(samples_8a, nil, "after clear: old unit has no samples"), "t8")

-- Test 9: max deficit multiplier caps predicted extra
M.clear()
local u9 = mock_unit("u9", 100, 1000, 1000, 0, 0)
for i = 1, 6 do
    _G.mock_now = base_time + (i - 1) * 1
    u9._current_hp = 1000 - (i - 1) * 200
    u9.hp_pct = u9._current_hp / 10
    M.update(u9, _G.mock_now, { healer_predict_sample_interval = 0.1, healer_predict_window = 10 })
end
_G.mock_now = base_time + 5
local pred9 = M.predicted_deficit(u9, 2, { healer_predict_enabled = true, healer_predict_safety_pct = 0, healer_predict_max_mult = 15 })
-- Base deficit = 0 (HP=0? no, HP=0 would mean dead). Let's recalculate: at i=6, current_hp = 0? That's dead.
-- Actually 1000 - 5*200 = 0. That's dead. Let's fix: at i=6, current_hp = 1000 - 5*150 = 250, hp_pct = 25
M.clear()
u9 = mock_unit("u9", 100, 1000, 1000, 0, 0)
for i = 1, 6 do
    _G.mock_now = base_time + (i - 1) * 1
    u9._current_hp = 1000 - (i - 1) * 150
    u9.hp_pct = u9._current_hp / 10
    M.update(u9, _G.mock_now, { healer_predict_sample_interval = 0.1, healer_predict_window = 10 })
end
_G.mock_now = base_time + 5
u9._current_hp = 250
u9.hp_pct = 25
local pred9b = M.predicted_deficit(u9, 2, { healer_predict_enabled = true, healer_predict_safety_pct = 0, healer_predict_max_mult = 15 })
-- Base deficit = 750. Rate = 75%/5s = 15%/s. Over 2s horizon = 30% = 300 HP. But capped at 1.5x base = 1125.
-- So total should be ~750 + 300 = 1050 (under cap).
check(assert_true(pred9b >= 1000 and pred9b <= 1100, "max mult cap: predicted deficit ~1050 (base 750 + 300 extra, under 1.5x cap)"), "t9")

-- Test 10: prune stale entries
M.clear()
local u10 = mock_unit("u10", 80, 1000, 800, 0, 0)
M.update(u10, base_time, { healer_predict_sample_interval = 1 })
M.update(u10, base_time + 1, { healer_predict_sample_interval = 1 })
-- Force stale prune by triggering an update cycle with a far future time
_G.mock_now = base_time + 35
-- Update will add a new sample then prune stale entries
M.update(u10, base_time + 35, { healer_predict_sample_interval = 0.1, healer_predict_window = 10 })
local pred10 = M.predicted_deficit(u10, 2, { healer_predict_enabled = true, healer_predict_safety_pct = 0 })
-- After 35s, old samples are stale and pruned; should fall back to base deficit
check(assert_eq(pred10, 200, "stale prune: falls back to base deficit after 35s silence"), "t10")

-- Test 11: heal_absorbs increase effective deficit (e.g. Mortal Strike)
M.clear()
local u11 = mock_unit("u11", 80, 1000, 800, 0, 0, 150)  -- 200 base deficit + 150 heal_absorbs
local pred11 = M.predicted_deficit(u11, 2, { healer_predict_enabled = false })
check(assert_eq(pred11, 350, "heal_absorbs: 200 base + 150 absorb = 350 deficit"), "t11")

-- Test 12: heal_absorbs with shields and incoming heals (net effect)
M.clear()
local u12 = mock_unit("u12", 80, 1000, 800, 50, 30, 100)
-- base = 1000 - 800 - 50 - 30 + 100 = 220
local pred12 = M.predicted_deficit(u12, 2, { healer_predict_enabled = false })
check(assert_eq(pred12, 220, "heal_absorbs net: 1000-800-50-30+100 = 220"), "t12")

if all_pass then
    print("PASS test_healer_deficit")
else
    print("FAIL test_healer_deficit")
end
