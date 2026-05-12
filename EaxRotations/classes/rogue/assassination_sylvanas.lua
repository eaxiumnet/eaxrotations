-- Readability notes:
--   What: Rogue Assassination priority list.
--   When: dispatcher runs this playstyle when selected.
--   Why: action rows show what is cast, why it is gated, and when it is allowed.
--   Safety: all rows use shared spell/resource/range/form checks before casting.

-- Decision notes:
--   Playstyle files are ordered priority lists: earlier strategies must be more urgent or more time-sensitive.
--   Matches functions explain when an action is allowed; execute functions only perform the already-gated cast.
--   Role logic follows TBC expectations and avoids post-TBC spells, speculative target swaps, and impossible casts.
local NS = _G.EaxRotations
if not NS then return nil end
local SPELLS = NS.RogueSpells or {}

local ACTIONS = {
    { name = "Stealth", spell = SPELLS.Stealth, target = "self", kind = "buff", buff = { 1787, 1786, 1785, 1784 }, ooc = true, requires_target = false },
    { name = "Garrote", spell = SPELLS.Garrote, requires_buff = { 1787, 1786, 1785, 1784 }, requires_behind = true, min_energy = 50, debuff = { 26884, 26839, 11290, 11289, 8633, 8632, 8631, 703 }, refresh = 3 },
    { name = "SliceAndDice", spell = SPELLS.SliceAndDice, target = "self", kind = "buff", buff = { 6774, 5171 }, min_combo = 2, min_energy = 25, requires_target = false },
    { name = "Rupture", spell = SPELLS.Rupture, min_combo = 4, min_energy = 25, debuff = { 26867, 11275, 11274, 11273, 8640, 8639, 1943 }, refresh = 3 },
    { name = "Mutilate", spell = SPELLS.Mutilate, requires_behind = true, min_energy = 60 },
    { name = "Eviscerate", spell = SPELLS.Eviscerate, min_combo = 5, min_energy = 35 },
}

local strategies = {}
for i = 1, #ACTIONS do
    local action = ACTIONS[i]
    strategies[#strategies + 1] = {
        name = action.name,
        matches = function(context) return NS.action_matches(context, action) end,
        execute = function(context) return NS.action_execute(context, action, "[ASSASSINATION]") end,
    }
end

NS.rotation_registry:register("assassination", strategies, { get_state = function(context) return context end })
NS.log("Rogue assassination rotation registered")
return strategies
