-- EAX Rogue Assassination | utils.lua

---@type spell_helper
local spell_helper = require("common/utility/spell_helper")
---@type spell_queue
local spell_queue = require("common/modules/spell_queue")

local utils = {}

local throttle_timestamps = {}
local queue_timestamps = {}
local SPELL_QUEUE_INTERVAL_S = 0.25
local FAST_SPELL_QUEUE_INTERVAL_S = 0.10

function utils.resolve_spell_id(rank_table)
    if not rank_table then
        return nil
    end

    for i = 1, #rank_table do
        local spell_id = rank_table[i]
        if core.spell_book.is_spell_learned(spell_id) then
            return spell_id
        end
    end

    return nil
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

function utils.get_health_pct(unit)
    if not unit or not unit:is_valid() then
        return 1.0
    end

    local max_hp = unit:get_max_health()
    if max_hp <= 0 then
        return 1.0
    end

    return unit:get_health() / max_hp
end

function utils.get_buff_remaining_ms(unit, ids)
    if not unit or not unit:is_valid() then
        return 0
    end

    local data = unit:get_buff_data(ids)
    if data and data.is_active then
        return data.remaining or data.remaining_time or 0
    end

    return 0
end

function utils.get_debuff_data(unit, ids)
    if not unit or not unit:is_valid() then
        return nil
    end

    return unit:get_debuff_data(ids)
end

function utils.has_debuff(unit, ids)
    local data = utils.get_debuff_data(unit, ids)
    return data ~= nil and data.is_active == true
end

function utils.get_debuff_remaining_ms(unit, ids)
    local data = utils.get_debuff_data(unit, ids)
    if data and data.is_active then
        return data.remaining or data.remaining_time or 0
    end
    return 0
end

function utils.get_debuff_stacks(unit, ids)
    local data = utils.get_debuff_data(unit, ids)
    if not data or not data.is_active then
        return 0
    end

    return data.stacks or data.stack_count or 0
end

function utils.detect_mode()
    local objects = core.object_manager.get_all_objects()
    local party_count = 0

    for i = 1, #objects do
        local obj = objects[i]
        if obj and obj:is_valid() and obj:is_unit() and not obj:is_dead() 
           and obj:is_party_member() then
            party_count = party_count + 1
        end
    end

    if party_count == 0 then
        return "solo"
    elseif party_count <= 4 then
        return "dungeon"
    end

    return "raid"
end

function utils.get_selected_mode(menu)
    local mode_index = menu.mode:get()
    if mode_index == 2 then
        return "solo"
    elseif mode_index == 3 then
        return "dungeon"
    elseif mode_index == 4 then
        return "raid"
    end

    return utils.detect_mode()
end

function utils.can_attack(me, target)
    return me and target and target:is_valid() and not target:is_dead() and me:can_attack(target)
end

function utils.is_spell_ready(spell_id)
    return spell_id
        and not core.spell_book.is_current_spell(spell_id)
        and core.spell_book.get_spell_cooldown(spell_id) <= 0
        and core.spell_book.is_usable_spell(spell_id)
end

local function can_issue_queue_request(kind, spell_id, target, interval_s)
    local key = kind .. ":" .. tostring(spell_id) .. ":" .. tostring(target)
    local now = core.time()
    local last = queue_timestamps[key] or 0
    if (now - last) < interval_s then
        return false
    end

    queue_timestamps[key] = now
    return true
end

function utils.can_cast_target(spell_id, me, target)
    if not spell_id or not me or not target or not target:is_valid() then
        return false
    end

    return spell_helper:is_spell_castable(spell_id, me, target, false, false)
end

function utils.can_cast_self(spell_id, me)
    if not spell_id or not me then
        return false
    end

    return spell_helper:is_spell_castable(spell_id, me, me, true, true)
end

function utils.cast_target(spell_id, target, message)
    if not spell_id or not target or not target:is_valid() then
        return false
    end

    if not can_issue_queue_request("target", spell_id, target, SPELL_QUEUE_INTERVAL_S) then
        return false
    end

    spell_queue:queue_spell_target(spell_id, target, 1, message)
    return true
end

function utils.cast_target_fast(spell_id, target, message)
    if not spell_id or not target or not target:is_valid() then
        return false
    end

    if not can_issue_queue_request("target_fast", spell_id, target, FAST_SPELL_QUEUE_INTERVAL_S) then
        return false
    end

    spell_queue:queue_spell_target_fast(spell_id, target, 1, message)
    return true
end

function utils.cast_self(spell_id, me, message)
    if not spell_id or not me then
        return false
    end

    if not can_issue_queue_request("self", spell_id, me, SPELL_QUEUE_INTERVAL_S) then
        return false
    end

    spell_queue:queue_spell_target(spell_id, me, 1, message)
    return true
end

function utils.cast_self_fast(spell_id, me, message)
    if not spell_id or not me then
        return false
    end

    if not can_issue_queue_request("self_fast", spell_id, me, FAST_SPELL_QUEUE_INTERVAL_S) then
        return false
    end

    spell_queue:queue_spell_target_fast(spell_id, me, 1, message)
    return true
end

function utils.log_debug(menu, message)
    if menu.debug:get_state() then
        core.log("[EAX Rogue Assassination] " .. message)
    end
end

return utils
