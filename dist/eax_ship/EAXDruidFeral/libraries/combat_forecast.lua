-- combat_forecast.lua
-- Time-To-Death (TTD) prediction for cooldown gating
-- Based on Flux NS.get_time_to_die() and trinket_manager TTD gating

local combat_forecast = {}

-- ============================================================================
-- API Caching (at module load)
-- ============================================================================
local _core_time = core.time

-- ============================================================================
-- Configuration Constants
-- ============================================================================
local MAX_SAMPLES = 10           -- Rolling window size
local SAMPLE_INTERVAL = 1.0      -- Seconds between samples
local WINDOW_S = 10              -- Maximum age of samples (seconds)
local MIN_LOSS = 0.001           -- Minimum HP loss rate to consider
local DEFAULT_TTD = 500          -- Default for stable/healing targets
local MIN_SAMPLES_FOR_TTD = 2    -- Minimum samples needed for calculation

-- ============================================================================
-- State Storage
-- ============================================================================
local _samples = {}              -- target_key -> array of {t, hp}
local _last_sample_time = {}     -- target_key -> timestamp

-- ============================================================================
-- Helper Functions
-- ============================================================================

---Generate a unique key for a target object
---@param target userdata Game object (target)
---@return string key Unique identifier
local function target_key(target)
    if not target then return "nil" end
    -- Use tostring for object identity, fallback to "unknown"
    local success, result = pcall(tostring, target)
    return success and result or "unknown"
end

---Get target's current health percentage (0.0 - 1.0)
---@param target userdata Game object
---@return number hp_percent Current HP as percentage (0-1)
local function get_hp_percent(target)
    if not target then return 1.0 end
    
    local success, health = pcall(function() return target:get_health() end)
    if not success or not health then return 1.0 end
    
    local success2, max_health = pcall(function() return target:get_max_health() end)
    if not success2 or not max_health or max_health <= 0 then return 1.0 end
    
    return health / max_health
end

---Check if target is valid for tracking
---@param target userdata Game object
---@return boolean is_valid
local function is_valid_target(target)
    if not target then return false end
    
    local success, is_valid = pcall(function() return target:is_valid() end)
    if not success or not is_valid then return false end
    
    local success2, is_dead = pcall(function() return target:is_dead() end)
    if not success2 or is_dead then return false end
    
    return true
end

-- ============================================================================
-- Public API
-- ============================================================================

---Sample target HP (call every ~1 second)
---Records timestamp + target HP and maintains rolling window
---@param target userdata Game object to sample
function combat_forecast:sample(target)
    if not is_valid_target(target) then
        return
    end
    
    local key = target_key(target)
    local now = _core_time()
    local hp = get_hp_percent(target)
    
    -- Initialize sample array if needed
    if not _samples[key] then
        _samples[key] = {}
    end
    
    -- Add new sample
    local s = _samples[key]
    s[#s + 1] = { t = now, hp = hp }
    _last_sample_time[key] = now
    
    -- Maintain rolling window: remove samples older than WINDOW_S
    while s[1] and (now - s[1].t) > WINDOW_S do
        table.remove(s, 1)
    end
    
    -- Hard limit: never exceed MAX_SAMPLES
    while #s > MAX_SAMPLES do
        table.remove(s, 1)
    end
end

---Calculate Time-To-Death in seconds
---Returns nil if can't calculate (insufficient data)
---Returns DEFAULT_TTD (500+) if target stable/healing
---@param target userdata Game object
---@return number|nil ttd Time to death in seconds, or nil if unknown
function combat_forecast:get_ttd(target)
    if not is_valid_target(target) then
        return nil
    end
    
    local key = target_key(target)
    local s = _samples[key]
    
    -- Need at least MIN_SAMPLES_FOR_TTD samples
    if not s or #s < MIN_SAMPLES_FOR_TTD then
        return nil
    end
    
    local oldest = s[1]
    local newest = s[#s]
    local elapsed = newest.t - oldest.t
    
    -- Need time to have actually passed
    if elapsed <= 0 then
        return nil
    end
    
    -- Calculate HP loss rate
    local hp_loss = oldest.hp - newest.hp
    
    -- If HP is stable or increasing (healing), return default high value
    if hp_loss < MIN_LOSS then
        return DEFAULT_TTD
    end
    
    -- Calculate rate and TTD
    local rate = hp_loss / elapsed  -- HP loss per second
    local current_hp = newest.hp
    local ttd = current_hp / rate   -- seconds until death
    
    return ttd
end

---Check if target is "worth" using CDs on
---Returns false if TTD < min_ttd (target dying too fast)
---Returns true if TTD >= min_ttd or nil (insufficient data = assume worth it)
---@param target userdata Game object
---@param min_ttd number Minimum acceptable TTD in seconds
---@return boolean worth_it
function combat_forecast:worth_using_cds(target, min_ttd)
    min_ttd = min_ttd or 10  -- Default 10 second threshold
    
    local ttd = self:get_ttd(target)
    
    -- If we can't calculate TTD (new target), assume it's worth using CDs
    if ttd == nil then
        return true
    end
    
    -- If target is stable/healing (DEFAULT_TTD), it's worth using CDs
    if ttd >= DEFAULT_TTD then
        return true
    end
    
    -- Only use CDs if target will live long enough
    return ttd >= min_ttd
end

---Reset samples for a target (or all targets if nil)
---@param target userdata|nil Target to reset, or nil to reset all
function combat_forecast:reset(target)
    if target then
        local key = target_key(target)
        _samples[key] = nil
        _last_sample_time[key] = nil
    else
        -- Reset all
        _samples = {}
        _last_sample_time = {}
    end
end

---Get the number of samples for a target (for debugging)
---@param target userdata Game object
---@return number count Number of samples stored
function combat_forecast:get_sample_count(target)
    if not target then return 0 end
    local key = target_key(target)
    local s = _samples[key]
    return s and #s or 0
end

---Check if target is dying (convenience method)
---@param target userdata Game object
---@param threshold_s number Threshold in seconds (default 20)
---@return boolean is_dying
function combat_forecast:is_dying(target, threshold_s)
    threshold_s = threshold_s or 20
    local ttd = self:get_ttd(target)
    
    if ttd == nil then
        return false  -- Unknown = not dying
    end
    
    return ttd < threshold_s
end

---Legacy compatibility: is_valid_forecast_logic for trinket_manager
---Matches the signature expected by trinket_manager.lua
---@param min_ttd number Minimum TTD threshold
---@param target userdata Target object
---@param allow_nil boolean If true, nil TTD returns true; if false, returns false
---@return boolean is_valid
function combat_forecast:is_valid_forecast_logic(min_ttd, target, allow_nil)
    local ttd = self:get_ttd(target)
    
    -- Handle nil case based on allow_nil parameter
    if ttd == nil then
        return allow_nil == true
    end
    
    -- Stable/healing targets are always valid
    if ttd >= DEFAULT_TTD then
        return true
    end
    
    -- Check against threshold
    return ttd >= min_ttd
end

-- ============================================================================
-- Module Export
-- ============================================================================

return combat_forecast
