-- What: Quest blacklist — tracks quest failures with a 60s sliding window and answers whether a
--       quest has failed often enough to stop retrying it.
-- When: Loaded at startup; record_failure() called by quest interaction handlers
-- Why: Prevent infinite retry loops on broken quests (missing NPC, unsolvable gossip, area fail)
-- Safety: Standalone module; no hard dependencies; clock injection for testing. Reports only —
--         nothing here deletes a quest, and nothing may: the plugin never abandons quests
--         (tests/test_no_quest_abandon.lua fails if any production file calls abandon_quest).
--         `should_abandon`/`mark_abandoned` are queries the caller may use to give up on a
--         target and warn; they have no production caller today.
-- Decision: In-memory only (no persistence); clock via core.time() with documented,
--           same-unit fallbacks. No os.* call: the runtime sandbox does not document
--           os as available (see docs/runtime_sandbox_audit.md).

-- ============================================================================
-- Hot-path API Caching at Module Load (Pattern 2 from AGENTS.md)
-- ============================================================================

local _core_time, _core_cpu_time = nil, nil
local _tick = 0

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
-- Default clock: core.time() (documented: seconds since injection) with two
-- fallbacks, both in the SAME unit so the 60s window keeps meaning 60 seconds:
--   core.cpu_time()  documented (nanoseconds) -> divided to seconds
--   tick counter     one unit per call, when no clock API exists at all
--
-- os.clock() was used here and is deliberately gone: .api/core.lua documents
-- os.date()/os.time() as unavailable in the sandboxed Lua (core.get_local_time
-- exists for exactly that reason), so no os.* function may be assumed to exist.
-- ============================================================================

local function _probe(name)
    local ok, fn = pcall(function() return core[name] end)
    if ok and type(fn) == "function" then return fn end
    return nil
end

local function _default_clock()
    if _core_time == nil then
        _core_time = _probe("time")
    end
    if _core_time then
        return _core_time()
    end
    if _core_cpu_time == nil then
        _core_cpu_time = _probe("cpu_time")
    end
    if _core_cpu_time then
        return _core_cpu_time() / 1e9
    end
    -- No clock API present: stay monotonic, one unit per call. The 60-second
    -- window becomes a 60-event window in this mode; it is only reachable when
    -- the module runs with no core API at all.
    _tick = _tick + 1
    return _tick
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
