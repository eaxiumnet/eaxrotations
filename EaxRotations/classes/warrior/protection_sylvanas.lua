-- Readability notes:
--   What: Warrior Protection priority list.
--   When: dispatcher runs this playstyle when selected.
--   Why: action rows show what is cast, why it is gated, and when it is allowed.
--   Safety: all rows use shared spell/resource/range/form checks before casting.

-- Decision notes:
--   Playstyle files are ordered priority lists: earlier strategies must be more urgent or more time-sensitive.
--   Matches functions explain when an action is allowed; execute functions only perform the already-gated cast.
--   Role logic follows TBC expectations and avoids post-TBC spells, speculative target swaps, and impossible casts.
--   Enhancement notes (2026-05-13): Added Shield Slam priority (highest threat), Revenge proc optimization,
--   improved Sunder stack logic (5-stack maintenance), and rage dump Heroic Strike at 70+ rage.
local NS = _G.EaxRotations
if not NS then return nil end
local SPELLS = NS.WarriorSpells or {}

local SUNDER_DEBUFF = { 25225, 11597, 11596, 8380, 7405, 7386 }
local DEMO_SHOUT_DEBUFF = { 25260, 25261, 1160, 6190, 11556, 11555, 11554 }
local THUNDER_CLAP_DEBUFF = { 25264, 8198, 8205, 8204, 11580, 11581 }

local SUNDER_REFRESH_WINDOW = 3
local SUNDER_MAX_STACKS = 5
local HEROIC_STRIKE_RAGE_DUMP = 70

-- ============================================================================
-- Sunder Armor Stack Optimization
-- ============================================================================
-- TBC Prot Warrior: Build 5 Sunder stacks ASAP, then maintain with Devastate.

local function sunder_matches(context, action)
    local target = context.target
    if not target then return false end
    local stacks = NS.get_debuff_stacks and NS.get_debuff_stacks(target, SUNDER_DEBUFF) or 0
    local remains = NS.debuff_remains and NS.debuff_remains(target, SUNDER_DEBUFF) or 0
    -- If not at 5 stacks, prioritize Sunder
    if stacks < SUNDER_MAX_STACKS then
        return NS.action_matches(context, action)
    end
    -- At 5 stacks, only refresh when about to expire
    if remains <= SUNDER_REFRESH_WINDOW then
        return NS.action_matches(context, action)
    end
    return false
end

local function devastate_matches(context, action)
    local target = context.target
    if target then
        local stacks = NS.get_debuff_stacks and NS.get_debuff_stacks(target, SUNDER_DEBUFF) or 0
        -- Devastate is higher DPS than Sunder at 5 stacks
        if stacks >= SUNDER_MAX_STACKS then
            return NS.action_matches(context, action)
        end
    end
    return false
end

-- ============================================================================
-- Heroic Strike Rage Dump
-- ============================================================================

local function heroic_strike_matches(context, action)
    local rage = context.rage or 0
    -- Only dump rage if we have excess and core abilities aren't ready
    if rage < HEROIC_STRIKE_RAGE_DUMP then return false end
    -- Don't HS if Shield Slam or Revenge are ready (higher priority)
    if NS.spell_ready(SPELLS.ShieldSlam, context.target, { expected_cooldown = 6 }) then return false end
    if NS.spell_ready(SPELLS.Revenge, context.target, { expected_cooldown = 5 }) then return false end
    return NS.action_matches(context, action)
end

-- ============================================================================
-- Thunder Clap AoE
-- ============================================================================

local function thunderclap_matches(context, action)
    if (context.enemy_count or 1) < 2 then return false end
    return NS.action_matches(context, action)
end

-- ============================================================================
-- Demoralizing Shout Maintenance
-- ============================================================================

local function demo_shout_matches(context, action)
    local target = context.target
    if not target then return false end
    local remains = NS.debuff_remains and NS.debuff_remains(target, DEMO_SHOUT_DEBUFF) or 0
    if remains > 5 then return false end
    return NS.action_matches(context, action)
end

local ACTIONS = {
    { name = "DefensiveStance", spell = SPELLS.DefensiveStance, target = "self", kind = "form", form = "defensive", requires_target = false },
    { name = "ShieldBlock", spell = SPELLS.ShieldBlock, target = "self", required_stance = 2, min_rage = 10, cooldown = 5, requires_target = false },
    { name = "ShieldSlam", spell = SPELLS.ShieldSlam, required_stance = 2, min_rage = 20, cooldown = 6 },
    { name = "Revenge", spell = SPELLS.Revenge, required_stance = 2, min_rage = 5, cooldown = 5 },
    { name = "SunderArmor", spell = SPELLS.SunderArmor, required_stance = 2, min_rage = 15, debuff = SUNDER_DEBUFF, refresh = 3, matches = sunder_matches },
    { name = "Devastate", spell = SPELLS.Devastate, required_stance = 2, min_rage = 15, matches = devastate_matches },
    { name = "DemoralizingShout", spell = SPELLS.DemoralizingShout, target = "self", required_stance = 2, min_rage = 10, cooldown = 25, requires_target = false, matches = demo_shout_matches },
    { name = "ThunderClap", spell = SPELLS.ThunderClap, target = "self", min_rage = 20, cooldown = 4, requires_target = false, matches = thunderclap_matches },
    { name = "HeroicStrike", spell = SPELLS.HeroicStrike, required_stance = 2, min_rage = 55, matches = heroic_strike_matches },
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
        execute = function(context) return NS.action_execute(context, action, "[PROTECTION]") end,
    }
end

NS.rotation_registry:register("protection", strategies, { get_state = function(context) return context end })
NS.log("Warrior protection rotation registered (enhanced: Sunder stack optimization, SS/Revenge priority, rage dump logic)")
return strategies
