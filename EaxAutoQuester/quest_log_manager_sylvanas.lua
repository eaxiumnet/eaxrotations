-- quest_log_manager_sylvanas.lua — Quest log maintenance for EaxAutoQuester
-- WHAT:  Detects grey (trivial) quests and abandoned quests; auto-abandons
--        when log is near full (>20 entries) or when explicitly grey.
-- WHEN:  idle state, throttled to once per 30s.
-- WHY:   prevents quest log bloat which blocks new quest acceptance.
-- SAFETY: never abandons quests with "(Low Level)" indicator from Zygor; pcall
--         on all API calls; maintains blacklist of manually-abandoned quests.

local M = {}

-- ============================================================================
-- Constants
-- ============================================================================

local _GREY_LEVEL_DELTA = 7       -- quest_level < player_level - 7 → grey
local _LOG_CAPACITY = 25          -- max quest log entries in TBC
local _ABANDON_THRESHOLD = 20     -- abandon grey when log has ≥ this many entries
local _CHECK_INTERVAL = 30.0      -- throttle: once per 30 seconds

-- ============================================================================
-- State
-- ============================================================================

local _last_check_time = 0
local _abandoned_quest_ids = {}   -- blacklist: don't re-abandon same quest

-- ============================================================================
-- Helpers
-- ============================================================================

--- Get player level safely.
-- @return number|nil
local function get_player_level()
    local me = core.object_manager.get_local_player()
    if not me then return nil end
    local ok, level = pcall(function() return me:get_level() end)
    if ok then return level end
    return nil
end

--- Scan quest log and return list of quests with metadata.
-- @return table[] Each entry: { index, quest_id, title, level, is_complete, is_grey }
function M.scan_quest_log()
    local ok, count = pcall(core.quests.get_num_quest_log_entries)
    if not ok or not count then return {} end

    local player_level = get_player_level()
    local quests = {}

    for i = 1, count do
        local ok2, info = pcall(core.quests.get_quest_log_title, i)
        if ok2 and info and not info.is_header then
            local q = {
                index = i,
                quest_id = info.quest_id,
                title = info.title or "?",
                level = info.level or 0,
                is_complete = info.is_complete or false,
            }
            if player_level and q.level > 0 then
                q.is_grey = q.level < (player_level - _GREY_LEVEL_DELTA)
            else
                q.is_grey = false
            end
            quests[#quests + 1] = q
        end
    end

    return quests
end

--- Find grey quests that are safe to abandon (not complete, not blacklisted).
-- @return table[] List of grey quest entries.
function M.find_grey_quests()
    local all = M.scan_quest_log()
    local grey = {}
    for _, q in ipairs(all) do
        if q.is_grey and not q.is_complete and not _abandoned_quest_ids[q.quest_id] then
            grey[#grey + 1] = q
        end
    end
    return grey
end

--- Abandon a quest by its log index.
-- @param quest_id number
-- @param log_index number
-- @return boolean
function M.abandon_quest(quest_id, log_index)
    if not quest_id or not log_index then return false end
    if _abandoned_quest_ids[quest_id] then return false end

    local ok = pcall(function()
        core.quests.set_abandon_quest(log_index)
        core.quests.abandon_quest()
    end)

    if ok then
        _abandoned_quest_ids[quest_id] = true
        if core.log then
            core.log("[EaxAutoQuester] Abandoned grey quest: " .. tostring(quest_id))
        end
        return true
    end
    return false
end

--- Main maintenance check: abandon grey quests if log is bloated.
-- Call from idle state, throttled internally.
-- @return number Number of quests abandoned this call.
function M.maintenance_check()
    local now = core.time()
    if now - _last_check_time < _CHECK_INTERVAL then return 0 end
    _last_check_time = now

    local ok, count = pcall(core.quests.get_num_quest_log_entries)
    if not ok or not count or count < _ABANDON_THRESHOLD then return 0 end

    local grey = M.find_grey_quests()
    if #grey == 0 then return 0 end

    -- Abandon up to 3 grey quests per check (gentle)
    local abandoned = 0
    for i = 1, math.min(#grey, 3) do
        local q = grey[i]
        if M.abandon_quest(q.quest_id, q.index) then
            abandoned = abandoned + 1
        end
    end

    return abandoned
end

return M
