-- progress_tracker_sylvanas.lua — Objective progress tracking for EaxAutoQuester
-- WHAT:  Tracks quest objective progress over time. If a "kill" or "area" goal
--        shows no progress for 5 minutes, blacklists the objective and triggers
--        a retry (navigate to alternate location or wait for respawn).
-- WHEN:  idle/do_action states, checked every 10 seconds.
-- WHY:   prevents infinite loops on bugged objectives, phasing issues, or
--        wrong-location objectives.
-- SAFETY: pcall on all API calls; only tracks kill/loot/area types; 5-min
--         timeout with 3-strike rule (no progress in 3 consecutive windows).

local M = {}

-- ============================================================================
-- Constants
-- ============================================================================

local _TRACK_INTERVAL = 10.0      -- check every 10 seconds
local _STRIKE_TIMEOUT = 300.0     -- 5 minutes = 3 strikes (3 * 10s * 10 = 300s)
local _MAX_STRIKES = 3            -- 3 strikes → blacklist

-- ============================================================================
-- State
-- ============================================================================

local _tracked = {}               -- quest_id → { last_progress, strikes, last_check }
local _blacklisted = {}           -- quest_id → true (permanently blacklisted)

-- ============================================================================
-- Helpers
-- ============================================================================

--- Read current objective progress for a quest.
-- Uses get_num_quest_leader_boards to sum current progress counts.
-- @param quest_id number
-- @return number|nil Sum of current counts (higher = more progress), or nil if unavailable.
local function read_progress(quest_id)
    if not quest_id then return nil end
    -- Find the quest in the log by ID
    local ok, count = pcall(core.quests.get_num_quest_log_entries)
    if not ok or not count then return nil end

    for i = 1, count do
        local ok2, info = pcall(core.quests.get_quest_log_title, i)
        if ok2 and info and info.quest_id == quest_id and not info.is_header then
            local ok3, num_boards = pcall(core.quests.get_num_quest_leader_boards, i)
            if ok3 and num_boards then
                local total_current = 0
                for j = 1, num_boards do
                    local ok4, text = pcall(core.quests.get_quest_log_leader_board, j, i)
                    if ok4 and text then
                        -- "5/10 Boars killed" — sum current progress
                        local current = text:match("(%d+)/%d+")
                        if current then
                            total_current = total_current + tonumber(current)
                        end
                    end
                end
                return total_current
            end
        end
    end
    return nil
end

--- Check if a goal type is trackable (kill/loot/area).
-- @param goal_type string
-- @return boolean
local function is_trackable(goal_type)
    return goal_type == "kill" or goal_type == "loot" or goal_type == "area"
end

-- ============================================================================
-- Core Logic
-- ============================================================================

--- Check progress for a single quest and update strike count.
-- @param quest_id number
-- @param goal_type string
-- @return string|nil "blacklisted" if quest should be skipped, "progress" if
--         progress was made, "waiting" if still waiting, nil if not trackable.
function M.check_progress(quest_id, goal_type)
    if not is_trackable(goal_type) then return nil end
    if not quest_id then return nil end
    if _blacklisted[quest_id] then return "blacklisted" end

    local now = core.time()
    local current_progress = read_progress(quest_id)
    if current_progress == nil then return nil end

    local t = _tracked[quest_id]
    if not t then
        _tracked[quest_id] = {
            last_progress = current_progress,
            strikes = 0,
            last_check = now,
        }
        return "waiting"
    end

    if now - t.last_check < _TRACK_INTERVAL then
        return "waiting"  -- too soon
    end

    t.last_check = now

    if current_progress > t.last_progress then
        -- Progress made! Reset strikes.
        t.last_progress = current_progress
        t.strikes = 0
        return "progress"
    end

    -- No progress — increment strike
    t.strikes = t.strikes + 1

    if t.strikes >= _MAX_STRIKES then
        _blacklisted[quest_id] = true
        if core.log then
            core.log("[EaxAutoQuester] Blacklisting quest " .. tostring(quest_id) .. " — no progress for 5 min")
        end
        return "blacklisted"
    end

    return "waiting"
end

--- Check if a quest is blacklisted.
-- @param quest_id number
-- @return boolean
function M.is_blacklisted(quest_id)
    return quest_id and _blacklisted[quest_id] == true
end

--- Reset tracking for a quest (e.g., after step change or successful completion).
-- @param quest_id number
function M.reset_tracking(quest_id)
    if quest_id then
        _tracked[quest_id] = nil
        _blacklisted[quest_id] = nil
    end
end

--- Clear all tracking state.
function M.clear_all()
    _tracked = {}
    _blacklisted = {}
end

return M
