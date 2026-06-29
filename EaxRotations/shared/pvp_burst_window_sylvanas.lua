-- pvp_burst_window_sylvanas.lua -- PvP burst-window scoring component (used by burst_logic)
-- WHAT:  score current target's burst-vulnerability for PvP offensive cooldown use
-- WHEN:  PvP arenas + rated BGs
-- WHY:   centralizes tactical scoring so specs read a single signal
-- SAFETY: is_in_combat + is_pvp gate; nil-guards on enemy auras

-- Shared Helper: PvP Burst Window Scoring
-- ============================================================================
local M = {}
local _G = _G
local NS = _G.EaxRotations

-- Static reuse buffer for score reasons (avoids per-frame allocation; AGENTS.md Pattern 4)
local REASONS_BUF = { n = 0 }

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
    45438,  -- Ice Block
    642,    -- Divine Shield
    1022,   -- Blessing of Protection
    22812,  -- Barkskin
    33206,  -- Pain Suppression
}

-- Offensive buffs that indicate burst
local OFFENSIVE_BUFFS = {
    1719,   -- Recklessness
    12292,  -- Death Wish (TBC) / Sweeping Strikes (Vanilla — harmless false-positive)
    13750,  -- Adrenaline Rush
    19574,  -- Bestial Wrath
    2825,   -- Bloodlust
    32182,  -- Heroism
    12472,  -- Icy Veins
    12042,  -- Arcane Power
    31884,  -- Avenging Wrath
    10060,  -- Power Infusion
    30823,  -- Shamanistic Rage
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
    
    for _, buff_id in ipairs(DEFENSIVE_BUFFS) do
        if NS.has_buff(context.target, buff_id) then
            return true
        end
    end
    return false
end

-- DRTracker module was deleted; stub returns false until DR tracking is reimplemented
local function target_is_dr_immune(context)
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
        for _, buff_id in ipairs(OFFENSIVE_BUFFS) do
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

-- EnemyCDTracker module was deleted; stub returns "unknown" until enemy CD tracking is reimplemented
local function enemy_defensive_status(context)
    return "unknown", 0
end

-- Calculate burst score (0-100 scale)
function M.score(context)
    if not context then return 0 end
    
    local score = 0
    REASONS_BUF.n = 0
    
    local target_hp = get_target_hp_pct(context)
    local player_hp = get_player_hp_pct(context)
    
    -- Target HP factor (full bonus at < 35%)
    if target_hp < 35 then
        local hp_factor = (35 - target_hp) / 35  -- 0.0 to 1.0
        local hp_bonus = SCORE.TARGET_LOW_HP * hp_factor
        score = score + hp_bonus
        REASONS_BUF.n = REASONS_BUF.n + 1; REASONS_BUF[REASONS_BUF.n] = "target low HP"
    end
    
    -- Target defensive status
    local def_status = enemy_defensive_status(context)
    if def_status == "down" then
        score = score + SCORE.TARGET_NO_DEFENSIVE
        REASONS_BUF.n = REASONS_BUF.n + 1; REASONS_BUF[REASONS_BUF.n] = "enemy defensive down"
    end
    
    -- Target immune checks
    if target_has_defensive(context) then
        score = score + SCORE.PENALTY_BUBBLE
        REASONS_BUF.n = REASONS_BUF.n + 1; REASONS_BUF[REASONS_BUF.n] = "target has defensive buff"
    end
    
    -- Target casting (vulnerable)
    if is_target_casting(context) then
        score = score + SCORE.TARGET_CASTING
        REASONS_BUF.n = REASONS_BUF.n + 1; REASONS_BUF[REASONS_BUF.n] = "target casting"
    end
    
    -- Target is healer (check via ArenaPriority)
    if NS and NS.ArenaPriority and NS.ArenaPriority.is_healer then
        if context.target and NS.ArenaPriority.is_healer(context.target) then
            score = score + SCORE.TARGET_HEALER
            REASONS_BUF.n = REASONS_BUF.n + 1; REASONS_BUF[REASONS_BUF.n] = "target is healer"
        end
    end
    
    -- Player health safety
    if player_hp > 50 then
        score = score + SCORE.HEALTH_SAFE
        REASONS_BUF.n = REASONS_BUF.n + 1; REASONS_BUF[REASONS_BUF.n] = "player HP safe"
    else
        score = score + SCORE.PENALTY_LOW_HP
        REASONS_BUF.n = REASONS_BUF.n + 1; REASONS_BUF[REASONS_BUF.n] = "player HP low"
    end
    
    -- Offensive CDs ready
    local has_off, off_count = has_offensive_ready(context)
    if has_off then
        score = score + SCORE.OFFENSIVE_READY
        REASONS_BUF.n = REASONS_BUF.n + 1; REASONS_BUF[REASONS_BUF.n] = "offensive CDs available"
    else
        score = score + SCORE.PENALTY_NO_OFFENSIVE
        REASONS_BUF.n = REASONS_BUF.n + 1; REASONS_BUF[REASONS_BUF.n] = "no offensive CDs ready"
    end
    
    -- DR immunity check
    if target_is_dr_immune(context) then
        score = score + SCORE.PENALTY_DR_IMMUNE
        REASONS_BUF.n = REASONS_BUF.n + 1; REASONS_BUF[REASONS_BUF.n] = "target DR immune"
    end
    
    -- Clamp score to 0-100
    score = math.max(0, math.min(100, score))
    
    -- Store reasons snapshot on context for debugging (consumed by M.reason).
    -- REASONS_BUF is a shared static buffer (Pattern 4); snapshot it so a later
    -- score() call cannot overwrite the reasons a caller is still inspecting.
    -- Hot path: the accumulation above already uses the static buffer (no
    -- table.insert); this snapshot is a tiny array allocated only when n>0.
    if context then
        if REASONS_BUF.n > 0 then
            local snap = {}
            for i = 1, REASONS_BUF.n do snap[i] = REASONS_BUF[i] end
            context.burst_score_reasons = snap
        else
            context.burst_score_reasons = nil
        end
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
