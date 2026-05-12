-- ============================================================================
-- Shared Helper: Performance Benchmarks
-- ============================================================================
-- Readability notes:
--   What: expected DPS/HPS values for class/spec/gear tier comparisons.
--   When: post-combat performance analysis.
--   Why: helps players understand how they're performing vs expectations.
--   Safety: static data tables, no runtime API dependency.

local M = {}
local _G = _G
local NS = _G.EaxRotations

-- Expected DPS by class/spec/gear tier (approximate TBC values)
local BENCHMARKS = {
    warrior = {
        arms = { preraid = 700, t4 = 900, t5 = 1100, t6 = 1400, sunwell = 1800 },
        fury = { preraid = 800, t4 = 1000, t5 = 1200, t6 = 1500, sunwell = 1900 },
        protection = { preraid = 300, t4 = 400, t5 = 500, t6 = 600, sunwell = 700 },
    },
    rogue = {
        assassination = { preraid = 750, t4 = 950, t5 = 1150, t6 = 1450, sunwell = 1850 },
        combat = { preraid = 800, t4 = 1000, t5 = 1200, t6 = 1500, sunwell = 1900 },
    },
    hunter = {
        beast_mastery = { preraid = 900, t4 = 1100, t5 = 1300, t6 = 1600, sunwell = 2000 },
        marksmanship = { preraid = 850, t4 = 1050, t5 = 1250, t6 = 1550, sunwell = 1950 },
        survival = { preraid = 800, t4 = 1000, t5 = 1200, t6 = 1500, sunwell = 1900 },
    },
    mage = {
        arcane = { preraid = 900, t4 = 1100, t5 = 1350, t6 = 1700, sunwell = 2100 },
        fire = { preraid = 850, t4 = 1050, t5 = 1250, t6 = 1550, sunwell = 1950 },
        frost = { preraid = 750, t4 = 950, t5 = 1150, t6 = 1450, sunwell = 1850 },
    },
    warlock = {
        affliction = { preraid = 800, t4 = 1000, t5 = 1200, t6 = 1500, sunwell = 1900 },
        demonology = { preraid = 750, t4 = 950, t5 = 1150, t6 = 1450, sunwell = 1850 },
        destruction = { preraid = 850, t4 = 1050, t5 = 1250, t6 = 1550, sunwell = 1950 },
    },
    priest = {
        shadow = { preraid = 700, t4 = 900, t5 = 1100, t6 = 1400, sunwell = 1800 },
    },
    shaman = {
        elemental = { preraid = 800, t4 = 1000, t5 = 1200, t6 = 1500, sunwell = 1900 },
        enhancement = { preraid = 750, t4 = 950, t5 = 1150, t6 = 1450, sunwell = 1850 },
    },
    druid = {
        balance = { preraid = 750, t4 = 950, t5 = 1150, t6 = 1450, sunwell = 1850 },
        feral = { preraid = 700, t4 = 900, t5 = 1100, t6 = 1400, sunwell = 1800 },
    },
    paladin = {
        retribution = { preraid = 650, t4 = 850, t5 = 1050, t6 = 1350, sunwell = 1750 },
        protection = { preraid = 300, t4 = 400, t5 = 500, t6 = 600, sunwell = 700 },
    },
}

-- Get expected DPS for class/spec/tier
function M.get_expected_dps(class, spec, gear_tier)
    if not BENCHMARKS[class] then return nil end
    if not BENCHMARKS[class][spec] then return nil end
    return BENCHMARKS[class][spec][gear_tier or "preraid"]
end

-- Compare actual vs expected performance
function M.compare(class, spec, gear_tier, actual_dps)
    local expected = M.get_expected_dps(class, spec, gear_tier)
    if not expected then
        return { expected = 0, actual = actual_dps, percent = 0, status = "unknown" }
    end
    
    local ratio = actual_dps / expected
    local status = "poor"
    if ratio >= 0.95 then status = "excellent"
    elseif ratio >= 0.85 then status = "good"
    elseif ratio >= 0.70 then status = "average"
    end
    
    return {
        expected = expected,
        actual = actual_dps,
        percent = ratio * 100,
        status = status,
    }
end

if NS then
    NS.Benchmarks = M
end

return M
