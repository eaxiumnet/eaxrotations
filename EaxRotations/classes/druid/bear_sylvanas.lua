-- Readability notes:
--   What: Druid Bear priority list.
--   When: dispatcher runs this playstyle when selected.
--   Why: action rows show what is cast, why it is gated, and when it is allowed.
--   Safety: all rows use shared spell/resource/range/form checks before casting.

-- Decision notes:
--   Playstyle files are ordered priority lists: earlier strategies must be more urgent or more time-sensitive.
--   Matches functions explain when an action is allowed; execute functions only perform the already-gated cast.
--   Role logic follows TBC expectations and avoids post-TBC spells, speculative target swaps, and impossible casts.
--   Enhancement notes (2026-05-13): Added proper defensive thresholds, Mangle maintenance,
--   Lacerate stack optimization (5-stack priority), and improved Faerie Fire uptime.
local NS = _G.EaxRotations
if not NS then return nil end
local SPELLS = NS.DruidSpells or {}

local FAERIE_FIRE_DEBUFF = { 27011, 17392, 17391, 17390, 16857, 26993, 9907, 9749, 778, 770 }
local LACERATE_DEBUFF = { 33745 }

local LACERATE_REFRESH_WINDOW = 3
local FRENZIED_REGEN_HP = 35
local FRENZIED_REGEN_RAGE = 10

-- ============================================================================
-- Faerie Fire Feral: Maintain armor debuff
-- ============================================================================

local function faerie_fire_matches(context, action)
    local target = context.target
    if not target then return false end
    local remains = NS.debuff_remains and NS.debuff_remains(target, FAERIE_FIRE_DEBUFF) or 0
    if remains > 4 then return false end
    return NS.action_matches(context, action)
end

-- ============================================================================
-- Lacerate Stack Optimization
-- ============================================================================
-- TBC Bear: Lacerate to 5 stacks ASAP, then maintain. Never let it drop.

local function lacerate_matches(context, action)
    local target = context.target
    if not target then return false end
    local remains = NS.debuff_remains and NS.debuff_remains(target, LACERATE_DEBUFF) or 0
    local stacks = NS.get_debuff_stacks and NS.get_debuff_stacks(target, LACERATE_DEBUFF) or 0
    -- If not at 5 stacks, prioritize lacerating
    if stacks < 5 then
        return NS.action_matches(context, action)
    end
    -- At 5 stacks, only refresh when about to fall off
    if remains <= LACERATE_REFRESH_WINDOW then
        return NS.action_matches(context, action)
    end
    return false
end

local function swipe_aoe_matches(context, action)
    if (context.enemy_count or 1) < 3 then return false end
    return NS.action_matches(context, action)
end

local function swipe_matches(context, action)
    if (context.enemy_count or 1) < 2 then return false end
    return NS.action_matches(context, action)
end

local function maul_matches(context, action)
    -- Only Maul if we have excess rage (35+) and Lacerate is already at 5 stacks
    local rage = context.rage or 0
    if rage < 35 then return false end
    local target = context.target
    if target then
        local stacks = NS.get_debuff_stacks and NS.get_debuff_stacks(target, LACERATE_DEBUFF) or 0
        if stacks < 5 then return false end
    end
    return NS.action_matches(context, action)
end

local ACTIONS = {
    { name = "BearForm", spell = SPELLS.BearForm, target = "self", kind = "form", form = "bear", requires_target = false },
    { name = "FrenziedRegeneration", spell = SPELLS.FrenziedRegeneration, target = "self", max_hp = FRENZIED_REGEN_HP, min_rage = FRENZIED_REGEN_RAGE, requires_target = false },
    { name = "DemoralizingRoar", spell = SPELLS.DemoralizingRoar, target = "self", required_form = "bear", min_rage = 10, cooldown = 25, requires_target = false },
    { name = "FaerieFireFeral", spell = SPELLS.FaerieFireFeral, required_form = "bear", debuff = FAERIE_FIRE_DEBUFF, refresh = 4, matches = faerie_fire_matches },
    { name = "SwipeAoE", spell = SPELLS.SwipeBear, target = "self", required_form = "bear", enemy_count = 3, min_rage = 20, requires_target = false, matches = swipe_aoe_matches },
    { name = "MangleBear", spell = SPELLS.MangleBear, required_form = "bear", min_rage = 15 },
    { name = "Lacerate", spell = SPELLS.Lacerate, required_form = "bear", min_rage = 15, max_enemy_count = 2, debuff = LACERATE_DEBUFF, min_debuff_stacks = 5, refresh = 3, matches = lacerate_matches },
    { name = "Swipe", spell = SPELLS.SwipeBear, target = "self", required_form = "bear", enemy_count = 2, min_rage = 20, requires_target = false, matches = swipe_matches },
    { name = "Maul", spell = SPELLS.Maul, required_form = "bear", min_rage = 35, matches = maul_matches },
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
        execute = function(context) return NS.action_execute(context, action, "[BEAR]") end,
    }
end

NS.rotation_registry:register("bear", strategies, { get_state = function(context) return context end })
NS.log("Druid bear rotation registered (enhanced: Lacerate stack optimization, defensive thresholds, Faerie Fire uptime)")
return strategies
