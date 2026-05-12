-- Readability notes:
--   What: Shaman Elemental priority list.
--   When: dispatcher runs this playstyle when selected.
--   Why: action rows show what is cast, why it is gated, and when it is allowed.
--   Safety: all rows use shared spell/resource/range/form checks before casting.

-- Decision notes:
--   Playstyle files are ordered priority lists: earlier strategies must be more urgent or more time-sensitive.
--   Matches functions explain when an action is allowed; execute functions only perform the already-gated cast.
--   Role logic follows TBC expectations and avoids post-TBC spells, speculative target swaps, and impossible casts.
local NS = _G.EaxRotations
if not NS then return nil end
local SPELLS = NS.ShamanSpells or {}

local ACTIONS = {
    { name = "LightningShield", spell = SPELLS.LightningShield, target = "self", kind = "buff", buff = { 25472, 25469, 10432, 10431, 8134, 945, 905, 325, 324 }, requires_target = false },
    { name = "Bloodlust", spell = SPELLS.Bloodlust, target = "self", combat = true, setting = "use_cooldowns", cooldown = 600, min_mana = 25, requires_target = false },
    { name = "ChainLightning", spell = SPELLS.ChainLightning, not_moving = true, cooldown = 6 },
    { name = "LightningBolt", spell = SPELLS.LightningBolt, not_moving = true },
    { name = "FlameShockMoving", spell = SPELLS.FlameShock, debuff = { 25457, 29228, 10448, 10447, 8053, 8052, 8050 }, refresh = 3, moving = true, cooldown = 6 },
    { name = "EarthShockMoving", spell = SPELLS.EarthShock, moving = true, cooldown = 6 },
}

local strategies = {}
for i = 1, #ACTIONS do
    local action = ACTIONS[i]
    strategies[#strategies + 1] = {
        name = action.name,
        matches = function(context) return NS.action_matches(context, action) end,
        execute = function(context) return NS.action_execute(context, action, "[ELEMENTAL]") end,
    }
end

NS.rotation_registry:register("elemental", strategies, { get_state = function(context) return context end })
NS.log("Shaman elemental rotation registered")
return strategies
