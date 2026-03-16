local utils = {}

---@type spell_queue
local spell_queue = require("common/modules/spell_queue")

local queue_request_timestamps = {}
local SPELL_QUEUE_INTERVAL_S = 0.25

local throttle_data = {}

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
        local id = rank_table[i]
        if id and core.spell_book.is_spell_learned(id) then
            return id
        end
    end
    return nil
end

function utils.get_health_pct(unit)
    if not unit or not unit:is_valid() then
        return 0
    end
    local hp = unit:get_health()
    local max = unit:get_max_health()
    if not max or max <= 0 then
        return 0
    end
    return hp / max
end

function utils.get_distance_to_target(me, target)
    if not me or not target then
        return math.huge
    end
    local me_pos = me:get_position()
    local target_pos = target:get_position()
    if not me_pos or not target_pos then
        return math.huge
    end
    return me_pos:dist_to(target_pos)
end

function utils.is_valid_hostile_target(me, target)
    if not me or not target then
        return false
    end
    if not target:is_valid() or target:is_dead() then
        return false
    end
    return me:can_attack(target)
end

function utils.can_cast_target(spell_id, me, target)
    if not spell_id or not me or not target then
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
    if not core.spell_book.is_spell_in_range(spell_id, target, me) then
        return false
    end
    return true
end

function utils.has_debuff(unit, debuff_table)
    if not unit or not unit:is_valid() or not debuff_table then
        return false
    end
    for i = 1, #debuff_table do
        local entry = unit:get_debuff_data(debuff_table[i])
        if entry and entry.is_active then
            return true
        end
    end
    return false
end

function utils.has_buff(unit, buff_table)
    if not unit or not unit:is_valid() or not buff_table then
        return false
    end
    for i = 1, #buff_table do
        local entry = unit:get_buff_data(buff_table[i])
        if entry and entry.is_active then
            return true
        end
    end
    return false
end

function utils.cast_target(spell_id, target)
    if not spell_id or not target or not target:is_valid() then return false end
    if not can_issue_queue_request("spell_target", spell_id, target, SPELL_QUEUE_INTERVAL_S) then
        return false
    end
    spell_queue:queue_spell_target(spell_id, target, 1)
    return true
end

function utils.log_debug(menu_module, message)
    if menu_module and menu_module.debug and menu_module.debug:get_state() then
        core.log("[EAX Hunter Marksmanship] " .. tostring(message))
    end
end

return utils
