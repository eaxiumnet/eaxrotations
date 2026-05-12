-- Readability notes:
--   What: Warlock Affliction priority list.
--   When: dispatcher runs this playstyle when selected.
--   Why: action rows show what is cast, why it is gated, and when it is allowed.
--   Safety: all rows use shared spell/resource/range/form checks before casting.

-- Decision notes:
--   Playstyle files are ordered priority lists: earlier strategies must be more urgent or more time-sensitive.
--   Matches functions explain when an action is allowed; execute functions only perform the already-gated cast.
--   Role logic follows TBC expectations and avoids post-TBC spells, speculative target swaps, and impossible casts.
local NS = _G.EaxRotations
if not NS then return nil end
local SPELLS = NS.WarlockSpells or {}

local CURSE_OF_DOOM_DEBUFF = { 30910, 603 }

local ACTIONS = {
    { name = "FelArmor", spell = SPELLS.FelArmor, target = "self", kind = "buff", buff = { 28189, 28176 }, requires_target = false },
    { name = "CurseOfDoom", spell = SPELLS.CurseOfDoom, debuff = CURSE_OF_DOOM_DEBUFF, refresh = 5, cooldown = 60, min_ttd = 62, require_ttd = true, target_not_player = true },
    { name = "CurseOfAgony", spell = SPELLS.CurseOfAgony, debuff = { 27218, 11713, 11712, 11711, 6217, 1014, 980 }, blocked_debuff = CURSE_OF_DOOM_DEBUFF, refresh = 3 },
    { name = "Corruption", spell = SPELLS.Corruption, debuff = { 27216, 25311, 11672, 11671, 7648, 6223, 6222, 172 }, refresh = 3 },
    { name = "UnstableAffliction", spell = SPELLS.UnstableAffliction, debuff = { 30405, 30404, 30108 }, refresh = 3, not_moving = true },
    { name = "SiphonLife", spell = SPELLS.SiphonLife, debuff = { 30911, 27264, 18881, 18880, 18879, 18265 }, refresh = 3 },
    { name = "LifeTap", spell = SPELLS.LifeTap, target = "self", min_hp = 55, max_mana = 65, requires_target = false },
    { name = "ShadowBolt", spell = SPELLS.ShadowBolt, not_moving = true },
}

local strategies = {}
for i = 1, #ACTIONS do
    local action = ACTIONS[i]
    strategies[#strategies + 1] = {
        name = action.name,
        matches = function(context) return NS.action_matches(context, action) end,
        execute = function(context) return NS.action_execute(context, action, "[AFFLICTION]") end,
    }
end

NS.rotation_registry:register("affliction", strategies, { get_state = function(context) return context end })
NS.log("Warlock affliction rotation registered")
return strategies
