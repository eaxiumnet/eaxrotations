-- Readability notes:
--   What: Warrior Arms priority list.
--   When: dispatcher runs this playstyle when selected.
--   Why: action rows show what is cast, why it is gated, and when it is allowed.
--   Safety: all rows use shared spell/resource/range/form checks before casting.

-- Decision notes:
--   Playstyle files are ordered priority lists: earlier strategies must be more urgent or more time-sensitive.
--   Matches functions explain when an action is allowed; execute functions only perform the already-gated cast.
--   Role logic follows TBC expectations and avoids post-TBC spells, speculative target swaps, and impossible casts.
local NS = _G.EaxRotations
if not NS then return nil end
local SPELLS = NS.WarriorSpells or {}

local function execute_matches(context, action)
    if not NS.is_execute_phase(context.target_hp, 20) then return false end
    return NS.action_matches(context, action)
end

local ACTIONS = {
    { name = "BattleStance", spell = SPELLS.BattleStance, target = "self", kind = "form", form = "battle", requires_target = false },
    { name = "BattleShout", spell = SPELLS.BattleShout, target = "self", kind = "buff", buff = { 25289, 2048, 11551, 11550, 11549, 6192, 5242, 6673 }, requires_target = false },
    { name = "MortalStrike", spell = SPELLS.MortalStrike, required_stance = 1, min_rage = 30, cooldown = 6 },
    { name = "Overpower", spell = SPELLS.Overpower, required_stance = 1, min_rage = 5 },
    { name = "Execute", spell = SPELLS.Execute, min_rage = 15, matches = execute_matches },
    { name = "HeroicStrike", spell = SPELLS.HeroicStrike, min_rage = 45 },
}

local strategies = {}
for i = 1, #ACTIONS do
    local action = ACTIONS[i]
    strategies[#strategies + 1] = {
        name = action.name,
        matches = function(context) return action.matches and action.matches(context, action) or NS.action_matches(context, action) end,
        execute = function(context) return NS.action_execute(context, action, "[ARMS]") end,
    }
end

NS.rotation_registry:register("arms", strategies, { get_state = function(context) return context end })
NS.log("Warrior arms rotation registered")
return strategies
