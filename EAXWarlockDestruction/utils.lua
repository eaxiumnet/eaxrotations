-- utils.lua
-- Helper utilities for EAX Warlock Destruction.

---@type enums
local enums = require("common/enums")
---@type spell_queue
local spell_queue = require("common/modules/spell_queue")

local utils = {}
local throttle_timestamps = {}
local queue_timestamps = {}
local SPELL_QUEUE_INTERVAL_S = 0.25

local function queue_key(kind, spell_id, target)
    return kind .. ":" .. tostring(spell_id) .. ":" .. tostring(target)
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

function utils.can_cast_target(spell_id, me, target)
    if not spell_id or not me or not target or not target:is_valid() then
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

function utils.can_cast_self(spell_id, me)
    if not spell_id or not me then
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

local function can_issue_queue_request(kind, spell_id, target, interval)
    local key = queue_key(kind, spell_id, target)
    local now = core.time()
    local last = queue_timestamps[key] or 0
    if (now - last) < interval then
        return false
    end
    queue_timestamps[key] = now
    return true
end

function utils.cast_target(spell_id, target)
    if not spell_id or not target or not target:is_valid() then
        return false
    end
    if not can_issue_queue_request("spell_target", spell_id, target, SPELL_QUEUE_INTERVAL_S) then
        return false
    end
    spell_queue:queue_spell_target(spell_id, target, 1)
    return true
end

function utils.cast_self(spell_id, me)
    if not spell_id or not me then
        return false
    end
    if not can_issue_queue_request("spell_self", spell_id, me, SPELL_QUEUE_INTERVAL_S) then
        return false
    end
    spell_queue:queue_spell_target(spell_id, me, 1)
    return true
end

function utils.get_debuff_remaining_ms(unit, id_table)
    if not unit or not id_table then
        return 0
    end
    local data = unit:get_debuff_data(id_table)
    if data and data.is_active then
        return data.remaining or 0
    end
    return 0
end

function utils.has_debuff(unit, id_table)
    if not unit or not id_table then
        return false
    end
    return unit:get_debuff_data(id_table) ~= nil
end

function utils.get_health_pct(unit)
    if not unit then
        return 0
    end
    local max_hp = unit:get_max_health()
    if max_hp <= 0 then
        return 0
    end
    return unit:get_health() / max_hp
end

function utils.get_mana_pct(unit)
    if not unit then
        return 0
    end
    local current = unit:get_power(enums.power_type.MANA) or 0
    local maximum = unit:get_max_power(enums.power_type.MANA) or 1
    if maximum <= 0 then
        return 0
    end
    return math.min(1, math.max(0, current / maximum))
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

function utils.log_debug(menu_ref, message)
    if menu_ref and menu_ref.debug and menu_ref.debug:get_state() then
        core.log("[EAX Warlock Destruction] " .. message)
    end
end

return utils
