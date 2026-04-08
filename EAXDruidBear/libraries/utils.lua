-- utils.lua  |  EAX Druid Bear (Tank)  |  TBC
-- Helper functions for Bear tank rotation

---@type buff_manager
local buff_manager = require("common/modules/buff_manager")

---@type izi_sdk
local izi = require("common/izi_sdk")

local utils = {}

-- Spell resolver with persistent caching
local spell_resolver = require("libraries/spell_resolver")

-- Throttle tracking
local throttle_data = {}

-- Throttle function to limit execution frequency
---@param key string
---@param interval number
---@return boolean
function utils.throttle(key, interval)
    local now = core.time()
    if not throttle_data[key] or (now - throttle_data[key]) >= interval then
        throttle_data[key] = now
        return true
    end
    return false
end

-- Cached IZI spell objects
local cached_spells = {}

---Get or create an IZI spell object for a spell ID
---@param spell_id number
---@return table|nil
local function get_izi_spell(spell_id)
    if not spell_id then return nil end
    if not cached_spells[spell_id] then
        cached_spells[spell_id] = izi.spell(spell_id)
    end
    return cached_spells[spell_id]
end

-- Get rage amount from player
---@param me table
---@return number
function utils.get_rage(me)
    if not me or not me:is_valid() then return 0 end
    local ok, rage = pcall(function() return me:get_power(1) end)  -- 1 = rage power type
    if ok and type(rage) == "number" then return rage end
    return 0
end

-- Get health percentage (0-100)
---@param me table
---@return number
function utils.get_health_percentage(me)
    if not me or not me:is_valid() then return 0 end
    local ok_hp, hp = pcall(function() return me:get_health() end)
    local ok_max, max_hp = pcall(function() return me:get_max_health() end)
    if ok_hp and ok_max and max_hp and max_hp > 0 then
        return (hp / max_hp) * 100
    end
    return 0
end

-- Check if player has any buff from buff_table
---@param me table
---@param buff_table table
---@return boolean
function utils.has_buff(me, buff_table)
    if not me or not me:is_valid() or not buff_table then return false end
    local entry = buff_manager:get_buff_data(me, buff_table)
    if entry and entry.is_active then return true end
    entry = buff_manager:get_aura_data(me, buff_table)
    return entry ~= nil and entry.is_active == true
end

-- Check if player has any debuff from debuff_table
---@param me table
---@param debuff_table table
---@return boolean
function utils.has_debuff(me, debuff_table)
    if not me or not me:is_valid() or not debuff_table then return false end
    local data = buff_manager:get_debuff_data(me, debuff_table)
    if data and data.is_active then return true end
    data = buff_manager:get_aura_data(me, debuff_table)
    return data ~= nil and data.is_active
end

-- Resolve spell ID from ranks table (highest available)
---@param ranks_table table
---@return number|nil
function utils.resolve_spell_id(ranks_table)
    if not ranks_table then return nil end
    if type(ranks_table) == "number" then
        return core.spell_book.is_spell_learned(ranks_table) and ranks_table or nil
    end
    for i = 1, #ranks_table do
        local spell_id = ranks_table[i]
        if spell_id and core.spell_book.is_spell_learned(spell_id) then
            return spell_id
        end
    end
    return nil
end

-- Cast spell on target with safety checks
---@param spell_id number
---@param target table
---@return boolean
function utils.cast_target(spell_id, target)
    if not spell_id then return false end
    if not target or not target:is_valid() then return false end
    local izi_spell = get_izi_spell(spell_id)
    if not izi_spell then return false end
    if izi_spell:is_learned() and izi_spell:is_castable_to_unit(target) then
        local ok, result = pcall(function()
            return izi_spell:cast_safe(target, "[Target] Cast")
        end)
        if ok and result then
            return true
        end
    end
    return false
end

-- Cast spell on self
---@param spell_id number
---@param me table
---@return boolean
function utils.cast_self(spell_id, me)
    if not spell_id then return false end
    if not me or not me:is_valid() then return false end
    local izi_spell = get_izi_spell(spell_id)
    if not izi_spell then return false end
    if izi_spell:is_learned() and izi_spell:is_castable_to_unit(me) then
        local ok, result = pcall(function()
            return izi_spell:cast_safe(me, "[Self] Cast")
        end)
        if ok and result then
            return true
        end
    end
    return false
end

-- Static table for enemy counting (reused to avoid allocation)
local _enemy_count_objects = { n = 0 }

-- Count enemies in radius (squared distance - NO sqrt())
---@param me table
---@param radius number
---@return number
function utils.enemy_count_in_radius(me, radius)
    if not me or not me:is_valid() then return 0 end
    local me_pos = me:get_position()
    if not me_pos then return 0 end
    
    local radius_sq = radius * radius  -- Squared!
    local count = 0
    
    local objects = core.object_manager.get_visible_objects()
    for _, obj in ipairs(objects) do
        if obj:is_enemy_with(me) and obj:is_valid() and not obj:is_dead() then
            local obj_pos = obj:get_position()
            if obj_pos then
                local dx = obj_pos.x - me_pos.x
                local dy = obj_pos.y - me_pos.y
                local dist_sq = dx * dx + dy * dy  -- Squared distance!
                if dist_sq <= radius_sq then
                    count = count + 1
                end
            end
        end
    end
    return count
end

-- Debug logging with menu check
---@param menu table
---@param message string
function utils.log_debug(menu, message)
    local debug_enabled = (menu and menu.debug and menu.debug.get and menu.debug:get()) or false
    if debug_enabled then
        core.log("[EAX Druid Bear] " .. tostring(message))
    end
end

-- Check if in Bear/Dire Bear form
---@param me table
---@return boolean
function utils.is_in_bear_form(me)
    if not me or not me:is_valid() then return false end
    local spells = require("libraries/spells")
    return utils.has_buff(me, spells.BUFF_BEAR_FORM) or utils.has_buff(me, spells.BUFF_DIRE_BEAR_FORM)
end

-- Squared distance for performance (no sqrt)
---@param me table
---@param target table
---@return number
function utils.dist_squared(me, target)
    if not me or not target then return 999999 end
    local p1, p2 = me:get_position(), target:get_position()
    if not p1 or not p2 then return 999999 end
    local dx, dy, dz = p1.x - p2.x, p1.y - p2.y, p1.z - p2.z
    return (dx * dx + dy * dy + dz * dz)
end

-- Check if can cast spell on target (comprehensive check)
---@param spell_id number
---@param me table
---@param target table
---@return boolean
function utils.can_cast_target(spell_id, me, target)
    if not spell_id or not me or not target then return false end
    if not core.spell_book.is_spell_learned(spell_id) then return false end
    if core.spell_book.get_spell_cooldown(spell_id) > 0 then return false end
    if not core.spell_book.is_usable_spell(spell_id) then return false end
    if not core.spell_book.is_spell_in_range(spell_id, target, me) then return false end
    return true
end

-- Check if can cast spell on self
---@param spell_id number
---@param me table
---@return boolean
function utils.can_cast_self(spell_id, me)
    if not spell_id or not me or not me:is_valid() then return false end
    if not core.spell_book.is_spell_learned(spell_id) then return false end
    if core.spell_book.get_spell_cooldown(spell_id) > 0 then return false end
    if not core.spell_book.is_usable_spell(spell_id) then return false end
    return true
end

-- Get mana percentage (0-100)
---@param me table
---@return number
function utils.get_mana_percentage(me)
    if not me or not me:is_valid() then return 0 end
    local ok_mana, mana = pcall(function() return me:get_power(0) end)  -- 0 = mana
    local ok_max, max_mana = pcall(function() return me:get_max_power(0) end)
    if ok_mana and ok_max and max_mana and max_mana > 0 then
        return (mana / max_mana) * 100
    end
    return 0
end

-- Check if target is valid hostile
---@param me table
---@param target table
---@return boolean
function utils.is_valid_hostile_target(me, target)
    if not me or not target then return false end
    if not target:is_valid() or target:is_dead() then return false end
    return me:can_attack(target)
end

-- Check if target is casting
---@param target table
---@return boolean
function utils.is_target_casting(target)
    if not target then return false end
    local ok, result = pcall(function() return target:is_casting() end)
    return ok and result or false
end

-- Check if target's cast is interruptible
---@param target table
---@return boolean
function utils.is_casting_interruptible(target)
    if not target then return false end
    local ok, result = pcall(function() return target:is_casting_interruptible() end)
    return ok and result or false
end

-- ============================================================================
-- Crowd Control Detection
-- ============================================================================

-- Loss of Control Type Enum Values (from Sylvanas API)
local LOC_NONE = 0
local LOC_POSSESS = 1
local LOC_CONFUSE = 2
local LOC_CHARM = 3
local LOC_FEAR = 4
local LOC_STUN = 5
local LOC_PACIFY = 6
local LOC_ROOT = 7
local LOC_SILENCE = 8
local LOC_PACIFY_SILENCE = 9
local LOC_DISARM = 10
local LOC_SCHOOL_INTERRUPT = 11
local LOC_STUN_MECHANIC = 12
local LOC_FEAR_MECHANIC = 13

-- CC types that prevent spell casting
local CAST_PREVENTING_CC_TYPES = {
    [LOC_STUN] = true,
    [LOC_PACIFY] = true,
    [LOC_SILENCE] = true,
    [LOC_PACIFY_SILENCE] = true,
    [LOC_SCHOOL_INTERRUPT] = true,
    [LOC_STUN_MECHANIC] = true,
    [LOC_CONFUSE] = true,
    [LOC_CHARM] = true,
    [LOC_FEAR] = true,
    [LOC_FEAR_MECHANIC] = true,
    [LOC_DISARM] = true,
}

--[[
    Checks if the unit has a loss of control effect that prevents casting
    
    @param unit: game_object - The player or unit to check
    @return boolean: true if unit cannot cast spells, false otherwise
--]]
function utils.is_cced(unit)
    if not unit or not unit.is_valid or not unit:is_valid() then
        return false
    end
    
    -- Check if method exists (API compatibility)
    if not unit.get_loss_of_control_info then
        return false
    end
    
    local loc_info = unit:get_loss_of_control_info()
    if not loc_info or not loc_info.valid then
        return false
    end
    
    return CAST_PREVENTING_CC_TYPES[loc_info.type] or false
end

return utils
