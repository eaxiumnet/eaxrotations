-- Readability notes:
--   What: Druid Cat priority list.
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
local RIP_DEBUFF = { 27008, 1079 }
local RAKE_DEBUFF = { 1822 }

local function rip_matches(context, action)
    local target = context.target
    if not target then return false end
    local remains = NS.debuff_remains and NS.debuff_remains(target, RIP_DEBUFF) or 0
    if not NS.should_refresh_dot(remains, 3, context.ttd, 12) then return false end
    return NS.action_matches(context, action)
end

local function rake_matches(context, action)
    local target = context.target
    if not target then return false end
    local remains = NS.debuff_remains and NS.debuff_remains(target, RAKE_DEBUFF) or 0
    if not NS.should_refresh_dot(remains, 3, context.ttd, 9) then return false end
    return NS.action_matches(context, action)
end

local ACTIONS = {
    { name = "CatForm", spell = SPELLS.CatForm, target = "self", kind = "form", form = "cat", requires_target = false },
    { name = "Prowl", spell = SPELLS.Prowl, target = "self", kind = "buff", buff = { 9913, 6783, 5215 }, ooc = true, required_form = "cat", requires_target = false },
    { name = "RavageOpener", spell = SPELLS.Ravage, requires_buff = { 9913, 6783, 5215 }, requires_behind = true, min_energy = 60 },
    { name = "MangleDebuff", spell = SPELLS.MangleCat, required_form = "cat", min_energy = 45, debuff = { 33876, 33983, 33982, 33878, 33986, 33987 }, refresh = 3 },
    { name = "Rip", spell = SPELLS.Rip, required_form = "cat", min_combo = 4, min_energy = 30, matches = rip_matches },
    { name = "FerociousBite", spell = SPELLS.FerociousBite, required_form = "cat", target_max_hp = 25, min_combo = 4, min_energy = 35 },
    { name = "Shred", spell = SPELLS.Shred, required_form = "cat", requires_behind = true, min_energy = 40 },
    { name = "Rake", spell = SPELLS.Rake, required_form = "cat", min_energy = 40, matches = rake_matches },
    { name = "Mangle", spell = SPELLS.MangleCat, required_form = "cat", min_energy = 45 },
    { name = "Claw", spell = SPELLS.Claw, required_form = "cat", min_energy = 45 },
}

local strategies = {}
for i = 1, #ACTIONS do
    local action = ACTIONS[i]
    strategies[#strategies + 1] = {
        name = action.name,
        matches = function(context) return action.matches and action.matches(context, action) or NS.action_matches(context, action) end,
        execute = function(context) return NS.action_execute(context, action, "[CAT]") end,
    }
end

NS.rotation_registry:register("cat", strategies, { get_state = function(context) return context end })
NS.log("Druid cat rotation registered")
return strategies
