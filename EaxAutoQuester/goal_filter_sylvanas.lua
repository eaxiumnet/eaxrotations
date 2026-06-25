-- What: Filter Zygor goals against player state (quest progress, level, class, faction)
-- When: Before selecting a goal to execute
-- Why: Skip completed, level-gated, class-restricted, or faction-restricted goals
-- Safety: All API calls pcall-guarded; Pattern 2 (cache APIs at load), Pattern 14 (nil-guards)
-- API: core.quests.is_quest_flagged_completed, me:get_level(), me:get_class(), me:get_faction_id()

-- ============================================================================
-- Hot-path API Caching at Module Load (Pattern 2 from AGENTS.md)
-- ============================================================================

local _safe_api = nil
local function ensure_safe_api()
    if not _safe_api then
        local ok, api = pcall(require, "EaxAutoQuester/safe_api_wrapper")
        if ok then _safe_api = api end
    end
    return _safe_api
end

-- Probed API handles — populated once at load via build_checkers()
local _probed = {}

-- Class ID → name lookup (TBC client: class_id 1-11)
local CLASS_NAMES = {
    [1]  = "Warrior",
    [2]  = "Paladin",
    [3]  = "Hunter",
    [4]  = "Rogue",
    [5]  = "Priest",
    [6]  = "Death Knight",
    [7]  = "Shaman",
    [8]  = "Mage",
    [9]  = "Warlock",
    [10] = "Monk",
    [11] = "Druid",
    [12] = "Demon Hunter",
}

-- ============================================================================
-- Load-time API Probing (Pattern 2)
-- ============================================================================

local function build_checkers()
    local safe_api = ensure_safe_api()
    if not safe_api then return end

    -- Probe is_quest_flagged_completed with test arg 1 (nominal quest_id)
    local ok, wrapped = pcall(function()
        return safe_api.wrap(core.quests.is_quest_flagged_completed, { 1 })
    end)
    if ok and wrapped then
        _probed.is_quest_flagged_completed = wrapped
    end
end

-- Initialize at load
build_checkers()

-- ============================================================================
-- Static Table Reuse (Pattern 4 from AGENTS.md)
-- ============================================================================

local _t = { n = 0 }

-- ============================================================================
-- Module
-- ============================================================================

local M = {}

--- Filter a Zygor goal against player state.
--- All field reads nil-guarded (Pattern 14). All game_object method calls pcall-guarded.
--- @param goal table|nil   -- Raw goal table from zygor live API
--- @param me game_object|nil
--- @param core_proxy table|nil -- table of probed APIs (see safe_api_wrapper); nil falls back to raw core.*
--- @return boolean passes, string|nil skip_reason
function M.passes(goal, me, core_proxy)
    -- Pattern 14: nil goal or nil me → pass through (can't filter)
    if not goal or not me then return true, nil end

    -- ========================================================================
    -- 1. Quest completed check
    -- ========================================================================
    local quest_id = goal.quest_id  -- Pattern 14: nil → handled by > 0 comparsion
    if quest_id and quest_id > 0 then
        local completed = false

        -- Try in order: core_proxy → probed handle → raw pcall
        if core_proxy and core_proxy.is_quest_flagged_completed then
            local ok, r = pcall(core_proxy.is_quest_flagged_completed, quest_id)
            completed = ok and r == true
        elseif _probed.is_quest_flagged_completed then
            local ok, r = pcall(_probed.is_quest_flagged_completed, quest_id)
            completed = ok and r == true
        else
            local ok, r = pcall(core.quests.is_quest_flagged_completed, quest_id)
            completed = ok and r == true
        end

        if completed then return false, "completed" end
    end

    -- ========================================================================
    -- 2. Level check
    -- ========================================================================
    local min_level = goal.min_level  -- Pattern 14: nil → type check skips
    if type(min_level) == "number" and min_level > 0 then
        local ok, level = pcall(function() return me:get_level() end)
        local player_level = ok and level or 0  -- Pattern 14: nil → 0
        if player_level < min_level then
            return false, "level_too_low"
        end
    end

    -- ========================================================================
    -- 3. Class check
    -- ========================================================================
    local goal_class = goal.class  -- Pattern 14: nil → skipped
    if goal_class then
        local ok, class_id = pcall(function() return me:get_class() end)
        local player_class = ok and class_id
        if player_class then
            if type(goal_class) == "number" and player_class ~= goal_class then
                return false, "class_mismatch"
            end
            if type(goal_class) == "string" then
                local name = CLASS_NAMES[player_class]
                if name and name ~= goal_class then
                    return false, "class_mismatch"
                end
            end
        end
    end

    -- ========================================================================
    -- 4. Faction check
    -- ========================================================================
    local goal_faction = goal.faction  -- Pattern 14: nil → type check skips
    if type(goal_faction) == "number" then
        local ok, faction = pcall(function() return me:get_faction_id() end)
        local player_faction = ok and faction or -1  -- Pattern 14: nil → -1 (force mismatch)
        if player_faction ~= goal_faction then
            return false, "faction_mismatch"
        end
    end

    -- ========================================================================
    -- 5. Passes all checks
    -- ========================================================================
    return true, nil
end

-- ============================================================================
-- Exports
-- ============================================================================

_G.EaxAutoQuester = _G.EaxAutoQuester or {}
_G.EaxAutoQuester.goal_filter = M
return M
