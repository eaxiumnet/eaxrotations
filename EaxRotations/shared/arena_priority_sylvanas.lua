-- ============================================================================
-- Shared Helper: Arena Priority System
-- ============================================================================
-- Readability notes:
--   What: arena target selection scoring - determines kill target and CC target.
--   When: arena PvP for intelligent target prioritization.
--   Why: proper target selection dramatically improves arena effectiveness.
--   Safety: uses throttled enemy scans, nil-guards all unit access.

local M = {}
local _G = _G
local NS = _G.EaxRotations

local EMPTY = {}

-- Scoring weights (tune these based on testing)
local WEIGHTS = {
    LOW_HP = 100,           -- Base bonus for low HP
    HEALER_CLASS = 60,      -- Bonus for healer classes
    CLOTH_ARMOR = 30,       -- Bonus for cloth wearers
    NO_DEFENSIVE = 40,      -- Bonus when no defensive CD available
    TARGET_CASTING = 25,    -- Bonus when target is casting
    CURRENT_TARGET = 15,    -- Small bonus for current target (stickiness)
    DR_PENALTY = -30,       -- Penalty for low DR (CC immune soon)
    ALREADY_CC = -40,       -- Penalty for already CC'd target
    IMMUNE = -100,          -- Penalty for immune targets
    HAS_DEFENSIVE = -20,    -- Small penalty for targets with defensives ready
}

-- Class classifications
local HEALER_CLASSES = {
    PRIEST = true,
    PALADIN = true,
    SHAMAN = true,
    DRUID = true,
}

local CLOTH_CLASSES = {
    MAGE = true,
    WARLOCK = true,
    PRIEST = true,
}

-- Static result buffer to avoid allocations
local result_buffer = {
    kill_target = nil,
    cc_target = nil,
    all_enemies = { n = 0 },
}

-- Get unit class safely
local function get_unit_class(unit)
    if not unit then return nil end
    local ok, class = pcall(function() return unit:get_class() end)
    if ok and class then return class end
    return nil
end

-- Get unit HP percentage safely
local function get_unit_hp_pct(unit)
    if not unit then return 100 end
    if NS and NS.unit_health_pct then
        return NS.unit_health_pct(unit) or 100
    end
    -- Fallback
    local ok, hp = pcall(function() return unit:get_health_percentage() end)
    if ok and hp then return hp end
    return 100
end

-- Check if unit is casting
local function is_unit_casting(unit)
    if not unit then return false end
    if NS and NS.is_casting then
        return NS.is_casting(unit) or false
    end
    local ok, casting = pcall(function() return unit:is_casting() end)
    return ok and casting or false
end

-- Check if unit is a healer class
local function is_healer_class(class)
    if not class then return false end
    return HEALER_CLASSES[class] or false
end

-- Check if unit is cloth armor
local function is_cloth_class(class)
    if not class then return false end
    return CLOTH_CLASSES[class] or false
end

-- Get enemies in arena range
function M.get_arena_enemies(context)
    if not NS then return EMPTY end
    
    -- Use NS.GetEnemiesInRange if available (40 yard arena range)
    if NS.GetEnemiesInRange then
        local enemies = NS.GetEnemiesInRange(40)
        return enemies or EMPTY
    end
    
    -- Fallback: return context enemies if available
    if context and context.enemies then
        return context.enemies
    end
    
    return EMPTY
end

-- Score a unit as kill target priority
-- Higher score = better kill target
function M.score_kill_target(unit, context)
    if not unit then return -999 end
    
    local score = 0
    local class = get_unit_class(unit)
    local hp_pct = get_unit_hp_pct(unit)
    local is_current = (context and context.target == unit)
    
    -- Low HP bonus (100 at 0 HP, 0 at 100 HP)
    local hp_bonus = WEIGHTS.LOW_HP * (1 - hp_pct / 100)
    score = score + hp_bonus
    
    -- Healer class bonus
    if is_healer_class(class) then
        score = score + WEIGHTS.HEALER_CLASS
    end
    
    -- Cloth armor bonus (squishy targets)
    if is_cloth_class(class) then
        score = score + WEIGHTS.CLOTH_ARMOR
    end
    
    -- Defensive cooldown check
    if NS and NS.EnemyCDTracker then
        local has_def = NS.EnemyCDTracker.has_defensive_available(unit)
        if has_def then
            score = score + WEIGHTS.HAS_DEFENSIVE
        else
            score = score + WEIGHTS.NO_DEFENSIVE
        end
    end
    
    -- Casting bonus (vulnerable)
    if is_unit_casting(unit) then
        score = score + WEIGHTS.TARGET_CASTING
    end
    
    -- Current target stickiness
    if is_current then
        score = score + WEIGHTS.CURRENT_TARGET
    end
    
    return score
end

-- Score a unit as CC target priority
-- Higher score = better CC target
function M.score_cc_target(unit, context)
    if not unit then return -999 end
    
    local score = 0
    local class = get_unit_class(unit)
    local hp_pct = get_unit_hp_pct(unit)
    
    -- Healers are high priority CC targets
    if is_healer_class(class) then
        score = score + WEIGHTS.HEALER_CLASS
    end
    
    -- Check DR status if available
    if NS and NS.DRTracker then
        -- Prefer targets with no DRs applied yet
        local dr_stun = NS.DRTracker.get_dr_count(unit, NS.DRTracker.CATEGORIES and NS.DRTracker.CATEGORIES.STUN or "stun")
        local dr_fear = NS.DRTracker.get_dr_count(unit, NS.DRTracker.CATEGORIES and NS.DRTracker.CATEGORIES.FEAR or "fear")
        local dr_incap = NS.DRTracker.get_dr_count(unit, NS.DRTracker.CATEGORIES and NS.DRTracker.CATEGORIES.INCAPACITATE or "incapacitate")
        
        -- Average DR across categories
        local avg_dr = (dr_stun + dr_fear + dr_incap) / 3
        if avg_dr >= 2 then
            score = score + WEIGHTS.DR_PENALTY
        elseif avg_dr >= 3 then
            score = score + WEIGHTS.IMMUNE
        end
        
        -- Check if immune to stuns
        if NS.DRTracker.is_dr_immune and NS.DRTracker.is_dr_immune(unit, NS.DRTracker.CATEGORIES and NS.DRTracker.CATEGORIES.STUN or "stun") then
            score = score + WEIGHTS.IMMUNE
        end
    end
    
    -- Already CC'd penalty
    if NS and NS.has_cc then
        -- Check for common CC debuffs
        if NS.has_cc(unit) then
            score = score + WEIGHTS.ALREADY_CC
        end
    end
    
    return score
end

-- Get priority targets
-- Returns: {kill_target, cc_target, all_enemies}
function M.get_priority_targets(context)
    -- Clear result buffer
    result_buffer.kill_target = nil
    result_buffer.cc_target = nil
    result_buffer.all_enemies.n = 0
    
    -- Get enemies
    local enemies = M.get_arena_enemies(context)
    if not enemies or #enemies == 0 then
        return result_buffer
    end
    
    -- Populate all_enemies
    for i = 1, #enemies do
        result_buffer.all_enemies.n = result_buffer.all_enemies.n + 1
        result_buffer.all_enemies[result_buffer.all_enemies.n] = enemies[i]
    end
    
    -- Find best kill target
    local best_kill_score = -999
    local best_kill_target = nil
    
    -- Find best CC target
    local best_cc_score = -999
    local best_cc_target = nil
    
    for i = 1, result_buffer.all_enemies.n do
        local enemy = result_buffer.all_enemies[i]
        if enemy then
            -- Score for kill
            local kill_score = M.score_kill_target(enemy, context)
            if kill_score > best_kill_score then
                best_kill_score = kill_score
                best_kill_target = enemy
            end
            
            -- Score for CC
            local cc_score = M.score_cc_target(enemy, context)
            if cc_score > best_cc_score then
                best_cc_score = cc_score
                best_cc_target = enemy
            end
        end
    end
    
    result_buffer.kill_target = best_kill_target
    result_buffer.cc_target = best_cc_target
    
    return result_buffer
end

-- Quick check: is unit a healer?
function M.is_healer(unit)
    local class = get_unit_class(unit)
    return is_healer_class(class)
end

-- Quick check: should we switch targets?
-- Returns true if there's a significantly better kill target than current
function M.should_switch_target(context, threshold)
    threshold = threshold or 30  -- Default 30 point difference
    
    local priorities = M.get_priority_targets(context)
    if not priorities.kill_target then return false end
    if not context or not context.target then return true end
    
    local current_score = M.score_kill_target(context.target, context)
    local best_score = M.score_kill_target(priorities.kill_target, context)
    
    -- Only switch if significantly better
    return (best_score - current_score) > threshold
end

-- Export categories for other modules
if NS then
    NS.ArenaPriority = M
end

return M
