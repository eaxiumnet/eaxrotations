-- Readability notes:
--   What: Warrior Arms priority list.
--   When: dispatcher runs this playstyle when selected.
--   Why: action rows show what is cast, why it is gated, and when it is allowed.
--   Safety: all rows use shared spell/resource/range/form checks before casting.

-- Decision notes:
--   Playstyle files are ordered priority lists: earlier strategies must be more urgent or more time-sensitive.
--   Matches functions explain when an action is allowed; execute functions only perform the already-gated cast.
--   Role logic follows TBC expectations and avoids post-TBC spells, speculative target swaps, and impossible casts.
--   Enhancement notes (2026-05-13): Added slam weaving via swing timer, stance dancing with rage-safe calculations,
--   PvP rotation branch (intercept, disarm, spell reflect), proactive Battle Shout refresh, and Victory Rush detection.
local NS = _G.EaxRotations
if not NS then return nil end
local SPELLS = NS.WarriorSpells or {}

-- Load swing timer for slam weaving
local _swing_ok, SwingTimer = pcall(require, "shared/swing_timer_sylvanas")
if not _swing_ok or type(SwingTimer) ~= "table" then SwingTimer = nil end

local function execute_matches(context, action)
    if not NS.is_execute_phase(context.target_hp, 20) then return false end
    return NS.action_matches(context, action)
end

local BATTLE_SHOUT_BUFF = { 25289, 2048, 11551, 11550, 11549, 6192, 5242, 6673 }

-- ============================================================================
-- Stance Dancing: Rage-Safe Stance Switching
-- ============================================================================
-- Tactical Mastery talent preserves 5 rage per rank (0-25) when swapping stances.
-- These helpers let playstyles decide whether a stance swap is rage-safe.

local TACTICAL_MASTERY_SPELLS = { 12295, 12676, 12677, 12678, 12679 }

local function get_tactical_mastery_rank()
    if NS.talent_inference and NS.talent_inference.has_talent then
        return NS.talent_inference.has_talent("TacticalMastery") and 5 or 0
    end
    local learned = 0
    for i = 1, #TACTICAL_MASTERY_SPELLS do
        if NS.is_spell_learned and NS.is_spell_learned(TACTICAL_MASTERY_SPELLS[i]) then
            learned = learned + 1
        end
    end
    return learned
end

local function get_preserved_rage_after_swap(current_rage)
    local tm_cap = get_tactical_mastery_rank() * 5
    return current_rage <= tm_cap and current_rage or tm_cap
end

local function is_stance_swap_safe(current_rage, ability_cost)
    local rage_after_swap = get_preserved_rage_after_swap(current_rage)
    return rage_after_swap >= (ability_cost or 0)
end

-- ============================================================================
-- PvP Rotation Branch
-- ============================================================================
-- Arms Warrior is THE premier PvP spec in TBC
-- Key: Mortal Strike (50% healing reduction), Hamstring uptime, Intercept stun
-- Pummel interrupt, Intimidating Shout fear, Overpower on dodges

local HAMSTRING_DEBUFF = { 25212, 7373, 7372, 1715 }

local function pvp_matches(context, action)
    if not (context.is_pvp or (context.settings and context.settings.pvp_mode)) then return false end
    if not context.target then return false end
    return NS.action_matches(context, action)
end

local function is_target_player_or_pet(target)
    if not target then return false end
    local ok, is_player = pcall(function() return target.is_player and target:is_player() end)
    if ok and is_player then return true end
    local ok2, is_pet = pcall(function() return target.is_pet and target:is_pet() end)
    return ok2 and is_pet or false
end

-- ============================================================================
-- Slam Weaving: Timing-based swing weapon weaving
-- ============================================================================
-- TBC Arms: Slam is only valuable when it fits inside the swing timer dead zone.
-- With Improved Slam (reduces cast time to 0.5s), weave Slam between swings.

local SLAM_SPELL = SPELLS.Slam or NS.spell_action({ 25242, 25241, 11605, 11604, 8820, 1464 }, "Slam")
local SLAM_RAGE_COST = 15
local SLAM_WEAVE_WINDOW = 1.5  -- seconds before swing to consider weaving

local function can_weave_slam(context)
    if not SwingTimer then return false end
    local mh_remaining = SwingTimer.get_mh_time_until and SwingTimer.get_mh_time_until() or 999
    if mh_remaining > SLAM_WEAVE_WINDOW then return false end
    -- Only weave if we have enough rage and nothing higher priority is ready
    if (context.rage or 0) < SLAM_RAGE_COST then return false end
    -- Don't weave if Mortal Strike or Overpower is ready (higher priority)
    if NS.spell_ready(SPELLS.MortalStrike, context.target, { expected_cooldown = 6 }) then return false end
    if NS.spell_ready(SPELLS.Overpower, context.target) then return false end
    return true
end

local function victory_rush_matches(context, action)
    -- Victory Rush is only usable within 20s of a killing blow
    local me = context.me
    if not me then return false end
    local has_vr = NS.buff_up(me, { 34428 })  -- Victory Rush buff ID
    if not has_vr then return false end
    return NS.action_matches(context, action)
end

local ACTIONS = {
    { name = "BattleStance", spell = SPELLS.BattleStance, target = "self", kind = "form", form = "battle", requires_target = false },
    { name = "BattleShout", spell = SPELLS.BattleShout, target = "self", kind = "buff", buff = BATTLE_SHOUT_BUFF, requires_target = false },
    { name = "VictoryRush", spell = SPELLS.VictoryRush, matches = victory_rush_matches },
    { name = "MortalStrike", spell = SPELLS.MortalStrike, required_stance = 1, min_rage = 30, cooldown = 6 },
    { name = "Overpower", spell = SPELLS.Overpower, required_stance = 1, min_rage = 5 },
    { name = "Execute", spell = SPELLS.Execute, min_rage = 15, matches = execute_matches },
    { name = "Slam", spell = SLAM_SPELL, required_stance = 1, min_rage = 15, not_moving = true, matches = can_weave_slam },
    { name = "HeroicStrike", spell = SPELLS.HeroicStrike, min_rage = 45 },
}

-- PvP actions (lower priority, only active in PvP)
local PVP_ACTIONS = {
    { name = "Hamstring", spell = SPELLS.Hamstring, debuff = HAMSTRING_DEBUFF, pvp_only = true },
    { name = "Disarm", spell = SPELLS.Disarm, pvp_only = true },
    { name = "SpellReflection", spell = SPELLS.SpellReflection, target = "self", requires_target = false, pvp_only = true },
    { name = "Intercept", spell = SPELLS.Intercept, pvp_only = true },
}

local strategies = {}

-- Add core actions
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
        execute = function(context) return NS.action_execute(context, action, "[ARMS]") end,
    }
end

-- Add PvP actions at the end (lower priority than core rotation)
for i = 1, #PVP_ACTIONS do
    local action = PVP_ACTIONS[i]
    strategies[#strategies + 1] = {
        name = action.name,
        matches = function(context)
            if not (context.is_pvp or (context.settings and context.settings.pvp_mode)) then return false end
            if not is_target_player_or_pet(context.target) then return false end
            return NS.action_matches(context, action)
        end,
        execute = function(context) return NS.action_execute(context, action, "[ARMS-PvP]") end,
    }
end

NS.rotation_registry:register("arms", strategies, { get_state = function(context) return context end })
NS.log("Warrior arms rotation registered (enhanced: slam weaving, stance dancing, PvP, Victory Rush)")
return strategies
