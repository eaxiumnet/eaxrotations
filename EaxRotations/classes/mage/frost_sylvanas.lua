-- Readability notes:
--   What: Mage Frost priority list.
--   When: dispatcher runs this playstyle when selected.
--   Why: action rows show what is cast, why it is gated, and when it is allowed.
--   Safety: all rows use shared spell/resource/range/form checks before casting.

-- Decision notes:
--   Playstyle files are ordered priority lists: earlier strategies must be more urgent or more time-sensitive.
--   Matches functions explain when an action is allowed; execute functions only perform the already-gated cast.
--   Role logic follows TBC expectations and avoids post-TBC spells, speculative target swaps, and impossible casts.
local NS = _G.EaxRotations
if not NS then return nil end
local SPELLS = NS.MageSpells or {}

local ACTIONS = {
    { name = "IceBlock", spell = SPELLS.IceBlock, target = "self", max_hp = 20, requires_target = false },
    { name = "IcyVeins", spell = SPELLS.IcyVeins, target = "self", combat = true, cooldown = 180, requires_target = false, setting = "use_cooldowns" },
    { name = "WaterElemental", spell = SPELLS.WaterElemental, target = "self", combat = true, cooldown = 180, requires_target = false },
    { name = "Frostbolt", spell = SPELLS.Frostbolt, not_moving = true },
    { name = "IceLance", spell = SPELLS.IceLance },
    { name = "Blizzard", spell = SPELLS.Blizzard, position = "target", enemy_count = 3, not_moving = true },
}

local strategies = {}
for i = 1, #ACTIONS do
    local action = ACTIONS[i]
    strategies[#strategies + 1] = {
        name = action.name,
        matches = function(context) return NS.action_matches(context, action) end,
        execute = function(context) return NS.action_execute(context, action, "[FROST]") end,
    }
end

NS.rotation_registry:register("frost", strategies, { get_state = function(context) return context end })
NS.log("Mage frost rotation registered")
return strategies
