---@type buff_manager
local buff_manager = require("common/modules/buff_manager")

local utils = {}

-- Spell resolver with persistent caching
local spell_resolver = require("libraries/spell_resolver")

---@type izi_sdk
local izi = require("common/izi_sdk")

---@type heal_utils
local heal_utils = require("libraries/heal_utils")

---@type heal_context
local heal_context = require("libraries/heal_context")

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
    return hp / max
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

function utils.log_debug(menu_module, message)
    if menu_module and menu_module.debug and menu_module.debug:get_state() then
        core.log("[EAX] " .. tostring(message))
    end
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
    local p1, p2 = me:get_position(), target:get_position()
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
-- HEALING UTILITY FUNCTIONS (Shared Module Wrappers)
-- ============================================================================

---Find the ally with the lowest effective HP (considering incoming heals/damage)
---@param me game_object The player unit
---@param threshold number|nil HP threshold (0-100), only return targets below this
---@param skip_self boolean|nil If true, exclude the player from results
---@return game_object|nil The lowest HP ally, or nil if none found
function utils.find_lowest_effective_ally(me, threshold, skip_self)
    return heal_utils.find_lowest_effective_ally(me, threshold, skip_self)
end

---Identify the tank unit via aggro/role detection
---@param me game_object The player unit
---@return game_object|nil The tank unit, or nil if none found
function utils.get_tank_unit(me)
    return heal_utils.get_tank_unit(me)
end

---Count allies below a specific HP threshold (for AoE heal decisions)
---@param me game_object The player unit
---@param threshold number HP threshold (0-100)
---@return number Count of allies below threshold
function utils.count_below_hp(me, threshold)
    return heal_utils.count_below_hp(me, threshold)
end

---Get mana percentage for a unit (wrapper for consistency)
---@param me game_object The player unit
---@return number Mana percentage (0-1)
function utils.get_mana_pct(me)
    return heal_utils.get_mana_pct(me) / 100  -- Convert from 0-100 to 0-1
end

---Get effective HP percentage considering incoming damage/heals
---@param unit game_object The target unit
---@return number Effective HP percentage (0-1)
function utils.get_effective_hp_pct(unit)
    if not unit or not unit:is_valid() then return 1 end
    local hp_pct = heal_utils.get_mana_pct(unit)  -- Reuse percentage logic
    -- Actually use health percentage
    local ok, health_pct = pcall(function()
        return unit:get_health_percentage() / 100
    end)
    if ok and health_pct then
        return health_pct
    end
    return 1
end

---Get party units for healing/cleansing
---@param me game_object The player unit
---@return table Array of party units
function utils.get_party_units(me)
    if not me or not me:is_valid() then return {} end
    local ctx = heal_context.get_context(me)
    local units = {}
    if ctx and ctx.tanks then
        for i = 1, ctx.tanks.n do
            table.insert(units, ctx.tanks[i])
        end
    end
    if ctx and ctx.healers then
        for i = 1, ctx.healers.n do
            table.insert(units, ctx.healers[i])
        end
    end
    -- Add self if not already included
    local self_found = false
    for _, u in ipairs(units) do
        if u == me then self_found = true break end
    end
    if not self_found then
        table.insert(units, me)
    end
    return units
end

---Check if unit needs cleanse (has dispellable debuff)
---@param unit game_object The unit to check
---@return boolean True if unit has dispellable debuff
function utils.needs_cleanse(unit)
    if not unit or not unit:is_valid() then return false end
    -- Check for poison, disease, magic debuffs that Cleanse can remove
    local ok, needs = pcall(function()
        -- Use buff_manager to check for dispellable debuffs
        local debuff_data = buff_manager:get_all_debuff_data(unit)
        if debuff_data then
            for _, debuff in ipairs(debuff_data) do
                if debuff.is_active then
                    -- Check if debuff is poison, disease, or magic
                    if debuff.dispel_type == 1 or debuff.dispel_type == 2 or debuff.dispel_type == 3 then
                        return true
                    end
                end
            end
        end
        return false
    end)
    return ok and needs
end

---Get remaining duration of a debuff in milliseconds
---@param unit game_object The unit to check
---@param debuff_table table Table of debuff spell IDs
---@return number Remaining duration in milliseconds
function utils.get_debuff_remaining_ms(unit, debuff_table)
    if not unit or not unit:is_valid() or not debuff_table then return 0 end
    local data = buff_manager:get_debuff_data(unit, debuff_table)
    if data and data.is_active and data.remaining_ms then
        return data.remaining_ms
    end
    return 0
end

---Check if a spell is known/learned
---@param spell_id number The spell ID to check
---@return boolean True if spell is known
function utils.is_known_spell(spell_id)
    if not spell_id then return false end
    return core.spell_book.is_spell_learned(spell_id)
end

---Cast a spell on self without queue check (fast cast)
---@param spell_id number The spell ID to cast
---@param me game_object The player unit
---@return boolean True if cast succeeded
function utils.cast_self_fast(spell_id, me)
    if not spell_id or not me or not me:is_valid() then return false end
    if not utils.can_cast_self(spell_id, me) then return false end
    -- Direct cast without queue throttling for emergency spells
    core.input.cast_target_spell(spell_id, me)
    return true
end

---Try to break CC with Divine Shield
---@param me game_object The player unit
---@param menu table The menu module for settings
---@return boolean True if Divine Shield was used to break CC
function utils.try_divine_shield_cc_break(me, menu)
    if not me or not me:is_valid() then return false end
    -- Check if Divine Shield is available and enabled
    local divine_shield_id = utils.resolve_spell_id({642})  -- Divine Shield
    if not divine_shield_id then return false end
    if not utils.can_cast_self(divine_shield_id, me) then return false end
    -- Check Forbearance debuff
    local forbearance_ids = {25771}
    if utils.has_debuff(me, forbearance_ids) then return false end
    -- Cast Divine Shield
    if utils.cast_self(divine_shield_id, me) then
        if menu and menu.debug and menu.debug:get_state() then
            utils.log_debug(menu, "Divine Shield (CC break)")
        end
        return true
    end
    return false
end

return utils


