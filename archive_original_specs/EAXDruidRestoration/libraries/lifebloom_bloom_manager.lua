-- lifebloom_bloom_manager.lua
-- Flux Adaptation: Lifebloom bloom state tracking and mana optimization
-- TBC 2.4.3: Lifebloom blooms on natural expiry, returning mana + burst heal

---@type buff_manager
local buff_manager = require("common/modules/buff_manager")

local lifebloom_bloom_manager = {}

-- ============================================================================
-- CONSTANTS (TBC 2.4.3 Mechanics)
-- ============================================================================
local LIFEBLOOM_SPELL_ID = 33763
local LIFEBLOOM_BUFF_ID = 33763
local MAX_STACKS = 3
local BASE_DURATION_MS = 7000  -- 7 seconds base

-- Bloom returns 50% of mana cost in TBC (110 mana out of 220 cost)
local BLOOM_MANA_RETURN = 110
local BLOOM_HEAL_AMOUNT = 600  -- Approximate bloom heal at level 70

-- ============================================================================
-- STATE TRACKING
-- ============================================================================
local tracked_units = {}  -- [unit_guid] = { stacks, duration_ms, last_update }
local bloom_history = {}  -- Recent blooms for mana accounting
local last_cleanup_time = 0

-- ============================================================================
-- CORE FUNCTIONS
-- ============================================================================

--- Get Lifebloom stack count and remaining duration on a unit
---@param unit game_object Unit to check
---@return number stack_count (0-3)
---@return number remaining_ms Duration remaining in milliseconds
function lifebloom_bloom_manager.get_lifebloom_state(unit)
    if not unit or not unit.is_valid or not unit:is_valid() then
        return 0, 0
    end
    
    -- Try buff_manager first (cached)
    local data = buff_manager:get_buff_data(unit, { LIFEBLOOM_BUFF_ID })
    if data and data.is_active then
        local stacks = data.stacks or 1
        local remaining = data.remaining or 0
        return stacks, remaining * 1000  -- Convert to ms
    end
    
    -- Fallback: check unit directly
    local ok, stacks = pcall(function() return unit:get_buff_stacks(LIFEBLOOM_BUFF_ID) end)
    if ok and stacks and stacks > 0 then
        local ok2, remaining = pcall(function() return unit:get_buff_time_remaining(LIFEBLOOM_BUFF_ID) end)
        return stacks, (ok2 and remaining or 0) * 1000
    end
    
    return 0, 0
end

--- Check if bloom is optimal for this unit
---@param unit game_object Unit to check
---@param threshold_seconds number Seconds before expiry to consider bloom
---@param is_tank boolean Whether this is the tank (priority target)
---@return boolean should_allow_bloom
---@return string reason
function lifebloom_bloom_manager.should_allow_bloom(unit, threshold_seconds, is_tank)
    if not unit or not unit.is_valid or not unit:is_valid() then
        return false, "invalid_unit"
    end
    
    local stacks, remaining_ms = lifebloom_bloom_manager.get_lifebloom_state(unit)
    
    -- Must have 3 stacks to bloom effectively
    if stacks < 3 then
        return false, "building_stacks"
    end
    
    -- Check if we're in the bloom window
    local threshold_ms = (tonumber(threshold_seconds) or 1.5) * 1000
    local in_bloom_window = remaining_ms > 0 and remaining_ms <= threshold_ms
    
    if not in_bloom_window then
        return false, "outside_window"
    end
    
    -- Tank safety: only bloom if tank HP is safe
    if is_tank then
        local hp_pct = 100
        local ok, val = pcall(function() return unit:get_health_percentage() end)
        if ok and val then hp_pct = tonumber(val) or 100 end
        
        -- Don't bloom if tank is critically low (bloom heal won't save them)
        if hp_pct < 35 then
            return false, "tank_critical"
        end
        
        -- Don't bloom if tank has aggro on dangerous mob
        local ok2, has_aggro = pcall(function() return unit:has_aggro() end)
        if ok2 and has_aggro and hp_pct < 55 then
            return false, "tank_aggro_low"
        end
    end
    
    return true, "optimal"
end

--- Calculate effective heal from bloom
---@param unit game_object Unit receiving bloom
---@return number effective_heal Total heal (bloom + hot ticks before expiry)
function lifebloom_bloom_manager.calculate_bloom_value(unit)
    if not unit or not unit.is_valid or not unit:is_valid() then
        return 0
    end
    
    local stacks, remaining_ms = lifebloom_bloom_manager.get_lifebloom_state(unit)
    
    if stacks == 0 then
        return 0
    end
    
    -- Bloom heal (scales slightly with stacks but mostly flat)
    local bloom_heal = BLOOM_HEAL_AMOUNT * (1 + (stacks - 1) * 0.1)
    
    -- Add remaining HoT ticks
    local tick_interval = 1000  -- 1 second ticks
    local ticks_remaining = math.floor(remaining_ms / tick_interval)
    local tick_heal = 39 * stacks  -- ~39 per tick per stack at max level
    local hot_remaining = ticks_remaining * tick_heal
    
    return bloom_heal + hot_remaining
end

--- Record a bloom event for mana tracking
---@param unit game_object Unit that bloomed
---@param was_manual boolean Whether we intentionally let it bloom
function lifebloom_bloom_manager.record_bloom(unit, was_manual)
    if not unit then return end
    
    local guid = ""
    local ok, val = pcall(function() return unit:get_guid() end)
    if ok and val then guid = tostring(val) end
    
    table.insert(bloom_history, {
        guid = guid,
        timestamp = core.time(),
        mana_returned = BLOOM_MANA_RETURN,
        was_manual = was_manual == true,
        heal_amount = lifebloom_bloom_manager.calculate_bloom_value(unit)
    })
    
    -- Keep only last 50 blooms
    while #bloom_history > 50 do
        table.remove(bloom_history, 1)
    end
end

--- Get bloom statistics for reporting/optimization
---@param time_window_seconds number How far back to look (default 300 = 5 min)
---@return number total_blooms
---@return number manual_blooms
---@return number total_mana_returned
---@return number avg_heal_per_bloom
function lifebloom_bloom_manager.get_bloom_stats(time_window_seconds)
    local window = tonumber(time_window_seconds) or 300
    local cutoff_time = core.time() - window
    
    local total_blooms = 0
    local manual_blooms = 0
    local total_mana = 0
    local total_heal = 0
    
    for _, bloom in ipairs(bloom_history) do
        if bloom.timestamp >= cutoff_time then
            total_blooms = total_blooms + 1
            total_mana = total_mana + bloom.mana_returned
            total_heal = total_heal + bloom.heal_amount
            
            if bloom.was_manual then
                manual_blooms = manual_blooms + 1
            end
        end
    end
    
    local avg_heal = total_blooms > 0 and (total_heal / total_blooms) or 0
    
    return total_blooms, manual_blooms, total_mana, avg_heal
end

--- Get recommendation for tank Lifebloom management
---@param tank_unit game_object Tank unit
---@param menu table Menu configuration (for threshold settings)
---@return string action "refresh", "bloom", or "build"
---@return number priority 1-10 (higher = more urgent)
function lifebloom_bloom_manager.get_tank_recommendation(tank_unit, menu)
    if not tank_unit or not tank_unit.is_valid or not tank_unit:is_valid() then
        return "build", 0
    end
    
    local stacks, remaining_ms = lifebloom_bloom_manager.get_lifebloom_state(tank_unit)
    
    -- Get thresholds from menu (nil-guarded)
    local bloom_threshold = 1.5  -- default 1.5s
    local allow_bloom = false
    
    if menu then
        if menu.lifebloom_bloom_threshold then
            local method = menu.lifebloom_bloom_threshold.get
            if type(method) == "function" then
                bloom_threshold = method(menu.lifebloom_bloom_threshold) or 1.5
            end
        end
        if menu.lifebloom_allow_bloom then
            local method = menu.lifebloom_allow_bloom.get
            if type(method) == "function" then
                allow_bloom = method(menu.lifebloom_allow_bloom) or false
            end
        end
    end
    
    -- Building stacks (0-2): must refresh
    if stacks < 3 then
        local priority = (3 - stacks) * 2  -- 6, 4, 2
        if remaining_ms < 2000 then
            priority = priority + 3  -- Urgent if expiring soon
        end
        return "build", priority
    end
    
    -- 3 stacks: decide between refresh and bloom
    if remaining_ms <= (bloom_threshold * 1000) then
        if allow_bloom then
            -- Check if bloom is safe
            local should_bloom, reason = lifebloom_bloom_manager.should_allow_bloom(tank_unit, bloom_threshold, true)
            if should_bloom then
                return "bloom", 3  -- Low priority - let it bloom
            end
        end
        
        -- Either bloom not allowed or not safe - must refresh
        return "refresh", 8  -- High priority - about to fall off
    end
    
    -- 3 stacks with time remaining - check if refresh needed
    local refresh_threshold_ms = 3000  -- Refresh at <3s remaining
    if remaining_ms <= refresh_threshold_ms then
        return "refresh", 5
    end
    
    -- All good - no action needed
    return "hold", 0
end

--- Clean up old tracking data
function lifebloom_bloom_manager.cleanup()
    local now = core.time()
    if (now - last_cleanup_time) < 60 then  -- Cleanup every 60s
        return
    end
    last_cleanup_time = now
    
    -- Remove stale unit tracking (not seen in 5 minutes)
    local stale_cutoff = now - 300
    for guid, data in pairs(tracked_units) do
        if data.last_update and data.last_update < stale_cutoff then
            tracked_units[guid] = nil
        end
    end
    
    -- Trim bloom history to last 100 entries
    while #bloom_history > 100 do
        table.remove(bloom_history, 1)
    end
end

--- Debug output (if debug mode enabled)
---@param menu table Menu configuration
function lifebloom_bloom_manager.debug_output(menu)
    if not menu or not menu.debug then return end
    
    local method = menu.debug.get
    if type(method) ~= "function" then return end
    
    if not method(menu.debug) then return end
    
    local total, manual, mana, avg = lifebloom_bloom_manager.get_bloom_stats(300)
    if total > 0 then
        core.log(string.format("[LB Bloom] %d blooms (%d manual), %d mana returned, %.0f avg heal",
            total, manual, mana, avg))
    end
end

return lifebloom_bloom_manager
