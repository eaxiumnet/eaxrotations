-- energy_tick.lua
-- Server-side energy tick tracking for Feral Druid optimization
-- Prevents clipping ticks with unnecessary powershifts
--
-- Usage:
--   local tick = require("libraries/energy_tick")
--   tick:update(me:get_power(3), in_cat_form, last_shift_time)  -- Call every frame
--   if tick:should_delay_action() then return end  -- Wait for tick

local energy_tick = {
    last_energy = 0,
    last_tick_time = 0,
    confident = false,
    TICK_INTERVAL = 2.0,
    DELAY_THRESHOLD = 0.4,  -- Wait if tick < 0.4s away
    TICK_OPT_THRESHOLD = 1.0,  -- Tick optimization window (seconds)
    SHIFT_ENERGY_IGNORE_WINDOW = 0.6,  -- Ignore energy increases within 0.6s of shift
    last_shift_time = 0,  -- Track when last powershift occurred
}

-- ============================================================================
-- Dynamic Threshold Calculation (from flux cat.lua)
-- ============================================================================
-- These are calculated dynamically based on actual spell costs
-- Formula: lower = 2*mangle_cost - 20, upper = mangle_cost + shred_cost - 21
-- With 2pT6 (mangle=35): 50-56. Without (mangle=40): 60-61. Adapts to actual costs.
local _cached_mangle_cost = 40
local _cached_shred_cost = 42

---Update cached spell costs for dynamic threshold calculation
---Call this whenever spell costs might change (on load, talent changes)
---@param mangle_cost number Energy cost of Mangle (typically 40, or 35 with 2pT6)
---@param shred_cost number Energy cost of Shred (typically 42)
function energy_tick.update_spell_costs(mangle_cost, shred_cost)
    if mangle_cost and mangle_cost > 0 then
        _cached_mangle_cost = mangle_cost
    end
    if shred_cost and shred_cost > 0 then
        _cached_shred_cost = shred_cost
    end
end

---Get the dynamic tick optimization thresholds
---@return number low_threshold TICK_OPT_MANGLE_LOW
---@return number high_threshold TICK_OPT_MANGLE_HIGH
function energy_tick.get_tick_opt_thresholds()
    local low = 2 * _cached_mangle_cost - 20
    local high = _cached_mangle_cost + _cached_shred_cost - 21
    return low, high
end

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
---@param in_cat_form boolean|nil True if player is in cat form
---@param last_shift_time number|nil Timestamp of last powershift (for filtering Furor energy)
function energy_tick:update(current_energy, in_cat_form, last_shift_time)
    -- Validate input
    if not current_energy or type(current_energy) ~= "number" then
        return
    end

    -- Only track in Cat form
    if in_cat_form == false then
        self.last_energy = 0
        self.confident = false
        return
    end

    local now = _core_time()
    local delta = current_energy - self.last_energy

    -- Update shift time tracking
    if last_shift_time then
        self.last_shift_time = last_shift_time
    end

    -- Detect energy tick: increase of 1-25 energy
    -- Energy ticks are 20 energy every 2.0s in TBC
    -- Filter out Furor energy (40) + Wolfshead (20) by checking shift window
    local time_since_shift = now - self.last_shift_time
    if delta > 0 and delta <= 25 and time_since_shift > self.SHIFT_ENERGY_IGNORE_WINDOW then
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
    self.last_shift_time = _core_time()
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
---@param mangle_cost number|nil Energy cost of Mangle (uses cached if nil)
---@param shred_cost number|nil Energy cost of Shred (uses cached if nil)
---@return boolean True if Mangle should be preferred over Shred
function energy_tick.should_prefer_mangle(current_energy, mangle_cost, shred_cost)
    -- Update cached costs if provided
    if mangle_cost then
        _cached_mangle_cost = mangle_cost
    end
    if shred_cost then
        _cached_shred_cost = shred_cost
    end

    -- If not confident about tick timing, don't optimize
    if not energy_tick.confident then
        return false
    end

    local time_until = energy_tick:time_until_next_tick()

    -- If tick is more than threshold away, no need to optimize
    if time_until > energy_tick.TICK_OPT_THRESHOLD then
        return false
    end

    -- Calculate dynamic thresholds
    local tick_opt_low, tick_opt_high = energy_tick.get_tick_opt_thresholds()

    -- Check if energy is in the "dead zone" where Mangle is preferred
    -- In this zone, Shred leaves you too low to act after the tick, but Mangle doesn't
    if current_energy >= tick_opt_low and current_energy <= tick_opt_high then
        return true  -- Prefer Mangle in the dead zone
    end

    return false
end

---Get debug information for dashboard/HUD display
---@return table Debug info table with fields: confident, time_until_next, should_delay, wolfshead
function energy_tick.get_debug_info()
    local low, high = energy_tick.get_tick_opt_thresholds()
    return {
        confident = energy_tick.confident,
        time_until_next = energy_tick:time_until_next_tick(),
        should_delay = energy_tick:should_delay_action(),
        wolfshead = energy_tick.is_wolfshead_equipped(),
        tick_opt_low = low,
        tick_opt_high = high,
        mangle_cost = _cached_mangle_cost,
        shred_cost = _cached_shred_cost,
    }
end

---Check if player has Wolfshead Helm equipped
---Wolfshead Helm (item ID 8345) provides +20 energy when shifting into cat form
---@return boolean True if Wolfshead Helm is equipped
function energy_tick.is_wolfshead_equipped()
    -- Try multiple methods to check for Wolfshead Helm
    
    -- Method 1: Check equipped item via player object
    local me = core.object_manager.get_local_player()
    if me and me.get_equipped_item then
        local item = me:get_equipped_item(1)  -- slot 1 is head
        if item and item.id then
            return item.id == 8345
        end
    end
    
    return false
end

-- ============================================================================
-- Module Export
-- ============================================================================

return energy_tick
