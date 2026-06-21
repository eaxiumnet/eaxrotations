-- Test: Triage Target Ranking
-- EaxRotations File Version: 1.0.0
-- WHAT: Validates NS.Triage.rank sorts healing targets by urgency.
-- WHEN: run via run_rotation_tests.lua or standalone.
-- WHY:  Ensures tank-first + predicted-deficit-aware ranking works.

local _G = _G
local NS = _G.EaxRotations or {}
_G.EaxRotations = NS

NS.log = function(msg) end
NS.settings = {}

-- Stub HealerDeficit so rank() can compute predicted_deficit
NS.HealerDeficit = {
    predicted_deficit = function(unit, horizon, settings)
        return unit._predicted_deficit or 0
    end,
}

local mod_ok, mod_err = pcall(dofile, "EaxRotations/shared/triage_sylvanas.lua")
if not mod_ok then
    print("FAIL: could not load shared/triage_sylvanas.lua: " .. tostring(mod_err))
    return
end

local Triage = NS.Triage
if not Triage then
    print("FAIL: NS.Triage not registered after load")
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

-- ---------------------------------------------------------------------------
-- SCENARIO 1: Tank at 50% HP should outrank DPS at 30% HP (tank priority <60%)
-- ---------------------------------------------------------------------------
do
    local entries = {
        { unit = "tank1", hp = 50, effective_hp = 50, is_tank = true,  max_hp = 10000, current_hp = 5000, deficit = 5000, effective_deficit = 5000 },
        { unit = "dps1",  hp = 30, effective_hp = 30, is_tank = false, max_hp = 8000,  current_hp = 2400, deficit = 5600, effective_deficit = 5600 },
    }
    local ranked = Triage.rank(entries, 2)
    all_ok = assert_eq(ranked[1].unit, "tank1", "S1: tank at 50% outranks dps at 30%") and all_ok
    all_ok = assert_eq(ranked[2].unit, "dps1",  "S1: dps second") and all_ok
end

-- ---------------------------------------------------------------------------
-- SCENARIO 2: Tank at 80% HP should NOT outrank DPS at 20% HP (tank >60%)
-- ---------------------------------------------------------------------------
do
    local entries = {
        { unit = "tank1", hp = 80, effective_hp = 80, is_tank = true,  max_hp = 10000, current_hp = 8000, deficit = 2000, effective_deficit = 2000 },
        { unit = "dps1",  hp = 20, effective_hp = 20, is_tank = false, max_hp = 8000,  current_hp = 1600, deficit = 6400, effective_deficit = 6400 },
    }
    local ranked = Triage.rank(entries, 2)
    all_ok = assert_eq(ranked[1].unit, "dps1", "S2: dps at 20% outranks tank at 80%") and all_ok
    all_ok = assert_eq(ranked[2].unit, "tank1", "S2: tank second") and all_ok
end

-- ---------------------------------------------------------------------------
-- SCENARIO 3: Two non-tanks — lower effective_hp first
-- ---------------------------------------------------------------------------
do
    local entries = {
        { unit = "dps1", hp = 60, effective_hp = 60, is_tank = false, max_hp = 8000, current_hp = 4800, deficit = 3200, effective_deficit = 3200 },
        { unit = "dps2", hp = 40, effective_hp = 40, is_tank = false, max_hp = 8000, current_hp = 3200, deficit = 4800, effective_deficit = 4800 },
    }
    local ranked = Triage.rank(entries, 2)
    all_ok = assert_eq(ranked[1].unit, "dps2", "S3: lower HP first") and all_ok
    all_ok = assert_eq(ranked[2].unit, "dps1", "S3: higher HP second") and all_ok
end

-- ---------------------------------------------------------------------------
-- SCENARIO 4: Higher effective_deficit break-tie — same HP, higher deficit wins
-- ---------------------------------------------------------------------------
do
    local entries = {
        { unit = "dps1", hp = 50, effective_hp = 50, is_tank = false, max_hp = 10000, current_hp = 5000, deficit = 5000, effective_deficit = 3000 },
        { unit = "dps2", hp = 50, effective_hp = 50, is_tank = false, max_hp = 10000, current_hp = 5000, deficit = 5000, effective_deficit = 6000 },
    }
    local ranked = Triage.rank(entries, 2)
    all_ok = assert_eq(ranked[1].unit, "dps2", "S4: higher effective deficit wins tie") and all_ok
end

-- ---------------------------------------------------------------------------
-- SCENARIO 5: Nil/empty input safety
-- ---------------------------------------------------------------------------
do
    local ranked_nil = Triage.rank(nil, 0)
    all_ok = assert_true(type(ranked_nil) == "table" and #ranked_nil == 0, "S5: nil entries returns empty table") and all_ok
    local ranked_empty = Triage.rank({}, 0)
    all_ok = assert_true(type(ranked_empty) == "table" and #ranked_empty == 0, "S5: empty entries returns empty table") and all_ok
end

-- ---------------------------------------------------------------------------
-- SCENARIO 6: Self (is_player) gets same treatment as any other unit
-- ---------------------------------------------------------------------------
do
    local entries = {
        { unit = "me",    hp = 25, effective_hp = 25, is_tank = false, is_player = true,  max_hp = 6000, current_hp = 1500, deficit = 4500, effective_deficit = 4500 },
        { unit = "dps1",  hp = 30, effective_hp = 30, is_tank = false, is_player = false, max_hp = 8000, current_hp = 2400, deficit = 5600, effective_deficit = 5600 },
    }
    local ranked = Triage.rank(entries, 2)
    -- Self at 25% should be first (lower effective_hp)
    all_ok = assert_eq(ranked[1].unit, "me", "S6: self lowest HP first") and all_ok
end

if all_ok then
    print("OK triage_rank")
else
    print("FAIL triage_rank")
end
