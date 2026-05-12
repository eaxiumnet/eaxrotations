-- Readability notes:
--   What: Rogue Combat priority list.
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
    { name = "BladeFlurry", spell = SPELLS.BladeFlurry, target = "self", combat = true, setting = "use_cooldowns", cooldown = 120, requires_target = false },
    { name = "AdrenalineRush", spell = SPELLS.AdrenalineRush, target = "self", combat = true, setting = "use_cooldowns", cooldown = 300, requires_target = false },
    { name = "SliceAndDice", spell = SPELLS.SliceAndDice, target = "self", kind = "buff", buff = { 6774, 5171 }, min_combo = 2, min_energy = 25, requires_target = false },
    { name = "Rupture", spell = SPELLS.Rupture, min_combo = 5, min_energy = 25, debuff = { 26867, 11275, 11274, 11273, 8640, 8639, 1943 }, refresh = 3, max_enemy_count = 1 },
    { name = "Eviscerate", spell = SPELLS.Eviscerate, min_combo = 5, min_energy = 35 },
    { name = "SinisterStrike", spell = SPELLS.SinisterStrike, min_energy = 45 },
}

local strategies = {}
for i = 1, #ACTIONS do
    local action = ACTIONS[i]
    strategies[#strategies + 1] = {
        name = action.name,
        matches = function(context) return NS.action_matches(context, action) end,
        execute = function(context) return NS.action_execute(context, action, "[COMBAT]") end,
    }
end

NS.rotation_registry:register("combat", strategies, { get_state = function(context) return context end })
NS.log("Rogue combat rotation registered")
return strategies
