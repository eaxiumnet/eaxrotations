-- EAX Druid Balance | utils.lua
-- Shared helpers validated against documented Project Sylvanas APIs.

---@type enums
local enums = require("common/enums")
---@type spell_queue
local spell_queue = require("common/modules/spell_queue")

local utils = {}

local throttle_timestamps = {}
local queue_request_timestamps = {}
local SPELL_QUEUE_INTERVAL_S = 0.25
local FAST_SPELL_QUEUE_INTERVAL_S = 0.10

function utils.resolve_spell_id(rank_table)
    if not rank_table then return nil end
    for i = 1, #rank_table do
        if core.spell_book.is_spell_learned(rank_table[i]) then
            return rank_table[i]
        end
    end
    return nil
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

function utils.can_cast_target(spell_id, me, target)
    if not spell_id or not me or not target or not target:is_valid() then return false end
    if core.spell_book.get_spell_cooldown(spell_id) > 0 then return false end
    if not core.spell_book.is_usable_spell(spell_id) then return false end
    if not core.spell_book.is_spell_in_range(spell_id, target, me) then return false end
    return true
end

function utils.can_cast_self(spell_id, me)
    if not spell_id or not me then return false end
    if core.spell_book.get_spell_cooldown(spell_id) > 0 then return false end
    if not core.spell_book.is_usable_spell(spell_id) then return false end
    return true
end

function utils.cast_target(spell_id, target)
    if not spell_id or not target or not target:is_valid() then return false end
    if not can_issue_queue_request("spell_target", spell_id, target, SPELL_QUEUE_INTERVAL_S) then return false end
    spell_queue:queue_spell_target(spell_id, target, 1)
    return true
end

function utils.cast_self(spell_id, me)
    if not spell_id or not me then return false end
    if not can_issue_queue_request("spell_self", spell_id, me, SPELL_QUEUE_INTERVAL_S) then return false end
    spell_queue:queue_spell_target(spell_id, me, 1)
    return true
end

function utils.cast_self_fast(spell_id, me)
    if not spell_id or not me then return false end
    if not can_issue_queue_request("spell_self_fast", spell_id, me, FAST_SPELL_QUEUE_INTERVAL_S) then return false end
    spell_queue:queue_spell_target_fast(spell_id, me, 1)
    return true
end

function utils.get_health_pct(unit)
    if not unit or not unit:is_valid() then return 1.0 end
    local max_hp = unit:get_max_health()
    if max_hp <= 0 then return 1.0 end
    return unit:get_health() / max_hp
end

function utils.get_mana_pct(unit)
    if not unit or not unit:is_valid() then return 0 end
    local max_mana = unit:get_max_power(enums.power_type.MANA)
    if max_mana <= 0 then return 0 end
    return unit:get_power(enums.power_type.MANA) / max_mana
end

function utils.get_buff_data(unit, id_table)
    if not unit or not unit:is_valid() or not id_table then return nil end
    return unit:get_buff_data(id_table)
end

function utils.get_debuff_data(unit, id_table)
    if not unit or not unit:is_valid() or not id_table then return nil end
    return unit:get_debuff_data(id_table)
end

function utils.has_buff(unit, id_table)
    local data = utils.get_buff_data(unit, id_table)
    return data ~= nil and data.is_active or false
end

function utils.has_debuff(unit, id_table)
    local data = utils.get_debuff_data(unit, id_table)
    return data ~= nil and data.is_active or false
end

function utils.get_buff_remaining_ms(unit, id_table)
    local data = utils.get_buff_data(unit, id_table)
    if data and data.is_active then
        return data.remaining or 0
    end
    return 0
end

function utils.get_debuff_remaining_ms(unit, id_table)
    local data = utils.get_debuff_data(unit, id_table)
    if data and data.is_active then
        return data.remaining or 0
    end
    return 0
end

function utils.same_unit(a, b)
    if not a or not b then return false end
    if a == b then return true end
    if not a.is_valid or not b.is_valid or not a:is_valid() or not b:is_valid() then return false end
    if a.get_name and b.get_name then
        local a_name = a:get_name() or ""
        local b_name = b:get_name() or ""
        if a_name ~= "" and b_name ~= "" then
            return a_name == b_name
        end
    end
    return false
end

function utils.is_group_member(me, unit)
    if not unit or not unit:is_valid() then return false end
    if utils.same_unit(me, unit) then return false end
    return unit:is_party_member()
end

function utils.enemy_count_in_radius(me, radius)
    if not me or not me:is_valid() then return 0 end
    local my_pos = me:get_position()
    local count = 0
    local objects = core.object_manager.get_all_objects()

    for i = 1, #objects do
        local obj = objects[i]
        if obj
            and obj:is_valid()
            and obj:is_unit()
            and not obj:is_dead()
            and me:can_attack(obj)
        then
            local obj_pos = obj:get_position()
            local threshold = radius + obj:get_bounding_radius()
            local sq_dist = my_pos:squared_dist_to_ignore_z(obj_pos)
            if sq_dist <= (threshold * threshold) then
                count = count + 1
            end
        end
    end

    return count
end

function utils.throttle(key, interval_s)
    local now = core.time()
    local last = throttle_timestamps[key] or 0
    if (now - last) >= interval_s then
        throttle_timestamps[key] = now
        return true
    end
    return false
end

function utils.log_debug(menu_ref, msg)
    if menu_ref.debug:get_state() then
        core.log("[EAX Druid Balance] " .. msg)
    end
end

return utils
