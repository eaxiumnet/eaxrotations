-- Readability notes:
--   What: Warrior Fury priority list.
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
local SLAM = SPELLS.Slam or NS.spell_action({ 25242, 25241, 11605, 11604, 8820, 1464 }, "Slam")

local SLAM_RAGE_COST = 15
local BLOODTHIRST_RESERVE = 30
local WHIRLWIND_RESERVE = 25
local CORE_POOL_WINDOW = 2.0

local function burst_cooldown_matches(context, action)
    if not (context.should_burst or (context.settings and context.settings.use_cooldowns ~= false)) then return false end
    if not NS.should_use_long_cd(context, action.cooldown) then return false end
    return NS.action_matches(context, action)
end

local function execute_matches(context, action)
    if not NS.is_execute_phase(context.target_hp, 20) then return false end
    return NS.action_matches(context, action)
end

local function can_cast_slam(context, action)
    if not NS.action_matches(context, action) then return false end

    local rage_after_slam = (context.rage or 0) - SLAM_RAGE_COST
    local bt_cd = NS.cooldown_remains(SPELLS.Bloodthirst, 6)
    if bt_cd <= CORE_POOL_WINDOW and rage_after_slam < BLOODTHIRST_RESERVE then
        return false
    end

    local ww_cd = NS.cooldown_remains(SPELLS.Whirlwind, 10)
    if ww_cd <= CORE_POOL_WINDOW and rage_after_slam < WHIRLWIND_RESERVE then
        return false
    end

    return true
end

local ACTIONS = {
    { name = "BerserkerStance", spell = SPELLS.BerserkerStance, target = "self", kind = "form", form = "berserker", requires_target = false },
    { name = "BattleShout", spell = SPELLS.BattleShout, target = "self", kind = "buff", buff = { 25289, 2048, 11551, 11550, 11549, 6192, 5242, 6673 }, required_stance = 3, requires_target = false },
    { name = "DeathWish", spell = SPELLS.DeathWish, target = "self", combat = true, cooldown = 180, requires_target = false, is_burst = true, matches = burst_cooldown_matches },
    { name = "Rampage", spell = SPELLS.Rampage, target = "self", combat = true, kind = "buff", buff = { 30033, 30032, 30030 }, required_stance = 3, requires_target = false },
    { name = "Bloodthirst", spell = SPELLS.Bloodthirst, required_stance = 3, min_rage = 30, cooldown = 6 },
    { name = "Whirlwind", spell = SPELLS.Whirlwind, required_stance = 3, min_rage = 25, cooldown = 10 },
    { name = "Execute", spell = SPELLS.Execute, min_rage = 15, required_stance = 3, matches = execute_matches },
    { name = "Slam", spell = SLAM, required_stance = 3, min_rage = 15, not_moving = true, matches = can_cast_slam },
    { name = "HeroicStrike", spell = SPELLS.HeroicStrike, required_stance = 3, min_rage = 50 },
}

local strategies = {}
for i = 1, #ACTIONS do
    local action = ACTIONS[i]
    strategies[#strategies + 1] = {
        name = action.name,
        is_burst = action.is_burst,
        matches = function(context) return action.matches and action.matches(context, action) or NS.action_matches(context, action) end,
        execute = function(context) return NS.action_execute(context, action, "[FURY]") end,
    }
end

NS.rotation_registry:register("fury", strategies, { get_state = function(context) return context end })
NS.log("Warrior fury rotation registered")
return strategies
