-- Readability notes:
--   What: Paladin Protection priority list.
--   When: dispatcher runs this playstyle when selected.
--   Why: action rows show what is cast, why it is gated, and when it is allowed.
--   Safety: all rows use shared spell/resource/range/form checks before casting.

-- Decision notes:
--   Playstyle files are ordered priority lists: earlier strategies must be more urgent or more time-sensitive.
--   Matches functions explain when an action is allowed; execute functions only perform the already-gated cast.
--   Role logic follows TBC expectations and avoids post-TBC spells, speculative target swaps, and impossible casts.
local NS = _G.EaxRotations
if not NS then return nil end
local SPELLS = NS.PaladinSpells or {}
local DEMON_OR_UNDEAD = { [3] = true, [6] = true }

local ACTIONS = {
    { name = "RighteousFury", spell = SPELLS.RighteousFury, target = "self", kind = "buff", buff = { 25780 }, requires_target = false },
    { name = "HolyShield", spell = SPELLS.HolyShield, target = "self", combat = true, cooldown = 10, requires_target = false },
    { name = "Consecration", spell = SPELLS.Consecration, target = "self", combat = true, cooldown = 8, requires_target = false },
    { name = "AvengerShield", spell = SPELLS.AvengerShield, not_moving = true, cooldown = 30 },
    { name = "Exorcism", spell = SPELLS.Exorcism, not_moving = true, cooldown = 15, min_mana = 20, creature_types = DEMON_OR_UNDEAD },
    { name = "SealRighteousness", spell = SPELLS.SealRighteousness, target = "self", kind = "buff", buff = { 27155, 20293, 20292, 20291, 20290, 20289, 20288, 20287, 21084 }, requires_target = false },
    { name = "Judgement", spell = SPELLS.Judgement, cooldown = 10 },
}

local strategies = {}
for i = 1, #ACTIONS do
    local action = ACTIONS[i]
    strategies[#strategies + 1] = {
        name = action.name,
        matches = function(context) return NS.action_matches(context, action) end,
        execute = function(context) return NS.action_execute(context, action, "[PROTECTION]") end,
    }
end

NS.rotation_registry:register("protection", strategies, { get_state = function(context) return context end })
NS.log("Paladin protection rotation registered")
return strategies
