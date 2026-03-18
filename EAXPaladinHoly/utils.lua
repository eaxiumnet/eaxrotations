-- utils.lua
-- EAX Paladin Holy | Utility Functions
-- Shared helper functions

---@type spell_queue
local spell_queue = require("common/modules/spell_queue")
---@type buff_manager
local buff_manager = require("common/modules/buff_manager")

local utils = {}

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

-- Resolve spell ID from table (find highest learned rank)
function utils.resolve_spell_id(rank_table)
    if not rank_table then return nil end
    -- Accept a plain spell ID (number) as well as a ranked table
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
    for i = 1, #buff_table do
        local data = buff_manager:get_buff_data(unit, buff_table[i])
        if data and data.is_active then
            return true
        end
    end
    return false
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
    -- Never cast damage spells on self
    if utils.same_unit(me, target) then return false end
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
function utils.find_best_target(me)
    if not me or not me:is_valid() then return nil end

    local function is_hostile(unit)
        return unit and unit:is_valid() and not unit:is_dead() and me:can_attack(unit)
    end

    -- Priority 1: keep current target if it is already a valid hostile
    local current = me:get_target()
    if is_hostile(current) then
        return current
    end

    local objects = core.object_manager.get_all_objects()
    local best_attacking_me   = nil
    local best_attacking_party = nil
    local best_any            = nil

    for i = 1, #objects do
        local obj = objects[i]
        if obj and obj:is_valid() and obj:is_unit() and is_hostile(obj) then
            local obj_target = obj:get_target()

            -- Priority 2: unit actively targeting me
            if obj_target and utils.same_unit(obj_target, me) then
                if not best_attacking_me then
                    best_attacking_me = obj
                end

            -- Priority 3: unit targeting a party member
            elseif obj_target and obj_target:is_valid()
                and obj_target:is_party_member() then
                if not best_attacking_party then
                    best_attacking_party = obj
                end

            -- Priority 4: any hostile (fallback)
            else
                if not best_any then
                    best_any = obj
                end
            end
        end
    end

    return best_attacking_me or best_attacking_party or best_any
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
