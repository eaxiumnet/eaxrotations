-- test_healer_deficit_consumers.lua — Verify healer specs wire HealerDeficit overheal gates.
-- WHAT:  Confirms gate_overheal / HealerDeficit references exist in healer consumers.
-- WHEN:  rotation test suite.
-- WHY:  Scenario 3 binary pass: healer_deficit consumed by all healer specs.

local function assert_true(v, msg)
    if not v then error(msg or "assert_true failed", 2) end
end

local function file_contains(path, pattern)
    local f = io.open(path, "r")
    if not f then return false end
    local content = f:read("*a")
    f:close()
    return content:find(pattern, 1, true) ~= nil
end

local consumers = {
    "EaxRotations/classes/paladin/holy_sylvanas.lua",
    "EaxRotations/classes/paladin/heal_helper_sylvanas.lua",
    "EaxRotations/classes/priest/holy_sylvanas.lua",
    "EaxRotations/classes/priest/discipline_sylvanas.lua",
    "EaxRotations/classes/priest/healing_sylvanas.lua",
    "EaxRotations/classes/priest/holy_vanilla.lua",
    "EaxRotations/classes/priest/discipline_vanilla.lua",
    "EaxRotations/classes/shaman/restoration_sylvanas.lua",
    "EaxRotations/classes/shaman/restoration_vanilla.lua",
    "EaxRotations/classes/shaman/healing_sylvanas.lua",
    "EaxRotations/classes/druid/resto_sylvanas.lua",
    "EaxRotations/classes/druid/healing_sylvanas.lua",
}

local missing = {}
for i = 1, #consumers do
    local path = consumers[i]
    if not file_contains(path, "HealerDeficit") then
        missing[#missing + 1] = path
    end
end

assert_true(#missing == 0, "HealerDeficit missing from: " .. table.concat(missing, ", "))
assert_true(#consumers >= 11, "expected at least 11 healer consumers, got " .. tostring(#consumers))

-- Module API still exposes overheal gates
local NS = _G.EaxRotations or {}
_G.EaxRotations = NS
NS.log = function() end
NS.settings = {}
NS.time_now = function() return 10 end
NS.unit_health_pct = function() return 50 end
dofile("EaxRotations/shared/healer_deficit_sylvanas.lua")
local M = NS.HealerDeficit
assert_true(M ~= nil, "HealerDeficit loaded")
assert_true(type(M.gate_spell_overheal) == "function", "gate_spell_overheal exists")
assert_true(type(M.heal_would_overheal) == "function", "heal_would_overheal exists")

local unit = {
    get_guid = function() return "consumer_u1" end,
    get_max_health = function() return 10000 end,
    get_health = function() return 10000 end,
    get_incoming_heals = function() return 0 end,
    get_total_shield = function() return 0 end,
    get_total_heal_absorbs = function() return 0 end,
}
assert_true(M.gate_spell_overheal("HolyLight", unit, 2.5, { healer_predict_enabled = true }) == true,
    "HolyLight overheal-gates full HP target")
assert_true(M.gate_spell_overheal("HealingTouch", unit, 2.5, { healer_predict_enabled = true }) == true,
    "HealingTouch overheal-gates full HP target")
assert_true(M.gate_spell_overheal("ChainHeal", unit, 2.5, { healer_predict_enabled = true }) == true,
    "ChainHeal overheal-gates full HP target")

print("PASS test_healer_deficit_consumers (" .. #consumers .. " files)")
