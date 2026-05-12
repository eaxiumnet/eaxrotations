-- Readability notes:
--   What: Warrior Protection priority list.
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

local ACTIONS = {
    { name = "DefensiveStance", spell = SPELLS.DefensiveStance, target = "self", kind = "form", form = "defensive", requires_target = false },
    { name = "ShieldBlock", spell = SPELLS.ShieldBlock, target = "self", required_stance = 2, min_rage = 10, cooldown = 5, requires_target = false },
    { name = "ShieldSlam", spell = SPELLS.ShieldSlam, required_stance = 2, min_rage = 20, cooldown = 6 },
    { name = "Revenge", spell = SPELLS.Revenge, required_stance = 2, min_rage = 5, cooldown = 5 },
    { name = "Devastate", spell = SPELLS.Devastate, required_stance = 2, min_rage = 15 },
    { name = "SunderArmor", spell = SPELLS.SunderArmor, required_stance = 2, min_rage = 15, debuff = { 25225, 11597, 11596, 8380, 7405, 7386 }, refresh = 3 },
    { name = "DemoralizingShout", spell = SPELLS.DemoralizingShout, target = "self", required_stance = 2, min_rage = 10, cooldown = 25, requires_target = false },
    { name = "ThunderClap", spell = SPELLS.ThunderClap, target = "self", min_rage = 20, enemy_count = 2, cooldown = 4, requires_target = false },
    { name = "HeroicStrike", spell = SPELLS.HeroicStrike, required_stance = 2, min_rage = 55 },
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
NS.log("Warrior protection rotation registered")
return strategies
