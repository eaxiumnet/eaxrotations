---@type buff_manager
local buff_manager = require("common/modules/buff_manager")

local utils = {}

-- Spell resolver with persistent caching
local spell_resolver = require("libraries/spell_resolver")

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
    local me_pos = me:get_position()
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
            return (mana / max_mana) * 100
        end
    end
    return 0
end

-- Squared distance for performance (no sqrt)
function utils.dist_squared(me, target)
    if not me or not target then return 999999 end
    local p1, p2 = me:get_position(), target:get_position()
    if not p1 or not p2 then return 999999 end
    local dx, dy, dz = p1.x - p2.x, p1.y - p2.y, p1.z - p2.z
    return (dx * dx + dy * dy + dz * dz)
end

-- ============================================================================

-- ============================================================================

--- Check if target is a player (for PvP)
-- @param target GameObject
-- @return boolean
function utils.is_player(target)
    if not target or not target:is_valid() then return false end
    if target.is_player then
        local ok, is_player = pcall(function() return target:is_player() end)
        if ok then return is_player end
    end
    return false
end

--- Check if target is an enemy player
-- @param me GameObject: Local player
-- @param target GameObject
-- @return boolean
function utils.is_enemy_player(me, target)
    if not me or not target then return false end
    if not utils.is_player(target) then return false end
    return me:can_attack(target)
end

--- Detect PvP mode based on menu settings and context
-- @param menu table: Menu module
-- @param me GameObject: Local player
-- @param target GameObject: Current target
-- @return string: "pvp", "pve", or "auto"
function utils.detect_pvp_mode(menu, me, target)
    if not menu then return "pve" end
    
    -- Check if PvP is enabled
    local pvp_enabled = (menu.pvp_enabled and menu.pvp_enabled:get_state()) or false
    if not pvp_enabled then return "pve" end
    
    -- Check PvP mode setting
    local pvp_mode = (menu.pvp_mode and menu.pvp_mode:get()) or 1
    
    -- Mode 2 = PVE Only
    if pvp_mode == 2 then return "pve" end
    
    -- Mode 3 = PVP Only
    if pvp_mode == 3 then return "pvp" end
    
    -- Mode 1 = Auto (detect based on target)
    if target and utils.is_enemy_player(me, target) then
        return "pvp"
    end
    
    -- Check if player is in a PvP zone/flagged
    if me and me.is_pvp_flagged then
        local ok, flagged = pcall(function() return me:is_pvp_flagged() end)
        if ok and flagged then return "pvp" end
    end
    
    return "pve"
end

--- Check if in PvP combat (targeting or being targeted by enemy player)
-- @param me GameObject: Local player
-- @return boolean
function utils.is_in_pvp_combat(me)
    if not me or not me:is_valid() then return false end
    
    -- Check if targeting an enemy player
    local target = (me and me:get_target())
    if target and utils.is_enemy_player(me, target) then
        return true
    end
    
    -- Check if being targeted by an enemy player
    if me.is_target_of then
        local ok, is_targeted = pcall(function() return me:is_target_of() end)
        if ok and is_targeted then
            -- Check if the targeter is a player
            for _, o in ipairs(core.object_manager.get_all_objects()) do
                if o and o:is_valid() and o:is_unit() and not o:is_dead() then
                    if utils.is_enemy_player(me, o) then
                        -- Check if this player is targeting us
                        if o.get_target then
                            local ok_target, their_target = pcall(function() return o:get_target() end)
                            if ok_target and their_target and utils.same_unit(their_target, me) then
                                return true
                            end
                        end
                    end
                end
            end
        end
    end
    
    return false
end

-- ============================================================================

-- ============================================================================

--- Count active HoTs on party/raid members
-- @return number: Count of active HoTs
function utils.get_active_hot_count()
    local me = core.object_manager.get_local_player()
    if not me then return 0 end
    
    local hot_count = 0
    local spells = require("libraries/spells")
    
    for _, o in ipairs(core.object_manager.get_all_objects()) do
        if o and o:is_valid() and o:is_unit() and not o:is_dead() then
            if o:is_party_member() or utils.same_unit(o, me) then
                -- Check for Rejuvenation
                if utils.has_buff(o, spells.BUFF_REJUVENATION) then
                    hot_count = hot_count + 1
                end
                -- Check for Regrowth
                if utils.has_buff(o, spells.BUFF_REGROWTH) then
                    hot_count = hot_count + 1
                end
                -- Check for Lifebloom
                if utils.has_buff(o, spells.BUFF_LIFEBLOOM) then
                    hot_count = hot_count + 1
                end
            end
        end
    end
    
    return hot_count
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
-- Shared Healing Module Wrappers
-- ============================================================================

---Find the ally with the lowest effective HP (considering incoming heals/damage)
---@param me game_object The player unit
---@param threshold number|nil HP threshold (0-100), only return targets below this
---@param skip_self boolean|nil If true, exclude the player from results
---@return game_object|nil The lowest HP ally, or nil if none found
function utils.find_lowest_effective_ally(me, threshold, skip_self)
    local heal_utils = require("libraries/heal_utils")
    return heal_utils.find_lowest_effective_ally(me, threshold, skip_self)
end

---Get the tank unit via aggro/role detection
---@param me game_object The player unit
---@return game_object|nil The tank unit, or nil if none found
function utils.get_tank_unit(me)
    local heal_utils = require("libraries/heal_utils")
    return heal_utils.get_tank_unit(me)
end

---Count allies below a specific HP threshold (for AoE heal decisions)
---@param me game_object The player unit
---@param threshold number HP threshold (0-100)
---@return number Count of allies below threshold
function utils.count_below_hp(me, threshold)
    local heal_utils = require("libraries/heal_utils")
    return heal_utils.count_below_hp(me, threshold)
end

-- ============================================================================
-- Battle Resurrection Helpers
-- ============================================================================

---Find the first dead ally that can be assisted
---Iterates through party/raid members and returns the first dead unit
---@param me game_object The player unit
---@return game_object|nil The dead ally, or nil if none found
function utils.find_dead_ally(me)
    if not me or not me:is_valid() then return nil end
    
    for _, o in ipairs(core.object_manager.get_all_objects()) do
        if o and o:is_valid() and o:is_unit() and o:is_dead() then
            -- Check if it's a party/raid member or the player
            if o:is_party_member() or utils.same_unit(o, me) then
                -- Verify we can assist this target (not an enemy)
                if not me:can_attack(o) then
                    return o
                end
            end
        end
    end
    
    return nil
end

---Check if there are any dead party/raid members
---Convenience wrapper around find_dead_ally
---@param me game_object The player unit
---@return boolean True if a dead party member exists
function utils.has_dead_party_member(me)
    return utils.find_dead_ally(me) ~= nil
end

return utils


