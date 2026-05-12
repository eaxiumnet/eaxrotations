-- Readability notes:
--   What: Mage Fire priority list.
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
local SCORCH_DEBUFF = { 22959 }

local COMBUSTION_ACTION = { name = "Combustion", spell = SPELLS.Combustion, target = "self", combat = true, cooldown = 180, requires_target = false }
local SCORCH_ACTION = { name = "Scorch", spell = SPELLS.Scorch, not_moving = true, debuff = { 22959 }, min_debuff_stacks = 5 }

local function combustion_matches(context, action)
    if not NS.should_use_long_cd(context, action.cooldown) then return false end
    if context.should_burst then return NS.action_matches(context, action) end
    if context.settings and context.settings.use_cooldowns == false then return false end
    return NS.action_matches(context, action)
end

COMBUSTION_ACTION.matches = combustion_matches
COMBUSTION_ACTION.is_burst = true

local ACTIONS = {
    COMBUSTION_ACTION,
    SCORCH_ACTION,
    { name = "Fireball", spell = SPELLS.Fireball, not_moving = true },
    { name = "FireBlast", spell = SPELLS.FireBlast, cooldown = 8 },
    { name = "Flamestrike", spell = SPELLS.Flamestrike, position = "target", enemy_count = 3, min_mana = 30, not_moving = true, not_casting = true, cooldown = 16 },
    { name = "FlamestrikeRank6", spell = SPELLS.FlamestrikeRank6, position = "target", enemy_count = 3, min_mana = 30, not_moving = true, not_casting = true, cooldown = 16 },
    { name = "Blizzard", spell = SPELLS.Blizzard, position = "target", enemy_count = 3, not_moving = true, not_casting = true },
}

local strategies = {}
for i = 1, #ACTIONS do
    local action = ACTIONS[i]
    strategies[#strategies + 1] = {
        name = action.name,
        matches = function(context) return action.matches and action.matches(context, action) or NS.action_matches(context, action) end,
        execute = function(context) return NS.action_execute(context, action, "[FIRE]") end,
    }
end

NS.rotation_registry:register("fire", strategies, { get_state = function(context) return context end })
NS.log("Mage fire rotation registered")
return strategies
