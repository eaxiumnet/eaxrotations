-- Readability notes:
--   What: Hunter Survival priority list.
--   When: dispatcher runs this playstyle when selected.
--   Why: action rows show what is cast, why it is gated, and when it is allowed.
--   Safety: all rows use shared spell/resource/range/form checks before casting.

-- Decision notes:
--   Playstyle files are ordered priority lists: earlier strategies must be more urgent or more time-sensitive.
--   Matches functions explain when an action is allowed; execute functions only perform the already-gated cast.
--   Role logic follows TBC expectations and avoids post-TBC spells, speculative target swaps, and impossible casts.
local NS = _G.EaxRotations
if not NS then return nil end
local SPELLS = NS.HunterSpells or {}

local AUTO_SHOT_BUFFER_MS = 100
local MULTI_SHOT_CAST_MS = 500

local function can_cast_steady(context, action)
    if not NS.action_matches(context, action) then return false end
    local tracker = NS.HunterClipTracker
    if tracker and type(tracker.can_cast_steady) == "function" then
        return tracker.can_cast_steady() ~= false
    end
    return true
end

local function can_cast_before_auto(context, action, cast_ms)
    if not NS.action_matches(context, action) then return false end
    local tracker = NS.HunterClipTracker
    if tracker and type(tracker.ms_until_auto) == "function" then
        local remain = tracker.ms_until_auto()
        return remain == 0 or remain > cast_ms + AUTO_SHOT_BUFFER_MS
    end
    return true
end

local function record_manual_shot()
    local tracker = NS.HunterClipTracker
    if tracker and type(tracker.record_manual_shot) == "function" then
        tracker.record_manual_shot()
    end
end

local function execute_action(context, action, prefix)
    if NS.action_execute(context, action, prefix) then
        if action.after_cast then action.after_cast(context, action) end
        return true
    end
    return false
end

local ACTIONS = {
    { name = "MendPet", spell = SPELLS.MendPet, target = "pet", max_hp = 45, requires_target = false },
    { name = "HuntersMark", spell = SPELLS.HuntersMark, debuff = { 14325, 14324, 14323, 1130 }, refresh = 10 },
    { name = "RapidFire", spell = SPELLS.RapidFire, target = "self", combat = true, cooldown = 300, requires_target = false, setting = "use_cooldowns" },
    { name = "ExplosiveTrap", spell = SPELLS.ExplosiveTrap, target = "self", enemy_count = 7, cooldown = 30, requires_target = false },
    { name = "KillCommand", spell = SPELLS.KillCommand, combat = true, cooldown = 5, skip_gcd = true },
    { name = "MultiShot", spell = SPELLS.MultiShot, cooldown = 10, matches = function(context, action) return can_cast_before_auto(context, action, MULTI_SHOT_CAST_MS) end, after_cast = record_manual_shot },
    { name = "SteadyShot", spell = SPELLS.SteadyShot, not_moving = true, matches = can_cast_steady, after_cast = record_manual_shot },
    { name = "ArcaneShot", spell = SPELLS.ArcaneShot, cooldown = 6, after_cast = record_manual_shot },
    { name = "SerpentSting", spell = SPELLS.SerpentSting, debuff = { 27016, 25295, 13555, 13554, 13553, 13552, 13551, 13550, 13549, 1978 }, refresh = 3 },
}

local strategies = {}
for i = 1, #ACTIONS do
    local action = ACTIONS[i]
    strategies[#strategies + 1] = {
        name = action.name,
        matches = function(context) return action.matches and action.matches(context, action) or NS.action_matches(context, action) end,
        execute = function(context) return execute_action(context, action, "[SURVIVAL]") end,
    }
end

NS.rotation_registry:register("survival", strategies, { get_state = function(context) return context end })
NS.log("Hunter survival rotation registered")
return strategies
