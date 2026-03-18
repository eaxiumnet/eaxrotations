-- EAX PaladinProtection | utils.lua
-- Helpers validated against the documented Sylvanas APIs (spell_book, object_manager, auto_attack_helper).

---@type auto_attack_helper
local auto_attack = require("common/utility/auto_attack_helper")
---@type spell_queue
local spell_queue = require("common/modules/spell_queue")
---@type buff_manager
local buff_manager = require("common/modules/buff_manager")

local utils = {}
local queue_request_timestamps = {}
local throttle_timestamps = {}
local SPELL_QUEUE_INTERVAL_S = 0.25
local FAST_SPELL_QUEUE_INTERVAL_S = 0.10

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

function utils.can_cast_target(spell_id, me, target)
    if not spell_id or not me or not target or not target:is_valid() then
        return false
    end
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


function utils.can_cast_self(spell_id, me)
    if not spell_id or not me then return false end
    if core.spell_book.get_spell_cooldown(spell_id) > 0 then return false end
    if not core.spell_book.is_usable_spell(spell_id) then return false end
    return true
end

function utils.cast_target(spell_id, target)
    if not spell_id or not target or not target:is_valid() then return false end
    if not can_issue_queue_request("spell_target", spell_id, target, SPELL_QUEUE_INTERVAL_S) then
        return false
    end
    spell_queue:queue_spell_target(spell_id, target, 1)
    return true
end

function utils.cast_self(spell_id, me)
    if not spell_id or not me then return false end
    if not can_issue_queue_request("spell_self", spell_id, me, SPELL_QUEUE_INTERVAL_S) then
        return false
    end
    spell_queue:queue_spell_target(spell_id, me, 1)
    return true
end

function utils.has_buff(unit, id_table)
    if not unit or not id_table then return false end
    local data = buff_manager:get_buff_data(unit, id_table)
    return data ~= nil and data.is_active
end

function utils.is_valid_hostile_target(me, target)
    return target
        and target:is_valid()
        and not target:is_dead()
        and me:can_attack(target)
end

function utils.count_enemies_within_radius(me, radius)
    if not me or not radius or radius <= 0 then
        return 0
    end

    local center_pos = me:get_position()
    local count = 0
    local objects = core.object_manager.get_visible_objects()

    for i = 1, #objects do
        local obj = objects[i]
        if utils.is_valid_hostile_target(me, obj)
            and obj:is_in_combat()
        then
            local obj_pos = obj:get_position()
            local threshold = radius + (obj:get_bounding_radius() or 0)
            local sq_dist = center_pos:squared_dist_to_ignore_z(obj_pos)
            if sq_dist <= (threshold * threshold) then
                count = count + 1
            end
        end
    end

    return count
end

function utils.find_best_target(me)
    local target = me and me:get_target()
    if utils.is_valid_hostile_target(me, target) then
        return target
    end

    local visible = core.object_manager.get_visible_objects()
    for i = 1, #visible do
        local candidate = visible[i]
        if utils.is_valid_hostile_target(me, candidate) then
            return candidate
        end
    end

    return nil
end

function utils.ensure_melee_attack(me, target)
    if not me or not target or not target:is_valid() then return false end
    if auto_attack:is_auto_attacking(target) then return true end
    return auto_attack:start_attack(target, auto_attack.ATTACK_TYPE.MELEE)
end

function utils.is_melee_target(me, target)
    if not me or not target or not target:is_valid() then return false end

    local my_pos = me:get_position()
    local target_pos = target:get_position()
    local reach = (me:get_combat_reach() or 0) + (target:get_combat_reach() or 0) + 1.0
    local sq_dist = my_pos:squared_dist_to_ignore_z(target_pos)
    return sq_dist <= (reach * reach)
end

function utils.get_visible_party_size()
    local count = 0
    local visible = core.object_manager.get_visible_objects()
    for i = 1, #visible do
        local member = visible[i]
        if member
            and member:is_valid()
            and member:is_unit()
            and not member:is_dead()
            and member:is_party_member()
        then
            count = count + 1
        end
    end
    return count
end

function utils.throttle(key, interval_s)
    if not key or not interval_s then return false end
    local now = core.time()
    local last = throttle_timestamps[key] or 0
    if (now - last) >= interval_s then
        throttle_timestamps[key] = now
        return true
    end
    return false
end

function utils.log_debug(menu_ref, msg)
    if not menu_ref or not menu_ref.debug then return end
    if menu_ref.debug:get_state() then
        core.log("[EAX Paladin Protection] " .. tostring(msg))
    end
end

return utils
