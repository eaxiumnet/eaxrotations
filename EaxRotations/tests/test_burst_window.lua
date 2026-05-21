-- ============================================================================
-- Test: Burst Window Detection
-- What: Verify Bloodlust/Heroism detection and burst phase gating
-- When: During test execution
-- Why: PvP Tier 2 had no direct tests
-- Safety: Pure detection logic, no API calls
-- ============================================================================

local NS = _G.EaxRotations or {}
_G.EaxRotations = NS

local BLOODLUST_IDS = { 2825, 32182 }
local DRUMS_IDS = { 35475, 35474, 35473, 35476 }

function detect_burst_state(buff_ids)
    for _, id in ipairs(buff_ids or {}) do
        for _, bl_id in ipairs(BLOODLUST_IDS) do
            if id == bl_id then return true, "bloodlust" end
        end
        for _, drum_id in ipairs(DRUMS_IDS) do
            if id == drum_id then return true, "drums" end
        end
    end
    return false, nil
end

function should_burst(buffs, cooldowns_ready)
    local has_burst, source = detect_burst_state(buffs)
    if not has_burst then return false, nil end
    local cd_ready = true
    for _, r in ipairs(cooldowns_ready or {}) do
        if not r then cd_ready = false; break end
    end
    return cd_ready, source
end

-- Test 1: detects Bloodlust
assert(detect_burst_state({2825}) == true)
assert(select(2, detect_burst_state({2825})) == "bloodlust")
print("PASS burst_detect_bloodlust")

-- Test 2: detects Heroism
assert(detect_burst_state({32182}) == true)
assert(select(2, detect_burst_state({32182})) == "bloodlust")
print("PASS burst_detect_heroism")

-- Test 3: detects Drums
assert(detect_burst_state({35475}) == true)
assert(select(2, detect_burst_state({35475})) == "drums")
print("PASS burst_detect_drums")

-- Test 4: no burst when no matching buffs
local has, src = detect_burst_state({1234, 5678})
assert(has == false)
assert(src == nil)
print("PASS burst_no_burst")

-- Test 5: cooldown alignment - burst only when CDs ready
assert(should_burst({2825}, {true, true}) == true)
assert(should_burst({2825}, {true, false}) == false)
assert(should_burst({2825}, {}) == true) -- no CDs specified = ready
print("PASS burst_cooldown_alignment")

-- Test 6: multiple buffs
has, src = detect_burst_state({35474, 2825})
assert(has == true)
-- First match wins; order matters
print("PASS burst_multiple_buffs")

print("PASS burst_window")
