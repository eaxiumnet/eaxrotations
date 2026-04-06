-- =============================================================================
-- HEALING ENGINE - Shared Healing Utilities for Sylvanas Framework
-- Converted from Flux AIO healing.lua patterns
-- Provides: target scanning, effective HP calculation, HoT tracking
-- =============================================================================

local izi = require("izi_sdk")
local core = _G.core

-- =============================================================================
-- HEALING ENGINE
-- =============================================================================
local HealingEngine = {
    -- Configuration
    scan_interval = 0.1,  -- 100ms throttle between scans
    heal_range = 40,      -- Default healing range in yards
    
    -- State
    last_scan_time = 0,
    cached_targets = {},
    cached_count = 0,
    
    -- Pre-allocated target pool (avoid GC in combat)
    targets = {},
}

-- Initialize the target pool
function HealingEngine:init()
    for i = 1, 40 do
        self.targets[i] = {
            unit = nil,
            unit_obj = nil,
            hp = 100,
            effective_hp = 100,
            is_player = false,
            is_tank = false,
            has_aggro = false,
            -- Dynamic fields added by class-specific checkers
        }
    end
    return self
end

-- =============================================================================
-- TARGET VALIDATION
-- =============================================================================
function HealingEngine:is_valid_heal_target(unit_obj)
    if not unit_obj then return false end
    if not unit_obj:is_valid() then return false end
    if unit_obj:is_dead_or_ghost() then return false end
    if not unit_obj:is_connected() then return false end
    
    -- Range check (40 yards default for healing)
    if not unit_obj:is_in_range(self.heal_range) then return false end
    
    return true
end

-- =============================================================================
-- MAIN SCANNING FUNCTION
-- =============================================================================
function HealingEngine:scan_targets(class_specific_checker)
    -- Throttle scans to avoid excessive API calls
    local now = core.game_time()
    if now - self.last_scan_time < self.scan_interval and self.cached_count > 0 then
        return self.cached_targets, self.cached_count
    end
    
    self.last_scan_time = now
    self.cached_count = 0
    
    -- Get party or raid members
    local members = {}
    local raid = izi.raid and izi.raid() or {}
    if #raid > 0 then
        members = raid
    else
        local party = izi.party and izi.party() or {}
        members = party
    end
    
    -- Scan and collect valid targets
    for _, unit_obj in ipairs(members) do
        if self:is_valid_heal_target(unit_obj) then
            self.cached_count = self.cached_count + 1
            local entry = self.targets[self.cached_count]
            
            -- Basic target info
            entry.unit = unit_obj:id() or "unknown"
            entry.unit_obj = unit_obj
            entry.hp = unit_obj:get_health_percentage()
            entry.is_player = unit_obj:is_player()
            entry.is_tank = (unit_obj:get_role() == "TANK")
            
            -- Aggro detection via incoming damage (3 second window)
            local inc_dmg = unit_obj:get_incoming_damage(3000) or 0
            entry.has_aggro = inc_dmg > 0 or entry.is_tank
            
            -- Calculate effective HP
            -- Formula: current_hp + incoming_heals - incoming_damage
            local max_hp = unit_obj:get_health_max()
            local current_hp = unit_obj:get_health()
            
            local inc_heals = unit_obj:get_incoming_heals(2.5) or 0
            local inc_dmg_short = unit_obj:get_incoming_damage(2500) or 0
            
            -- Convert to percentage
            local heal_pct = (inc_heals / max_hp) * 100
            local dmg_pct = (inc_dmg_short / max_hp) * 100
            
            entry.effective_hp = entry.hp + heal_pct - dmg_pct
            
            -- Class-specific buff/debuff detection
            if class_specific_checker then
                class_specific_checker(entry, unit_obj)
            end
            
            self.cached_targets[self.cached_count] = entry
        end
    end
    
    -- Sort by effective HP ascending (lowest first)
    if self.cached_count > 1 then
        table.sort(self.cached_targets, function(a, b)
            return a.effective_hp < b.effective_hp
        end)
    end
    
    return self.cached_targets, self.cached_count
end

-- =============================================================================
-- TARGET RETRIEVAL FUNCTIONS
-- =============================================================================

-- Get the tank target (or lowest HP if no tank found)
function HealingEngine:get_tank_target()
    for i = 1, self.cached_count do
        local target = self.cached_targets[i]
        if target and target.is_tank then
            return target
        end
    end
    -- Fallback to lowest HP target
    return self.cached_count > 0 and self.cached_targets[1] or nil
end

-- Get the lowest HP target below a threshold
function HealingEngine:get_lowest_hp_target(threshold)
    threshold = threshold or 100
    for i = 1, self.cached_count do
        local target = self.cached_targets[i]
        if target and target.hp < threshold then
            return target
        end
    end
    return nil
end

-- Count targets below HP threshold
function HealingEngine:count_below_hp(threshold)
    local count = 0
    for i = 1, self.cached_count do
        local target = self.cached_targets[i]
        if target and target.hp < threshold then
            count = count + 1
        end
    end
    return count
end

-- Check if all targets are above HP threshold
function HealingEngine:all_above_hp(threshold)
    for i = 1, self.cached_count do
        local target = self.cached_targets[i]
        if target and target.hp < threshold then
            return false
        end
    end
    return true
end

-- Get emergency targets (below critical threshold)
function HealingEngine:get_emergency_targets(threshold)
    threshold = threshold or 30
    local emergencies = {}
    local count = 0
    
    for i = 1, self.cached_count do
        local target = self.cached_targets[i]
        if target and target.hp < threshold then
            count = count + 1
            emergencies[count] = target
        end
    end
    
    return emergencies, count
end

-- =============================================================================
-- SPELL SELECTION HELPERS
-- =============================================================================

-- Select best heal rank based on target deficit and options
function HealingEngine:select_best_heal_rank(spell_ranks, target_deficit_pct, options)
    options = options or {}
    options.overheal_threshold = options.overheal_threshold or 1.2  -- Allow 20% overheal
    
    -- Mode: Prioritize speed (fastest cast that won't overheal too much)
    if options.prioritize_speed then
        for _, rank in ipairs(spell_ranks) do
            local spell = izi.spell(rank.spell_id)
            if spell:is_learned() and spell:is_ready() then
                local expected_heal_pct = (rank.heal_amount / rank.base_hp) * 100
                local overheal = expected_heal_pct / target_deficit_pct
                if overheal <= options.overheal_threshold then
                    return spell, rank
                end
            end
        end
        return nil, nil
    end
    
    -- Mode: Prioritize efficiency (best heal per mana)
    if options.prioritize_efficiency then
        local best_rank = nil
        local best_efficiency = 0
        
        for _, rank in ipairs(spell_ranks) do
            local spell = izi.spell(rank.spell_id)
            if spell:is_learned() and spell:is_ready() and rank.mana_cost > 0 then
                local efficiency = rank.heal_amount / rank.mana_cost
                if efficiency > best_efficiency then
                    -- Check overheal constraint
                    local expected_heal_pct = (rank.heal_amount / rank.base_hp) * 100
                    if expected_heal_pct <= target_deficit_pct * options.overheal_threshold then
                        best_efficiency = efficiency
                        best_rank = rank
                    end
                end
            end
        end
        
        if best_rank then
            return izi.spell(best_rank.spell_id), best_rank
        end
    end
    
    -- Default: Largest rank that won't overheal > threshold
    for i = #spell_ranks, 1, -1 do
        local rank = spell_ranks[i]
        local spell = izi.spell(rank.spell_id)
        if spell:is_learned() and spell:is_ready() then
            local expected_heal_pct = (rank.heal_amount / rank.base_hp) * 100
            if target_deficit_pct >= expected_heal_pct * 0.8 then  -- Allow 20% overheal
                return spell, rank
            end
        end
    end
    
    -- Fallback: smallest available rank
    for _, rank in ipairs(spell_ranks) do
        local spell = izi.spell(rank.spell_id)
        if spell:is_learned() and spell:is_ready() then
            return spell, rank
        end
    end
    
    return nil, nil
end

-- =============================================================================
-- UTILITY FUNCTIONS
-- =============================================================================

-- Clear cached targets (call on combat end/reset)
function HealingEngine:clear_cache()
    self.cached_count = 0
    self.cached_targets = {}
    self.last_scan_time = 0
end

-- Set custom scan interval
function HealingEngine:set_scan_interval(interval)
    self.scan_interval = interval
end

-- Set custom heal range
function HealingEngine:set_heal_range(range)
    self.heal_range = range
end

-- =============================================================================
-- EXPORT
-- =============================================================================

-- Auto-initialize on load
HealingEngine:init()

return HealingEngine


