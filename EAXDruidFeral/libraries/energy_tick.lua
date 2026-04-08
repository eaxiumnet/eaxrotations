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

---Determine if Mangle should be preferred over Shred based on energy tick timing
---Call this when CP < 5 and deciding between Mangle and Shred
---If energy tick is imminent and using Shred would clip the tick, prefer Mangle
---@param current_energy number Current player energy
---@param mangle_cost number Energy cost of Mangle (typically 45)
---@param shred_cost number Energy cost of Shred (typically 42)
---@return boolean True if Mangle should be preferred over Shred
function energy_tick.should_prefer_mangle(current_energy, mangle_cost, shred_cost)
    -- If not confident about tick timing, don't optimize
    if not energy_tick.confident then
        return false
    end

    local time_until = energy_tick:time_until_next_tick()

    -- If tick is more than 1 second away, no need to optimize
    if time_until > 1.0 then
        return false
    end

    -- Check if we have enough energy for either ability
    if current_energy < shred_cost then
        return false  -- Can't afford Shred anyway
    end

    -- The "dead zone" logic: if a tick is imminent (within 1 second),
    -- and we can afford Mangle (which costs more), prefer Mangle
    -- because it uses more energy before the tick arrives
    if current_energy >= mangle_cost then
        return true  -- Prefer Mangle in the dead zone
    end

    return false
end

---Get debug information for dashboard/HUD display
---@return table Debug info table with fields: confident, time_until_next, should_delay, wolfshead
function energy_tick.get_debug_info()
    return {
        confident = energy_tick.confident,
        time_until_next = energy_tick:time_until_next_tick(),
        should_delay = energy_tick:should_delay_action(),
        wolfshead = energy_tick.is_wolfshead_equipped()
    }
end

---Check if player has Wolfshead Helm equipped
---Wolfshead Helm (item ID 8345) provides +20 energy when shifting into cat form
---@return boolean True if Wolfshead Helm is equipped
function energy_tick.is_wolfshead_equipped()
    -- Try multiple methods to check for Wolfshead Helm
    
    -- Method 1: Sylvanas inventory API
    if core.inventory and core.inventory.get_item_id then
        local head_item = core.inventory.get_item_id(1)  -- slot 1 is head
        if head_item then
            return head_item == 8345
        end
    end
    
    -- Method 2: Check via player equipment (if available)
    local player = core.object_manager.get_local_player()
    if player then
        -- Try to get equipped items via buff manager or other means
        -- For now, return false as fallback
        return false
    end
    
    return false
end

-- ============================================================================
-- Module Export
-- ============================================================================

return energy_tick
