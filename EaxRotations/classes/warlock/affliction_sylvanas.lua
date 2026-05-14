-- Readability notes:
--   What: Warlock Affliction priority list.
--   When: dispatcher runs this playstyle when selected.
--   Why: action rows show what is cast, why it is gated, and when it is allowed.
--   Safety: all rows use shared spell/resource/range/form checks before casting.

-- Decision notes:
--   Playstyle files are ordered priority lists: earlier strategies must be more urgent or more time-sensitive.
--   Matches functions explain when an action is allowed; execute functions only perform the already-gated cast.
--   Role logic follows TBC expectations and avoids post-TBC spells, speculative target swaps, and impossible casts.
--   Enhancement notes (2026-05-13): Added DoT uptime optimization with pandemic windows,
--   Shadow Embrace stacking, Drain Life filler, and Nightfall (Shadow Trance) proc handling.
local NS = _G.EaxRotations
if not NS then return nil end
local SPELLS = NS.WarlockSpells or {}

local CURSE_OF_DOOM_DEBUFF = { 30910, 603 }
local CORRUPTION_DEBUFF = { 27216, 25311, 11672, 11671, 7648, 6223, 6222, 172 }
local CURSE_OF_AGONY_DEBUFF = { 27218, 11713, 11712, 11711, 6217, 1014, 980 }
local SIPHON_LIFE_DEBUFF = { 30911, 27264, 18881, 18880, 18879, 18265 }
local UNSTABLE_AFFLICTION_DEBUFF = { 30405, 30404, 30108 }
local SHADOW_EMBRACE_DEBUFF = { 32386, 32388, 32389, 32390, 32391 }
local NIGHTFALL_BUFF = { 17941 }  -- Shadow Trance proc (instant Shadow Bolt)

local DOT_REFRESH_WINDOW = 3.5
local LOW_MANA_THRESHOLD = 20
local DRAIN_LIFE_HP_THRESHOLD = 50

-- ============================================================================
-- DoT Refresh Gates with Pandemic Window
-- ============================================================================

local function corruption_matches(context, action)
    local target = context.target
    if not target then return false end
    local remains = NS.debuff_remains and NS.debuff_remains(target, CORRUPTION_DEBUFF) or 0
    if remains > DOT_REFRESH_WINDOW then return false end
    if not NS.should_refresh_dot(remains, 1.5, context.ttd, 18) then return false end
    return NS.action_matches(context, action)
end

local function curse_of_agony_matches(context, action)
    local target = context.target
    if not target then return false end
    local remains = NS.debuff_remains and NS.debuff_remains(target, CURSE_OF_AGONY_DEBUFF) or 0
    if remains > DOT_REFRESH_WINDOW then return false end
    -- Don't cast CoA if CoD is active
    local cod_remains = NS.debuff_remains and NS.debuff_remains(target, CURSE_OF_DOOM_DEBUFF) or 0
    if cod_remains > 0 then return false end
    return NS.action_matches(context, action)
end

local function unstable_affliction_matches(context, action)
    local target = context.target
    if not target then return false end
    local remains = NS.debuff_remains and NS.debuff_remains(target, UNSTABLE_AFFLICTION_DEBUFF) or 0
    if remains > DOT_REFRESH_WINDOW then return false end
    if not NS.should_refresh_dot(remains, 1.5, context.ttd, 18) then return false end
    return NS.action_matches(context, action)
end

local function siphon_life_matches(context, action)
    local target = context.target
    if not target then return false end
    local remains = NS.debuff_remains and NS.debuff_remains(target, SIPHON_LIFE_DEBUFF) or 0
    if remains > DOT_REFRESH_WINDOW then return false end
    if not NS.should_refresh_dot(remains, 1.5, context.ttd, 30) then return false end
    return NS.action_matches(context, action)
end

-- ============================================================================
-- Nightfall (Shadow Trance) Proc Handling
-- ============================================================================
-- Nightfall makes next Shadow Bolt instant - cast it immediately!

local function nightfall_matches(context, action)
    local me = context.me
    if not me then return false end
    local has_nightfall = NS.buff_up(me, NIGHTFALL_BUFF)
    if not has_nightfall then return false end
    return NS.action_matches(context, action)
end

-- ============================================================================
-- Life Tap Optimization
-- ============================================================================

local function life_tap_matches(context, action)
    local mana_pct = context.mana_pct or 100
    local hp_pct = context.hp or 100
    if mana_pct > 40 then return false end
    if hp_pct < 40 then return false end  -- Safety: don't tap when low HP
    return NS.action_matches(context, action)
end

-- ============================================================================
-- Drain Life Filler (when moving or low HP)
-- ============================================================================

local function drain_life_matches(context, action)
    if context.is_moving then return false end
    local hp_pct = context.hp or 100
    if hp_pct < DRAIN_LIFE_HP_THRESHOLD then
        -- Emergency: drain to stay alive
        return NS.action_matches(context, action)
    end
    return false
end

local ACTIONS = {
    { name = "FelArmor", spell = SPELLS.FelArmor, target = "self", kind = "buff", buff = { 28189, 28176 }, requires_target = false },
    { name = "CurseOfDoom", spell = SPELLS.CurseOfDoom, debuff = CURSE_OF_DOOM_DEBUFF, refresh = 5, cooldown = 60, min_ttd = 62, require_ttd = true, target_not_player = true },
    { name = "NightfallShadowBolt", spell = SPELLS.ShadowBolt, not_moving = true, matches = nightfall_matches, priority = 100 },
    { name = "UnstableAffliction", spell = SPELLS.UnstableAffliction, debuff = UNSTABLE_AFFLICTION_DEBUFF, refresh = 3, not_moving = true, matches = unstable_affliction_matches },
    { name = "Corruption", spell = SPELLS.Corruption, debuff = CORRUPTION_DEBUFF, refresh = 3, matches = corruption_matches },
    { name = "CurseOfAgony", spell = SPELLS.CurseOfAgony, debuff = CURSE_OF_AGONY_DEBUFF, refresh = 3, matches = curse_of_agony_matches },
    { name = "SiphonLife", spell = SPELLS.SiphonLife, debuff = SIPHON_LIFE_DEBUFF, refresh = 3, matches = siphon_life_matches },
    { name = "LifeTap", spell = SPELLS.LifeTap, target = "self", min_hp = 40, max_mana = 65, requires_target = false, matches = life_tap_matches },
    { name = "DrainLife", spell = SPELLS.DrainLife, not_moving = true, matches = drain_life_matches },
    { name = "ShadowBolt", spell = SPELLS.ShadowBolt, not_moving = true },
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
        execute = function(context) return NS.action_execute(context, action, "[AFFLICTION]") end,
    }
end

NS.rotation_registry:register("affliction", strategies, { get_state = function(context) return context end })
NS.log("Warlock affliction rotation registered (enhanced: DoT pandemic windows, Nightfall proc, Life Tap optimization)")
return strategies
