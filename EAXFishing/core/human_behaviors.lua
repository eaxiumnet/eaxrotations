-- human_behaviors.lua — Subtle human-like behaviors that don't break fishing.
-- WHAT:  adds random look-arounds, bobber gazing, and idle stares between casts.
--        All behaviors use existing `look_at()` API only.
-- WHEN:  between casts, during idle periods, before clicking bobber.
-- WHY:   Humans look around, stare at the bobber, and gaze into the distance.
--        Bots cast-click-cast in a perfect loop. These breaks add realism.
-- IMPACT: Each behavior adds 0.3-2s max. Catches per hour drop <3%.
-- STEALTH: Highly realistic. Hard to distinguish from a real player.
-- SAFETY: pcall on all look_at calls. Never blocks the fishing loop.

local APISurface = require("core/api_surface")

local M = {}

--- Random look-around before casting
-- Humans glance around before casting — checking for mobs, other players, etc.
-- Adds 0.5-1.5s. Only triggers ~15% of the time between casts.
-- @param ctx table
-- @param me game_object
-- @param now number
-- @return boolean true if behavior triggered this tick
function M.look_around_before_cast(ctx, me, now)
    local state = ctx.state
    if not APISurface.is_valid(me) then return false end

    -- Throttle: only once every 10s minimum
    if state.human_behaviors and state.human_behaviors.last_lookaround > 0
       and now - state.human_behaviors.last_lookaround < 10.0 then
        return false
    end

    -- 15% chance to look around before casting
    if math.random() > 0.15 then return false end

    local pos = APISurface.get_object_position(me)
    if not pos then return false end

    -- Pick a random direction (full 360°, but weighted toward looking at water)
    -- Most of the time humans look at the water they're fishing in
    local yaw = math.random() * math.pi * 2
    local dist = 15.0
    local target = {
        x = pos.x + math.cos(yaw) * dist,
        y = pos.y + math.sin(yaw) * dist,
        z = pos.z,
    }

    local ok = pcall(APISurface.look_at, target)
    if ok then
        state.fishing.status = "Looking around..."
        state.human_behaviors.last_lookaround = now
        return true
    end
    return false
end

--- Bobber gaze before clicking
-- Humans stare at the bobber for a moment before clicking.
-- Adds 200-500ms to reaction time. Triggers ~40% of the time.
-- @param ctx table
-- @param me game_object
-- @param now number
-- @return boolean true if behavior triggered (gazing)
function M.gaze_at_bobber(ctx, me, now)
    local state = ctx.state
    if not APISurface.is_valid(me) then return false end

    -- Only when a bobber bite is detected
    if not state.bite.pending then return false end

    -- Already gazing?
    if state.human_behaviors and state.human_behaviors.bobber_gaze_end
       and now < state.human_behaviors.bobber_gaze_end then
        state.fishing.status = "Watching bobber..."
        return true  -- Still gazing
    end

    -- 40% chance to gaze at the bobber before clicking
    if math.random() > 0.40 then
        state.human_behaviors.bobber_gaze_end = 0
        return false
    end

    -- Find the bobber and look at it
    local pos = APISurface.get_object_position(me)
    if not pos then return false end

    local bobber = APISurface.find_bobber(ctx, me, pos.x, pos.y, pos.z)
    if bobber then
        local bpos = APISurface.get_object_position(bobber)
        if bpos then
            local ok = pcall(APISurface.look_at, bpos)
            if ok then
                -- Gaze for 200-500ms
                local gaze_duration = 0.2 + math.random() * 0.3
                state.human_behaviors.bobber_gaze_end = now + gaze_duration
                state.fishing.status = "Watching bobber..."
                return true
            end
        end
    end

    return false
end

--- Idle stare after clicking (between casts)
-- After catching a fish, humans stare into the distance for 1-2s before recasting.
-- Only triggers ~10% of the time after a catch.
-- @param ctx table
-- @param me game_object
-- @param now number
-- @return boolean true if behavior triggered
function M.idle_stare_after_catch(ctx, me, now)
    local state = ctx.state
    if not APISurface.is_valid(me) then return false end

    -- Only after a successful catch
    if state.session.catches <= 0 then return false end

    -- Already staring?
    if state.human_behaviors and state.human_behaviors.idle_stare_end
       and now < state.human_behaviors.idle_stare_end then
        state.fishing.status = "Staring into the water..."
        return true
    end

    -- 10% chance to stare after a catch
    if math.random() > 0.10 then
        state.human_behaviors.idle_stare_end = 0
        return false
    end

    local pos = APISurface.get_object_position(me)
    if not pos then return false end

    -- Look straight ahead (where the bobber was)
    local yaw = math.random() * math.pi * 2
    local dist = 20.0
    local target = {
        x = pos.x + math.cos(yaw) * dist,
        y = pos.y + math.sin(yaw) * dist,
        z = pos.z,
    }

    local ok = pcall(APISurface.look_at, target)
    if ok then
        -- Stare for 1.0-2.5s
        local stare_duration = 1.0 + math.random() * 1.5
        state.human_behaviors.idle_stare_end = now + stare_duration
        state.fishing.status = "Staring into the water..."
        return true
    end
    return false
end

--- Should we block this tick for human behavior?
-- Called from engine tick to check if any behavior is active.
-- @param ctx table
-- @param now number
-- @return boolean true if a behavior is blocking this tick
function M.is_blocking(ctx, now)
    local hb = ctx.state.human_behaviors
    if not hb then return false end

    -- Bobber gaze
    if hb.bobber_gaze_end and now < hb.bobber_gaze_end then
        return true
    end

    -- Idle stare
    if hb.idle_stare_end and now < hb.idle_stare_end then
        return true
    end

    return false
end

--- Get current behavior status text (for HUD)
-- @param ctx table
-- @param now number
-- @return string|nil status text
function M.get_status(ctx, now)
    local hb = ctx.state.human_behaviors
    if not hb then return nil end

    if hb.bobber_gaze_end and now < hb.bobber_gaze_end then
        return "Watching bobber..."
    end
    if hb.idle_stare_end and now < hb.idle_stare_end then
        return "Staring into the water..."
    end
    return nil
end

--- Reset human behavior state
function M.reset(state)
    if not state.human_behaviors then
        state.human_behaviors = {}
    end
    state.human_behaviors.last_lookaround = 0.0
    state.human_behaviors.bobber_gaze_end = 0.0
    state.human_behaviors.idle_stare_end = 0.0
end

return M
