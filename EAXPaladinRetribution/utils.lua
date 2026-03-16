-- EAX Paladin Retribution | utils.lua
-- Helper utilities used by the retri rotation.

local auto_attack = require("common/utility/auto_attack_helper")
local spell_queue = require("common/modules/spell_queue")

local utils = {}

local queue_request_timestamps = {}
local throttle_timestamps = {}
local SPELL_QUEUE_INTERVAL_S = 0.25

local function can_issue_queue_request(kind, spell_id, target_key, interval)
    local key = kind .. ":" .. tostring(spell_id) .. ":" .. tostring(target_key)
    local now = core.time()
    local last = queue_request_timestamps[key] or 0
    if (now - last) < interval then
        return false
    end
    queue_request_timestamps[key] = now
    return true
end

function utils.resolve_spell_id(rank_table)
    if not rank_table then
        return nil
    end
    for i = 1, #rank_table do
        if core.spell_book.is_spell_learned(rank_table[i]) then
            return rank_table[i]
        end
    end
    return nil
end

function utils.cast_target(spell_id, target)
    if not spell_id or not target or not target:is_valid() then
        return false
    end
    if not can_issue_queue_request("cast_target", spell_id, target, SPELL_QUEUE_INTERVAL_S) then
        return false
    end

    spell_queue:queue_spell_target(spell_id, target, 1)
    return true
end

function utils.cast_self(spell_id, me)
    if not spell_id or not me then
        return false
    end
    if not can_issue_queue_request("cast_self", spell_id, me, SPELL_QUEUE_INTERVAL_S) then
        return false
    end

    spell_queue:queue_spell_target(spell_id, me, 1)
    return true
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
    if menu_ref and menu_ref.debug and menu_ref.debug:get_state() then
        core.log("[EAX Paladin Retribution] " .. msg)
    end
end

function utils.get_next_swing_ms(me)
    if not me then
        return math.huge
    end
    local next_attack_time = auto_attack:get_next_attack_game_time(me, 1)
    if not next_attack_time or next_attack_time <= 0 then
        return math.huge
    end
    local remaining = next_attack_time - core.game_time()
    if remaining < 0 then
        return 0
    end
    return remaining
end

function utils.is_melee_target(me, target)
    if not me or not target or not target:is_valid() or target:is_dead() then
        return false
    end
    local my_pos = me:get_position()
    local target_pos = target:get_position()
    if not my_pos or not target_pos then
        return false
    end
    local reach = (me:get_combat_reach() or 0) + (target:get_combat_reach() or 0) + 1.0
    local sq_dist = my_pos:squared_dist_to_ignore_z(target_pos)
    return sq_dist <= (reach * reach)
end

function utils.ensure_melee_auto_attack(me, target)
    if not me or not target or not target:is_valid() or target:is_dead() then
        return false
    end
    if auto_attack:is_auto_attacking(target) then
        return true
    end
    if not utils.throttle("paladin:ensure_auto_attack", 0.30) then
        return false
    end
    return auto_attack:start_attack(target, auto_attack.ATTACK_TYPE.MELEE)
end

function utils.has_buff(unit, id_table)
    if not unit or not id_table then
        return false
    end
    local data = unit:get_buff_data(id_table)
    return data ~= nil and data.is_active
end

function utils.has_debuff(unit, id_table)
    if not unit or not id_table then
        return false
    end
    local data = unit:get_debuff_data(id_table)
    return data ~= nil and data.is_active
end

return utils
