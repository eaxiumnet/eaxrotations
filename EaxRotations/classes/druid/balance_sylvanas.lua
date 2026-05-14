-- Readability notes:
--   What: Druid Balance priority list.
--   When: dispatcher runs this playstyle when selected.
--   Why: action rows show what is cast, why it is gated, and when it is allowed.
--   Safety: all rows use shared spell/resource/range/form checks before casting.

-- Decision notes:
--   Playstyle files are ordered priority lists: earlier strategies must be more urgent or more time-sensitive.
--   Matches functions explain when an action is allowed; execute functions only perform the already-gated cast.
--   Role logic follows TBC expectations and avoids post-TBC spells, speculative target swaps, and impossible casts.
--   Enhancement notes (2026-05-13): Added proper DoT refresh gates, mana management with Innervate,
--   and Hurricane AoE threshold optimization.
local NS = _G.EaxRotations
if not NS then return nil end
local SPELLS = NS.DruidSpells or {}

local MOONKIN_FORM_BUFF = { 24858, 24905 }
local INSECT_SWARM_DEBUFF = { 27013, 24977, 24976, 24975, 24974, 5570 }
local MOONFIRE_DEBUFF = { 26988, 26987, 9835, 9834, 9833, 8929, 8928, 8927, 8926, 8925, 8924, 8921 }
local FAERIE_FIRE_DEBUFF = { 26993, 9907, 9749, 778, 770 }

local DOT_REFRESH_WINDOW = 3
local LOW_MANA_THRESHOLD = 15
local INNERVATE_MANA_THRESHOLD = 30

-- ============================================================================
-- DoT Refresh Gates with Pandemic Window
-- ============================================================================

local function insect_swarm_matches(context, action)
    local target = context.target
    if not target then return false end
    local remains = NS.debuff_remains and NS.debuff_remains(target, INSECT_SWARM_DEBUFF) or 0
    if remains > DOT_REFRESH_WINDOW then return false end
    if not NS.should_refresh_dot(remains, 1.5, context.ttd, 12) then return false end
    return NS.action_matches(context, action)
end

local function moonfire_matches(context, action)
    local target = context.target
    if not target then return false end
    local remains = NS.debuff_remains and NS.debuff_remains(target, MOONFIRE_DEBUFF) or 0
    if remains > DOT_REFRESH_WINDOW then return false end
    -- Moonfire is instant, use early-refresh buffer
    if not NS.should_refresh_dot(remains, 1.5, context.ttd, 12) then return false end
    return NS.action_matches(context, action)
end

local function faerie_fire_matches(context, action)
    local target = context.target
    if not target then return false end
    local remains = NS.debuff_remains and NS.debuff_remains(target, FAERIE_FIRE_DEBUFF) or 0
    if remains > 4 then return false end
    return NS.action_matches(context, action)
end

-- ============================================================================
-- Mana Management
-- ============================================================================

local function innervate_matches(context, action)
    if not context.in_combat then return false end
    local mana_pct = context.mana_pct or 100
    if mana_pct > INNERVATE_MANA_THRESHOLD then return false end
    return NS.action_matches(context, action)
end

local function starfire_matches(context, action)
    if context.is_moving then return false end
    local mana_pct = context.mana_pct or 100
    -- Conserve mana when critically low - prefer Wrath over Starfire
    if mana_pct < LOW_MANA_THRESHOLD then return false end
    return NS.action_matches(context, action)
end

local function wrath_matches(context, action)
    if context.is_moving then return false end
    return NS.action_matches(context, action)
end

local ACTIONS = {
    { name = "MoonkinForm", spell = SPELLS.MoonkinForm, target = "self", kind = "form", form = "moonkin", requires_target = false },
    { name = "Innervate", spell = SPELLS.Innervate, target = "self", min_mana = INNERVATE_MANA_THRESHOLD, requires_target = false, matches = innervate_matches },
    { name = "FaerieFire", spell = SPELLS.FaerieFire, debuff = FAERIE_FIRE_DEBUFF, refresh = 4, matches = faerie_fire_matches },
    { name = "ForceOfNature", spell = SPELLS.ForceOfNature, position = "target", combat = true, setting = "use_cooldowns", cooldown = 180, min_mana = 25 },
    { name = "Hurricane", spell = SPELLS.Hurricane, position = "target", enemy_count = 3, not_moving = true, min_mana = 35, cooldown = 60 },
    { name = "InsectSwarm", spell = SPELLS.InsectSwarm, debuff = INSECT_SWARM_DEBUFF, refresh = 3, min_mana = 25, matches = insect_swarm_matches },
    { name = "Moonfire", spell = SPELLS.Moonfire, debuff = MOONFIRE_DEBUFF, refresh = 3, min_mana = 25, matches = moonfire_matches },
    { name = "Starfire", spell = SPELLS.Starfire, not_moving = true, min_mana = 15, matches = starfire_matches },
    { name = "Wrath", spell = SPELLS.Wrath, not_moving = true, min_mana = 10, matches = wrath_matches },
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
        execute = function(context) return NS.action_execute(context, action, "[BALANCE]") end,
    }
end

NS.rotation_registry:register("balance", strategies, { get_state = function(context) return context end })
NS.log("Druid balance rotation registered (enhanced: DoT refresh gates, mana management, pandemic windows)")
return strategies
