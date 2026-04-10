---@type buff_manager
local buff_manager = require("common/modules/buff_manager")

local utils = {}

-- Spell resolver with persistent caching
local spell_resolver = require("libraries/spell_resolver")

---@type heal_utils
local heal_utils = require("libraries/heal_utils")

---@type izi_sdk
local izi = require("common/izi_sdk")

local throttle_data = {}
local queue_request_timestamps = {}
local SPELL_QUEUE_INTERVAL_S = 0.25

function utils.throttle(key, interval)
    local now = core.time()
    if not throttle_data[key] or (now - throttle_data[key]) >= interval then
        throttle_data[key] = now
        return true
    end
    return false
end

-- Create IZI spell objects for common casting patterns
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

function utils.resolve_spell_id(rank_table)
    if not rank_table then return nil end
    if type(rank_table) == "number" then
        return core.spell_book.is_spell_learned(rank_table) and rank_table or nil
    end
    for i = 1, #rank_table do
        local spell_id = rank_table[i]
        if spell_id and core.spell_book.is_spell_learned(spell_id) then
            return spell_id
        end
    end
    return nil
end

function utils.get_health_pct(unit)
    if not unit or not unit:is_valid() then return 0 end
    local hp = unit:get_health()
    local max = unit:get_max_health()
    if not max or max <= 0 then return 0 end
    return (hp / max) * 100
end

function utils.get_distance_to_target(me, target)
    if not me or not target then return math.huge end
    local ok_pos, me_pos = pcall(function() return me:get_position() end)
    if not ok_pos then return nil end
    me_pos = me_pos
    local target_pos = target:get_position()
    if not me_pos or not target_pos then return math.huge end
    return me_pos:dist_to(target_pos)
end

function utils.is_valid_hostile_target(me, target)
    if not me or not target then return false end
    if not target:is_valid() or target:is_dead() then return false end
    return me:can_attack(target)
end

function utils.can_cast_target(spell_id, me, target)
    if not spell_id or not me or not target then return false end
    if not core.spell_book.is_spell_learned(spell_id) then return false end
    if core.spell_book.get_spell_cooldown(spell_id) > 0 then return false end
    if not core.spell_book.is_usable_spell(spell_id) then return false end
    if not core.spell_book.is_spell_in_range(spell_id, target, me) then return false end
    return true
end

function utils.same_unit(a, b)
    if not a or not b then return false end
    if a == b then return true end
    if not a.is_valid or not b.is_valid or not a:is_valid() or not b:is_valid() then return false end
    local function safe_guid(u)
        if type(u.get_guid) ~= "function" then return nil end
        local ok, g = pcall(function() return u:get_guid() end)
        return (ok and g ~= nil) and tostring(g) or nil
    end
    local ga, gb = safe_guid(a), safe_guid(b)
    if ga and gb then return ga == gb end
    return false
end

function utils.can_cast_hostile(spell_id, me, target)
    if not me or not target then return false end
    if utils.same_unit(me, target) then return false end
    if not me:can_attack(target) then return false end
    return utils.can_cast_target(spell_id, me, target)
end

function utils.has_buff(unit, buff_table)
    if not unit or not unit:is_valid() or not buff_table then return false end
    local entry = buff_manager:get_buff_data(unit, buff_table)
    if entry and entry.is_active then return true end
    entry = buff_manager:get_aura_data(unit, buff_table)
    return entry ~= nil and entry.is_active == true
end

function utils.has_debuff(unit, debuff_table)
    if not unit or not unit:is_valid() or not debuff_table then return false end
    local data = buff_manager:get_debuff_data(unit, debuff_table)
    if data and data.is_active then return true end
    data = buff_manager:get_aura_data(unit, debuff_table)
    return data ~= nil and data.is_active
end

-- Debug logging (disabled - menu.debug removed from all specs)
function utils.log_debug(menu_module, message)
    -- Debug logging disabled - menu.debug removed from all specs
end

local function can_issue_queue_request(kind, spell_id, target, interval_s)
    local key = kind .. ":" .. tostring(spell_id) .. ":" .. tostring(target)
    local now = core.time()
    local last = queue_request_timestamps[key] or 0
    if (now - last) < interval_s then return false end
    queue_request_timestamps[key] = now
    return true
end

function utils.can_cast_self(spell_id, me)
    if not spell_id or not me or not me:is_valid() then return false end
    if not core.spell_book.is_spell_learned(spell_id) then return false end
    if core.spell_book.get_spell_cooldown(spell_id) > 0 then return false end
    if not core.spell_book.is_usable_spell(spell_id) then return false end
    return true
end

function utils.cast_self(spell_id, me)
    if not spell_id or not me or not me:is_valid() then return false end
    local izi_spell = get_izi_spell(spell_id)
    if not izi_spell then return false end
    if not can_issue_queue_request("spell_target", spell_id, me, SPELL_QUEUE_INTERVAL_S) then return false end

    -- Use IZI SDK cast_safe method
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

function utils.cast_target(spell_id, me, target)
    local can_cast, reason = utils.can_cast_target(spell_id, me, target)
    if not can_cast then return false, reason end
    local izi_spell = get_izi_spell(spell_id)
    if not izi_spell then return false end

    -- Use IZI SDK cast_safe method
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

function utils.get_energy(me)
    if me and me.get_power then
        local ok, e = pcall(function() return me:get_power(3) end)
        if ok and type(e) == "number" then return e end
    end
    return 0
end

function utils.get_max_energy(me)
    if me and me.get_max_power then
        local ok, e = pcall(function() return me:get_max_power(3) end)
        if ok and type(e) == "number" then return e end
    end
    return 100
end

function utils.get_combo_points(me)
    if me and me.get_combo_points then
        local ok, cp = pcall(function() return me:get_combo_points() end)
        if ok and type(cp) == "number" then return cp end
    end
    return 0
end

function utils.mana_pct(me)
    if me and me.get_power and me.get_max_power then
        local ok_mana, mana = pcall(function() return me:get_power(0) end)
        local ok_max, max_mana = pcall(function() return me:get_max_power(0) end)
        if ok_mana and ok_max and max_mana > 0 then
            return mana / max_mana
        end
    end
    return 0
end

-- Squared distance for performance (no sqrt)
function utils.dist_squared(me, target)
    if not me or not target then return 999999 end
    local ok_p1, p1 = pcall(function() if me and me.get_position then return me:get_position() end return nil end)
    local ok_p2, p2 = pcall(function() if target and target.get_position then return target:get_position() end return nil end)
    if not ok_p1 then p1 = nil end
    if not ok_p2 then p2 = nil end
    if not p1 or not p2 then return 999999 end
    local dx, dy, dz = p1.x - p2.x, p1.y - p2.y, p1.z - p2.z
    return (dx * dx + dy * dy + dz * dz)
end

-- Crowd Control Detection
-- Uses get_loss_of_control_info() to detect if player cannot cast spells

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
    -- Note: DISARM is handled separately for melee classes
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

-- ============================================================================
-- MISSING HEALING UTILITY FUNCTIONS (Added for Restoration Shaman)
-- ============================================================================

---Check if the player is moving
---@param me game_object The player unit
---@return boolean True if moving
function utils.is_moving(me)
    if not me or not me:is_valid() then return false end
    local ok, moving = pcall(function()
        return me:is_moving()
    end)
    return ok and moving
end

---Check if target is a valid friendly target for healing
---@param me game_object The player unit
---@param target game_object The target to check
---@return boolean True if valid friendly target
function utils.is_valid_friendly_target(me, target)
    if not me or not target then return false end
    if not target:is_valid() or target:is_dead() then return false end
    -- Check if can assist (friendly)
    local ok, can_assist = pcall(function()
        return me:can_attack(target) == false  -- Can't attack = friendly
    end)
    return ok and can_assist
end

---Check if can cast a friendly spell on target
---@param spell_id number Spell ID
---@param me game_object The player unit
---@param target game_object The target
---@return boolean True if can cast
function utils.can_cast_friendly(spell_id, me, target)
    if not spell_id or not me or not target then return false end
    if not core.spell_book.is_spell_learned(spell_id) then return false end
    if core.spell_book.get_spell_cooldown(spell_id) > 0 then return false end
    if not core.spell_book.is_usable_spell(spell_id) then return false end
    if not core.spell_book.is_spell_in_range(spell_id, target, me) then return false end
    return true
end

---Find the lowest HP party member
---Wrapper around heal_utils.find_lowest_effective_ally
---@param me game_object The player unit
---@return game_object|nil The lowest HP ally
---@return number Health percentage (0-100)
function utils.find_lowest_hp_party_member(me)
    local target = heal_utils.find_lowest_effective_ally(me, 100, false)
    if target and target:is_valid() then
        local hp_pct = utils.get_health_pct(target) * 100
        return target, hp_pct
    end
    return nil, 100
end

---Find focus target or tank unit
---Wrapper around heal_utils.get_tank_unit
---@param me game_object The player unit
---@return game_object|nil The tank unit or nil
function utils.find_focus_target(me)
    return heal_utils.get_tank_unit(me)
end

---Get buff stack count on a unit
---@param unit game_object The unit to check
---@param buff_table table|number Buff ID(s) to check
---@return number Stack count (0 if not found)
function utils.get_buff_stacks(unit, buff_table)
    if not unit or not unit:is_valid() or not buff_table then return 0 end
    local entry = buff_manager:get_buff_data(unit, buff_table)
    if entry and entry.is_active then
        return entry.stacks or 1
    end
    return 0
end

---Get mana percentage for the player
---Wrapper around heal_utils.get_mana_pct
---@param me game_object The player unit
---@return number Mana percentage (0-100)
function utils.get_mana_pct(me)
    return heal_utils.get_mana_pct(me)
end

---Find lowest effective ally (wrapper for heal_utils)
---@param me game_object The player unit
---@param threshold number|nil HP threshold (0-100)
---@param skip_self boolean|nil If true, exclude player
---@return game_object|nil The lowest HP ally
function utils.find_lowest_effective_ally(me, threshold, skip_self)
    return heal_utils.find_lowest_effective_ally(me, threshold, skip_self)
end

---Get tank unit (wrapper for heal_utils)
---@param me game_object The player unit
---@return game_object|nil The tank unit
function utils.get_tank_unit(me)
    return heal_utils.get_tank_unit(me)
end

---Count allies below HP threshold (wrapper for heal_utils)
---@param me game_object The player unit
---@param threshold number HP threshold (0-100)
---@return number Count of allies below threshold
function utils.count_below_hp(me, threshold)
    return heal_utils.count_below_hp(me, threshold)
end

return utils


