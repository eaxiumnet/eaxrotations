-- utils.lua
-- EAX Shaman Enhancement | Utility helpers

local enums = require("common/enums")
---@type spell_queue
local spell_queue = require("common/modules/spell_queue")

local utils = {}

local throttle_data = {}

local queue_request_timestamps = {}
local SPELL_QUEUE_INTERVAL_S = 0.25

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

function utils.throttle(key, interval)
    local now = core.time()
    if not throttle_data[key] or (now - throttle_data[key]) >= interval then
        throttle_data[key] = now
        return true
    end
    return false
end

function utils.resolve_spell_id(rank_table)
    if not rank_table then return nil end
    for i = #rank_table, 1, -1 do
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
    local max_hp = unit:get_max_health()
    if not max_hp or max_hp <= 0 then return 0 end
    return hp / max_hp
end

function utils.get_power_pct(unit, power_type)
    if not unit or not unit:is_valid() then return 0 end
    local current = unit:get_power(power_type)
    local maximum = unit:get_max_power(power_type)
    if not maximum or maximum <= 0 then return 0 end
    return current / maximum
end

function utils.get_mana_pct(unit)
    return utils.get_power_pct(unit, enums.power_type.MANA)
end

function utils.can_cast_self(spell_id, me)
    if not spell_id or not me or not me:is_valid() then
        return false
    end
    if not core.spell_book.is_spell_learned(spell_id) then
        return false
    end
    if core.spell_book.get_spell_cooldown(spell_id) > 0 then
        return false
    end
    if not core.spell_book.is_usable_spell(spell_id) then
        return false
    end
    return true
end

function utils.cast_self(spell_id, me)
    if not spell_id or not me or not me:is_valid() then return false end
    if not can_issue_queue_request("spell_self", spell_id, me, SPELL_QUEUE_INTERVAL_S) then
        return false
    end
    spell_queue:queue_spell_target(spell_id, me, 1)
    return true
end

function utils.cast_target(spell_id, me, target)
    if not spell_id or not target or not target:is_valid() then return false end
    if not can_issue_queue_request("spell_target", spell_id, target, SPELL_QUEUE_INTERVAL_S) then
        return false
    end
    spell_queue:queue_spell_target(spell_id, target, 1)
    return true
end

function utils.get_distance(me, target)
    if not me or not target then return math.huge end
    if not me:is_valid() or not target:is_valid() then return math.huge end
    local me_pos = me:get_position()
    local target_pos = target:get_position()
    if not me_pos or not target_pos then return math.huge end
    return me_pos:dist_to(target_pos)
end

function utils.is_valid_hostile(me, target)
    if not me or not target then return false end
    if not target:is_valid() or target:is_dead() then return false end
    return me:can_attack(target)
end

function utils.has_debuff(unit, debuff_table)
    if not unit or not unit:is_valid() or not debuff_table then return false end
    -- get_debuff_data expects number[] (the whole array), not a single number.
    local entry = unit:get_debuff_data(debuff_table)
    return entry ~= nil and entry.is_active
end

function utils.is_melee_target(me, target)
    if not me or not target then return false end
    if not me:is_valid() or not target:is_valid() then return false end
    local distance = utils.get_distance(me, target)
    local bounding = target:get_bounding_radius() or 0
    return distance <= (5 + bounding)
end

function utils.count_enemies_in_range(me, radius)
    if not me or not me:is_valid() then return 0 end
    local objects = core.object_manager.get_all_objects()
    local me_pos = me:get_position()
    if not me_pos then return 0 end
    local count = 0
    for i = 1, #objects do
        local obj = objects[i]
        if obj and obj:is_valid() and obj:is_unit() and not obj:is_dead() and me:can_attack(obj) then
            local obj_pos = obj:get_position()
            if obj_pos and me_pos:dist_to(obj_pos) <= radius then
                count = count + 1
            end
        end
    end
    return count
end

function utils.log_debug(menu_module, message)
    if menu_module and menu_module.debug and menu_module.debug:get_state() then
        core.log("[EAX Shaman Enhancement] " .. tostring(message))
    end
end

return utils
