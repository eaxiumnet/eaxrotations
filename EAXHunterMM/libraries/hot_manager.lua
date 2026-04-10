-- hot_manager.lua
-- Shared HoT (Heal over Time) tracking module for Druid and Priest healing
-- Prevents overwriting HoTs and manages Lifebloom 3-stack maintenance

local hot_manager = {}

-- ============================================================================
-- API Resources
-- ============================================================================

---@type buff_manager
local buff_manager = require('common/modules/buff_manager')

---@type izi_api
local izi = require('common/izi_sdk')

-- ============================================================================
-- API Caching (at module load)
-- ============================================================================

local _get_local_player = core.object_manager.get_local_player
local _get_friends_in_range = core.object_manager.get_friends_in_range

-- Get health/mana from game_object methods (not core.unit.*)
local function _get_health_percentage(unit)
    if unit and unit.get_health and unit.get_max_health then
        local ok_hp, hp = pcall(function() return unit:get_health() end)
        local ok_max, max_hp = pcall(function() return unit:get_max_health() end)
        if ok_hp and ok_max and hp and max_hp and max_hp > 0 then return (hp / max_hp) * 100 end
        return 100
    end
    return 100
end

local function _unit_exists(unit)
    return unit ~= nil and unit.is_valid ~= nil and unit:is_valid()
end

local function _unit_is_dead(unit)
    if unit and unit.is_dead then
        return unit:is_dead()
    end
    return true
end

-- ============================================================================
-- HoT Spell ID Tables (TBC Classic)
-- ============================================================================

-- Rejuvenation spell IDs (all ranks)
local REJUVENATION_IDS = { 774, 1058, 1430, 2090, 2091, 3627, 8910, 9839, 9840, 9841, 25299, 26981, 26982 }

-- Regrowth spell IDs (all ranks)
local REGROWTH_IDS = { 8936, 8938, 8939, 8940, 8941, 9750, 9856, 9857, 9858, 26980, 26981 }

-- Renew spell IDs (all ranks)
local RENEW_IDS = { 139, 6074, 6075, 6076, 6077, 6078, 10927, 10928, 10929, 25315, 25221, 25222, 26981, 26982 }

-- Lifebloom spell ID (TBC)
local LIFEBLOOM_ID = 33763

-- All HoT IDs for counting
local ALL_HOT_IDS = {}
local ALL_HOT_IDS_COUNT = 0

-- Build combined table once at load
local function build_all_hot_ids()
    ALL_HOT_IDS_COUNT = 0
    
    -- Add Rejuvenation IDs
    for _, id in ipairs(REJUVENATION_IDS) do
        ALL_HOT_IDS_COUNT = ALL_HOT_IDS_COUNT + 1
        ALL_HOT_IDS[ALL_HOT_IDS_COUNT] = id
    end
    
    -- Add Regrowth IDs
    for _, id in ipairs(REGROWTH_IDS) do
        ALL_HOT_IDS_COUNT = ALL_HOT_IDS_COUNT + 1
        ALL_HOT_IDS[ALL_HOT_IDS_COUNT] = id
    end
    
    -- Add Renew IDs
    for _, id in ipairs(RENEW_IDS) do
        ALL_HOT_IDS_COUNT = ALL_HOT_IDS_COUNT + 1
        ALL_HOT_IDS[ALL_HOT_IDS_COUNT] = id
    end
    
    -- Add Lifebloom
    ALL_HOT_IDS_COUNT = ALL_HOT_IDS_COUNT + 1
    ALL_HOT_IDS[ALL_HOT_IDS_COUNT] = LIFEBLOOM_ID
end

build_all_hot_ids()

-- ============================================================================
-- Internal Cache
-- ============================================================================

-- Cache table with n=0 pattern (not {} allocation per frame)
local _hot_cache = { n = 0 }
local _cache_timestamp = 0
local _cache_ttl = 1.0 -- Cache time-to-live in seconds

-- Pre-allocated scan results table
local _scan_results = {}
local _scan_results_count = 0

-- ============================================================================
-- Core HoT Functions
-- ============================================================================

---Check if a target has a specific HoT buff
---@param unit game_object|nil The unit to check
---@param hot_spell_id number|number[] The HoT spell ID(s) to check for
---@return boolean True if the unit has the HoT
function hot_manager.has_hot(unit, hot_spell_id)
    if not unit or not hot_spell_id then
        return false
    end
    
    -- Use izi_sdk unit:has_buff() for efficient checking
    local success, has = pcall(function()
        return unit:has_buff(hot_spell_id)
    end)
    
    if success then
        return has or false
    end
    
    -- Fallback to buff_manager if izi fails
    local success2, buff_data = pcall(function()
        return buff_manager:get_buff_data(unit, hot_spell_id)
    end)
    
    if success2 and buff_data then
        return buff_data.is_active or false
    end
    
    return false
end

---Get the remaining duration of a HoT on a target
---@param unit game_object|nil The unit to check
---@param hot_spell_id number|number[] The HoT spell ID(s) to check for
---@return number Remaining duration in seconds (0 if not found)
function hot_manager.get_hot_remaining(unit, hot_spell_id)
    if not unit or not hot_spell_id then
        return 0
    end
    
    -- Use izi_sdk unit:buff_remains() for efficient checking
    local success, remains = pcall(function()
        return unit:buff_remains(hot_spell_id)
    end)
    
    if success and remains then
        return remains > 0 and remains or 0
    end
    
    -- Fallback to buff_manager
    local success2, buff_data = pcall(function()
        return buff_manager:get_buff_data(unit, hot_spell_id)
    end)
    
    if success2 and buff_data and buff_data.is_active then
        return buff_data.remaining or 0
    end
    
    return 0
end

---Count total HoTs on a target (for Druid mastery-style calculations)
---@param unit game_object|nil The unit to check
---@return number Count of active HoTs
function hot_manager.count_hots(unit)
    if not unit then
        return 0
    end
    
    local count = 0
    
    -- Check all known HoT IDs
    for i = 1, ALL_HOT_IDS_COUNT do
        local hot_id = ALL_HOT_IDS[i]
        if hot_manager.has_hot(unit, hot_id) then
            count = count + 1
        end
    end
    
    return count
end

---Check if Lifebloom needs refresh (for 3-stack maintenance)
---Returns true if:
--- - Lifebloom is not at 3 stacks
--- - Lifebloom is about to expire (below threshold)
--- - Lifebloom is missing entirely
---@param unit game_object|nil The unit to check
---@param refresh_threshold number|nil Seconds before expiry to trigger refresh (default: 3)
---@return boolean True if Lifebloom needs refresh
function hot_manager.is_lifebloom_refresh_needed(unit, refresh_threshold)
    if not unit then
        return false
    end
    
    refresh_threshold = refresh_threshold or 3
    
    -- Get Lifebloom data using buff_manager for stack count
    local success, buff_data = pcall(function()
        return buff_manager:get_buff_data(unit, LIFEBLOOM_ID)
    end)
    
    if not success or not buff_data or not buff_data.is_active then
        -- Lifebloom is missing - refresh needed
        return true
    end
    
    -- Check stack count (Lifebloom should be maintained at 3 stacks)
    local stacks = buff_data.stacks or 0
    if stacks < 3 then
        return true
    end
    
    -- Check remaining duration
    local remaining = buff_data.remaining or 0
    if remaining <= refresh_threshold then
        return true
    end
    
    return false
end

---Get the current Lifebloom stack count on a target
---@param unit game_object|nil The unit to check
---@return number Stack count (0-3)
function hot_manager.get_lifebloom_stacks(unit)
    if not unit then
        return 0
    end
    
    local success, buff_data = pcall(function()
        return buff_manager:get_buff_data(unit, LIFEBLOOM_ID)
    end)
    
    if success and buff_data and buff_data.is_active then
        return buff_data.stacks or 1
    end
    
    return 0
end

-- ============================================================================
-- Target Finding Functions
-- ============================================================================

---Internal: Get party/raid units to scan
---@return table Array of unit IDs
---@return number Max units to scan
local function get_units_to_scan()
    local is_in_raid = _G.IsInRaid and _G.IsInRaid() or false
    
    if is_in_raid then
        local raid_units = {}
        for i = 1, 40 do
            raid_units[i] = 'raid' .. i
        end
        return raid_units, 40
    else
        return {'player', 'party1', 'party2', 'party3', 'party4'}, 5
    end
end

---Internal: Check if unit is valid for healing
---@param unit_id string Unit ID to check
---@return boolean True if valid
local function is_valid_heal_target(unit_id)
    if not unit_id then
        return false
    end
    
    local exists = _G.UnitExists and _G.UnitExists(unit_id) or false
    if not exists then
        return false
    end
    
    local is_dead = _G.UnitIsDead and _G.UnitIsDead(unit_id) or false
    if is_dead then
        return false
    end
    
    local is_connected = _G.UnitIsConnected and _G.UnitIsConnected(unit_id) or true
    if not is_connected then
        return false
    end
    
    local can_assist = _G.UnitCanAssist and _G.UnitCanAssist('player', unit_id) or false
    if not can_assist then
        return false
    end
    
    return true
end

---Internal: Get unit health percentage
---@param unit_id string Unit ID
---@return number Health percentage (0-100)
local function get_unit_hp_pct(unit_id)
    if not unit_id then
        return 100
    end
    
    local max_hp = _G.UnitHealthMax and _G.UnitHealthMax(unit_id) or 1
    local current_hp = _G.UnitHealth and _G.UnitHealth(unit_id) or max_hp
    
    if max_hp > 0 then
        return (current_hp / max_hp) * 100
    end
    
    return 100
end

---Internal: Scan for healing targets and cache results
---@return table Array of valid healing targets
---@return number Count of targets
local function scan_healing_targets()
    -- Check cache validity
    local now = core.time()
    if now - _cache_timestamp < _cache_ttl and _hot_cache.n > 0 then
        return _hot_cache, _hot_cache.n
    end
    
    -- Clear cache using n=0 pattern
    _hot_cache.n = 0
    _scan_results_count = 0
    
    local units, max_units = get_units_to_scan()
    
    for i = 1, max_units do
        local unit_id = units[i]
        
        if is_valid_heal_target(unit_id) then
            local hp_pct = get_unit_hp_pct(unit_id)
            
            _scan_results_count = _scan_results_count + 1
            
            -- Reuse or create entry
            if not _scan_results[_scan_results_count] then
                _scan_results[_scan_results_count] = {}
            end
            
            local entry = _scan_results[_scan_results_count]
            entry.unit_id = unit_id
            entry.hp_pct = hp_pct
            entry.has_renew = hot_manager.has_hot(unit_id, RENEW_IDS)
            entry.has_rejuvenation = hot_manager.has_hot(unit_id, REJUVENATION_IDS)
            entry.has_regrowth = hot_manager.has_hot(unit_id, REGROWTH_IDS)
            entry.has_lifebloom = hot_manager.has_hot(unit_id, LIFEBLOOM_ID)
            entry.lifebloom_stacks = entry.has_lifebloom and hot_manager.get_lifebloom_stacks(unit_id) or 0
            entry.lifebloom_remains = entry.has_lifebloom and hot_manager.get_hot_remaining(unit_id, LIFEBLOOM_ID) or 0
        end
    end
    
    -- Copy to cache
    for i = 1, _scan_results_count do
        if not _hot_cache[i] then
            _hot_cache[i] = {}
        end
        
        local src = _scan_results[i]
        local dst = _hot_cache[i]
        
        dst.unit_id = src.unit_id
        dst.hp_pct = src.hp_pct
        dst.has_renew = src.has_renew
        dst.has_rejuvenation = src.has_rejuvenation
        dst.has_regrowth = src.has_regrowth
        dst.has_lifebloom = src.has_lifebloom
        dst.lifebloom_stacks = src.lifebloom_stacks
        dst.lifebloom_remains = src.lifebloom_remains
    end
    
    _hot_cache.n = _scan_results_count
    _cache_timestamp = now
    
    return _hot_cache, _hot_cache.n
end

---Find a target that needs Renew (no existing Renew, below health threshold)
---@param threshold number|nil Health percentage threshold (default: 90)
---@return string|nil Unit ID that needs Renew, or nil
function hot_manager.get_renew_target(threshold)
    threshold = threshold or 90
    
    local targets, count = scan_healing_targets()
    
    for i = 1, count do
        local entry = targets[i]
        if entry and not entry.has_renew and entry.hp_pct < threshold then
            return entry.unit_id
        end
    end
    
    return nil
end

---Find a target that needs Rejuvenation (no existing Rejuvenation, below health threshold)
---@param threshold number|nil Health percentage threshold (default: 90)
---@return string|nil Unit ID that needs Rejuvenation, or nil
function hot_manager.get_rejuvenation_target(threshold)
    threshold = threshold or 90
    
    local targets, count = scan_healing_targets()
    
    for i = 1, count do
        local entry = targets[i]
        if entry and not entry.has_rejuvenation and entry.hp_pct < threshold then
            return entry.unit_id
        end
    end
    
    return nil
end

---Find a target that needs Regrowth (no existing Regrowth, below health threshold)
---@param threshold number|nil Health percentage threshold (default: 80)
---@return string|nil Unit ID that needs Regrowth, or nil
function hot_manager.get_regrowth_target(threshold)
    threshold = threshold or 80
    
    local targets, count = scan_healing_targets()
    
    for i = 1, count do
        local entry = targets[i]
        if entry and not entry.has_regrowth and entry.hp_pct < threshold then
            return entry.unit_id
        end
    end
    
    return nil
end

---Find a target that needs Lifebloom (not at 3 stacks or expiring soon)
---@param threshold number|nil Health percentage threshold (default: 95)
---@param refresh_threshold number|nil Seconds before expiry to trigger refresh (default: 3)
---@return string|nil Unit ID that needs Lifebloom, or nil
function hot_manager.get_lifebloom_target(threshold, refresh_threshold)
    threshold = threshold or 95
    refresh_threshold = refresh_threshold or 3
    
    local targets, count = scan_healing_targets()
    
    -- First pass: find targets missing Lifebloom entirely
    for i = 1, count do
        local entry = targets[i]
        if entry and not entry.has_lifebloom and entry.hp_pct < threshold then
            return entry.unit_id
        end
    end
    
    -- Second pass: find targets with low stacks or expiring soon
    for i = 1, count do
        local entry = targets[i]
        if entry and entry.has_lifebloom then
            if entry.lifebloom_stacks < 3 or entry.lifebloom_remains <= refresh_threshold then
                return entry.unit_id
            end
        end
    end
    
    return nil
end

-- ============================================================================
-- Cache Management
-- ============================================================================

---Clear the HoT cache (call periodically or when group composition changes)
function hot_manager.clear_cache()
    _hot_cache.n = 0
    _cache_timestamp = 0
    _scan_results_count = 0
end

---Set the cache TTL (time-to-live)
---@param seconds number New TTL in seconds
function hot_manager.set_cache_ttl(seconds)
    _cache_ttl = seconds or 1.0
end

---Get cache statistics for debugging
---@return table Stats containing cache info
function hot_manager.get_cache_stats()
    return {
        cache_entries = _hot_cache.n,
        cache_timestamp = _cache_timestamp,
        cache_ttl = _cache_ttl,
        cache_age = core.time() - _cache_timestamp
    }
end

-- ============================================================================
-- Module Export
-- ============================================================================

return hot_manager
