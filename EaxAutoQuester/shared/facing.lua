-- shared/facing.lua — the one place the quester aims the character at something.
-- WHAT:  facing.ensure(me, target) issues at most one movement_handler look-at lock per
--        RELOCK_INTERVAL, only when the target is outside a 60-degree cone, and never at a corpse.
-- WHEN:  callers that used to run "pause movement + look_at_target(0.5, 0, unit)" on every tick.
-- WHY:   movement_handler:look_at_target(lock_duration, delay, target) HOLDS the facing for that
--        duration and only releases when it expires or is unlocked (scraped_docs_md/dev/api/
--        movement-handler.md). Calling it every tick with a 0.5s duration therefore restarts a
--        fresh servo toward a unit that is itself moving — the character turns and turns and never
--        settles. That is the "spinning in circles" report, and it is worst exactly where these
--        callers live: an enemy circling in melee, or the client's stale target after a kill,
--        which is a corpse. One lock per few seconds plus a cone test is enough to cast, and it
--        cannot pin the camera.
-- SAFETY: every probe is pcall-guarded; a missing movement_handler, direction vector or
--        lootability read degrades to "aim once per interval" rather than to an error. No state
--        survives beyond the last lock time, so a new target aims immediately.
-- DECISION: shared module (two quest-state files need the same rule); no per-tick allocation.

local M = {}

local _core_time = core.time

local LOCK_SECONDS = 2.0        -- how long one lock is asked to hold
local RELOCK_INTERVAL = 3.0     -- earliest a second lock may be requested
local FACING_CONE_DEG = 60      -- aim only when the target is outside this half-cone
local CONE_COS = math.cos(math.rad(FACING_CONE_DEG))

local _last_lock_time = -math.huge

-- Hoisted closures: these ran inside pcall(function() ... end) at every call site.
local function unit_is_alive(u) return u:is_alive() end
local function unit_can_be_looted(u) return u:can_be_looted() end
local function unit_get_direction(u) return u:get_direction() end
local function unit_get_position(u) return u:get_position() end

--- Cosine of the angle between where the player faces and where the target is, horizontally.
--- @return number|nil cos, or nil when the client cannot answer
local function facing_cos(me, pos)
    if not pos then return nil end
    local ok_dir, dir = pcall(unit_get_direction, me)
    if not ok_dir or not dir then return nil end
    local dx, dy = (dir.x or 0), (dir.y or 0)
    local dlen = math.sqrt(dx * dx + dy * dy)
    if dlen < 0.0001 then return nil end

    local ok_me, me_pos = pcall(unit_get_position, me)
    if not ok_me or not me_pos then return nil end
    local tx, ty = (pos.x or 0) - (me_pos.x or 0), (pos.y or 0) - (me_pos.y or 0)
    local tlen = math.sqrt(tx * tx + ty * ty)
    if tlen < 0.0001 then return nil end          -- standing on it: nothing to turn toward

    return (dx * tx + dy * ty) / (dlen * tlen)
end

--- Aim the player at a unit, at most once per RELOCK_INTERVAL.
--- @param me game_object|nil the local player
--- @param target game_object|nil unit to face
--- @return boolean locked Whether a lock was issued this call
function M.ensure(me, target)
    if not me or not target then return false end

    -- Never aim at a corpse. The client keeps a unit selected after it dies, and both callers here
    -- reach this with "whatever is targeted", so a kill used to spin the player on the body.
    local ok_alive, alive = pcall(unit_is_alive, target)
    if ok_alive and alive == false then return false end
    local ok_loot, lootable = pcall(unit_can_be_looted, target)
    if ok_loot and lootable == true then return false end

    local now = _core_time and _core_time() or 0
    if now - _last_lock_time < RELOCK_INTERVAL then return false end

    -- Already looking at it: a lock here can only be redundant servo.
    local ok_pos, pos = pcall(unit_get_position, target)
    if ok_pos and pos then
        local cos = facing_cos(me, pos)
        if cos and cos >= CONE_COS then
            _last_lock_time = now     -- treat as satisfied; do not aim again for an interval
            return false
        end
    end

    local mh_ok, mh = pcall(require, "common/utility/movement_handler")
    if not (mh_ok and mh and mh.look_at_target) then return false end

    _last_lock_time = now
    if mh.pause_movement_light then
        pcall(function() mh:pause_movement_light(LOCK_SECONDS) end)
    end
    pcall(function() mh:look_at_target(LOCK_SECONDS, 0, target) end)
    return true
end

--- Forget the last lock time (tests, and any state change that should aim immediately).
function M.reset()
    _last_lock_time = -math.huge
end

return M
