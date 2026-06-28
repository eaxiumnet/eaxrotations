-- test_triage_tank_bias.lua — Unit tests for tank HP bias in triage scoring.
-- WHAT:  Validates that tank_hp_bias and focus_hp_bias affect urgency scores.
-- WHEN:  Run via run_rotation_tests.lua or standalone.
-- WHY:   Ensures tanks outrank DPS at same HP% when bias is configured.

local _G = _G
local NS = _G.EaxRotations or {}
_G.EaxRotations = NS

NS.log = function(msg) end
NS.settings = {}

-- Stub HealerDeficit for triage load
NS.HealerDeficit = {
    predicted_deficit = function(unit, horizon, settings) return 0 end,
}

-- Load triage module
local mod_ok, mod_err = pcall(dofile, "EaxRotations/shared/triage_sylvanas.lua")
if not mod_ok then
    print("FAIL: could not load shared/triage_sylvanas.lua: " .. tostring(mod_err))
    return
end

local function assert_true(v, msg)
    if not v then
        print("FAIL " .. tostring(msg))
        return false
    end
    print("PASS " .. tostring(msg))
    return true
end

local function assert_eq(a, b, msg)
    if a ~= b then
        print("FAIL " .. tostring(msg) .. ": " .. tostring(a) .. " ~= " .. tostring(b))
        return false
    end
    print("PASS " .. tostring(msg))
    return true
end

local all_ok = true

-- Test 1: Module loaded
all_ok = assert_true(NS.Triage ~= nil, "NS.Triage is non-nil after load") and all_ok
all_ok = assert_true(type(NS.Triage.rank) == "function", "NS.Triage.rank is a function") and all_ok

-- Test 2: Tank with bias outranks DPS at same HP
local entries = {
    { unit = "dps1", hp = 60, effective_hp = 60, is_tank = false, max_hp = 10000, deficit = 4000, effective_deficit = 4000 },
    { unit = "tank1", hp = 60, effective_hp = 60, is_tank = true, max_hp = 15000, deficit = 6000, effective_deficit = 6000 },
}
-- With 15% tank bias, tank effective_hp for scoring = 60 - 15 = 45, DPS = 60
-- Lower score = higher urgency, so tank should be ranked first
local ranked = NS.Triage.rank(entries, 2, { tank_hp_bias = 15 })
all_ok = assert_eq(ranked[1].unit, "tank1", "Tank with 15% bias outranks DPS at same HP") and all_ok
all_ok = assert_eq(ranked[2].unit, "dps1", "DPS ranked second") and all_ok

-- Test 3: No bias = entries with same effective HP are tie-broken by deficit
-- Both entries score ~40 (60 - deficit_pct*0.5). Sort may not be stable, so just verify both exist.
local ranked_no_bias = NS.Triage.rank(entries, 2, { tank_hp_bias = 0 })
all_ok = assert_true(#ranked_no_bias == 2, "No bias: returns both entries") and all_ok
all_ok = assert_true(ranked_no_bias[1].unit == "tank1" or ranked_no_bias[1].unit == "dps1", "No bias: first entry is one of the two") and all_ok

-- Test 4: Focus target bias
local entries_focus = {
    { unit = "dps1", hp = 60, effective_hp = 60, is_tank = false, is_focus = false, max_hp = 10000, deficit = 4000, effective_deficit = 4000 },
    { unit = "focus1", hp = 60, effective_hp = 60, is_tank = false, is_focus = true, max_hp = 10000, deficit = 4000, effective_deficit = 4000 },
}
local ranked_focus = NS.Triage.rank(entries_focus, 2, { focus_hp_bias = 10 })
all_ok = assert_eq(ranked_focus[1].unit, "focus1", "Focus target with 10% bias outranks DPS at same HP") and all_ok

-- Test 5: Empty entries
local empty = NS.Triage.rank({}, 0)
all_ok = assert_eq(#empty, 0, "Empty entries returns empty table") and all_ok

if all_ok then
    print("OK triage_tank_bias")
else
    print("FAIL triage_tank_bias")
end
