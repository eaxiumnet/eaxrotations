-- dungeon_detector_sylvanas.lua — Detect and skip dungeon/instance quests
-- WHAT:  Scans Zygor step text and quest objectives for dungeon keywords.
--        Also checks if the player is currently inside an instance.
-- WHEN:  goal_filter pass + idle state goal selection.
-- WHY:   prevents the bot from getting stuck at instance portals or
--        attempting solo dungeon quests.
-- SAFETY: pcall on all API calls; text matching is case-insensitive;
--          no state mutations.

local M = {}

-- ============================================================================
-- Constants
-- ============================================================================

local _DUNGEON_STEP_PATTERNS = {
    "[Ee]nter .-[Dd]ungeon",
    "[Gg]o inside .-[Ii]nstance",
    "[Cc]omplete inside .-[Dd]ungeon",
    "[Hh]eroic .-[Dd]ungeon",
    "[Mm]ust be completed in .-[Dd]ungeon",
    "[Mm]ust be completed in .-[Hh]eroic",
    "[Rr]aid",
    "[Dd]ungeon",
    "[Ii]nstance",
}

local _DUNGEON_QUEST_PATTERNS = {
    "[Tt]his quest must be completed in .-[Dd]ungeon",
    "[Tt]his quest must be completed in .-[Hh]eroic",
    "[Hh]eroic .-[Dd]ungeon",
    "[Rr]aid",
}

-- ============================================================================
-- Helpers
-- ============================================================================

--- Check text against dungeon patterns.
-- @param text string|nil
-- @param patterns table Array of Lua patterns.
-- @return boolean
local function text_matches_any(text, patterns)
    if not text then return false end
    for _, pattern in ipairs(patterns) do
        if text:find(pattern) then return true end
    end
    return false
end

--- Scan quest objective text for dungeon indicators.
-- @param quest_id number|nil
-- @return boolean
local function quest_is_dungeon(quest_id)
    if not quest_id then return false end

    local ok, count = pcall(core.quests.get_num_quest_log_entries)
    if not ok or not count then return false end

    for i = 1, count do
        local ok2, info = pcall(core.quests.get_quest_log_title, i)
        if ok2 and info and info.quest_id == quest_id and not info.is_header then
            -- Check leader board text for dungeon keywords
            local ok3, num_boards = pcall(core.quests.get_num_quest_leader_boards, i)
            if ok3 and num_boards then
                for j = 1, num_boards do
                    local ok4, text = pcall(core.quests.get_quest_log_leader_board, j, i)
                    if ok4 and text and text_matches_any(text, _DUNGEON_QUEST_PATTERNS) then
                        return true
                    end
                end
            end
            -- Also check the quest title itself
            if text_matches_any(info.title, _DUNGEON_QUEST_PATTERNS) then
                return true
            end
            break
        end
    end
    return false
end

-- ============================================================================
-- Core Logic
-- ============================================================================

--- Check if the player is currently inside an instance.
-- @return boolean
function M.player_in_instance()
    local ok, instance_type = pcall(core.get_instance_type)
    if ok and instance_type and instance_type ~= "none" and instance_type ~= 0 then
        return true
    end
    return false
end

--- Check if a goal indicates a dungeon quest.
-- @param goal table|nil Zygor goal table.
-- @param step_text string|nil Current Zygor step text.
-- @return boolean True if dungeon quest detected.
function M.is_dungeon_goal(goal, step_text)
    if not goal then return false end

    -- Check step text
    if text_matches_any(step_text, _DUNGEON_STEP_PATTERNS) then
        return true
    end

    -- Check goal text/name
    local goal_text = nil
    if type(goal) == "table" then
        goal_text = goal.text or goal.name or nil
    end
    if text_matches_any(goal_text, _DUNGEON_STEP_PATTERNS) then
        return true
    end

    -- Check quest log objective text
    local quest_id = nil
    if type(goal) == "table" then
        quest_id = goal.quest_id
    end
    if quest_is_dungeon(quest_id) then
        return true
    end

    return false
end

--- Full check: is this a dungeon quest AND the player is NOT inside an instance?
-- When inside an instance, we allow dungeon quests (user is presumably grouped).
-- @param goal table|nil
-- @param step_text string|nil
-- @return boolean True if the bot should SKIP this goal.
function M.should_skip(goal, step_text)
    -- If already inside an instance, allow all goals
    if M.player_in_instance() then return false end
    return M.is_dungeon_goal(goal, step_text)
end

return M
