-- utils.lua
-- EAX Paladin Holy | Utility Functions
-- Shared helper functions

---@type spell_queue
local spell_queue = require("common/modules/spell_queue")
---@type buff_manager
local buff_manager = require("common/modules/buff_manager")

local utils = {}

-- Spell resolver with persistent caching (see eax_shared/spell_resolver.lua)
local spell_resolver = require("spell_resolver")

local queue_request_timestamps = {}
local SPELL_QUEUE_INTERVAL_S = 0.25

-- Throttle helper
local throttle_data = {}
function utils.throttle(key, interval)
    local now = core.time()
    if not throttle_data[key] or (now - throttle_data[key]) >= interval then
        throttle_data[key] = now
        return true
    end
    return false
end

-- Delegated to shared spell resolver with persistent cache
function utils.resolve_spell_id(rank_table)
    return spell_resolver.resolve_spell_id(rank_table)
end

function utils.invalidate_spell_cache()
    spell_resolver.invalidate_cache()
end

-- Get player health percentage
function utils.get_health_pct(unit)
    if not unit or not unit:is_valid() then return 0 end
    local health = unit:get_health()
    local max_health = unit:get_max_health()
    if max_health == 0 then return 0 end
    return health / max_health
end

-- Get distance to target
function utils.get_distance_to_target(me, target)
    if not me or not target then return math.huge end
    if not me:is_valid() or not target:is_valid() then return math.huge end
    local my_pos = me:get_position()
    local target_pos = target:get_position()
    return my_pos:dist_to(target_pos)
end

-- Check if target is in melee range
function utils.is_melee_target(me, target)
    if not me or not target then return false end
    if not me:is_valid() or not target:is_valid() then return false end
    local distance = utils.get_distance_to_target(me, target)
    local bounding = target:get_bounding_radius() or 0
    return distance <= (5 + bounding)
end

-- Check if unit has buff (compliant version using documented get_buff_data)
function utils.has_buff(unit, buff_table)
    if not unit or not unit:is_valid() then return false end
    if not buff_table then return false end
    if type(buff_table) == "number" then
        buff_table = { buff_table }
    end
    local data = buff_manager:get_buff_data(unit, buff_table)
    return data ~= nil and data.is_active
end

-- Check if unit has debuff
function utils.has_debuff(unit, debuff_table)
    if not unit or not unit:is_valid() then return false end
    if not debuff_table then return false end
    local data = buff_manager:get_debuff_data(unit, debuff_table)
    if data and data.is_active then return true end
    data = buff_manager:get_aura_data(unit, debuff_table)
    return data ~= nil and data.is_active
end

-- Get buff remaining time (ms)
function utils.get_buff_remaining_ms(unit, buff_table)
    if not unit or not unit:is_valid() then return 0 end
    if not buff_table then return 0 end
    local data = buff_manager:get_buff_data(unit, buff_table)
    if data and data.is_active then
        return data.remaining_time or 0
    end
    return 0
end

-- Get debuff remaining time (ms)
function utils.get_debuff_remaining_ms(unit, debuff_table)
    if not unit or not unit:is_valid() then return 0 end
    if not debuff_table then return 0 end
    local data = buff_manager:get_debuff_data(unit, debuff_table)
    if data and data.is_active then
        return data.remaining_time or 0
    end
    return 0
end

-- Check if spell can be cast on self
function utils.can_cast_self(spell_id, me)
    if not spell_id then return false end
    if not me or not me:is_valid() then return false end
    if not core.spell_book.is_spell_learned(spell_id) then return false end
    if core.spell_book.get_spell_cooldown(spell_id) > 0 then return false end
    if not core.spell_book.is_usable_spell(spell_id) then return false end
    return true
end

-- Check if spell can be cast on target
function utils.can_cast_target(spell_id, me, target)
    if not spell_id then return false end
    if not me or not me:is_valid() then return false end
    if not target or not target:is_valid() then return false end
    if not core.spell_book.is_spell_learned(spell_id) then return false end
    if core.spell_book.get_spell_cooldown(spell_id) > 0 then return false end
    if not core.spell_book.is_usable_spell(spell_id) then return false end
    if not core.spell_book.is_spell_in_range(spell_id, target, me) then return false end
    return true
end

--- Can the player cast an OFFENSIVE spell on target right now?
--- Extends can_cast_target with a hostility check (me:can_attack) and
--- a self-cast guard so damage spells never fire on friendly units.
---@param spell_id number|nil
---@param me game_object
---@param target game_object
---@return boolean
function utils.can_cast_hostile(spell_id, me, target)
    if not me or not target then return false end
    local same_unit = utils.same_unit or function(a, b) return a == b end
    -- Never cast damage spells on self
    if same_unit(me, target) then return false end
    -- Target must be attackable by the player (fails for friendlies, self, neutral)
    if not me:can_attack(target) then return false end
    return utils.can_cast_target(spell_id, me, target)
end


-- Find the best hostile target using priority logic:
-- 1. Current target if it is a valid hostile
-- 2. A hostile unit that is actively targeting ME (attacking me)
-- 3. A hostile unit attacking any party member
-- 4. Any nearby hostile unit
-- Returns nil if no valid target found.
-- Max range for auto target acquisition.
-- Covers melee + max gap-closer range. Units beyond this are ignored
-- unless they are actively attacking us or party.
local MODE_DETECT_INTERVAL_S = 5.0
local AUTO_TARGET_MAX_RANGE = 40.0
local AUTO_TARGET_MAX_HOSTILES = 50
local mode_cache = "solo"
local mode_cache_refreshed_at = 0

function utils.detect_mode(me)
    local now = core.time()
    if mode_cache_refreshed_at > 0 and (now - mode_cache_refreshed_at) < MODE_DETECT_INTERVAL_S then
        return mode_cache
    end

    me = me or core.object_manager.get_local_player()
    local party_count = 0
    local objects = core.object_manager.get_all_objects()

    for i = 1, #objects do
        local obj = objects[i]
        if obj and obj:is_valid() and obj:is_unit() and not obj:is_dead() then
            local is_group_member = false

            if utils.is_group_member then
                is_group_member = utils.is_group_member(me, obj)
            elseif obj:is_party_member() then
                is_group_member = not (me and utils.same_unit and utils.same_unit(me, obj))
            end

            if is_group_member then
                party_count = party_count + 1
            end
        end
    end

    if party_count == 0 then
        mode_cache = "solo"
    elseif party_count <= 4 then
        mode_cache = "dungeon"
    else
        mode_cache = "raid"
    end

    mode_cache_refreshed_at = now
    return mode_cache
end


function utils.find_best_target(me)
    if not me or not me:is_valid() then return nil end

    local function is_hostile(unit)
        return unit and unit:is_valid() and not unit:is_dead() and me:can_attack(unit)
    end

    local current = me:get_target()
    if is_hostile(current) then
        if me:is_in_combat() then
            return current
        end
        return nil
    end

    if not me:is_in_combat() then
        return nil
    end

    local pos_me = nil
    do
        local ok, value = pcall(function() return me:get_position() end)
        if ok then
            pos_me = value
        end
    end

    local function in_range(unit, max_range)
        if not pos_me then return true end

        local ok, pos_u = pcall(function() return unit:get_position() end)
        if not ok or not pos_u then return true end

        local dx = pos_me.x - pos_u.x
        local dy = pos_me.y - pos_u.y
        local dz = pos_me.z - pos_u.z
        return (dx * dx + dy * dy + dz * dz) <= (max_range * max_range)
    end

    local objects = core.object_manager.get_all_objects()
    local best_attacking_party = nil
    local best_any = nil
    local hostile_scanned = 0

    for i = 1, #objects do
        local obj = objects[i]
        if obj and obj:is_valid() and obj:is_unit() and is_hostile(obj) and in_range(obj, AUTO_TARGET_MAX_RANGE) then
            hostile_scanned = hostile_scanned + 1

            local obj_target = obj:get_target()
            if obj_target and utils.same_unit(obj_target, me) then
                return obj
            end

            if not best_attacking_party and obj_target and obj_target:is_valid() and obj_target:is_party_member() then
                best_attacking_party = obj
            elseif not best_any then
                best_any = obj
            end

            if hostile_scanned >= AUTO_TARGET_MAX_HOSTILES then
                break
            end
        end
    end

    return best_attacking_party or best_any
end



-- Check if spell can be cast in melee
function utils.can_cast_melee(spell_id, me)
    if not spell_id then return false end
    if not me or not me:is_valid() then return false end
    if not core.spell_book.is_spell_learned(spell_id) then return false end
    if core.spell_book.get_spell_cooldown(spell_id) > 0 then return false end
    if not core.spell_book.is_usable_spell(spell_id) then return false end
    return true
end

local function can_issue_queue_request(kind, spell_id, target, interval_s)
    local key = kind .. ":" .. tostring(spell_id) .. ":" .. tostring(target)
    local now = core.time()
    local last = queue_request_timestamps[key] or 0
    if (now - last) < interval_s then
        return false
    end
    queue_request_timestamps[key] = now
    return true
end

-- Cast spell on self
function utils.cast_self(spell_id, me)
    if not utils.can_cast_self(spell_id, me) then return false end
    if not can_issue_queue_request("spell_self", spell_id, me, SPELL_QUEUE_INTERVAL_S) then
        return false
    end
    spell_queue:queue_spell_target(spell_id, me, 1)
    return true
end

-- Cast spell on target
function utils.cast_target(spell_id, target)
    if not spell_id or not target or not target:is_valid() then return false end
    if not can_issue_queue_request("spell_target", spell_id, target, SPELL_QUEUE_INTERVAL_S) then
        return false
    end
    spell_queue:queue_spell_target(spell_id, target, 1)
    return true
end

-- Cast spell fast (for instant abilities)
function utils.cast_self_fast(spell_id, me)
    if not utils.can_cast_self(spell_id, me) then return false end
    if not can_issue_queue_request("spell_self_fast", spell_id, me, SPELL_QUEUE_INTERVAL_S) then
        return false
    end
    spell_queue:queue_spell_target_fast(spell_id, me, 1)
    return true
end

function utils.cast_target_fast(spell_id, target)
    if not spell_id or not target or not target:is_valid() then return false end
    if not can_issue_queue_request("spell_target_fast", spell_id, target, SPELL_QUEUE_INTERVAL_S) then
        return false
    end
    spell_queue:queue_spell_target_fast(spell_id, target, 1)
    return true
end

-- Check if spell is already queued
function utils.is_spell_already_queued(spell_id)
    if not spell_id then return false end
    return core.spell_book.is_current_spell(spell_id)
end

-- Debug logging
function utils.log_debug(menu, message)
    if menu and menu.debug and menu.debug:get_state() then
        core.log("[EAX Paladin Holy] " .. message)
    end
end

return utils
