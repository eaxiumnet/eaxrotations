-- Readability notes:
--   What: Druid Bear priority list.
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
    { name = "BearForm", spell = SPELLS.BearForm, target = "self", kind = "form", form = "bear", requires_target = false },
    { name = "FrenziedRegeneration", spell = SPELLS.FrenziedRegeneration, target = "self", max_hp = 35, min_rage = 10, requires_target = false },
    { name = "DemoralizingRoar", spell = SPELLS.DemoralizingRoar, target = "self", required_form = "bear", min_rage = 10, cooldown = 25, requires_target = false },
    { name = "FaerieFireFeral", spell = SPELLS.FaerieFireFeral, required_form = "bear", debuff = { 27011, 17392, 17391, 17390, 16857, 26993, 9907, 9749, 778, 770 }, refresh = 4 },
    { name = "SwipeAoE", spell = SPELLS.SwipeBear, target = "self", required_form = "bear", enemy_count = 3, min_rage = 20, requires_target = false },
    { name = "MangleBear", spell = SPELLS.MangleBear, required_form = "bear", min_rage = 15 },
    { name = "Lacerate", spell = SPELLS.Lacerate, required_form = "bear", min_rage = 15, max_enemy_count = 2, debuff = { 33745 }, min_debuff_stacks = 5, refresh = 3 },
    { name = "Swipe", spell = SPELLS.SwipeBear, target = "self", required_form = "bear", enemy_count = 2, min_rage = 20, requires_target = false },
    { name = "Maul", spell = SPELLS.Maul, required_form = "bear", min_rage = 35 },
}

local strategies = {}
for i = 1, #ACTIONS do
    local action = ACTIONS[i]
    strategies[#strategies + 1] = {
        name = action.name,
        matches = function(context) return NS.action_matches(context, action) end,
        execute = function(context) return NS.action_execute(context, action, "[BEAR]") end,
    }
end

NS.rotation_registry:register("bear", strategies, { get_state = function(context) return context end })
NS.log("Druid bear rotation registered")
return strategies
