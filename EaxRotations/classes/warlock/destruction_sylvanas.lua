-- Readability notes:
--   What: Warlock Destruction priority list.
--   When: dispatcher runs this playstyle when selected.
--   Why: action rows show what is cast, why it is gated, and when it is allowed.
--   Safety: all rows use shared spell/resource/range/form checks before casting.

-- Decision notes:
--   Playstyle files are ordered priority lists: earlier strategies must be more urgent or more time-sensitive.
--   Matches functions explain when an action is allowed; execute functions only perform the already-gated cast.
--   Role logic follows TBC expectations and avoids post-TBC spells, speculative target swaps, and impossible casts.
local NS = _G.EaxRotations
if not NS then return nil end
local SPELLS = NS.WarlockSpells or {}

local CURSE_OF_DOOM_DEBUFF = { 30910, 603 }
local IMMOLATE_DEBUFF = { 27215, 25309, 11668, 11667, 11665, 2941, 1094, 707, 348 }

local function immolate_matches(context, action)
    local target = context.target
    if not target then return false end
    local remains = NS.debuff_remains and NS.debuff_remains(target, IMMOLATE_DEBUFF) or 0
    if not NS.should_refresh_dot(remains, 3, context.ttd, 15) then return false end
    return NS.action_matches(context, action)
end

local function shadowburn_matches(context, action)
    if not NS.is_execute_phase(context.target_hp, 25) then return false end
    return NS.action_matches(context, action)
end

local function curse_of_doom_matches(context, action)
    if not NS.should_use_long_cd(context, action.cooldown) then return false end
    return NS.action_matches(context, action)
end

local ACTIONS = {
    { name = "FelArmor", spell = SPELLS.FelArmor, target = "self", kind = "buff", buff = { 28189, 28176 }, requires_target = false },
    { name = "CurseOfDoom", spell = SPELLS.CurseOfDoom, debuff = CURSE_OF_DOOM_DEBUFF, refresh = 5, cooldown = 60, min_ttd = 62, require_ttd = true, target_not_player = true, matches = curse_of_doom_matches },
    { name = "Immolate", spell = SPELLS.Immolate, not_moving = true, matches = immolate_matches },
    { name = "Conflagrate", spell = SPELLS.Conflagrate, requires_debuff = { 27215, 25309, 11668, 11667, 11665, 2941, 1094, 707, 348 }, moving = true, cooldown = 10 },
    { name = "Shadowburn", spell = SPELLS.Shadowburn, cooldown = 15, matches = shadowburn_matches },
    { name = "Incinerate", spell = SPELLS.Incinerate, not_moving = true },
    { name = "ShadowBolt", spell = SPELLS.ShadowBolt, not_moving = true },
}

local strategies = {}
for i = 1, #ACTIONS do
    local action = ACTIONS[i]
    strategies[#strategies + 1] = {
        name = action.name,
        matches = function(context) return action.matches and action.matches(context, action) or NS.action_matches(context, action) end,
        execute = function(context) return NS.action_execute(context, action, "[DESTRUCTION]") end,
    }
end

NS.rotation_registry:register("destruction", strategies, { get_state = function(context) return context end })
NS.log("Warlock destruction rotation registered")
return strategies
