-- Readability notes:
--   What: Druid Balance priority list.
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
    { name = "MoonkinForm", spell = SPELLS.MoonkinForm, target = "self", kind = "form", form = "moonkin", requires_target = false },
    { name = "FaerieFire", spell = SPELLS.FaerieFire, debuff = { 26993, 9907, 9749, 778, 770 }, refresh = 4 },
    { name = "ForceOfNature", spell = SPELLS.ForceOfNature, position = "target", combat = true, setting = "use_cooldowns", cooldown = 180, min_mana = 25 },
    { name = "Hurricane", spell = SPELLS.Hurricane, position = "target", enemy_count = 3, not_moving = true, min_mana = 35, cooldown = 60 },
    { name = "InsectSwarm", spell = SPELLS.InsectSwarm, debuff = { 27013, 24977, 24976, 24975, 24974, 5570 }, refresh = 3, min_mana = 25 },
    { name = "Moonfire", spell = SPELLS.Moonfire, debuff = { 26988, 26987, 9835, 9834, 9833, 8929, 8928, 8927, 8926, 8925, 8924, 8921 }, refresh = 3, min_mana = 25 },
    { name = "Starfire", spell = SPELLS.Starfire, not_moving = true, min_mana = 15 },
    { name = "Wrath", spell = SPELLS.Wrath, not_moving = true, min_mana = 10 },
}

local strategies = {}
for i = 1, #ACTIONS do
    local action = ACTIONS[i]
    strategies[#strategies + 1] = {
        name = action.name,
        matches = function(context) return NS.action_matches(context, action) end,
        execute = function(context) return NS.action_execute(context, action, "[BALANCE]") end,
    }
end

NS.rotation_registry:register("balance", strategies, { get_state = function(context) return context end })
NS.log("Druid balance rotation registered")
return strategies
