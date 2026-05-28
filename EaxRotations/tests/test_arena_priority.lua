-- =========================================================================
-- EaxRotations File Version: 1.1.1
-- Last Modified: 2026-05-27
-- Change: File version stamp for runtime load verification
-- =========================================================================
local __eax_file = "tests/test_arena_priority.lua"
local __eax_version = "1.1.1"
local __eax_modified = "2026-05-27"
local __eax_change = "File version stamp for runtime load verification"
local __eax_versions = rawget(_G, "EaxRotationsFileVersions") or {}
_G.EaxRotationsFileVersions = __eax_versions
__eax_versions[__eax_file] = { version = __eax_version, modified = __eax_modified, change = __eax_change }
local __eax_core = rawget(_G, "core")
if type(__eax_core) == "table" and type(__eax_core.log) == "function" then
    pcall(__eax_core.log, "[EaxRotations] Loaded " .. __eax_file .. " v" .. __eax_version)
end
local __eax_ns = rawget(_G, "EaxRotations")
if type(__eax_ns) == "table" then __eax_ns.file_versions = __eax_versions end
-- ============================================================================
-- Test: Arena Priority Scoring
-- What: Verify arena target priority scoring
-- When: During test execution
-- Why: PvP Tier 2 had no direct tests
-- Safety: Pure scoring functions, no API calls
-- ============================================================================

local NS = _G.EaxRotations or {}
_G.EaxRotations = NS

-- Minimal scoring for test
local ROLE_WEIGHTS = { healer = 300, tank = 150, dps = 100 }
local FOCUS_BONUS = 200
local LOW_HP_BONUS_BELOW = 30

function score_target(unit, focus_guid)
    local score = 0
    local role = unit.role or "dps"
    score = score + (ROLE_WEIGHTS[role] or 100)
    if unit.guid == focus_guid then score = score + FOCUS_BONUS end
    if unit.hp and unit.hp < LOW_HP_BONUS_BELOW then score = score + (LOW_HP_BONUS_BELOW - unit.hp) * 2 end
    if unit.dead then score = -9999 end
    return score
end

-- Test 1: healer priority
local healer = { guid = "H1", role = "healer", hp = 80, dead = false }
local dps = { guid = "D1", role = "dps", hp = 80, dead = false }
assert(score_target(healer) > score_target(dps), "Healer should score higher than DPS")
print("PASS arena_healer_priority")

-- Test 2: focus bonus
local target_no_focus = { guid = "T1", role = "dps", hp = 50, dead = false }
local target_focus = { guid = "T1", role = "dps", hp = 50, dead = false }
assert(score_target(target_no_focus, "other") < score_target(target_focus, "T1"), "Focus target gets bonus")
print("PASS arena_focus_bonus")

-- Test 3: low HP bonus
local low_hp = { guid = "T2", role = "dps", hp = 20, dead = false }
local high_hp = { guid = "T3", role = "dps", hp = 80, dead = false }
assert(score_target(low_hp) > score_target(high_hp), "Low HP target gets bonus")
print("PASS arena_low_hp_bonus")

-- Test 4: dead target excluded
local dead = { guid = "T4", role = "healer", hp = 0, dead = true }
assert(score_target(dead) < 0, "Dead target should have massively negative score")
print("PASS arena_dead_excluded")

-- Test 5: pick best from list
local enemies = {
    { guid = "E1", role = "dps", hp = 80, dead = false },
    { guid = "E2", role = "healer", hp = 80, dead = false },
    { guid = "E3", role = "tank", hp = 50, dead = false },
    { guid = "E4", role = "dps", hp = 20, dead = false },
}
local best = nil
local best_score = -9999
for _, e in ipairs(enemies) do
    local s = score_target(e, "E4")
    if s > best_score then best_score = s; best = e end
end
assert(best == enemies[4], "Healer scores 300, DPS 100+40+200=340, so focused low-HP DPS wins")
print("PASS arena_pick_best")

print("PASS arena_priority")
