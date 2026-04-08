-- rejuv_spread_manager.lua
-- Proactive Rejuvenation blanketing for raid healing
-- Spreads HoTs across injured party members before they need direct heals

---@type buff_manager
local buff_manager = require("common/modules/buff_manager")

local rejuv_spread_manager = {}

-- ============================================================================
-- CONSTANTS
-- ============================================================================
local REJUVENATION_BUFF_IDS = {
    26982, 26981, 25299, 9841, 9840, 9839, 8910, 3627, 2091, 2090, 1430, 1058, 774
}

local REJUVENATION_SPELL_ID = 26982  -- Max rank for casting

-- ============================================================================
-- STATE
-- ============================================================================
local last_scan_time = 0
local scan_cache = {}
local SCAN_CACHE_DURATION = 0.5  -- 500ms

-- ============================================================================
-- CORE FUNCTIONS
-- ============================================================================

--- Check if unit already has Rejuvenation
---@param unit game_object Unit to check
---@return boolean has_rejuv
function rejuv_spread_manager.has_rejuvenation(unit)
    if not unit or not unit.is_valid or not unit:is_valid() then
        return false
    end
    
    local data = buff_manager:get_buff_data(unit, REJUVENATION_BUFF_IDS)
    if data and data.is_active then
        return true
    end
    
    -- Fallback: check directly
    local ok, has_buff = pcall(function()
        for _, id in ipairs(REJUVENATION_BUFF_IDS) do
            if unit:has_buff(id) then
                return true
            end
        end
        return false
    end)
    
    return ok and has_buff
end

--- Check if unit is a good candidate for Rejuv
---@param unit game_object Unit to evaluate
---@param hp_threshold number HP% below which to consider (default 0.85)
---@param exclude_tanks boolean Whether to skip tanks
---@return boolean should_rejuv
---@return number priority 1-10
function rejuv_spread_manager.is_rejuv_candidate(unit, hp_threshold, exclude_tanks)
    if not unit or not unit.is_valid or not unit:is_valid() then
        return false, 0
    end
    
    if unit:is_dead() then
        return false, 0
    end
    
    -- Skip if already has Rejuv
    if rejuv_spread_manager.has_rejuvenation(unit) then
        return false, 0
    end
    
    -- Get HP%
    local ok, hp_pct = pcall(function() return unit:get_health_percentage() end)
    if not ok or not hp_pct then
        return false, 0
    end
    
    local threshold = tonumber(hp_threshold) or 85
    if hp_pct >= threshold then
        return false, 0
    end
    
    -- Check role
    local ok2, is_tank = pcall(function()
        return unit_helper:is_tank(unit)
    end)
    
    if exclude_tanks and ok2 and is_tank then
        return false, 0
    end
    
    -- Calculate priority (lower HP = higher priority)
    local priority = math.floor((threshold - hp_pct) / 5) + 1
    priority = math.min(math.max(priority, 1), 10)
    
    -- Boost priority for predicted damage
    local ok3, will_need_heal = pcall(function()
        return heal_engine.will_need_heal(unit, threshold / 100, 3.0)
    end)
    
    if ok3 and will_need_heal then
        priority = priority + 2
    end
    
    return true, math.min(priority, 10)
end

--- Get all Rejuv candidates in group
---@param me game_object Player unit
---@param hp_threshold number HP% threshold
---@param max_targets number Maximum targets to find
---@param exclude_tanks boolean Skip tanks
---@return table candidates Array of {unit, priority, hp_pct}
function rejuv_spread_manager.get_candidates(me, hp_threshold, max_targets, exclude_tanks)
    local candidates = {}
    
    if not me or not me.is_valid or not me:is_valid() then
        return candidates
    end
    
    -- Check cache
    local now = core.time()
    if (now - last_scan_time) < SCAN_CACHE_DURATION then
        return scan_cache.candidates or candidates
    end
    
    last_scan_time = now
    
    -- Get group units
    local allies = {}
    local ok, ally_list = pcall(function()
        return unit_helper:get_ally_list_around(
            me:get_position(),
            60.0,  -- 60 yard range
            true,  -- include self
            true   -- include party/raid
        )
    end)
    
    if ok and ally_list then
        allies = ally_list
    end
    
    local max = tonumber(max_targets) or 5
    
    for _, ally in ipairs(allies) do
        if #candidates >= max then
            break
        end
        
        local should_rejuv, priority = rejuv_spread_manager.is_rejuv_candidate(
            ally, hp_threshold, exclude_tanks
        )
        
        if should_rejuv then
            local ok_hp, hp_pct = pcall(function() return ally:get_health_percentage() end)
            table.insert(candidates, {
                unit = ally,
                priority = priority,
                hp_pct = hp_pct or 85,
            })
        end
    end
    
    -- Sort by priority (highest first)
    table.sort(candidates, function(a, b)
        return a.priority > b.priority
    end)
    
    -- Cache result
    scan_cache = {
        candidates = candidates,
        timestamp = now
    }
    
    return candidates
end

--- Count current Rejuvenations active
---@param me game_object Player unit (for range check)
---@return number count
function rejuv_spread_manager.count_active_rejuvs(me)
    if not me or not me.is_valid or not me:is_valid() then
        return 0
    end
    
    local count = 0
    
    -- Check self first
    if rejuv_spread_manager.has_rejuvenation(me) then
        count = count + 1
    end
    
    -- Check allies
    local ok, allies = pcall(function()
        return unit_helper:get_ally_list_around(
            me:get_position(),
            60.0,
            false,  -- exclude self (already checked)
            true
        )
    end)
    
    if ok and allies then
        for _, ally in ipairs(allies) do
            if rejuv_spread_manager.has_rejuvenation(ally) then
                count = count + 1
            end
        end
    end
    
    return count
end

--- Find best target for next Rejuv
---@param me game_object Player unit
---@param menu table Menu configuration
---@return game_object|nil target
---@return number priority
function rejuv_spread_manager.find_best_target(me, menu)
    if not me or not me.is_valid or not me:is_valid() then
        return nil, 0
    end
    
    -- Get menu settings (nil-guarded)
    local hp_threshold = 80
    local max_targets = 5
    local exclude_tanks = false
    
    if menu then
        if menu.resto_proactive_hp then
            local method = menu.resto_proactive_hp.get
            if type(method) == "function" then
                hp_threshold = method(menu.resto_proactive_hp) or 80
            end
        end
        if menu.resto_max_rejuv_targets then
            local method = menu.resto_max_rejuv_targets.get
            if type(method) == "function" then
                max_targets = method(menu.resto_max_rejuv_targets) or 5
            end
        end
    end
    
    -- Check if we're already at max targets
    local active_count = rejuv_spread_manager.count_active_rejuvs(me)
    if active_count >= max_targets then
        return nil, 0
    end
    
    -- Get candidates
    local candidates = rejuv_spread_manager.get_candidates(
        me, hp_threshold, max_targets - active_count, exclude_tanks
    )
    
    if #candidates == 0 then
        return nil, 0
    end
    
    -- Return highest priority
    return candidates[1].unit, candidates[1].priority
end

--- Execute Rejuv spread on best target
---@param me game_object Player unit
---@param utils table Utils library
---@param spells table Spells database
---@param menu table Menu configuration
---@return boolean success
function rejuv_spread_manager.try_spread(me, utils, spells, menu)
    local target, priority = rejuv_spread_manager.find_best_target(me, menu)
    
    if not target then
        return false
    end
    
    -- Get Rejuv spell ID
    local spell_id = spells.REJUVENATION and spells.REJUVENATION[1]
    if not spell_id then
        return false
    end
    
    -- Check if already has Rejuv (double-check)
    if rejuv_spread_manager.has_rejuvenation(target) then
        return false
    end
    
    -- Cast
    if utils and utils.cast_target then
        local ok, result = pcall(utils.cast_target, utils, spell_id, target)
        if ok and result then
            return true
        end
    end
    
    return false
end

--- Get spread status for debugging
---@param me game_object Player unit
---@return table status
function rejuv_spread_manager.get_status(me)
    local active = rejuv_spread_manager.count_active_rejuvs(me)
    local candidates = rejuv_spread_manager.get_candidates(me, 80, 10, false)
    
    return {
        active_rejuvs = active,
        candidate_count = #candidates,
        last_scan = last_scan_time,
    }
end

return rejuv_spread_manager
