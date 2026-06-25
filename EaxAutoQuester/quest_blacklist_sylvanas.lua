-- What: Quest blacklist — tracks quest failures with 60s sliding window; abandons after 5 failures
-- When: Loaded at startup; record_failure() called by quest interaction handlers
-- Why: Prevent infinite retry loops on broken quests (missing NPC, unsolvable gossip, area fail)
-- Safety: Standalone module; no hard dependencies; clock injection for testing
-- Decision: In-memory only (no persistence); clock via core.time() with os.clock() fallback

-- ============================================================================
-- Hot-path API Caching at Module Load (Pattern 2 from AGENTS.md)
-- ============================================================================

local _core_time = nil

-- ============================================================================
-- Module Table (defined first, exported at end)
-- ============================================================================

local M = {}

-- ============================================================================
-- Internal State
-- ============================================================================

local failure_log = {}       -- failure_log[quest_id_str] = { {time, reason}, ... }
local abandoned_set = {}     -- abandoned_set[quest_id_str] = true
local WINDOW_SECONDS = 60
local ABANDON_THRESHOLD = 5

-- ============================================================================
-- Default clock: use core.time() with pcall guard, fallback to os.clock()*100
-- ============================================================================

local function _default_clock()
    if _core_time == nil then
        local ok
        ok, _core_time = pcall(function() return core.time end)
    end
    if _core_time then
        return _core_time()
    end
    return os.clock() * 100
end

local _clock = _default_clock

-- ============================================================================
-- Internal Helpers
-- ============================================================================

--- Trim failure entries older than WINDOW_SECONDS for a given quest_id.
--- Runs in O(N) for that quest_id's log.
--- @param key string Quest ID as string
--- @param now number Current clock time
local function _trim(key, now)
    local log = failure_log[key]
    if not log then return end
    local cutoff = now - WINDOW_SECONDS
    local n = 0
    for i = 1, #log do
        if log[i].time >= cutoff then
            n = n + 1
            log[n] = log[i]
        end
    end
    for i = n + 1, #log do
        log[i] = nil
    end
end

-- ============================================================================
-- Public API
-- ============================================================================

--- Record a failure for a quest. Appends a time-stamped entry and trims old ones.
--- Nil-guarded: no-op if quest_id is nil.
--- @param quest_id number|nil Quest ID that failed
--- @param reason string Reason category ('area_fail', 'unsolvable_gossip', 'dead_npc')
function M.record_failure(quest_id, reason)
    if not quest_id then return end
    local key = tostring(quest_id)
    local now = _clock()
    if not failure_log[key] then
        failure_log[key] = {}
    end
    failure_log[key][#failure_log[key] + 1] = { time = now, reason = reason or "unknown" }
    _trim(key, now)
end

--- Check if a quest should be abandoned (5+ failures in 60s window).
--- Also returns true if the quest was previously marked as abandoned.
--- When returning true, records the quest in the abandoned set for the session.
--- Nil-guarded: returns false if quest_id is nil.
--- @param quest_id number|nil Quest ID to check
--- @return boolean true if quest should be abandoned
function M.should_abandon(quest_id)
    if not quest_id then return false end
    local key = tostring(quest_id)

    -- Already abandoned this session?
    if abandoned_set[key] then return true end

    -- Count failures in current 60s window
    local log = failure_log[key]
    if not log then return false end
    local now = _clock()
    local cutoff = now - WINDOW_SECONDS
    local count = 0
    for i = 1, #log do
        if log[i].time >= cutoff then
            count = count + 1
        end
    end

    if count >= ABANDON_THRESHOLD then
        abandoned_set[key] = true
        return true
    end

    return false
end

--- Explicitly mark a quest as abandoned.
--- Quest is blacklisted for the remainder of the session.
--- Nil-guarded: no-op if quest_id is nil.
--- @param quest_id number|nil Quest ID to abandon
function M.mark_abandoned(quest_id)
    if not quest_id then return end
    abandoned_set[tostring(quest_id)] = true
end

--- Check if a quest is blacklisted in this session.
--- Returns true if mark_abandoned was called OR should_abandon previously returned true.
--- Nil-guarded: returns false if quest_id is nil.
--- @param quest_id number|nil Quest ID to check
--- @return boolean true if quest is blacklisted
function M.is_blacklisted(quest_id)
    if not quest_id then return false end
    return abandoned_set[tostring(quest_id)] == true
end

--- Reset blacklist state for one quest_id or all quests.
--- @param quest_id number|nil Specific quest ID to clear, or nil to clear all
function M.reset(quest_id)
    if quest_id then
        local key = tostring(quest_id)
        failure_log[key] = nil
        abandoned_set[key] = nil
    else
        failure_log = {}
        abandoned_set = {}
    end
end

--- Replace the clock function for testing.
--- @param fn function Function returning elapsed time in seconds
function M.set_clock(fn)
    _clock = fn
end

-- ============================================================================
-- Global Export — registered on _G.EaxAutoQuester
-- ============================================================================

local ns = _G.EaxAutoQuester
if ns then
    ns.quest_blacklist = M
end

return M
