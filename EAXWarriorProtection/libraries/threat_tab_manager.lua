-- libraries/threat_tab_manager.lua
-- Threat-aware tab targeting system for EAX tanking specs
-- Ported from Flux AIO protection.lua with adaptations for Project Sylvanas

local threat_tab_manager = {}

-- Unit priority constants (higher = more important)
threat_tab_manager.PRIO_BOSS = 3
threat_tab_manager.PRIO_ELITE = 2
threat_tab_manager.PRIO_TRASH = 1

-- Configuration
threat_tab_manager.MANUAL_TARGET_GRACE = 3  -- seconds
threat_tab_manager.TAB_COOLDOWN = 0.5       -- seconds between tab attempts
threat_tab_manager.SCAN_RADIUS = 50         -- yards for enemy scan
threat_tab_manager.CHECK_RANGE = 30         -- yards for threat check

-- State
local state = {
    last_manual_target_time = 0,
    last_tab_target_time = 0,
    last_target_guid = nil,
    desired_target = nil,
    tab_attempts = 0,
    max_tab_attempts = 10,
}

-- Threat tier definitions:
-- 0 = not on threat table (loose mob)
-- 1 = have threat but not tanking (target is someone else)
-- 2 = insecurely tanking (high threat but not highest)
-- 3 = securely tanking (highest threat)

---Get threat level for a unit
---@param target game_object
---@param me game_object
---@return number threat_level (0-3)
function threat_tab_manager.get_threat_level(target, me)
    if not target or not target:is_valid() then return 0 end
    if not me or not me:is_valid() then return 0 end
    
    -- Use core.threat API if available
    if target.get_threat_situation then
        local ok, threat_data = pcall(function() return target:get_threat_situation(me) end)
        if ok and threat_data then
            -- threat_data.status: 0=none, 1=aggro, 2=lose, 3=secure
            return threat_data.status or 0
        end
    end
    
    -- Fallback: check target's target
    local target_target = target:get_target()
    if target_target and target_target:is_valid() then
        if me == target_target then
            return 2  -- Target is on us but we can't confirm we're top threat
        end
    end
    
    return 0  -- Loose mob (not targeting us)
end

---Get unit priority for targeting
---@param target game_object
---@return number priority (PRIO_BOSS, PRIO_ELITE, or PRIO_TRASH)
function threat_tab_manager.get_unit_priority(target)
    if not target or not target:is_valid() then return threat_tab_manager.PRIO_TRASH end
    
    local classification = target:get_classification()
    if classification == "worldboss" then return threat_tab_manager.PRIO_BOSS end
    if classification == "elite" or classification == "rareelite" then 
        return threat_tab_manager.PRIO_ELITE 
    end
    return threat_tab_manager.PRIO_TRASH
end

---Check if manual target was recently selected
---@return boolean in_grace_period
function threat_tab_manager.is_manual_target_grace()
    local now = core.time()
    return (now - state.last_manual_target_time) < threat_tab_manager.MANUAL_TARGET_GRACE
end

---Update manual target detection
---@param current_target game_object|nil
function threat_tab_manager.update_manual_target(current_target)
    if not current_target or not current_target:is_valid() then return end
    
    local current_guid = nil
    if current_target.get_guid then
        local ok, guid = pcall(function() return current_target:get_guid() end)
        if ok then current_guid = guid end
    end
    
    if current_guid and current_guid ~= state.last_target_guid then
        -- Target changed - record manual selection time
        state.last_manual_target_time = core.time()
        state.last_target_guid = current_guid
    end
end

---Get best target for threat management
---Scans all visible enemies and returns the most urgent target
---@param me game_object
---@param current_target game_object|nil
---@param min_priority number Minimum unit priority to consider
---@return game_object|nil best_target
---@return string|nil reason
function threat_tab_manager.get_best_target(me, current_target, min_priority)
    if not me or not me:is_valid() then return nil, "invalid_player" end
    
    min_priority = min_priority or threat_tab_manager.PRIO_TRASH
    
    local current_threat = 0
    if current_target and current_target:is_valid() then
        current_threat = threat_tab_manager.get_threat_level(current_target, me)
    end
    
    -- Categorize all visible enemies by threat tier
    local tier0_units = {}  -- Loose mobs (not on threat table)
    local tier1_units = {}  -- Have threat but not tanking
    local tier2_units = {}  -- Insecurely tanking
    
    local scan_radius_sq = threat_tab_manager.SCAN_RADIUS * threat_tab_manager.SCAN_RADIUS
    local objects = core.object_manager.get_visible_objects()
    
    for i = 1, #objects do
        local obj = objects[i]
        if obj and obj:is_valid() and obj:is_unit() and not obj:is_dead() then
            if me:can_attack(obj) then
                -- Check distance
                local my_pos = me:get_position()
                local obj_pos = obj:get_position()
                if my_pos and obj_pos then
                    local dx = obj_pos.x - my_pos.x
                    local dy = obj_pos.y - my_pos.y
                    local dz = obj_pos.z - my_pos.z
                    local dist_sq = dx*dx + dy*dy + dz*dz
                    
                    if dist_sq <= scan_radius_sq then
                        -- Skip current target
                        if not (current_target and obj == current_target) then
                            local priority = threat_tab_manager.get_unit_priority(obj)
                            if priority >= min_priority then
                                local threat = threat_tab_manager.get_threat_level(obj, me)
                                
                                if threat == 0 then
                                    table.insert(tier0_units, {unit = obj, priority = priority})
                                elseif threat == 1 then
                                    table.insert(tier1_units, {unit = obj, priority = priority})
                                elseif threat == 2 then
                                    table.insert(tier2_units, {unit = obj, priority = priority})
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    
    -- Helper to find highest priority unit in a tier
    local function get_highest_priority(units)
        local best = nil
        local best_prio = 0
        for _, entry in ipairs(units) do
            if entry.priority > best_prio then
                best_prio = entry.priority
                best = entry.unit
            end
        end
        return best
    end
    
    -- SWITCH LOGIC: Only switch to MORE urgent threats
    -- Current threat 0 (loose): Stay and build threat
    -- Current threat 1 (have aggro): Switch to tier 0 (loose mob)
    -- Current threat 2 (insecure): Switch to tier 0 first, then tier 1
    -- Current threat 3 (secure): Can switch to any lower tier
    
    if current_threat == 0 then
        -- Stay on loose mob and build threat
        return nil, "building_threat"
    elseif current_threat == 1 then
        -- Have aggro but not tanking: only switch to loose mob
        local best_t0 = get_highest_priority(tier0_units)
        if best_t0 then
            return best_t0, "loose_mob"
        end
        return nil, "no_loose_mobs"
    elseif current_threat == 2 then
        -- Insecurely tanking: loose mobs first, then other non-tanking
        local best_t0 = get_highest_priority(tier0_units)
        if best_t0 then
            return best_t0, "loose_mob"
        end
        local best_t1 = get_highest_priority(tier1_units)
        if best_t1 then
            return best_t1, "not_tanking"
        end
        return nil, "no_better_target"
    else
        -- Securely tanking (3+): can leave for any lower threat tier
        local best_t0 = get_highest_priority(tier0_units)
        if best_t0 then
            return best_t0, "loose_mob"
        end
        local best_t1 = get_highest_priority(tier1_units)
        if best_t1 then
            return best_t1, "not_tanking"
        end
        local best_t2 = get_highest_priority(tier2_units)
        if best_t2 then
            return best_t2, "insecure_threat"
        end
        return nil, "all_secure"
    end
end

---Should we tab target?
---@param me game_object
---@param current_target game_object|nil
---@param menu table Menu settings
---@return boolean should_tab
---@return string|nil reason
---@return game_object|nil new_target
function threat_tab_manager.should_tab(me, current_target, menu)
    -- Check if tab targeting is enabled
    local use_auto_tab = false
    if menu and menu.use_auto_tab and menu.use_auto_tab.get_state then
        local ok, val = pcall(function() return menu.use_auto_tab:get_state() end)
        if ok then use_auto_tab = val end
    end
    if not use_auto_tab then
        return false, "disabled", nil
    end
    
    -- Respect manual target grace period
    if threat_tab_manager.is_manual_target_grace() then
        return false, "manual_target_grace", nil
    end
    
    -- Check tab cooldown
    local now = core.time()
    if (now - state.last_tab_target_time) < threat_tab_manager.TAB_COOLDOWN then
        return false, "tab_cooldown", nil
    end
    
    -- Single target - no need to tab
    local enemy_count = 0
    local objects = core.object_manager.get_visible_objects()
    for i = 1, #objects do
        local obj = objects[i]
        if obj and obj:is_valid() and obj:is_unit() and not obj:is_dead() then
            if me:can_attack(obj) then
                enemy_count = enemy_count + 1
                if enemy_count >= 2 then break end
            end
        end
    end
    if enemy_count < 2 then
        return false, "single_target", nil
    end
    
    -- Get minimum priority setting
    local min_priority = threat_tab_manager.PRIO_TRASH
    if menu and menu.tab_min_priority and menu.tab_min_priority.get then
        local ok, val = pcall(function() return menu.tab_min_priority:get() end)
        if ok then
            -- Map setting (1=trash, 2=elite, 3=boss)
            if val == 1 then min_priority = threat_tab_manager.PRIO_TRASH
            elseif val == 2 then min_priority = threat_tab_manager.PRIO_ELITE
            elseif val >= 3 then min_priority = threat_tab_manager.PRIO_BOSS
            end
        end
    end
    
    -- Get best target for threat management
    local best_target, reason = threat_tab_manager.get_best_target(me, current_target, min_priority)
    
    if best_target then
        state.desired_target = best_target
        return true, reason, best_target
    end
    
    return false, reason or "no_target_found", nil
end

---Execute tab target to desired unit
---Uses core.input.set_target() Sylvanas API
---@param me game_object
---@return boolean success
function threat_tab_manager.execute_tab(me)
    if not state.desired_target or not state.desired_target:is_valid() then
        return false
    end
    
    -- Use Sylvanas API: core.input.set_target()
    local ok = pcall(function()
        core.input.set_target(state.desired_target)
    end)
    
    if ok then
        state.last_tab_target_time = core.time()
        state.tab_attempts = state.tab_attempts + 1
        return true
    end
    
    return false
end

---Get state information for debugging
---@return table state_info
function threat_tab_manager.get_state()
    return {
        last_manual_target_time = state.last_manual_target_time,
        last_tab_target_time = state.last_tab_target_time,
        last_target_guid = state.last_target_guid,
        desired_target_valid = state.desired_target and state.desired_target:is_valid(),
        tab_attempts = state.tab_attempts,
        in_manual_grace = threat_tab_manager.is_manual_target_grace(),
    }
end

---Reset all state (useful on zone change, death, etc.)
function threat_tab_manager.reset()
    state.last_manual_target_time = 0
    state.last_tab_target_time = 0
    state.last_target_guid = nil
    state.desired_target = nil
    state.tab_attempts = 0
end

return threat_tab_manager
