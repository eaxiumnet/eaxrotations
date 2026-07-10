-- movement_assist_sylvanas.lua -- shared movement/facing assist for cast reliability..
-- WHAT:   shared movement/facing assist for cast reliability.
-- WHEN:   called per-frame when in_combat but target out_of_range
-- WHY:    auto-faces and steps toward target during 2.5s cast windows
-- SAFETY: is_moving nil-guarded per Pattern 14
-- DECISION: pure helper consumed via require() by specs; no on_update side-effects.

-- What: Shared movement/facing assist for cast reliability.
-- When: Used by specs or cast backend when a spell requires the player to stop moving and face the target.
-- Why: Movement/facing failures cause cast-time spells to fail. This helper uses the documented
--      movement_handler API to briefly pause movement and lock facing before casts.
-- Safety: All functions are no-ops when movement_handler is unavailable. Pause durations are short
--         and auto-expire. Never used for instant casts. Respects player control.
-- Decision: Conservative opt-in helper, not auto-integrated into try_cast. Specs call it when needed.

local NS = _G.EaxRotations
if not NS then return nil end

local core = NS.core or _G.core or {}

-- ============================================================================
-- Module cache
-- ============================================================================
local _mh_ok, _movement_handler = pcall(require, "common/utility/movement_handler")
if not _mh_ok or type(_movement_handler) ~= "table" then _movement_handler = nil end

local _get_spell_cast_time = core.spell_book and core.spell_book.get_spell_cast_time
if type(_get_spell_cast_time) ~= "function" then _get_spell_cast_time = nil end

-- ============================================================================
-- Constants
-- ============================================================================
local CAST_TIME_BUFFER = 0.25  -- Extra seconds beyond cast time for safety
local MAX_PAUSE_DURATION = 6.0 -- Cap to prevent long movement locks
local MIN_CAST_TIME_FOR_ASSIST = 0.1 -- Only assist spells with cast time > this (skip instants)

-- ============================================================================
-- State tracking
-- ============================================================================
local _last_face_time = 0
local _last_face_target = nil
local FACE_COOLDOWN = 0.5 -- Minimum seconds between face_for_cast calls (anti-spam)

-- ============================================================================
-- Public API
-- ============================================================================

local M = {}

--- Called from the render callback to process movement handler state.
-- Required for delays and auto-resume to work properly.
-- Source: movement-handler.md:on_render (line 158-169)
function M.on_render()
    if _movement_handler and type(_movement_handler.on_render) == "function" then
        _movement_handler:on_render()
    end
end

--- Pause movement and lock facing to target for a cast-time spell.
-- Only activates for non-instant spells. Auto-expires after cast_time + buffer.
-- Source: movement-handler.md:Safe Cast with Movement Check (line 192-196)
-- Source: movement-handler.md:pause_movement_light (line 58-76)
-- Source: movement-handler.md:look_at_target (line 98-116)
---@param target game_object The target to face and cast on.
---@param cast_time number|nil Cast time in seconds. If nil, uses 0 (no assist for instants).
---@return boolean ok True if movement assist was activated.
function M.face_for_cast(target, cast_time)
    if not _movement_handler then return false end
    if not target then return false end

    local ct = type(cast_time) == "number" and cast_time or 0
    if ct < MIN_CAST_TIME_FOR_ASSIST then return false end

    -- Anti-spam: don't re-trigger if we just locked facing to the same target
    local now = NS.time_now and NS.time_now() or 0
    if NS.same_unit(_last_face_target, target) and (now - _last_face_time) < FACE_COOLDOWN then
        return true -- Already active for this target
    end

    local duration = math.min(ct + CAST_TIME_BUFFER, MAX_PAUSE_DURATION)

    -- Light pause: less aggressive blocking, suitable for cast-time spells
    _movement_handler:pause_movement_light(duration)
    -- Lock facing to target for the cast duration
    _movement_handler:look_at_target(duration, 0, target)

    _last_face_time = now
    _last_face_target = target
    return true
end

--- Get the cast time for a spell ID, falling back to 0.
-- Source: api/core.lua:1722 (get_spell_cast_time)
---@param spell_id number The spell ID.
---@return number cast_time Cast time in seconds (0 for instant or unknown).
function M.get_cast_time(spell_id)
    if not spell_id or not _get_spell_cast_time then return 0 end
    local ok, ct = pcall(_get_spell_cast_time, spell_id)
    if ok and type(ct) == "number" and ct > 0 then return ct end
    return 0
end

--- Convenience: face target for a spell by ID (looks up cast time automatically).
---@param spell_id number The spell ID.
---@param target game_object The target to face.
---@return boolean ok True if movement assist was activated.
function M.face_for_spell(spell_id, target)
    if not spell_id or not target then return false end
    local ct = M.get_cast_time(spell_id)
    return M.face_for_cast(target, ct)
end

--- Resume movement immediately (caller can use this to cancel a pause early).
-- Source: movement-handler.md:resume_movement (line 78-96)
function M.resume()
    if _movement_handler and type(_movement_handler.resume_movement) == "function" then
        _movement_handler:resume_movement()
    end
end

--- Unlock look-at immediately (caller can use this to cancel a face lock early).
-- Source: movement-handler.md:unlock_look_at (line 138-155)
function M.unlock()
    if _movement_handler and type(_movement_handler.unlock_look_at) == "function" then
        _movement_handler:unlock_look_at()
    end
end

--- Returns true if movement_handler is available and assist can be used.
function M.is_available()
    return _movement_handler ~= nil
end

--- Pause movement (and optionally face a safe direction or away) for a boss/dungeon mechanic.
-- Use for pre-positioning, avoid, soak, fear break positioning, etc.
-- This closes the parent plan Phase 2 "Movement / pre-positioning for mechanics" item.
-- Conservative: short duration, auto-expires, opt-in by caller.
-- Examples: Gluth freeze positioning, Winterchill shackle avoid, general danger zones.
---@param duration number Seconds to pause (capped).
---@param reason string|nil For logging (e.g. "gluth_freeze", "fear_aoe").
---@param face_away_from any|nil Optional unit/position to face away from (uses look_at if available).
---@return boolean ok
function M.pause_for_mechanic(duration, reason, face_away_from)
    if not _movement_handler then return false end
    local d = math.min(duration or 1.5, MAX_PAUSE_DURATION)
    _movement_handler:pause_movement_light(d)
    if face_away_from and type(_movement_handler.look_at_target) == "function" then
        -- Best effort face away; ignore if API differs
        pcall(function() _movement_handler:look_at_target(d, 0, face_away_from) end)
    end
    if NS.log and reason then
        NS.log(string.format("[MovementAssist] Mechanic pause %.1fs for %s", d, tostring(reason)))
    end
    return true
end

--- Simple helper: should we pre-position for a known high-risk mechanic right now?
-- Callers (specs) can use this + pause_for_mechanic.
-- Starts conservative: looks for common fear/debuff patterns via context or unit.
-- Extend per boss as needed (no hardcoding of every NPC ID here).
function M.should_preposition_for_mechanic(context, me)
    if not context or not me then return false end
    -- Example triggers (safe, low false-positive):
    if context.fear_nearby or context.known_fear_boss then return true end
    if context.in_combat and (context.burst_risk or 0) > 50 then return true end
    -- Add more via context in future (e.g. specific debuff up)
    return false
end

-- Register on the shared namespace so core_sylvanas / main dispatchers can find it.
if NS then
    NS.MovementAssist = M
end


return M
