-- utils.lua
-- EAX Shaman Restoration | Helpers for heals and party tracking

local enums = require("common/enums")
---@type spell_queue
local spell_queue = require("common/modules/spell_queue")
---@type spell_helper
local spell_helper = require("common/utility/spell_helper")
---@type unit_helper
local unit_helper = require("common/utility/unit_helper")

local utils = {}

-- ─── Throttle ────────────────────────────────────────────────────────────────

local throttle_data = {}
function utils.throttle(key, interval_s)
    local now = core.time()
    if not throttle_data[key] or (now - throttle_data[key]) >= interval_s then
        throttle_data[key] = now
        return true
    end
    return false
end

-- ─── Spell resolution ────────────────────────────────────────────────────────

-- Walk rank table from lowest to highest rank and return the first learned ID.
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

-- ─── Health helpers ──────────────────────────────────────────────────────────

-- Returns 0.0–1.0 raw health fraction.
function utils.get_health_pct(unit)
    if not unit or not unit:is_valid() then return 0 end
    -- unit_helper:get_health_percentage returns 0.0–1.0
    return unit_helper:get_health_percentage(unit)
end

-- ─── Mana helper ─────────────────────────────────────────────────────────────

function utils.get_mana_pct(unit)
    if not unit or not unit:is_valid() then return 0 end
    local current = unit:get_power(enums.power_type.MANA)
    local maximum = unit:get_max_power(enums.power_type.MANA)
    if not maximum or maximum <= 0 then return 0 end
    return current / maximum
end

-- ─── Buff helpers ────────────────────────────────────────────────────────────

-- buff_manager_data.remaining is in MILLISECONDS.
-- Returns true if any ID in id_table is an active buff on unit.
function utils.has_buff(unit, id_table)
    if not unit or not unit:is_valid() or not id_table then return false end
    local data = unit:get_buff_data(id_table)
    return data ~= nil and data.is_active
end

-- Returns remaining duration in SECONDS (converts from ms internally).
function utils.get_buff_remaining_s(unit, id_table)
    if not unit or not unit:is_valid() or not id_table then return 0 end
    local data = unit:get_buff_data(id_table)
    if data and data.is_active then
        return (data.remaining or 0) / 1000.0
    end
    return 0
end

-- Returns true if any ID in id_table is an active debuff on unit.
function utils.has_debuff(unit, id_table)
    if not unit or not unit:is_valid() or not id_table then return false end
    local data = unit:get_debuff_data(id_table)
    return data ~= nil and data.is_active
end

-- ─── Target helpers ──────────────────────────────────────────────────────────

-- Returns true if `target` is a valid hostile the player can attack.
function utils.is_valid_hostile(me, target)
    if not me or not target then return false end
    if not target:is_valid() or target:is_dead() then return false end
    return me:can_attack(target)
end

-- ─── Cast helpers ────────────────────────────────────────────────────────────

local queue_timestamps = {}
local QUEUE_INTERVAL_S      = 0.25
local QUEUE_FAST_INTERVAL_S = 0.10

local function can_queue(kind, spell_id, target, interval_s)
    local key = kind .. ":" .. tostring(spell_id) .. ":" .. tostring(target)
    local now = core.time()
    local last = queue_timestamps[key] or 0
    if (now - last) < interval_s then return false end
    queue_timestamps[key] = now
    return true
end

-- Cast a spell on an ally target (GCD ability).
-- Checks castability via spell_helper before queuing.
function utils.cast_target(spell_id, caster, target)
    if not spell_id or not caster or not target then return false end
    if not target:is_valid() or target:is_dead() then return false end
    if not spell_helper:is_spell_castable(
            spell_id, caster, target, true, false) then
        return false
    end
    if not can_queue("target", spell_id, target, QUEUE_INTERVAL_S) then
        return false
    end
    spell_queue:queue_spell_target(spell_id, target, 1)
    return true
end

-- Cast a spell on self (GCD ability, e.g. totems, Water Shield).
-- Checks castability via spell_helper before queuing.
function utils.cast_self(spell_id, me)
    if not spell_id or not me or not me:is_valid() then return false end
    if not spell_helper:is_spell_castable(
            spell_id, me, me, true, true) then
        return false
    end
    if not can_queue("self", spell_id, me, QUEUE_INTERVAL_S) then
        return false
    end
    spell_queue:queue_spell_target(spell_id, me, 1)
    return true
end

-- Cast an off-GCD ability on self (e.g. Nature's Swiftness).
-- Uses queue_spell_target_fast to skip GCD check.
function utils.cast_self_fast(spell_id, me)
    if not spell_id or not me or not me:is_valid() then return false end
    if not spell_helper:is_spell_castable(
            spell_id, me, me, true, true) then
        return false
    end
    if not can_queue("self_fast", spell_id, me, QUEUE_FAST_INTERVAL_S) then
        return false
    end
    spell_queue:queue_spell_target_fast(spell_id, me, 1)
    return true
end

-- ─── Logging ─────────────────────────────────────────────────────────────────

function utils.log_debug(menu_module, message)
    if menu_module and menu_module.debug and menu_module.debug:get_state() then
        core.log("[EAX Shaman Restoration] " .. tostring(message))
    end
end

return utils
