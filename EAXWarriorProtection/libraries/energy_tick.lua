-- energy_tick.lua
-- Server-side energy tick tracking for Feral Druid optimization
-- Prevents clipping ticks with unnecessary powershifts
--
-- Usage:
--   local tick = require("libraries/energy_tick")
--   tick:update(me:get_power(3))  -- Call every frame
--   if tick:should_delay_action() then return end  -- Wait for tick

local energy_tick = {
    last_energy = 0,
    last_tick_time = 0,
    confident = false,
    TICK_INTERVAL = 2.0,
    DELAY_THRESHOLD = 0.4,  -- Wait if tick < 0.4s away
}

-- ============================================================================
-- API Caching (at module load)
-- ============================================================================
local _core_time = core.time

-- ============================================================================
-- Energy Tick Tracking
-- ============================================================================

---Update tick tracker with current energy
---Call this every frame with the player's current energy value
---@param current_energy number Current player energy (0-100)
function energy_tick:update(current_energy)
    -- Validate input
    if not current_energy or type(current_energy) ~= "number" then
        return
    end

    local delta = current_energy - self.last_energy

    -- Detect energy tick: increase of 1-25 energy
    -- Energy ticks are 20 energy every 2.0s in TBC
    -- We allow 1-25 range to account for:
    -- - Normal 20 energy ticks
    -- - Wolfshead Helm procs (+20 on shift, but filtered by caller timing)
    -- - Furor talent energy (+40 on shift, filtered by caller)
    -- - Small rounding variations
    if delta > 0 and delta <= 25 then
        local now = _core_time()
        self.last_tick_time = now
        self.confident = true
    end

    self.last_energy = current_energy
end

---Get time until next predicted energy tick
---@return number Seconds until next tick (1.0 if not confident yet)
function energy_tick:time_until_next_tick()
    if not self.confident or self.last_tick_time == 0 then
        return 1.0
    end

    local now = _core_time()
    local elapsed = now - self.last_tick_time
    local remaining = self.TICK_INTERVAL - (elapsed % self.TICK_INTERVAL)

    return remaining
end

---Check if an action should be delayed to wait for an imminent energy tick
---Use this in rotation logic to prevent clipping ticks with powershifts
---@return boolean True if tick is arriving within DELAY_THRESHOLD seconds
function energy_tick:should_delay_action()
    if not self.confident then
        return false
    end

    return self:time_until_next_tick() <= self.DELAY_THRESHOLD
end

---Reset tracking state
---Call this when powershifting to reset confidence until next tick is detected
function energy_tick:on_shift()
    self.confident = false
    self.last_tick_time = 0
    -- Keep last_energy as-is to avoid false positives from shift energy
end

---Get the predicted time of the last detected tick
---@return number Timestamp of last tick (0 if none detected)
function energy_tick:get_last_tick_time()
    return self.last_tick_time
end

---Check if tracker has detected at least one tick and is confident
---@return boolean True if at least one tick has been detected
function energy_tick:is_confident()
    return self.confident
end

-- ============================================================================
-- Module Export
-- ============================================================================

return energy_tick
