-- Readability notes:
--   What: Rogue Combat priority list.
--   When: dispatcher runs this playstyle when selected.
--   Why: action rows show what is cast, why it is gated, and when it is allowed.
--   Safety: all rows use shared spell/resource/range/form checks before casting.

-- Decision notes:
--   Playstyle files are ordered priority lists: earlier strategies must be more urgent or more time-sensitive.
--   Matches functions explain when an action is allowed; execute functions only perform the already-gated cast.
--   Role logic follows TBC expectations and avoids post-TBC spells, speculative target swaps, and impossible casts.
--   Enhancement notes (2026-05-13): Added energy tick optimization (pool before ticks, spend after),
--   Blade Flurry + Adrenaline Rush synchronization, and improved Slice and Dice/Rupture cycle timing.
local NS = _G.EaxRotations
if not NS then return nil end
local SPELLS = NS.RogueSpells or {}

local SND_BUFF = { 6774, 5171 }
local RUPTURE_DEBUFF = { 26867, 11275, 11274, 11273, 8640, 8639, 1943 }

-- Energy tick constants
local ENERGY_TICK = 2.0           -- Energy regenerates every 2 seconds
local ENERGY_PER_TICK = 20        -- 20 energy per tick (before haste)
local ENERGY_CAP = 100            -- Maximum energy
local SND_REFRESH_WINDOW = 3      -- Refresh Slice and Dice when <= 3s remains
local RUPTURE_REFRESH_WINDOW = 3  -- Refresh Rupture when <= 3s remains

-- ============================================================================
-- Energy Tick Optimization
-- ============================================================================
-- TBC Combat Rogue: Pool energy before ticks to avoid capping,
-- then spend efficiently after ticks land.

local _last_energy = 0
local _last_tick_time = 0

local function get_next_tick_in(energy)
    -- Estimate time until next energy tick based on energy pattern
    -- In TBC, energy ticks every 2.0s (unaffected by haste)
    local now = NS.time_now and NS.time_now() or 0
    local energy_gained = energy - _last_energy
    
    if energy_gained > 0 then
        -- Energy just ticked - next tick in ~2.0s
        _last_tick_time = now
        _last_energy = energy
        return ENERGY_TICK
    end
    
    -- Energy hasn't changed recently, estimate based on last tick
    local time_since_tick = now - _last_tick_time
    if time_since_tick < 0 or time_since_tick > ENERGY_TICK * 2 then
        -- Stale data, reset
        _last_tick_time = now
        return ENERGY_TICK
    end
    
    return math.max(0, ENERGY_TICK - time_since_tick)
end

local function should_pool_energy(context)
    -- Pool energy if next tick is imminent (within 0.5s) and we won't cap
    local energy = context.energy or 0
    local next_tick_in = get_next_tick_in(energy)
    if next_tick_in <= 0.5 then
        local projected_energy = energy + ENERGY_PER_TICK
        if projected_energy <= ENERGY_CAP then
            return true  -- Wait for tick before spending
        end
    end
    return false
end

local function should_spend_energy(context, cost)
    -- Spend energy if we're about to cap or if next tick is far away
    local energy = context.energy or 0
    local next_tick_in = get_next_tick_in(energy)
    local projected_energy = energy + ENERGY_PER_TICK
    
    -- Cap prevention: if next tick would put us over cap, spend now
    if projected_energy > ENERGY_CAP then
        return true
    end
    
    -- Tick is far away (>1s), safe to spend
    if next_tick_in > 1.0 then
        return true
    end
    
    -- Just ticked (<0.3s ago), spend now while energy is fresh
    if next_tick_in > ENERGY_TICK - 0.3 then
        return true
    end
    
    return false
end

-- ============================================================================
-- Blade Flurry + Adrenaline Rush Sync
-- ============================================================================
-- TBC Combat: Stack Blade Flurry and Adrenaline Rush for maximum burst.
-- BF (120s CD, 15s duration) + AR (300s CD, 15s duration).
-- When both are ready, cast AR first then BF immediately after.

local function adrenaline_rush_matches(context, action)
    if not NS.action_matches(context, action) then return false end
    -- Sync with Blade Flurry if both are ready
    local bf_ready = NS.spell_ready(SPELLS.BladeFlurry, context.me, { skip_range = true, expected_cooldown = 120 })
    if bf_ready then
        -- Cast AR first, then BF will be checked next tick
        return true
    end
    -- If BF is on cooldown but AR is ready, still cast AR for solo burst
    return true
end

local function blade_flurry_matches(context, action)
    if not NS.action_matches(context, action) then return false end
    -- Check if Adrenaline Rush is active - if so, cast BF immediately for sync
    local ar_active = context.me and NS.buff_up(context.me, { 13750 }) or false
    if ar_active then return true end
    -- Otherwise, only cast BF on its own if it's a good burst window
    return context.should_burst or false
end

-- ============================================================================
-- Slice and Dice/Rupture Cycle Optimization
-- ============================================================================
-- Maintain Slice and Dice at all times. Cycle Rupture at 5 CP.
-- Never let SND drop - refresh at 3s or less with 2+ CP.

local function snd_matches(context, action)
    local me = context.me
    if not me then return false end
    local snd_remains = NS.buff_remains(me, SND_BUFF) or 0
    local combo = context.combo_points or 0
    -- Refresh SND when <= 3s remaining and we have 2+ CP
    if snd_remains > SND_REFRESH_WINDOW then return false end
    if combo < 2 then return false end
    return NS.action_matches(context, action)
end

local function rupture_matches(context, action)
    local target = context.target
    if not target then return false end
    local rupture_remains = NS.debuff_remains(target, RUPTURE_DEBUFF) or 0
    local combo = context.combo_points or 0
    -- Only cast Rupture at 5 CP and when current Rupture is about to expire
    if combo < 5 then return false end
    if rupture_remains > RUPTURE_REFRESH_WINDOW then return false end
    return NS.action_matches(context, action)
end

local function sinister_strike_matches(context, action)
    -- Sinister Strike is the builder. Never energy cap.
    local energy = context.energy or 0
    -- Emergency: if we're about to cap, cast SS regardless of tick timing
    if energy >= 85 then return NS.action_matches(context, action) end
    -- Normal: only cast if it's safe to spend energy
    if not should_spend_energy(context, 45) then return false end
    return NS.action_matches(context, action)
end

local ACTIONS = {
    { name = "Stealth", spell = SPELLS.Stealth, target = "self", kind = "buff", buff = { 1787, 1786, 1785, 1784 }, ooc = true, requires_target = false },
    { name = "AdrenalineRush", spell = SPELLS.AdrenalineRush, target = "self", combat = true, setting = "use_cooldowns", cooldown = 300, requires_target = false, matches = adrenaline_rush_matches },
    { name = "BladeFlurry", spell = SPELLS.BladeFlurry, target = "self", combat = true, setting = "use_cooldowns", cooldown = 120, requires_target = false, matches = blade_flurry_matches },
    { name = "SliceAndDice", spell = SPELLS.SliceAndDice, target = "self", kind = "buff", buff = SND_BUFF, min_combo = 2, min_energy = 25, requires_target = false, matches = snd_matches },
    { name = "Rupture", spell = SPELLS.Rupture, min_combo = 5, min_energy = 25, debuff = RUPTURE_DEBUFF, refresh = 3, max_enemy_count = 1, matches = rupture_matches },
    { name = "Eviscerate", spell = SPELLS.Eviscerate, min_combo = 5, min_energy = 35 },
    { name = "SinisterStrike", spell = SPELLS.SinisterStrike, min_energy = 45, matches = sinister_strike_matches },
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
        execute = function(context) return NS.action_execute(context, action, "[COMBAT]") end,
    }
end

NS.rotation_registry:register("combat", strategies, { get_state = function(context) return context end })
NS.log("Rogue combat rotation registered (enhanced: energy tick optimization, BF+AR sync, SND/Rupture cycle)")
return strategies
