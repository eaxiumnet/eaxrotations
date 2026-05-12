-- Readability notes:
--   What: Mage Arcane priority list.
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
    { name = "ManaShield", spell = SPELLS.ManaShield, target = "self", kind = "buff", max_hp = 50, requires_target = false },
    { name = "ArcanePower", spell = SPELLS.ArcanePower, target = "self", combat = true, cooldown = 180, requires_target = false, setting = "use_cooldowns" },
    { name = "ArcaneBlast", spell = SPELLS.ArcaneBlast, not_moving = true },
    { name = "ArcaneMissiles", spell = SPELLS.ArcaneMissiles, not_moving = true },
    { name = "FireBlast", spell = SPELLS.FireBlast, cooldown = 8 },
}

local strategies = {}
for i = 1, #ACTIONS do
    local action = ACTIONS[i]
    strategies[#strategies + 1] = {
        name = action.name,
        matches = function(context) return NS.action_matches(context, action) end,
        execute = function(context) return NS.action_execute(context, action, "[ARCANE]") end,
    }
end

NS.rotation_registry:register("arcane", strategies, { get_state = function(context) return context end })
NS.log("Mage arcane rotation registered")
return strategies
