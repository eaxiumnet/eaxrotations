-- Test: Triage Module Load Regression
-- EaxRotations File Version: 1.0.0
-- WHAT: Confirms NS.Triage and NS.AoEHeal are non-nil after module load.
-- WHEN: run via run_rotation_tests.lua or standalone.
-- WHY:  Catches future loader-list regressions (HE1 root cause).

local _G = _G
local NS = _G.EaxRotations or {}
_G.EaxRotations = NS

NS.log = function(msg) end
NS.settings = {}

-- Stub HealerDeficit so rank() doesn't error on load
NS.HealerDeficit = {
    predicted_deficit = function(unit, horizon, settings) return 0 end,
}

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

local all_ok = true

all_ok = assert_true(NS.Triage ~= nil, "NS.Triage is non-nil after load") and all_ok
all_ok = assert_true(NS.Triage.rank ~= nil, "NS.Triage.rank is a function") and all_ok
all_ok = assert_true(NS.AoEHeal ~= nil, "NS.AoEHeal is non-nil after load") and all_ok
all_ok = assert_true(NS.AoEHeal.best_target ~= nil, "NS.AoEHeal.best_target is a function") and all_ok

if all_ok then
    print("OK triage_loaded")
else
    print("FAIL triage_loaded")
end
