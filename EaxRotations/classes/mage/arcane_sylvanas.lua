-- Readability notes:
--   What: Mage Arcane priority list.
--   When: dispatcher runs this playstyle when selected.
--   Why: action rows show what is cast, why it is gated, and when it is allowed.
--   Safety: all rows use shared spell/resource/range/form checks before casting.

-- Decision notes:
--   Playstyle files are ordered priority lists: earlier strategies must be more urgent or more time-sensitive.
--   Matches functions explain when an action is allowed; execute functions only perform the already-gated cast.
--   Role logic follows TBC expectations and avoids post-TBC spells, speculative target swaps, and impossible casts.
--   Enhancement notes (2026-05-13): Added Arcane Blast stack management (maintain 3 stacks), evocation planning,
--   mana gem optimization, Presence of Mind burst, Ice Barrier defensive, and Arcane Missiles filler logic.
local NS = _G.EaxRotations
if not NS then return nil end
local SPELLS = NS.MageSpells or {}

local ARCANE_BLAST_DEBUFF = { 36032, 36033, 36034 }  -- AB debuff: increases mana cost, reduces cast time
local ARCANE_POWER_BUFF = { 12042 }
local PRESENCE_OF_MIND_BUFF = { 12043 }
local ICE_BARRIER_BUFF = { 13032, 13031, 13033 }
local MANA_SHIELD_BUFF = { 27131, 10193, 10192, 10191, 8495, 8494, 1463 }

-- Constants
local AB_STACK_MAX = 3
local LOW_MANA_THRESHOLD = 20      -- Evocation below 20% mana
local AB_STACK_DROP_THRESHOLD = 8  -- Drop AB stacks when mana < 8% to conserve
local MANA_GEM_THRESHOLD = 70      -- Use mana gem when mana < 70% (high AB stacks are mana-intensive)

-- ============================================================================
-- Arcane Blast Stack Management
-- ============================================================================
-- TBC Arcane: Stack AB to 3 for maximum haste, then maintain with refresh casts.
-- Arcane Missiles is used as "filler" to let stacks drop when mana is low or moving.

local function get_ab_stacks(context)
    local me = context.me
    if not me then return 0, 0 end
    local stacks = NS.buff_stacks and NS.buff_stacks(me, ARCANE_BLAST_DEBUFF) or 0
    local remains = NS.buff_remains and NS.buff_remains(me, ARCANE_BLAST_DEBUFF) or 0
    return stacks, remains
end

local function arcane_blast_matches(context, action)
    -- Only cast Arcane Blast if:
    -- 1. We're not moving
    -- 2. Mana is sufficient (or we're in a burst window)
    -- 3. We want to maintain stacks
    if context.is_moving then return false end
    
    local stacks, remains = get_ab_stacks(context)
    local mana_pct = context.mana_pct or 100
    
    -- If mana is critically low, don't stack further
    if mana_pct < AB_STACK_DROP_THRESHOLD then
        return false
    end
    
    -- If we have 3 stacks and they're not about to drop, still cast AB to maintain DPS
    -- The stack refreshes on each cast
    return NS.action_matches(context, action)
end

local function arcane_missiles_matches(context, action)
    -- Arcane Missiles usage:
    -- 1. When moving (AB can't be cast while moving)
    -- 2. When mana is low (AM doesn't add AB stack, conserves mana)
    -- 3. When we want to let AB stacks drop intentionally
    local stacks, remains = get_ab_stacks(context)
    local mana_pct = context.mana_pct or 100
    
    -- Use AM when moving
    if context.is_moving then
        return NS.action_matches(context, action)
    end
    
    -- Use AM when mana is low to avoid stacking AB further
    if mana_pct < 30 and stacks >= 2 then
        return NS.action_matches(context, action)
    end
    
    -- Use AM as filler when not building stacks (stacks < 3 and not in burst)
    if stacks < AB_STACK_MAX and not context.should_burst then
        return NS.action_matches(context, action)
    end
    
    return false
end

local function fire_blast_matches(context, action)
    -- Fire Blast is instant cast - use on cooldown, especially while moving
    if not NS.action_matches(context, action) then return false end
    -- Priority when moving or when AB stacks are maxed (no time to hardcast)
    if context.is_moving then return true end
    local stacks = get_ab_stacks(context)
    if stacks >= AB_STACK_MAX then return true end
    return true
end

-- ============================================================================
-- Evocation Planning
-- ============================================================================
-- Use Evocation at optimal mana thresholds:
-- - Below 20% mana in combat (emergency)
-- - Below 40% mana if next major burn phase is coming soon
-- - Never evocate above 50% mana (wasteful)

local function evocation_matches(context, action)
    if not context.in_combat then return false end
    local mana_pct = context.mana_pct or 100
    -- Emergency: below 20% mana
    if mana_pct < LOW_MANA_THRESHOLD then
        return NS.action_matches(context, action)
    end
    -- Planned: below 40% if we have major cooldowns coming
    if mana_pct < 40 and (context.should_burst or context.bloodlust_active) then
        return NS.action_matches(context, action)
    end
    return false
end

-- ============================================================================
-- Mana Gem Optimization
-- ============================================================================
-- Use mana gem proactively when mana drops below threshold during AB spam.
-- This prevents having to evocate mid-fight.

local MANA_GEM_SPELLS = { 27103, 22797, 22796, 22795, 22794 }  -- Mana Emerald, Ruby, etc.

local function mana_gem_matches(context, action)
    local mana_pct = context.mana_pct or 100
    if mana_pct > MANA_GEM_THRESHOLD then return false end
    -- Only use gem if we have AB stacks (meaning we're in a mana-intensive phase)
    local stacks = get_ab_stacks(context)
    if stacks < 1 then return false end
    return NS.action_matches(context, action)
end

-- ============================================================================
-- Presence of Mind Burst Window
-- ============================================================================
-- PoM makes next spell instant. Use it for:
-- - Arcane Blast (to maintain stacks during movement)
-- - Pyroblast if available (not in TBC)
-- - Fire Blast if no better option

local function presence_of_mind_matches(context, action)
    if not NS.action_matches(context, action) then return false end
    -- Only use PoM in burst windows or when moving
    if context.should_burst or context.is_moving then
        return true
    end
    return false
end

-- ============================================================================
-- Arcane Power Burst Sync
-- ============================================================================
-- Arcane Power (+30% spell damage, -30% threat) should be synced with:
-- - High AB stacks (3)
-- - Mana gem available
-- - Bloodlust/drums active (if possible)

local function arcane_power_matches(context, action)
    if not NS.action_matches(context, action) then return false end
    -- Only cast AP when we have sufficient mana for the full duration
    local mana_pct = context.mana_pct or 100
    if mana_pct < 40 then return false end
    -- Prefer to cast AP when AB stacks are already high
    local stacks = get_ab_stacks(context)
    if stacks >= 2 then return true end
    -- Or during burst windows
    return context.should_burst or false
end

local ACTIONS = {
    { name = "IceBarrier", spell = SPELLS.IceBarrier, target = "self", kind = "buff", buff = ICE_BARRIER_BUFF, max_hp = 60, requires_target = false },
    { name = "ManaShield", spell = SPELLS.ManaShield, target = "self", kind = "buff", buff = MANA_SHIELD_BUFF, max_hp = 50, requires_target = false },
    { name = "PresenceOfMind", spell = SPELLS.PresenceOfMind, target = "self", combat = true, cooldown = 180, requires_target = false, setting = "use_cooldowns", matches = presence_of_mind_matches },
    { name = "ArcanePower", spell = SPELLS.ArcanePower, target = "self", combat = true, cooldown = 180, requires_target = false, setting = "use_cooldowns", matches = arcane_power_matches },
    { name = "Evocation", spell = SPELLS.Evocation, target = "self", combat = true, requires_target = false, matches = evocation_matches },
    { name = "ManaGem", spell = SPELLS.ManaGem or MANA_GEM_SPELLS, target = "self", requires_target = false, matches = mana_gem_matches },
    { name = "ArcaneBlast", spell = SPELLS.ArcaneBlast, not_moving = true, matches = arcane_blast_matches },
    { name = "FireBlast", spell = SPELLS.FireBlast, cooldown = 8, matches = fire_blast_matches },
    { name = "ArcaneMissiles", spell = SPELLS.ArcaneMissiles, not_moving = true, matches = arcane_missiles_matches },
}

local strategies = {}
for i = 1, #ACTIONS do
    local action = ACTIONS[i]
    strategies[#strategies + 1] = {
        name = action.name,
        matches = function(context)
            if action.matches then
                return action.matches(context, action)
            end
            return NS.action_matches(context, action)
        end,
        execute = function(context) return NS.action_execute(context, action, "[ARCANE]") end,
    }
end

NS.rotation_registry:register("arcane", strategies, { get_state = function(context) return context end })
NS.log("Mage arcane rotation registered (enhanced: AB stack management, evocation planning, mana gem optimization, PoM burst)")
return strategies
