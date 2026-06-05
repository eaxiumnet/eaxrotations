-- Shared Helper: PvP Burst Window Scoring
-- ============================================================================
local M = {}
local _G = _G
local NS = _G.EaxRotations

-- Scoring constants
local SCORE = {
    TARGET_LOW_HP = 30,          -- Base for 0% HP target
    TARGET_NO_DEFENSIVE = 20,    -- When enemy defensives are down
    TARGET_CASTING = 15,         -- Vulnerable while casting
    TARGET_HEALER = 10,          -- Bonus for healer kill target
    OFFENSIVE_READY = 15,        -- Our offensive CDs available
    HEALTH_SAFE = 10,            -- We have safe HP
    
    PENALTY_IMMUNE = -50,        -- Target immune to damage
    PENALTY_BUBBLE = -40,        -- Divine Shield/Ice Block
    PENALTY_LOW_HP = -30,        -- We are low HP
    PENALTY_DR_IMMUNE = -20,     -- Target DR immune
    PENALTY_NO_OFFENSIVE = -15,  -- None of our offensive CDs ready
}

-- Defensive buffs that prevent burst
local DEFENSIVE_BUFFS = {
    [11958] = true,  -- Ice Block
    [642] = true,    -- Divine Shield
    [1022] = true,   -- Blessing of Protection
    [22812] = true,  -- Barkskin
    [33206] = true,  -- Pain Suppression
}

-- Offensive buffs that indicate burst
local OFFENSIVE_BUFFS = {
    [1719] = true,   -- Recklessness
    [12292] = true,  -- Death Wish (TBC) / Sweeping Strikes (Vanilla — harmless false-positive)
    [13750] = true,  -- Adrenaline Rush
    [19574] = true,  -- Bestial Wrath
    [2825] = true,   -- Bloodlust
    [32182] = true,  -- Heroism
    [12472] = true,  -- Icy Veins
    [12042] = true,  -- Arcane Power
    [31884] = true,  -- Avenging Wrath
    [10060] = true,  -- Power Infusion
    [30823] = true,  -- Shamanistic Rage
}

-- Get player HP safely
local function get_player_hp_pct(context)
    if not context then return 100 end
    if context.player_hp then return context.player_hp end
    if context.me and NS and NS.unit_health_pct then
        return NS.unit_health_pct(context.me) or 100
    end
    return 100
end

-- Get target HP safely
local function get_target_hp_pct(context)
    if not context then return 100 end
    if context.target_hp then return context.target_hp end
    if context.target and NS and NS.unit_health_pct then
        return NS.unit_health_pct(context.target) or 100
    end
    return 100
end

-- Check if target is casting
local function is_target_casting(context)
    if not context or not context.target then return false end
    if NS and NS.is_casting then
        return NS.is_casting(context.target) or false
    end
    local ok, casting = pcall(function() return context.target:is_casting() end)
    return ok and casting or false
end

-- Check if target has defensive buff
local function target_has_defensive(context)
    if not context or not context.target then return false end
    if not NS or not NS.has_buff then return false end
    
    for buff_id, _ in pairs(DEFENSIVE_BUFFS) do
        if NS.has_buff(context.target, buff_id) then
            return true
        end
    end
    return false
end

-- Check if target is immune via DR
local function target_is_dr_immune(context)
    if not NS or not NS.DRTracker then return false end
    if not context or not context.target then return false end
    
    -- Check stun immunity (primary setup CC)
    if NS.DRTracker.is_dr_immune then
        local cat_stun = NS.DRTracker.CATEGORIES and NS.DRTracker.CATEGORIES.STUN or "stun"
        if NS.DRTracker.is_dr_immune(context.target, cat_stun) then
            return true
        end
    end
    
    return false
end

-- Check if we have offensive CDs ready
local function has_offensive_ready(context)
    if not NS then return false end
    
    local offensive_ready = 0
    local total_offensive = 0
    
    -- Check specific offensive spells from context or settings
    -- This is simplified - in practice you'd check class-specific spells
    
    -- Check if we have any offensive buffs active
    if context and context.me and NS.has_buff then
        for buff_id, _ in pairs(OFFENSIVE_BUFFS) do
            if NS.has_buff(context.me, buff_id) then
                offensive_ready = offensive_ready + 1
            end
            total_offensive = total_offensive + 1
        end
    end
    
    -- If we have active offensives, that's good
    if offensive_ready > 0 then
        return true, offensive_ready
    end
    
    -- Check if our major cooldowns are ready via spell_ready
    -- This requires knowing class-specific spells
    return false, 0
end

-- Check enemy defensive CD status
local function enemy_defensive_status(context)
    if not NS or not NS.EnemyCDTracker then 
        return "unknown", 0 
    end
    if not context or not context.target then 
        return "unknown", 0 
    end
    
    local has_def = NS.EnemyCDTracker.has_defensive_available(context.target)
    if has_def then
        return "ready", 1
    end
    
    return "down", 0
end

-- Calculate burst score (0-100 scale)
function M.score(context)
    if not context then return 0 end
    
    local score = 0
    local reasons = {}
    
    local target_hp = get_target_hp_pct(context)
    local player_hp = get_player_hp_pct(context)
    
    -- Target HP factor (full bonus at < 35%)
    if target_hp < 35 then
        local hp_factor = (35 - target_hp) / 35  -- 0.0 to 1.0
        local hp_bonus = SCORE.TARGET_LOW_HP * hp_factor
        score = score + hp_bonus
        table.insert(reasons, "target low HP")
    end
    
    -- Target defensive status
    local def_status = enemy_defensive_status(context)
    if def_status == "down" then
        score = score + SCORE.TARGET_NO_DEFENSIVE
        table.insert(reasons, "enemy defensive down")
    end
    
    -- Target immune checks
    if target_has_defensive(context) then
        score = score + SCORE.PENALTY_BUBBLE
        table.insert(reasons, "target has defensive buff")
    end
    
    -- Target casting (vulnerable)
    if is_target_casting(context) then
        score = score + SCORE.TARGET_CASTING
        table.insert(reasons, "target casting")
    end
    
    -- Target is healer (check via ArenaPriority)
    if NS and NS.ArenaPriority and NS.ArenaPriority.is_healer then
        if context.target and NS.ArenaPriority.is_healer(context.target) then
            score = score + SCORE.TARGET_HEALER
            table.insert(reasons, "target is healer")
        end
    end
    
    -- Player health safety
    if player_hp > 50 then
        score = score + SCORE.HEALTH_SAFE
        table.insert(reasons, "player HP safe")
    else
        score = score + SCORE.PENALTY_LOW_HP
        table.insert(reasons, "player HP low")
    end
    
    -- Offensive CDs ready
    local has_off, off_count = has_offensive_ready(context)
    if has_off then
        score = score + SCORE.OFFENSIVE_READY
        table.insert(reasons, "offensive CDs available")
    else
        score = score + SCORE.PENALTY_NO_OFFENSIVE
        table.insert(reasons, "no offensive CDs ready")
    end
    
    -- DR immunity check
    if target_is_dr_immune(context) then
        score = score + SCORE.PENALTY_DR_IMMUNE
        table.insert(reasons, "target DR immune")
    end
    
    -- Clamp score to 0-100
    score = math.max(0, math.min(100, score))
    
    -- Store reasons on context for debugging
    if context then
        context.burst_score_reasons = reasons
    end
    
    return score
end

-- Check if we should burst
function M.should_burst(context, threshold)
    threshold = threshold or 70  -- Default 70% threshold
    local score = M.score(context)
    return score >= threshold, score
end

-- Get human-readable reason for the score
function M.reason(context)
    local reasons = context and context.burst_score_reasons
    if not reasons or #reasons == 0 then
        return "no burst factors detected"
    end
    
    return table.concat(reasons, ", ")
end

-- Quick check: is this a good burst window?
-- Returns detailed info
function M.analyze(context)
    local score = M.score(context)
    local should_burst = M.should_burst(context)
    local reason_str = M.reason(context)
    
    return {
        score = score,
        should_burst = should_burst,
        reason = reason_str,
        target_hp = get_target_hp_pct(context),
        player_hp = get_player_hp_pct(context),
    }
end

if NS then
    NS.PvPBurstWindow = M
end

return M
