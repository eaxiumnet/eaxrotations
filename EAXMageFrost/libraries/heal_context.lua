-- heal_context.lua
-- Shared healing context module for all EAX healing specs
-- Builds a cached view of the healing situation for party/raid
--
-- Usage:
--   local heal_context = require("heal_context")
--   local ctx = heal_context.get_context(me)
--   if ctx.injured_count > 0 then
--       -- Heal the lowest ally
--       local target = ctx.lowest_ally
--   end

local heal_context = {}

-- ============================================================================
-- MODULE REQUIRES (API Resources)
-- ============================================================================

---@type izi_api
local izi = require("common/izi_sdk")

---@type health_prediction
local health_prediction = require("common/modules/health_prediction")

---@type target_selector
local target_selector = require("common/modules/target_selector")

---@type spell_prediction
local spell_prediction = require("common/modules/spell_prediction")

---@type unit_helper
local unit_helper = require("common/utility/unit_helper")

-- ============================================================================
-- HOT-PATH API CACHING (Module Load)
-- ============================================================================

local _core_time = core.time
local _core_object_manager = core.object_manager

-- ============================================================================
-- CONSTANTS
-- ============================================================================

-- Throttle interval for context rebuild (0.5 seconds)
local REBUILD_INTERVAL_S = 0.5

-- Default health threshold for considering a unit "injured"
local DEFAULT_INJURED_THRESHOLD = 90

-- Default emergency threshold
local DEFAULT_EMERGENCY_THRESHOLD = 40

-- Max scan range for healing (40 yards is typical for most heals)
local MAX_HEAL_RANGE = 40

-- ============================================================================
-- STATIC CACHE TABLES (No per-frame allocation)
-- ============================================================================

-- Pre-allocated context table (reused each build)
local _cached_context = {
    tanks = {},
    healers = {},
    injured = {},
    lowest_ally = nil,
    lowest_hp_pct = 100,
    injured_count = 0,
    total_allies = 0,
    avg_party_hp = 100,
    timestamp = 0,
    valid = false
}

-- Pre-allocated temporary tables for scanning
local _temp_allies = { n = 0 }
local _temp_tanks = { n = 0 }
local _temp_healers = { n = 0 }
local _temp_injured = { n = 0 }

-- Last rebuild timestamp for throttling
local _last_rebuild_time = 0

-- Force rebuild flag
local _force_rebuild = false

-- ============================================================================
-- HELPER FUNCTIONS
-- ============================================================================

---Clear a static table efficiently (sets n=0, doesn't create new table)
---@param t table Table with 'n' field for count
local function clear_static_table(t)
    t.n = 0
end

---Add item to static table
---@param t table Table with 'n' field
---@param item any Item to add
local function add_to_static_table(t, item)
    local n = t.n + 1
    t[n] = item
    t.n = n
end

---Get health percentage safely using unit_helper
---@param unit game_object
---@return number Health percentage (0-100)
local function get_health_percentage_safe(unit)
    if not unit or not unit:is_valid() then
        return 100
    end

    local ok, pct = pcall(function()
        return unit_helper:get_health_percentage(unit) * 100
    end)

    if ok and pct then
        return pct
    end

    -- Fallback to game_object method
    ok, pct = pcall(function()
        return unit:get_health_percentage()
    end)

    if ok and pct then
        return pct
    end

    return 100
end

---Check if unit is a tank using health_prediction and unit_helper
---@param unit game_object
---@return boolean
local function is_tank_unit(unit)
    if not unit or not unit:is_valid() then
        return false
    end

    -- Try health_prediction first
    local ok, is_tank = pcall(function()
        return health_prediction:is_tank(unit)
    end)

    if ok and is_tank then
        return true
    end

    -- Fallback to unit_helper
    ok, is_tank = pcall(function()
        return unit_helper:is_tank(unit)
    end)

    if ok and is_tank then
        return true
    end

    -- Fallback to game_object method
    ok, is_tank = pcall(function()
        return unit:is_tank()
    end)

    return ok and is_tank
end

---Check if unit is a healer
---@param unit game_object
---@return boolean
local function is_healer_unit(unit)
    if not unit or not unit:is_valid() then
        return false
    end

    -- Try unit_helper first
    local ok, is_healer = pcall(function()
        return unit_helper:is_healer(unit)
    end)

    if ok and is_healer then
        return true
    end

    -- Fallback to game_object method
    ok, is_healer = pcall(function()
        return unit:is_healer()
    end)

    return ok and is_healer
end

---Check if unit is injured (below threshold)
---@param unit game_object
---@param threshold number
---@return boolean
local function is_injured(unit, threshold)
    if not unit or not unit:is_valid() then
        return false
    end

    local hp_pct = get_health_percentage_safe(unit)
    return hp_pct < threshold
end

---Calculate average health of a list of units
---@param units table Array of game_objects with 'n' count
---@return number Average health percentage
local function calculate_avg_health(units)
    if units.n == 0 then
        return 100
    end

    local total = 0
    for i = 1, units.n do
        local unit = units[i]
        if unit and unit:is_valid() then
            total = total + get_health_percentage_safe(unit)
        end
    end

    return total / units.n
end

---Find the unit with lowest health
---@param units table Array of game_objects with 'n' count
---@return game_object|nil Lowest health unit
---@return number Lowest health percentage
local function find_lowest_hp_unit(units)
    if units.n == 0 then
        return nil, 100
    end

    local lowest_unit = nil
    local lowest_pct = 100

    for i = 1, units.n do
        local unit = units[i]
        if unit and unit:is_valid() then
            local pct = get_health_percentage_safe(unit)
            if pct < lowest_pct then
                lowest_pct = pct
                lowest_unit = unit
            end
        end
    end

    return lowest_unit, lowest_pct
end

---Count units below health threshold
---@param units table Array of game_objects with 'n' count
---@param threshold number
---@return number Count of injured units
local function count_injured_units(units, threshold)
    local count = 0
    for i = 1, units.n do
        local unit = units[i]
        if unit and unit:is_valid() then
            if is_injured(unit, threshold) then
                count = count + 1
            end
        end
    end
    return count
end

---Get all injured units
---@param units table Array of game_objects with 'n' count
---@param threshold number
---@param result_table table Table to store results (must have 'n' field)
local function get_injured_units(units, threshold, result_table)
    clear_static_table(result_table)

    for i = 1, units.n do
        local unit = units[i]
        if unit and unit:is_valid() then
            if is_injured(unit, threshold) then
                add_to_static_table(result_table, unit)
            end
        end
    end
end

-- ============================================================================
-- CORE SCANNING FUNCTIONS
-- ============================================================================

---Scan party/raid and populate ally lists
---Uses izi.friends() and izi.party() for efficient scanning
---@param me game_object Local player
local function scan_allies(me)
    clear_static_table(_temp_allies)
    clear_static_table(_temp_tanks)
    clear_static_table(_temp_healers)

    if not me or not me:is_valid() then
        return
    end

    -- Get friends/allies in heal range using izi SDK
    local ok, allies = pcall(function()
        -- Try party first (more accurate for healing)
        local party = izi.party(MAX_HEAL_RANGE)
        if party and #party > 0 then
            return party
        end
        -- Fall back to friends
        return izi.friends(MAX_HEAL_RANGE)
    end)

    if not ok or not allies then
        -- Fallback to object manager scan
        local objects = _core_object_manager.get_all_objects()
        for i = 1, #objects do
            local obj = objects[i]
            if obj and obj:is_valid() and obj:is_unit() then
                -- Check if ally
                local is_ally_ok, is_ally = pcall(function()
                    return obj:is_valid_ally()
                end)

                if is_ally_ok and is_ally then
                    -- Check range
                    local range_ok, in_range = pcall(function()
                        return obj:is_in_range(MAX_HEAL_RANGE)
                    end)

                    if range_ok and in_range then
                        add_to_static_table(_temp_allies, obj)

                        -- Classify
                        if is_tank_unit(obj) then
                            add_to_static_table(_temp_tanks, obj)
                        elseif is_healer_unit(obj) then
                            add_to_static_table(_temp_healers, obj)
                        end
                    end
                end
            end
        end
        return
    end

    -- Process allies from izi
    for _, ally in ipairs(allies) do
        if ally and ally:is_valid() then
            add_to_static_table(_temp_allies, ally)

            -- Classify role
            if is_tank_unit(ally) then
                add_to_static_table(_temp_tanks, ally)
            elseif is_healer_unit(ally) then
                add_to_static_table(_temp_healers, ally)
            end
        end
    end
end

-- ============================================================================
-- CONTEXT BUILDING
-- ============================================================================

---Build the healing context
---Scans party/raid, identifies tanks, counts injured, finds lowest HP ally
---@param me game_object Local player
---@return table Healing context table
function heal_context.build(me)
    local now = _core_time()

    -- Check throttle
    if not _force_rebuild then
        local time_since_last = now - _last_rebuild_time
        if time_since_last < REBUILD_INTERVAL_S then
            return _cached_context
        end
    end

    -- Reset force rebuild flag
    _force_rebuild = false
    _last_rebuild_time = now

    -- Scan allies
    scan_allies(me)

    -- Find lowest HP ally
    local lowest_ally, lowest_hp_pct = find_lowest_hp_unit(_temp_allies)

    -- Get injured units (using default threshold)
    get_injured_units(_temp_allies, DEFAULT_INJURED_THRESHOLD, _temp_injured)

    -- Calculate average party health
    local avg_hp = calculate_avg_health(_temp_allies)

    -- Update cached context
    _cached_context.lowest_ally = lowest_ally
    _cached_context.lowest_hp_pct = lowest_hp_pct
    _cached_context.injured_count = _temp_injured.n
    _cached_context.total_allies = _temp_allies.n
    _cached_context.avg_party_hp = avg_hp
    _cached_context.timestamp = now
    _cached_context.valid = true

    -- Copy tanks (shallow copy of references)
    _cached_context.tanks = {}
    for i = 1, _temp_tanks.n do
        _cached_context.tanks[i] = _temp_tanks[i]
    end
    _cached_context.tanks.n = _temp_tanks.n

    -- Copy healers
    _cached_context.healers = {}
    for i = 1, _temp_healers.n do
        _cached_context.healers[i] = _temp_healers[i]
    end
    _cached_context.healers.n = _temp_healers.n

    -- Copy injured
    _cached_context.injured = {}
    for i = 1, _temp_injured.n do
        _cached_context.injured[i] = _temp_injured[i]
    end
    _cached_context.injured.n = _temp_injured.n

    return _cached_context
end

-- ============================================================================
-- PUBLIC API FUNCTIONS
-- ============================================================================

---Get cached healing context
---Returns the cached context, rebuilding if necessary (throttled)
---@param me game_object|nil Local player (optional, will fetch if nil)
---@return table Healing context table with:
---   - tanks: table of tank units
---   - healers: table of healer units
---   - injured: table of injured units
---   - lowest_ally: game_object with lowest HP
---   - lowest_hp_pct: number (0-100)
---   - injured_count: number
---   - total_allies: number
---   - avg_party_hp: number (0-100)
---   - timestamp: number (last build time)
---   - valid: boolean (true if context has been built)
function heal_context.get_context(me)
    -- Get local player if not provided
    if not me or not me:is_valid() then
        local ok, player = pcall(function()
            return _core_object_manager.get_local_player()
        end)
        if ok and player then
            me = player
        else
            -- Return empty context if no player available
            return _cached_context
        end
    end

    -- Build context (throttled internally)
    return heal_context.build(me)
end

---Force context rebuild on next get
---Call this when significant events occur (combat start, group change, etc.)
function heal_context.invalidate()
    _force_rebuild = true
end

---Get list of tanks from context
---@return table Array of tank game_objects (with 'n' count field)
function heal_context.get_tanks()
    return _cached_context.tanks or { n = 0 }
end

---Get count of allies below health threshold
---@param threshold number|nil Health percentage threshold (default: 90)
---@return number Count of injured allies
function heal_context.get_injured_count(threshold)
    threshold = threshold or DEFAULT_INJURED_THRESHOLD

    -- If context is fresh, use cached injured count if threshold matches
    if threshold == DEFAULT_INJURED_THRESHOLD then
        return _cached_context.injured_count or 0
    end

    -- Otherwise count manually from allies
    return count_injured_units(_temp_allies, threshold)
end

---Find best target for AoE heal (Chain Heal, Circle of Healing, etc.)
---Uses spell_prediction for optimal positioning
---@param aoe_spell_id number Spell ID for the AoE heal
---@param min_targets number|nil Minimum targets to consider (default: 2)
---@return game_object|nil Best target for AoE heal, or nil if no good target
function heal_context.get_aoe_heal_target(aoe_spell_id, min_targets)
    min_targets = min_targets or 2

    if not aoe_spell_id then
        return nil
    end

    -- Ensure we have a valid context
    if not _cached_context.valid then
        heal_context.get_context()
    end

    -- If not enough injured targets, skip
    if _cached_context.injured_count < min_targets then
        return nil
    end

    -- Use spell_prediction to find best position
    local ok, result = pcall(function()
        -- Create spell data for prediction
        local spell_data = spell_prediction:new_spell_data(
            aoe_spell_id,
            MAX_HEAL_RANGE,  -- max_range
            15,              -- radius (typical AoE heal radius)
            0,               -- cast_time (instant for most AoE heals)
            0,               -- projectile_speed
            spell_prediction.prediction_type.MOST_HITS,
            spell_prediction.geometry_type.CIRCLE
        )

        -- Get injured allies as potential targets
        local injured = _cached_context.injured
        if not injured or injured.n == 0 then
            return nil
        end

        -- Find best target that hits most injured allies
        local best_target = nil
        local best_hits = 0

        for i = 1, injured.n do
            local target = injured[i]
            if target and target:is_valid() then
                local pred_result = spell_prediction:get_cast_position(target, spell_data)
                if pred_result and pred_result.amount_of_hits >= min_targets then
                    if pred_result.amount_of_hits > best_hits then
                        best_hits = pred_result.amount_of_hits
                        best_target = target
                    end
                end
            end
        end

        return best_target
    end)

    if ok then
        return result
    end

    -- Fallback: return lowest HP ally if enough injured
    if _cached_context.injured_count >= min_targets then
        return _cached_context.lowest_ally
    end

    return nil
end

---Check if emergency healing situation exists
---@param emergency_threshold number|nil Health percentage for emergency (default: 40)
---@return boolean True if emergency healing is needed
function heal_context.is_emergency_situation(emergency_threshold)
    emergency_threshold = emergency_threshold or DEFAULT_EMERGENCY_THRESHOLD

    -- Ensure we have a valid context
    if not _cached_context.valid then
        heal_context.get_context()
    end

    -- Check if lowest ally is below emergency threshold
    if _cached_context.lowest_hp_pct <= emergency_threshold then
        return true
    end

    -- Check if multiple allies are injured (3+ below 50%)
    local critical_count = count_injured_units(_temp_allies, 50)
    if critical_count >= 3 then
        return true
    end

    -- Check if tanks are in danger
    local tanks = _cached_context.tanks
    if tanks and tanks.n > 0 then
        for i = 1, tanks.n do
            local tank = tanks[i]
            if tank and tank:is_valid() then
                local tank_hp = get_health_percentage_safe(tank)
                if tank_hp <= emergency_threshold then
                    return true
                end
            end
        end
    end

    return false
end

---Get the lowest health ally
---@return game_object|nil Lowest health ally, or nil if none
---@return number Health percentage of lowest ally
function heal_context.get_lowest_ally()
    if not _cached_context.valid then
        heal_context.get_context()
    end

    return _cached_context.lowest_ally, _cached_context.lowest_hp_pct
end

---Get average party health percentage
---@return number Average health percentage (0-100)
function heal_context.get_avg_party_hp()
    if not _cached_context.valid then
        heal_context.get_context()
    end

    return _cached_context.avg_party_hp or 100
end

---Check if context is valid (has been built at least once)
---@return boolean
function heal_context.is_valid()
    return _cached_context.valid
end

---Get the time since last context build
---@return number Seconds since last build
function heal_context.get_time_since_build()
    local now = _core_time()
    return now - _last_rebuild_time
end

---Force immediate rebuild (bypasses throttle)
---@param me game_object|nil Local player
---@return table Fresh healing context
function heal_context.force_rebuild(me)
    _force_rebuild = true
    return heal_context.get_context(me)
end

-- ============================================================================
-- UTILITY FUNCTIONS
-- ============================================================================

---Check if a specific unit needs healing
---@param unit game_object Unit to check
---@param threshold number|nil Health threshold (default: 90)
---@return boolean True if unit needs healing
function heal_context.unit_needs_healing(unit, threshold)
    if not unit or not unit:is_valid() then
        return false
    end

    threshold = threshold or DEFAULT_INJURED_THRESHOLD
    return is_injured(unit, threshold)
end

---Get health percentage for a unit (convenience function)
---@param unit game_object
---@return number Health percentage (0-100)
function heal_context.get_unit_health_pct(unit)
    return get_health_percentage_safe(unit)
end

---Check if unit is a tank (convenience function)
---@param unit game_object
---@return boolean
function heal_context.is_unit_tank(unit)
    return is_tank_unit(unit)
end

---Check if unit is a healer (convenience function)
---@param unit game_object
---@return boolean
function heal_context.is_unit_healer(unit)
    return is_healer_unit(unit)
end

-- ============================================================================
-- MODULE EXPORT
-- ============================================================================

return heal_context
