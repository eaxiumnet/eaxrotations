-- heal_utils.lua
-- Shared healing utilities module for all EAX* healing specs
-- Provides target selection, effective health calculation, and healability checks

local heal_utils = {}

-- ============================================================================
-- API REQUIRES (Module Load)
-- ============================================================================

---@type izi_api
local _izi = require("common/izi_sdk")

---@type health_prediction
local _health_prediction = require("common/modules/health_prediction")

---@type target_selector
local _target_selector = require("common/modules/target_selector")

---@type pvp_helper
local _pvp_helper = require("common/utility/pvp_helper")

---@type unit_helper
local _unit_helper = require("common/utility/unit_helper")

-- ============================================================================
-- HOT-PATH API CACHING (Module Load)
-- ============================================================================

local _core_time = core.time
local _core_object_manager = core.object_manager

-- ============================================================================
-- CONSTANTS
-- ============================================================================

-- Default lookahead time for incoming heal prediction (seconds)
local DEFAULT_INCOMING_HEAL_LOOKAHEAD = 1.5

-- Default range for ally scanning (yards)
local DEFAULT_ALLY_RANGE = 40

-- Pre-allocated result tables to avoid GC pressure
local _cached_allies = {}
local _cached_ally_count = 0

-- ============================================================================
-- UTILITY FUNCTIONS
-- ============================================================================

---Safely get health percentage from a unit using unit_helper
---@param unit game_object
---@return number Health percentage (0-100)
local function get_unit_health_pct(unit)
    if not unit or not unit:is_valid() then
        return 100
    end

    local ok, result = pcall(function()
        local ok_hp, hp = pcall(function() return unit:get_health() end)
local ok_max, max_hp = pcall(function() return unit:get_max_health() end)
if not ok_hp or not ok_max or not hp or not max_hp or max_hp == 0 then return 100 end
return _((hp / max_hp) * 100)
    end)

    if ok and result then
        return result * 100  -- Convert from 0-1 to 0-100
    end

    -- Fallback to manual calculation
    if unit and unit.get_health and unit.get_max_health then
        local ok_hp, hp = pcall(function() return unit:get_health() end)
        local ok_max, max_hp = pcall(function() return unit:get_max_health() end)
        if hp and max_hp and max_hp > 0 then
            return (hp / max_hp) * 100
        end
    end

    return 100
end

---Safely check if unit is a tank using health_prediction module
---@param unit game_object
---@return boolean True if unit is a tank
local function is_unit_tank(unit)
    if not unit or not unit:is_valid() then
        return false
    end

    local ok, result = pcall(function()
        return _health_prediction:is_tank(unit)
    end)

    if ok then
        return result or false
    end

    -- Fallback to game_object method
    ok, result = pcall(function()
        return unit:is_tank()
    end)

    if ok then
        return result or false
    end

    return false
end

---Safely get incoming damage on a unit
---@param unit game_object
---@param lookahead number Time window in seconds
---@return number Incoming damage
local function get_unit_incoming_damage(unit, lookahead)
    if not unit or not unit:is_valid() then
        return 0
    end

    lookahead = lookahead or DEFAULT_INCOMING_HEAL_LOOKAHEAD

    local ok, result = pcall(function()
        return _health_prediction:get_incoming_damage(unit, lookahead)
    end)

    if ok and result then
        return result
    end

    -- Fallback to game_object method
    ok, result = pcall(function()
        return unit:get_incoming_damage(lookahead)
    end)

    if ok and result then
        return result
    end

    return 0
end

---Safely check if unit is immune to heals using pvp_helper
---@param unit game_object
---@return boolean True if unit cannot receive heals
local function is_unit_immune_to_heal(unit)
    if not unit or not unit:is_valid() then
        return true  -- Invalid units are "immune" (can't heal them)
    end

    local ok, result = pcall(function()
        return _pvp_helper:is_immune_to_heal(unit)
    end)

    if ok then
        return result or false
    end

    -- Fallback: check for Cyclone/Banish via game_object methods
    ok, result = pcall(function()
        return unit:is_cycloned() or unit:is_banished()
    end)

    if ok then
        return result or false
    end

    return false
end

-- ============================================================================
-- PUBLIC FUNCTIONS
-- ============================================================================

---Find the ally with the lowest effective HP (considering incoming heals/damage)
---@param me game_object The player unit
---@param threshold number|nil HP threshold (0-100), only return targets below this
---@param skip_self boolean|nil If true, exclude the player from results
---@return game_object|nil The lowest HP ally, or nil if none found
function heal_utils.find_lowest_effective_ally(me, threshold, skip_self)
    if not me or not me:is_valid() then
        return nil
    end

    threshold = threshold or 100
    skip_self = skip_self or false

    -- Get allies using target_selector
    local ok, allies = pcall(function()
        return _target_selector:get_targets_heal()
    end)

    if not ok or not allies or #allies == 0 then
        -- Fallback to izi.friends()
        ok, allies = pcall(function()
            return _izi.friends(DEFAULT_ALLY_RANGE)
        end)
    end

    if not ok or not allies or #allies == 0 then
        return nil
    end

    local lowest_ally = nil
    local lowest_effective_hp = threshold

    for _, ally in ipairs(allies) do
        if ally and ally:is_valid() and not ally:is_dead() then
            -- Skip self if requested
            if skip_self and ally == me then
                -- Skip
            else
                -- Check if healable
                if not is_unit_immune_to_heal(ally) then
                    -- Get effective HP using unit_helper:get_health_percentage_inc
                    local effective_hp = threshold
                    local ok_inc, hp_pct, incoming_dmg = pcall(function()
                        local hp, inc, _, _ = _unit_helper:get_health_percentage_inc(ally, DEFAULT_INCOMING_HEAL_LOOKAHEAD)
                        return hp, inc
                    end)

                    if ok_inc and hp_pct then
                        effective_hp = hp_pct
                    else
                        -- Fallback to basic health percentage
                        effective_hp = get_unit_health_pct(ally)
                    end

                    -- Track lowest
                    if effective_hp < lowest_effective_hp then
                        lowest_effective_hp = effective_hp
                        lowest_ally = ally
                    end
                end
            end
        end
    end

    return lowest_ally
end

---Identify the tank unit via aggro/role detection
---@param me game_object The player unit
---@return game_object|nil The tank unit, or nil if none found
function heal_utils.get_tank_unit(me)
    if not me or not me:is_valid() then
        return nil
    end

    -- Get allies using target_selector
    local ok, allies = pcall(function()
        return _target_selector:get_targets_heal()
    end)

    if not ok or not allies or #allies == 0 then
        -- Fallback to izi.friends()
        ok, allies = pcall(function()
            return _izi.friends(DEFAULT_ALLY_RANGE)
        end)
    end

    if not ok or not allies or #allies == 0 then
        return nil
    end

    -- First pass: look for explicit tank role
    for _, ally in ipairs(allies) do
        if ally and ally:is_valid() and not ally:is_dead() then
            if is_unit_tank(ally) then
                return ally
            end
        end
    end

    -- Second pass: look for unit with aggro (high threat)
    for _, ally in ipairs(allies) do
        if ally and ally:is_valid() and not ally:is_dead() then
            -- Check if unit has aggro via game_object method
            local ok_aggro, has_aggro = pcall(function()
                return ally:affecting_combat() and ally:get_enemies_in_range(10, false)
            end)

            if ok_aggro and has_aggro then
                -- Verify it's actually a tank-like target (melee range enemies)
                local ok_enemies, enemies = pcall(function()
                    return ally:get_enemies_in_melee_range(10)
                end)

                if ok_enemies and enemies and #enemies > 0 then
                    return ally
                end
            end
        end
    end

    return nil
end

---Count allies below a specific HP threshold (for AoE heal decisions)
---@param me game_object The player unit
---@param threshold number HP threshold (0-100)
---@return number Count of allies below threshold
function heal_utils.count_below_hp(me, threshold)
    if not me or not me:is_valid() then
        return 0
    end

    threshold = threshold or 80

    -- Get allies using target_selector
    local ok, allies = pcall(function()
        return _target_selector:get_targets_heal()
    end)

    if not ok or not allies or #allies == 0 then
        -- Fallback to izi.friends()
        ok, allies = pcall(function()
            return _izi.friends(DEFAULT_ALLY_RANGE)
        end)
    end

    if not ok or not allies or #allies == 0 then
        return 0
    end

    local count = 0

    for _, ally in ipairs(allies) do
        if ally and ally:is_valid() and not ally:is_dead() then
            if not is_unit_immune_to_heal(ally) then
                local hp_pct = get_unit_health_pct(ally)
                if hp_pct < threshold then
                    count = count + 1
                end
            end
        end
    end

    return count
end

---Get mana percentage for a unit (wrapper for consistency)
---@param me game_object The player unit
---@return number Mana percentage (0-100)
function heal_utils.get_mana_pct(me)
    if not me or not me:is_valid() then
        return 100
    end

    -- Try game_object method first
    local ok, result = pcall(function()
        return me:mana_pct()
    end)

    if ok and result then
        return result
    end

    -- Fallback to power query
    ok, result = pcall(function()
        local max = me:power_max(0)  -- 0 = mana
        local cur = me:power_current(0)
        if max and max > 0 then
            return (cur / max) * 100
        end
        return 100
    end)

    if ok and result then
        return result
    end

    return 100
end

---Check if a target can receive heals (not Cycloned, Banished, etc.)
---@param unit game_object The target unit
---@return boolean True if target can be healed
function heal_utils.is_healable_target(unit)
    if not unit or not unit:is_valid() then
        return false
    end

    if unit:is_dead() then
        return false
    end

    -- Check immunity using pvp_helper
    if is_unit_immune_to_heal(unit) then
        return false
    end

    -- Additional checks for specific CC states that block healing
    local ok, is_cycloned = pcall(function()
        return unit:is_cycloned()
    end)
    if ok and is_cycloned then
        return false
    end

    ok, is_cycloned = pcall(function()
        return _pvp_helper:is_crowd_controlled(unit, 500, 0x800)  -- CYCLONE flag
    end)
    if ok and is_cycloned then
        return false
    end

    return true
end

---Calculate effective health deficit considering incoming damage and heals
---@param unit game_object The target unit
---@param incoming_heal_lookahead number|nil Time window in seconds for prediction
---@return number Effective deficit (positive = needs healing, 0 = fully covered)
function heal_utils.predict_effective_deficit(unit, incoming_heal_lookahead)
    if not unit or not unit:is_valid() then
        return 0
    end

    if unit:is_dead() then
        return 0
    end

    incoming_heal_lookahead = incoming_heal_lookahead or DEFAULT_INCOMING_HEAL_LOOKAHEAD

    -- Get max health
    local ok, max_health = pcall(function()
        return unit:max_health()
    end)

    if not ok or not max_health or max_health <= 0 then
        return 0
    end

    -- Use unit_helper:get_health_percentage_inc for comprehensive prediction
    local ok_inc, health_pct_inc, incoming_damage, health_pct_raw, incoming_pct = pcall(function()
        return _unit_helper:get_health_percentage_inc(unit, incoming_heal_lookahead)
    end)

    if ok_inc and health_pct_inc then
        -- Calculate effective deficit based on predicted health
        local effective_health = (health_pct_inc / 100) * max_health
        local max_effective_deficit = max_health - effective_health

        -- If incoming damage is greater than 0, we need to account for it
        if incoming_damage and incoming_damage > 0 then
            return max_effective_deficit
        end

        -- Return deficit (never negative)
        return math.max(0, max_effective_deficit)
    end

    -- Fallback: manual calculation using health_prediction
    local current_health = 0
    ok, current_health = pcall(function()
        local ok_hp, hp = pcall(function() return unit:get_health() end); local ok_max, max_hp = pcall(function() return unit:get_max_health() end); if hp and max_hp and max_hp > 0 then return (hp / max_hp) * 100 end; return 100 / 100 * max_health
    end)

    if not ok or not current_health then
        current_health = max_health  -- Assume full health if we can't get current
    end

    -- Get incoming damage
    local incoming_dmg = get_unit_incoming_damage(unit, incoming_heal_lookahead)

    -- Calculate effective deficit
    local raw_deficit = max_health - current_health
    local effective_deficit = raw_deficit + incoming_dmg

    -- Clamp to max health (can't have more deficit than max health)
    return math.min(effective_deficit, max_health)
end

-- ============================================================================
-- MODULE EXPORT
-- ============================================================================

return heal_utils
