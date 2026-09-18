-- What: Anti-detection / human-like behavior module for EaxAutoQuester
-- When: Called from main loop when bot is idle or navigating (not in combat)
-- Why: Random delays, camera jitter, path deviation reduce detection signature
-- Safety: No state mutation; all actions pcall-guarded; throttled to avoid spam
-- Decision: Optional module — safe to disable; runs only when enabled flag is true

-- API caching at module load (Pattern 2)
local _core_time = core.time
local _core_log  = core.log

-- Module table
local M = {}

-- ============================================================================
-- Random Delay — Gaussian-ish distribution (Box-Muller approximate)
-- ============================================================================

--- Return a random delay centered on mean with stddev spread.
--- Uses math.random; Box-Muller transform for normal distribution.
--- @param mean number Center delay in seconds
--- @param stddev number Standard deviation in seconds
--- @return number delay Seconds (clamped to mean*0.5 minimum)
function M.random_delay(mean, stddev)
    mean = mean or 1.5
    stddev = stddev or 0.4
    local u1 = math.random()
    local u2 = math.random()
    local z0 = math.sqrt(-2.0 * math.log(u1)) * math.cos(2 * math.pi * u2)
    local delay = mean + z0 * stddev
    if delay < mean * 0.5 then delay = mean * 0.5 end
    return delay
end

-- ============================================================================
-- Camera Jitter — small random camera turns when idle
-- ============================================================================

local _last_jitter_time = 0
local _next_jitter_interval = 0

--- Perform a small random camera turn if enough time has passed.
--- Throttled to random intervals between 20-60 seconds.
--- Only runs when not in combat and not casting.
--- @param in_combat boolean true if player is in combat
--- @param is_casting boolean true if player is casting/channeling
function M.maybe_camera_jitter(in_combat, is_casting)
    if in_combat or is_casting then return end

    local now = _core_time()
    if _next_jitter_interval == 0 then
        _next_jitter_interval = 20 + math.random() * 40
        _last_jitter_time = now
        return
    end

    if now - _last_jitter_time < _next_jitter_interval then return end

    -- Small turn: 5-15 degrees in either direction
    local degrees = (math.random() > 0.5 and 1 or -1) * (5 + math.random() * 10)
    local radians = math.rad(degrees)
    pcall(core.input.turn, radians)

    -- Reset timer with new random interval
    _last_jitter_time = now
    _next_jitter_interval = 20 + math.random() * 40
end

-- ============================================================================
-- Path Deviation — random offset for waypoints
-- ============================================================================

--- Apply a small random offset to a destination for natural movement.
--- @param dest table {x, y, z} original destination
--- @param max_offset number Max yards to deviate (default 2.0)
--- @return table {x, y, z} jittered destination
function M.jitter_destination(dest, max_offset)
    if not dest then return nil end
    max_offset = max_offset or 2.0
    local angle = math.random() * 2 * math.pi
    local dist = math.random() * max_offset
    return {
        x = (dest.x or 0) + math.cos(angle) * dist,
        y = (dest.y or 0) + math.sin(angle) * dist,
        z = dest.z or 0,
    }
end

-- ============================================================================
-- Action Jitter — per-action-type delay recommendations
-- ============================================================================

--- Return a human-like delay for a given action type.
--- @param action_type string One of: "quest_accept", "loot", "vendor_sell", "interact"
--- @return number delay Seconds to wait
function M.action_delay(action_type)
    local delays = {
        quest_accept  = { mean = 1.0,  stddev = 0.3 },
        loot          = { mean = 1.5,  stddev = 0.4 },
        vendor_sell   = { mean = 0.4,  stddev = 0.15 },
        interact      = { mean = 3.0,  stddev = 0.8 },
        default       = { mean = 1.5,  stddev = 0.4 },
    }
    local d = delays[action_type] or delays.default
    return M.random_delay(d.mean, d.stddev)
end

-- ============================================================================
-- Player Proximity Pause — stop briefly when another player is near
-- ============================================================================

local _last_player_near_time = 0
local _player_pause_until = 0

--- Check for nearby players and pause bot briefly if one is detected.
--- Returns true if bot should pause this tick.
--- @param range number Detection range in yards (default 30)
--- @return boolean true if pause is active
function M.check_player_proximity(range)
    local now = _core_time()
    if now < _player_pause_until then return true end

    range = range or 30
    local range_sq = range * range

    local ok, me = pcall(core.object_manager.get_local_player)
    if not ok or not me then return false end

    local ok_pos, my_pos = pcall(function() return me:get_position() end)
    if not ok_pos or not my_pos then return false end

    local ok_objs, objects = pcall(core.object_manager.get_visible_objects)
    if not ok_objs or not objects then return false end

    for i = 1, math.min(#objects, 50) do
        local obj = objects[i]
        if obj then
            local ok_player, is_player = pcall(function() return obj:is_player() end)
            if ok_player and is_player then
                local ok_opp, other_pos = pcall(function() return obj:get_position() end)
                if ok_opp and other_pos then
                    local dx = (other_pos.x or 0) - (my_pos.x or 0)
                    local dy = (other_pos.y or 0) - (my_pos.y or 0)
                    if dx * dx + dy * dy < range_sq then
                        -- Another player is within range — pause 2-5s
                        local pause = 2.0 + math.random() * 3.0
                        _player_pause_until = now + pause
                        _last_player_near_time = now
                        return true
                    end
                end
            end
        end
    end

    return false
end

-- ============================================================================
-- Tick-rate variation — vary main loop cadence
-- ============================================================================

local _last_tick_variation = 0

--- Return a varied tick interval (100-300ms) to change reaction time.
--- Call once per tick to decide sleep/wait duration.
--- @return number interval Seconds for next tick
function M.varied_tick_interval()
    local now = _core_time()
    if now - _last_tick_variation < 5.0 then return 0.1 end
    _last_tick_variation = now
    return 0.1 + math.random() * 0.2
end

-- ============================================================================
-- Exports
-- ============================================================================

_G.EaxAutoQuester = _G.EaxAutoQuester or {}
_G.EaxAutoQuester.anti_detection = M

return M
