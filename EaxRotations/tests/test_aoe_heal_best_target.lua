-- Test: AoE Heal Cluster Targeting
-- EaxRotations File Version: 1.0.0
-- WHAT: Validates NS.AoEHeal.best_target finds dense ally clusters.
-- WHEN: run via run_rotation_tests.lua or standalone.
-- WHY:  Ensures Tranquility/CoH/Chain Heal hit the most injured allies.

local _G = _G
local NS = _G.EaxRotations or {}
_G.EaxRotations = NS

NS.log = function(msg) end
NS.settings = {}

local mod_ok, mod_err = pcall(dofile, "EaxRotations/shared/triage_sylvanas.lua")
if not mod_ok then
    print("FAIL: could not load shared/triage_sylvanas.lua: " .. tostring(mod_err))
    return
end

local AoEHeal = NS.AoEHeal
if not AoEHeal then
    print("FAIL: NS.AoEHeal not registered after load")
    return
end

local function assert_eq(a, b, msg)
    if a ~= b then
        print("FAIL " .. tostring(msg) .. ": expected " .. tostring(b) .. " got " .. tostring(a))
        return false
    end
    print("PASS " .. tostring(msg))
    return true
end

local function assert_true(v, msg)
    if not v then
        print("FAIL " .. tostring(msg))
        return false
    end
    print("PASS " .. tostring(msg))
    return true
end

local all_ok = true

-- Helper to create an entry
local function entry(name)
    return {
        unit = name,
        hp = 50,
        effective_hp = 50,
        is_tank = false,
        max_hp = 10000,
        current_hp = 5000,
        deficit = 5000,
        effective_deficit = 5000,
    }
end

-- Mock NS.unit_distance for deterministic testing
local orig_unit_distance = NS.unit_distance
NS.unit_distance = function(a, b)
    local dists = {
        a = { b = 8, c = 7, d = 5, e = 50 },
        b = { a = 8, c = 5, d = 6, e = 55 },
        c = { a = 7, b = 5, d = 5, e = 53 },
        d = { a = 5, b = 6, c = 5, e = 52 },
    }
    local key_a = type(a) == "table" and a.unit or a
    local key_b = type(b) == "table" and b.unit or b
    local d1 = dists[key_a] and dists[key_a][key_b]
    local d2 = dists[key_b] and dists[key_b][key_a]
    return d1 or d2 or 99
end

-- ---------------------------------------------------------------------------
-- SCENARIO 1: 3 targets in a tight cluster — should find center with count 3
-- ---------------------------------------------------------------------------
do
    local entries = {
        entry("a"),
        entry("b"),
        entry("c"),
    }
    local best, count = AoEHeal.best_target(entries, 3, 15, 3)
    all_ok = assert_true(best ~= nil, "S1: found a cluster center") and all_ok
    all_ok = assert_eq(count, 3, "S1: cluster count is 3") and all_ok
end

-- ---------------------------------------------------------------------------
-- SCENARIO 2: Spread out targets — no cluster of 3 within 15 yards
-- ---------------------------------------------------------------------------
do
    local entries = {
        entry("a"),
        entry("e"),
        entry("e2"),
    }
    local saved = NS.unit_distance
    NS.unit_distance = function(a, b) return 30 end
    local best, count = AoEHeal.best_target(entries, 3, 15, 3)
    NS.unit_distance = saved
    all_ok = assert_eq(best, nil, "S2: no cluster found when spread") and all_ok
    all_ok = assert_eq(count, 0, "S2: count 0 when no cluster") and all_ok
end

-- ---------------------------------------------------------------------------
-- SCENARIO 3: 5 targets, 4 in one cluster — should pick the 4-cluster
-- ---------------------------------------------------------------------------
do
    local entries = {
        entry("a"),
        entry("b"),
        entry("c"),
        entry("d"),
        entry("e"),
    }
    local best, count = AoEHeal.best_target(entries, 5, 15, 3)
    all_ok = assert_true(best ~= nil, "S3: found cluster") and all_ok
    all_ok = assert_eq(count, 4, "S3: 4-target cluster") and all_ok
end

-- ---------------------------------------------------------------------------
-- SCENARIO 4: min_targets = 5 but only 4 in cluster — returns nil
-- ---------------------------------------------------------------------------
do
    local entries = {
        entry("a"),
        entry("b"),
        entry("c"),
        entry("d"),
    }
    local best, count = AoEHeal.best_target(entries, 4, 15, 5)
    all_ok = assert_eq(best, nil, "S4: nil when cluster smaller than min") and all_ok
end

-- ---------------------------------------------------------------------------
-- SCENARIO 5: nil/empty input safety
-- ---------------------------------------------------------------------------
do
    local best1, count1 = AoEHeal.best_target(nil, 0, 15, 3)
    all_ok = assert_eq(best1, nil, "S5: nil entries -> nil") and all_ok
    local best2, count2 = AoEHeal.best_target({}, 0, 15, 3)
    all_ok = assert_eq(best2, nil, "S5: empty entries -> nil") and all_ok
end

-- ---------------------------------------------------------------------------
-- SCENARIO 6: 2 targets only, min_targets=2 — should find pair
-- ---------------------------------------------------------------------------
do
    local entries = {
        entry("a"),
        entry("b"),
    }
    local best, count = AoEHeal.best_target(entries, 2, 15, 2)
    all_ok = assert_true(best ~= nil, "S6: 2-target cluster found") and all_ok
    all_ok = assert_eq(count, 2, "S6: count 2") and all_ok
end

-- Restore
NS.unit_distance = orig_unit_distance

if all_ok then
    print("OK aoe_heal_best_target")
else
    print("FAIL aoe_heal_best_target")
end
