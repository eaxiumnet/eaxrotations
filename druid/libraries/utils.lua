-- =============================================================================
-- DRUID UTILITIES MODULE
-- Ported from Flux AIO - Helper functions for TBC Druid Rotation
-- =============================================================================

local core = _G.core
local izi = require("common/izi_sdk")
local Constants = require("libraries/constants")

-- Hot-path API caching (EAX pattern)
local _core_time = core.time

local Utils = {}

-- ============================================================================
-- STANCE DETECTION
-- ============================================================================

--- Get current druid stance/form
-- Returns: 0=Caster, 1=Bear, 3=Cat, 4=Travel, 5=Moonkin/Tree
function Utils.get_stance()
    local me = izi.me()
    if not me or not me:is_valid() then return 0 end
    
    if me:buff_up(768) then return Constants.STANCE.CAT
    elseif me:buff_up(9634) then return Constants.STANCE.BEAR
    elseif me:buff_up(24858) then return Constants.STANCE.MOONKIN
    elseif me:buff_up(33891) then return Constants.STANCE.TREE
    elseif me:buff_up(783) then return Constants.STANCE.TRAVEL
    else return Constants.STANCE.CASTER end
end

--- Check if a specific stance is active
function Utils.is_stance(stance)
    return Utils.get_stance() == stance
end

-- ============================================================================
-- WOLFSHEAD HELM DETECTION
-- ============================================================================

local wolfshead_cache = {
    equipped = false,
    last_check = 0,
    CHECK_INTERVAL = 2.0,
}

--- Check if Wolfshead Helm is equipped
function Utils.has_wolfshead_helm()
    local now = _core_time()
    if now - wolfshead_cache.last_check < wolfshead_cache.CHECK_INTERVAL then
        return wolfshead_cache.equipped
    end
    
    local item_id = nil
    local ok, result = pcall(function()
        return core.inventory_manager.get_item_in_slot(Constants.ITEM_ID.INVSLOT_HEAD)
    end)
    if ok and result then
        local ok2, id = pcall(function() return result:get_id() end)
        if ok2 then item_id = id end
    end
    
    wolfshead_cache.equipped = (item_id == Constants.ITEM_ID.WOLFSHEAD_HELM)
    wolfshead_cache.last_check = now
    return wolfshead_cache.equipped
end

-- ============================================================================
-- ENERGY TICK TRACKER
-- ============================================================================

Utils.energy_tick = {
    last_tick_time = 0,
    last_energy = 0,
    confident = false,
    last_shift_time = 0,
    tick_count = 0,
}

--- Update energy tick tracking
function Utils.energy_tick:update(current_energy, stance)
    if stance ~= Constants.STANCE.CAT then
        self.last_energy = 0
        return
    end
    
    local now = _core_time()
    local energy_diff = current_energy - self.last_energy
    
    if energy_diff > 0 then
        -- Filter out Furor energy (40) within ignore window
        if energy_diff == Constants.POWERSHIFT.FUROR_ENERGY then
            local time_since_shift = now - self.last_shift_time
            if time_since_shift < Constants.POWERSHIFT.SHIFT_IGNORE_WINDOW then
                self.last_energy = current_energy
                return
            end
        end
        
        -- Filter out Wolfshead energy (20) within ignore window
        if energy_diff == Constants.POWERSHIFT.WOLFSHEAD_BONUS then
            local time_since_shift = now - self.last_shift_time
            if time_since_shift < Constants.POWERSHIFT.SHIFT_IGNORE_WINDOW then
                self.last_energy = current_energy
                return
            end
        end
        
        -- Normal energy tick (1-25 energy)
        if energy_diff >= 1 and energy_diff <= 25 then
            self.last_tick_time = now
            self.tick_count = self.tick_count + 1
            if self.tick_count >= 2 then
                self.confident = true
            end
        end
    end
    
    self.last_energy = current_energy
end

--- Get time until next expected energy tick
function Utils.energy_tick:time_until_next()
    if not self.confident then return 1.0 end
    local now = _core_time()
    local elapsed = now - self.last_tick_time
    local remaining = Constants.ENERGY.TICK_INTERVAL - (elapsed % Constants.ENERGY.TICK_INTERVAL)
    return remaining
end

--- Check if we should delay powershift for imminent tick
function Utils.energy_tick:should_delay()
    if not self.confident then return false end
    return self:time_until_next() <= Constants.POWERSHIFT.TICK_WAIT_THRESHOLD
end

--- Record a form shift time
function Utils.energy_tick:record_shift()
    self.last_shift_time = _core_time()
    self.tick_count = 0
    self.confident = false
end

-- ============================================================================
-- FORM COST UTILITIES
-- ============================================================================

local form_cost_cache = {
    [768] = { cost = 0, expires = 0 },   -- Cat
    [9634] = { cost = 0, expires = 0 },  -- Bear
    [24858] = { cost = 0, expires = 0 }, -- Moonkin
    [783] = { cost = 0, expires = 0 },   -- Travel
    [33891] = { cost = 0, expires = 0 }, -- Tree
}

local FORM_COST_CACHE_TTL = 5.0

--- Get mana cost of a form spell
function Utils.get_form_cost(spell_id)
    local cached = form_cost_cache[spell_id]
    local now = _core_time()
    
    if cached and now < cached.expires then
        return cached.cost
    end
    
    -- Try to get actual cost from spell info
    local cost = 0
    local me = izi.me()
    if me and me:is_valid() then
        local ok, mana = pcall(function() return me:mana_current() end)
        if ok then
            -- Base costs: Cat/Bear ~435 mana at 70, varies by level
            -- We'll estimate based on known values
            if spell_id == 768 or spell_id == 9634 then
                cost = 435  -- Approximate base
            elseif spell_id == 24858 or spell_id == 33891 then
                cost = 0    -- No mana cost
            elseif spell_id == 783 then
                cost = 200  -- Travel form
            end
        end
    end
    
    if cached then
        cached.cost = cost
        cached.expires = now + FORM_COST_CACHE_TTL
    end
    
    return cost
end

-- ============================================================================
-- IMMUNITY CHECKS
-- ============================================================================

local IMMUNITY_TOTAL = { 642, 1020, 45438, 11958, 1022, 5599, 10278, 31224, 33786, 710, 18647, 498, 19263 }
local IMMUNITY_PHYS = { 1022, 5599, 10278, 642, 1020, 45438, 11958, 33786, 710, 18647, 3169, 19263 }
local IMMUNITY_MAGIC = { 31224, 8178, 642, 1020, 45438, 11958, 33786 }

--- Check if target has any immunity buff
function Utils.has_immunity(target)
    if not target or not target:is_valid() then return false end
    for _, id in ipairs(IMMUNITY_TOTAL) do
        if target:buff_up(id) then return true end
    end
    return false
end

--- Check if target has physical immunity
function Utils.has_phys_immunity(target)
    if not target or not target:is_valid() then return false end
    for _, id in ipairs(IMMUNITY_PHYS) do
        if target:buff_up(id) then return true end
    end
    return false
end

--- Check if target has magic immunity
function Utils.has_magic_immunity(target)
    if not target or not target:is_valid() then return false end
    for _, id in ipairs(IMMUNITY_MAGIC) do
        if target:buff_up(id) then return true end
    end
    return false
end

-- ============================================================================
-- DEBUFF CHECKS
-- ============================================================================

--- Check if target has Faerie Fire debuff (any source)
function Utils.has_faerie_fire(target)
    if not target or not target:is_valid() then return 0 end
    for _, id in ipairs(Constants.FAERIE_FIRE_DEBUFF_IDS) do
        local rem = target:debuff_remains(id)
        if rem > 0 then return rem end
    end
    return 0
end

--- Check if target has Mangle debuff
function Utils.has_mangle(target)
    if not target or not target:is_valid() then return 0 end
    for _, id in ipairs(Constants.MANGLE_DEBUFF_IDS) do
        local rem = target:debuff_remains(id)
        if rem > 0 then return rem end
    end
    return 0
end

--- Get Lacerate info on target
function Utils.get_lacerate_info(target)
    if not target or not target:is_valid() then return 0, 0 end
    local stacks = target:get_debuff_stacks(Constants.DEBUFF_ID.LACERATE) or 0
    local duration = target:debuff_remains(Constants.DEBUFF_ID.LACERATE) or 0
    return stacks, duration
end

-- ============================================================================
-- CC SAFETY CHECKS
-- ============================================================================

--- Check for breakable CC nearby
function Utils.has_breakable_cc_nearby(range)
    range = range or Constants.AOE.SWIPE_CC_CHECK_RANGE
    local enemies = izi.enemies(range)
    
    for _, enemy in ipairs(enemies) do
        if enemy:is_valid() then
            for _, cc_name in ipairs(Constants.BREAKABLE_CC_NAMES) do
                -- Check by debuff name would require iterating debuffs
                -- For now, simplified check using common CC spell IDs
                local cc_ids = {
                    [118] = true,    -- Polymorph
                    [3355] = true,   -- Freezing Trap
                    [20066] = true,  -- Repentance
                    [2094] = true,   -- Blind
                    [6770] = true,   -- Sap
                    [1776] = true,   -- Gouge
                    [2637] = true,   -- Hibernate
                    [19386] = true,  -- Wyvern Sting
                    [6358] = true,   -- Seduction
                }
                for id, _ in pairs(cc_ids) do
                    if enemy:debuff_up(id) then
                        return true
                    end
                end
            end
        end
    end
    return false
end

-- ============================================================================
-- THREAT UTILITIES (Simplified for Sylvanas)
-- ============================================================================

--- Get threat status for target (simplified)
-- Returns: 0=no threat, 1=have threat, 2=insecure tanking, 3=secure tanking
function Utils.get_threat_status(target)
    if not target or not target:is_valid() then return 0 end
    
    local tt = target:get_target()
    if not tt or not tt:is_valid() then return 0 end
    
    if tt:is_unit("player") then
        -- We're tanking - assume insecure for safety
        return 2
    end
    
    return 1
end

--- Check if target is being tanked by another player
function Utils.is_other_tank_target(target)
    if not target or not target:is_valid() then return false end
    
    local tt = target:get_target()
    if not tt or not tt:is_valid() then return false end
    if tt:is_unit("player") then return false end
    
    -- Check if target's target is another player
    -- Simplified: we can't easily detect "tank" role in Sylvanas
    -- Return false as safe default
    return false
end

-- ============================================================================
-- TARGET PRIORITY
-- ============================================================================

local PRIO_BOSS = 3
local PRIO_ELITE = 2
local PRIO_TRASH = 1

--- Get unit priority (boss > elite > trash)
function Utils.get_unit_priority(unit)
    if not unit or not unit:is_valid() then return PRIO_TRASH end
    local classification = unit:get_classification()
    if classification == 3 then return PRIO_BOSS end  -- worldboss
    if classification == 1 or classification == 2 then return PRIO_ELITE end  -- elite, rareelite
    return PRIO_TRASH
end

-- ============================================================================
-- COUNT NEARBY ENEMIES
-- ============================================================================

--- Count nearby enemies by classification
function Utils.count_nearby_enemies(max_range, loose_only)
    local elites, bosses, trash = 0, 0, 0
    local enemies = izi.enemies(max_range)
    
    for _, enemy in ipairs(enemies) do
        if enemy:is_valid() and not enemy:is_dead_or_ghost() then
            local should_count = true
            
            if loose_only then
                local et = enemy:get_target()
                if not et or not et:is_valid() or et:is_unit("player") then
                    should_count = false
                end
            end
            
            if should_count then
                local classification = enemy:get_classification()
                if classification == 3 then
                    bosses = bosses + 1
                elseif classification == 1 or classification == 2 then
                    elites = elites + 1
                else
                    trash = trash + 1
                end
            end
        end
    end
    
    return elites, bosses, trash
end

-- ============================================================================
-- HEALING TARGET SCANNER
-- ============================================================================

--- Scan party/raid for healing targets
function Utils.scan_healing_targets()
    local targets = {}
    local me = izi.me()
    if not me or not me:is_valid() then return targets end
    
    -- Get all objects
    local ok, objects = pcall(function()
        return core.object_manager.get_all_objects()
    end)
    if not ok or not objects then return targets end
    
    for i = 1, #objects do
        local obj = objects[i]
        local ok_valid, valid = pcall(function()
            return obj:is_valid() and obj:is_unit() and not obj:is_dead_or_ghost()
                and obj ~= me  -- Exclude self, only heal others (friendlies)
                and obj:is_party_member()  -- Only party/raid members
        end)
        
        if ok_valid and valid then
            local hp_ok, hp = pcall(function() return obj:get_health_percentage() end)
            if hp_ok and hp then
                -- Get HoT status
                local has_rejuv = false
                local has_regrowth = false
                for _, id in ipairs(Constants.REJUVENATION_BUFF_IDS) do
                    if obj:buff_up(id) then has_rejuv = true break end
                end
                for _, id in ipairs(Constants.REGROWTH_BUFF_IDS) do
                    if obj:buff_up(id) then has_regrowth = true break end
                end
                
                -- Get role
                local is_tank = false
                local ok_role, role = pcall(function() return obj:get_group_role() end)
                if ok_role and role == 0 then is_tank = true end
                
                -- Calculate effective HP
                local max_hp = obj:get_max_health() or 1
                local current_hp = obj:get_health() or 0
                local incoming_heals = 0
                local ok_heals, heals_val = pcall(function() return obj:get_incoming_heals(3.0) end)
                if ok_heals and heals_val then
                    incoming_heals = incoming_heals + heals_val
                end
                
                local effective_health = current_hp + incoming_heals
                local effective_hp = (effective_health / max_hp) * 100
                
                table.insert(targets, {
                    unit = obj,
                    unit_id = "party" .. i,  -- Approximate
                    hp = hp,
                    effective_hp = effective_hp,
                    has_rejuv = has_rejuv,
                    has_regrowth = has_regrowth,
                    is_tank = is_tank,
                })
            end
        end
    end
    
    -- Sort by effective HP (lowest first)
    table.sort(targets, function(a, b) return a.effective_hp < b.effective_hp end)
    return targets
end

--- Get tank from scanned targets
function Utils.get_tank(targets)
    for _, t in ipairs(targets) do
        if t.is_tank then return t end
    end
    return nil
end

--- Get lowest HP target below threshold
function Utils.get_lowest_hp(targets, threshold)
    threshold = threshold or 100
    for _, t in ipairs(targets) do
        if t.effective_hp < threshold then
            return t
        end
    end
    return nil
end

--- Count targets below emergency threshold
function Utils.count_emergency_targets(targets, threshold)
    local count = 0
    for _, t in ipairs(targets) do
        if t.effective_hp < threshold then
            count = count + 1
        end
    end
    return count
end

-- ============================================================================
-- SPELL RANK SELECTION HELPERS
-- ============================================================================

--- Find best Healing Touch rank for target deficit
function Utils.get_best_healing_touch(deficit)
    local Spells = require("libraries/spells")
    
    -- Healing values per rank (approximate, TBC values)
    local heal_values = {
        2908, 2472, 2060, 1890, 1730, 1590, 1440, 1290, 1000, 750, 450, 200, 40
    }
    
    -- Find appropriate rank
    for i, heal in ipairs(heal_values) do
        if heal >= deficit * 0.8 then
            return Spells.HealingTouchRanks[i], i
        end
    end
    
    -- Fallback to lowest rank
    return Spells.HealingTouchRanks[#Spells.HealingTouchRanks], #Spells.HealingTouchRanks
end

--- Find best Regrowth rank for target deficit
function Utils.get_best_regrowth(deficit)
    local Spells = require("libraries/spells")
    
    -- Healing values per rank (approximate, TBC values)
    local heal_values = {
        1142, 1003, 897, 803, 721, 650, 556, 256, 162, 93
    }
    
    for i, heal in ipairs(heal_values) do
        if heal >= deficit * 0.8 then
            return Spells.RegrowthRanks[i], i
        end
    end
    
    return Spells.RegrowthRanks[#Spells.RegrowthRanks], #Spells.RegrowthRanks
end

-- ============================================================================
-- CONSUMABLE AVAILABILITY
-- ============================================================================

--- Check if stance allows consumable use
function Utils.can_use_items(stance)
    if stance == Constants.STANCE.CASTER or stance == Constants.STANCE.CAT then
        return true
    end
    if stance == Constants.STANCE.MOONKIN or stance == Constants.STANCE.TREE then
        return true
    end
    return false
end

--- Check if we can afford to reshift after using consumable
function Utils.can_afford_reshift(stance, current_mana)
    if stance == Constants.STANCE.CASTER or stance == Constants.STANCE.MOONKIN or stance == Constants.STANCE.TREE then
        return true  -- No reshift needed
    end
    
    local form_id = nil
    if stance == Constants.STANCE.CAT then form_id = 768
    elseif stance == Constants.STANCE.BEAR then form_id = 9634 end
    
    if form_id then
        local cost = Utils.get_form_cost(form_id)
        return current_mana >= cost
    end
    
    return true
end

-- ============================================================================
-- LOGGING UTILITIES
-- ============================================================================

--- Log a cast with consistent formatting
function Utils.log_cast(spell_name, context)
    local prefix = "[Druid]"
    if context and context.spec then
        prefix = "[" .. context.spec .. "]"
    end
    core.log(string.format("[Cast] %s - %s", prefix, spell_name))
end

-- ============================================================================
-- POSITIONING UTILITIES
-- ============================================================================

--- Returns true when 'me' is positioned behind 'target'.
--- Uses the target's rotation (yaw) from get_rotation() and vec3 dot product.
--- Behind = attacker is in the rear 180-degree arc (dot product with target forward < 0).
--- Falls back to true if rotation data unavailable so Shred is never permanently blocked.
function Utils.is_behind_target(me, target)
    if not me or not target or not target:is_valid() then return false end
    local my_pos     = me:get_position()
    local target_pos = target:get_position()
    if not my_pos or not target_pos then return true end
    local ok, rotation = pcall(function() return target:get_rotation() end)
    if not ok or rotation == nil then return true end
    local fwd_x = math.cos(rotation)
    local fwd_y = math.sin(rotation)
    local to_me_x = my_pos.x - target_pos.x
    local to_me_y = my_pos.y - target_pos.y
    return (to_me_x * fwd_x + to_me_y * fwd_y) < 0
end

return Utils
