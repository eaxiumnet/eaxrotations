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


-- Get rage amount (for dashboard)
function utils.get_rage(me)
    if not me or not me:is_valid() then return 0 end
    local ok, rage = pcall(function() return me:get_power(1) end)  -- 1 = rage
    if ok and type(rage) == "number" then return rage end
    return 0
end

-- Get stance name
function utils.get_stance_name()
    local me = core.object_manager.get_local_player()
    if not me or not me:is_valid() then return "Unknown" end
    
    local spells = require("libraries/spells")
    if utils.has_buff(me, spells.BUFF_BERSERKER_STANCE) then
        return "Berserker"
    elseif utils.has_buff(me, spells.BUFF_BATTLE_STANCE) then
        return "Battle"
    elseif utils.has_buff(me, spells.BUFF_DEFENSIVE_STANCE) then
        return "Defensive"
    end
    return "Unknown"
end

-- Get current stance
function utils.get_current_stance(me)
    return utils.get_stance_name()
end

-- Get stance swap retention time
function utils.get_stance_swap_retention()
    return 1.5
end

-- Set tracked stance
function utils.set_tracked_stance(stance)
    -- Stance is tracked via buffs in get_stance_name
end

-- Get debuff remaining time in ms
function utils.get_debuff_remaining_ms(target, debuff_id)
    if not target or not target:is_valid() then return 0 end
    local ok, remaining = pcall(function() return target:get_remaining_time(debuff_id) end)
    if ok and type(remaining) == "number" then return remaining end
    return 0
end

-- Check if target is in melee range
function utils.is_melee_target(me, target)
    if not me or not me:is_valid() or not target or not target:is_valid() then return false end
    local dist_sq = utils.dist_squared(me, target)
    return dist_sq <= 36
end

-- Count enemies in radius
function utils.enemy_count_in_radius(me, radius)
    if not me or not me:is_valid() then return 0 end
    radius = radius or 8
    
    local count = 0
    local objects = core.object_manager.get_enemies_in_radius(me, radius)
    if objects then
        for _, obj in ipairs(objects) do
            if obj and obj:is_valid() and obj:is_hostile() then
                count = count + 1
            end
        end
    end
    return count
end

-- Check if there is breakable CC nearby
function utils.has_breakable_cc_nearby(me, radius)
    if not me or not me:is_valid() then return false end
    radius = radius or 10
    
    local objects = core.object_manager.get_enemies_in_radius(me, radius)
    if objects then
        for _, obj in ipairs(objects) do
            if obj and obj:is_valid() and obj:is_hostile() then
                if utils.is_cced(obj) then
                    return true
                end
            end
        end
    end
    return false
end

-- Fast cast self spell
function utils.cast_self_fast(spell_id, me)
    if not spell_id or not me or not me:is_valid() then return false end
    local izi_spell = get_izi_spell(spell_id)
    if not izi_spell then return false end
    
    if izi_spell:is_learned() and izi_spell:is_castable_to_unit(me) then
        local ok, result = pcall(function()
            return izi_spell:cast_safe(me, "[Fast Self] Cast")
        end)
        if ok and result then
            return true
        end
    end
    return false
end

-- Fast cast target spell
function utils.cast_target_fast(spell_id, target)
    if not spell_id or not target then return false end
    local izi_spell = get_izi_spell(spell_id)
    if not izi_spell then return false end
    
    if izi_spell:is_learned() and izi_spell:is_castable_to_unit(target) then
        local ok, result = pcall(function()
            return izi_spell:cast_safe(target, "[Fast Target] Cast")
        end)
        if ok and result then
            return true
        end
    end
    return false
end

-- Ensure melee auto-attack
function utils.ensure_melee_auto_attack(me)
    if not me or not me:is_valid() then return false end
    return me:is_in_combat()
end

-- Find best target
function utils.find_best_target(me)
    if not me or not me:is_valid() then return nil end
    
    local target = me:get_target()
    if target and target:is_valid() and target:is_hostile() then
        return target
    end
    
    local enemies = core.object_manager.get_enemies_in_radius(me, 40)
    if enemies and #enemies > 0 then
        for _, enemy in ipairs(enemies) do
            if enemy and enemy:is_valid() and enemy:is_hostile() then
                return enemy
            end
        end
    end
    return nil
end

-- Check if spell is already queued
function utils.is_spell_already_queued(spell_id)
    if not spell_id then return false end
    local now = core.time()
    if queue_request_timestamps[spell_id] then
        return (now - queue_request_timestamps[spell_id]) < SPELL_QUEUE_INTERVAL_S
    end
    return false
end

-- Check if we can cast a melee spell
function utils.can_cast_melee(spell_id, me)
    if not spell_id or not me or not me:is_valid() then return false end
    local izi_spell = get_izi_spell(spell_id)
    if not izi_spell then return false end
    
    if izi_spell:is_learned() and izi_spell:is_castable() then
        return true
    end
    return false
end

-- Smart Overpower usage check
function utils.should_use_overpower_smart(me, target, rage, ms_cd, ww_cd, target_hp_pct)
    if not me or not me:is_valid() or not target or not target:is_valid() then return false end
    
    local spells = require("libraries/spells")
    if utils.has_buff(me, spells.BUFF_OVERPOWER_AVAILABLE) then
        return true
    end
    
    if rage < 30 and (ms_cd > 1.5 or ww_cd > 1.5) then
        return true
    end
    
    return false
end

-- Check if we can stance dance for cost savings
function utils.can_stance_dance_for_cost(me, target_rage)
    if not me or not me:is_valid() then return false end
    
    local current_rage = utils.get_rage(me)
    return current_rage <= 25
end

-- Check if we can stealth (for Night Elf warriors with Shadowmeld)
function utils.can_stealth(me)
    if not me or not me:is_valid() then return false end
    local SHADOWMELD = 20580
    local izi_spell = get_izi_spell(SHADOWMELD)
    if izi_spell and izi_spell:is_learned() then
        return izi_spell:is_castable()
    end
    return false
end

-- Try to break fear with Berserker Rage
function utils.try_berserker_rage_fear_break(me)
    if not me or not me:is_valid() then return false end
    
    local BERSERKER_RAGE = 18499
    local izi_spell = get_izi_spell(BERSERKER_RAGE)
    if not izi_spell then return false end
    
    if utils.is_cced(me) then
        local loc_info = me:get_loss_of_control_info()
        if loc_info and loc_info.type == "FEAR" then
            if izi_spell:is_learned() and izi_spell:is_castable() then
                local ok, result = pcall(function()
                    return izi_spell:cast_safe(me, "Fear Break")
                end)
                return ok and result
            end
        end
    end
    return false
end

-- Detect PvP context
function utils.detect_pvp_context(me, target)
    me = me or core.object_manager.get_local_player()
    if not me then
        return {is_pvp = false, is_arena = false, is_battleground = false, target_is_player = false}
    end

    local is_battleground = false
    local is_arena = false
    local is_pvp = false
    local target_is_player = false

    if core.game_state.is_in_instance then
        local ok, instance_type = pcall(core.game_state.is_in_instance)
        if ok and instance_type then
            is_battleground = (instance_type == "battleground")
            is_arena = (instance_type == "arena")
        end
    end

    if core.game_state.is_pvp_flagged then
        local ok, flagged = pcall(core.game_state.is_pvp_flagged)
        if ok then
            is_pvp = flagged or false
        end
    end

    if target and core.object_manager.get_unit_type then
        local ok, unit_type = pcall(function() return core.object_manager.get_unit_type(target) end)
        if ok then
            target_is_player = (unit_type == "player")
        end
    end

    return {
        is_pvp = is_pvp,
        is_arena = is_arena,
        is_battleground = is_battleground,
        target_is_player = target_is_player
    }
end

-- Cached API references
local _is_pvp_flagged = core.game_state.is_pvp_flagged

-- Check if PvP is active
function utils.is_pvp_active()
    if _is_pvp_flagged then
        local ok, flagged = pcall(_is_pvp_flagged)
        if ok then return flagged or false end
    end
    return false
end

-- Check if PvP setting is enabled
function utils.is_pvp_setting_enabled(menu)
    if menu and menu.pvp_mode then
        local mode = menu.pvp_mode:get()
        return mode == 1 or mode == 3
    end
    return false
end

-- Check if we can Slam without clipping auto-attack
function utils.can_slam_without_clipping(me, slam_id, swing_time_remaining)
    if not me or not me:is_valid() then return false end
    swing_time_remaining = swing_time_remaining or 100
    
    local izi_spell = get_izi_spell(slam_id)
    if not izi_spell then return false end
    
    local slam_cast_time = 1500  -- 1.5 seconds in ms
    return swing_time_remaining > slam_cast_time + 200
end

return utils
