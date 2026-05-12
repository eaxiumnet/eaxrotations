-- Readability notes:
--   What: Druid Caster priority list.
--   When: dispatcher runs this playstyle when selected.
--   Why: action rows show what is cast, why it is gated, and when it is allowed.
--   Safety: all rows use shared spell/resource/range/form checks before casting.

-- Decision notes:
--   Playstyle files are ordered priority lists: earlier strategies must be more urgent or more time-sensitive.
--   Matches functions explain when an action is allowed; execute functions only perform the already-gated cast.
--   Role logic follows TBC expectations and avoids post-TBC spells, speculative target swaps, and impossible casts.
local NS = _G.EaxRotations
if not NS then return nil end
local SPELLS = NS.DruidSpells or {}

local ACTIONS = {
    { name = "FaerieFire", spell = SPELLS.FaerieFire, debuff = { 26993, 9907, 9749, 778, 770 }, refresh = 4 },
    { name = "Moonfire", spell = SPELLS.Moonfire, debuff = { 26988, 26987, 9835, 9834, 9833, 8929, 8928, 8927, 8926, 8925, 8924, 8921 }, refresh = 3, min_mana = 25 },
    { name = "Wrath", spell = SPELLS.Wrath, not_moving = true, min_mana = 10 },
}

local strategies = {}
for i = 1, #ACTIONS do
    local action = ACTIONS[i]
    strategies[#strategies + 1] = {
        name = action.name,
        matches = function(context) return NS.action_matches(context, action) end,
        execute = function(context) return NS.action_execute(context, action, "[CASTER]") end,
    }
end

NS.rotation_registry:register("caster", strategies, { get_state = function(context) return context end })
NS.log("Druid caster rotation registered")
return strategies
