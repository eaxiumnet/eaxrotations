-- EAX Mage Arcane | utils.lua

---@type enums
---@type spell_queue
local spell_queue = require("common/modules/spell_queue")
---@type buff_manager
local buff_manager = require("common/modules/buff_manager")

local utils = {}

local INVENTORY_SLOT_TRINKET_1 = 13
local INVENTORY_SLOT_TRINKET_2 = 14
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

function utils.throttle(key, interval_s)
    local now = core.time()
    local last = throttle_timestamps[key] or 0
    if (now - last) >= interval_s then
        throttle_timestamps[key] = now
        return true
    end
    return false
end

function utils.get_mana_pct(unit)
    if not unit or not unit:is_valid() then return 0 end
    local max_mana = unit:get_max_power(0)
    if max_mana <= 0 then return 0 end
    return (unit:get_power(0) / max_mana) * 100
end

function utils.get_health_pct(unit)
    if not unit or not unit:is_valid() then return 0 end
    local max_hp = unit:get_max_health()
    if max_hp <= 0 then return 0 end
    return (unit:get_health() / max_hp) * 100
end

function utils.has_buff(unit, id_table)
    if not unit or not unit:is_valid() then return false end
    local data = buff_manager:get_buff_data(unit, id_table)
    return data ~= nil and data.is_active
end

function utils.has_debuff(unit, id_table)
    if not unit or not unit:is_valid() then return false end
    local data = buff_manager:get_debuff_data(unit, id_table)
    if data and data.is_active then return true end
    data = buff_manager:get_aura_data(unit, id_table)
    return data ~= nil and data.is_active
end

function utils.get_buff_remaining_ms(unit, id_table)
    if not unit or not unit:is_valid() then return 0 end
    local data = buff_manager:get_buff_data(unit, id_table)
    if data and data.is_active then
        return data.remaining or 0
    end
    return 0
end

function utils.get_debuff_remaining_ms(unit, id_table)
    if not unit or not unit:is_valid() then return 0 end
    local data = buff_manager:get_debuff_data(unit, id_table)
    if data and data.is_active then
        return data.remaining or 0
    end
    return 0
end

function utils.get_buff_stacks(unit, id_table)
    if not unit or not unit:is_valid() then return 0 end
    local data = buff_manager:get_buff_data(unit, id_table)
    if data and data.is_active then
        return data.stacks or data.count or 0
    end
    return 0
end

function utils.get_debuff_stacks(unit, id_table)
    if not unit or not unit:is_valid() then return 0 end
    local data = buff_manager:get_debuff_data(unit, id_table)
    if data and data.is_active then
        return data.stacks or data.count or 0
    end
    return 0
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

function utils.cast_target(spell_id, target, message)
    if not spell_id or not target or not target:is_valid() then return false end
    if not core.spell_book.is_spell_learned(spell_id) then return false end
    if core.spell_book.get_spell_cooldown(spell_id) > 0 then return false end
    if not can_issue_queue_request("spell_target", spell_id, target, SPELL_QUEUE_INTERVAL_S) then return false end
    spell_queue:queue_spell_target(spell_id, target, 1, message)
    return true
end

function utils.cast_self(spell_id, me, message)
    if not spell_id or not me then return false end
    if not can_issue_queue_request("spell_self", spell_id, me, SPELL_QUEUE_INTERVAL_S) then return false end
    spell_queue:queue_spell_target(spell_id, me, 1, message)
    return true
end

function utils.cast_target_fast(spell_id, target, message)
    if not spell_id or not target or not target:is_valid() then return false end
    if not can_issue_queue_request("spell_target_fast", spell_id, target, FAST_SPELL_QUEUE_INTERVAL_S) then return false end
    spell_queue:queue_spell_target_fast(spell_id, target, 1, message)
    return true
end

function utils.cast_self_fast(spell_id, me, message)
    if not spell_id or not me then return false end
    if not can_issue_queue_request("spell_self_fast", spell_id, me, FAST_SPELL_QUEUE_INTERVAL_S) then return false end
    spell_queue:queue_spell_target_fast(spell_id, me, 1, message)
    return true
end

function utils.is_spell_already_queued(spell_id)
    if not spell_id then return false end
    return core.spell_book.is_current_spell(spell_id)
end

function utils.get_equipped_item_id_in_slot(me, slot_id)
    if not me then return nil end
    local slot_info = me:get_item_at_inventory_slot(slot_id)
    if not slot_info or not slot_info.object then return nil end
    local item = slot_info.object
    if item.is_valid and not item:is_valid() then return nil end
    local item_id = item:get_item_id()
    if item_id and item_id > 0 then
        return item_id
    end
    return nil
end

function utils.get_self_cast_trinket_ids(me)
    local ready = {}
    local slots = { INVENTORY_SLOT_TRINKET_1, INVENTORY_SLOT_TRINKET_2 }
    for i = 1, #slots do
        local slot_id = slots[i]
        local item_id = utils.get_equipped_item_id_in_slot(me, slot_id)
        if item_id and core.spell_book.is_item_usable(item_id) and not core.spell_book.has_item_range(item_id) then
            ready[#ready + 1] = { slot_id = slot_id, item_id = item_id }
        end
    end
    return ready
end

function utils.use_item_if_ready(item_id)
    if not item_id then return false end
    if not core.spell_book.is_item_usable(item_id) then return false end
    if core.spell_book.has_item_range(item_id) then return false end
    return core.input.use_item(item_id)
end

function utils.use_consumable_if_ready(me, item_id)
    if not me or not item_id then return false end
    if not me:has_item(item_id) then return false end
    if me:get_item_cooldown(item_id) > 0 then return false end
    if not core.spell_book.is_item_usable(item_id) then return false end
    return core.input.use_item(item_id)
end

function utils.log_debug(menu, message)
    if menu.debug:get_state() then
        core.log("[EAX Mage Arcane] " .. message)
    end
end

local INVENTORY_SLOT_HEAD = 0
local INVENTORY_SLOT_NECK = 1
local INVENTORY_SLOT_SHOULDER = 2
local INVENTORY_SLOT_CHEST = 4
local INVENTORY_SLOT_WAIST = 5
local INVENTORY_SLOT_LEGS = 6
local INVENTORY_SLOT_FEET = 7
local INVENTORY_SLOT_WRIST = 8
local INVENTORY_SLOT_HAND = 9
local INVENTORY_SLOT_FINGER = 10
local INVENTORY_SLOT_TRINKET_1 = 12
local INVENTORY_SLOT_TRINKET_2 = 13
local INVENTORY_SLOT_BACK = 14
local INVENTORY_SLOT_MAINHAND = 15
local INVENTORY_SLOT_OFFHAND = 16
local INVENTORY_SLOT_RANGED = 18

local ALL_EQUIP_SLOTS = {
    INVENTORY_SLOT_HEAD, INVENTORY_SLOT_NECK, INVENTORY_SLOT_SHOULDER,
    INVENTORY_SLOT_CHEST, INVENTORY_SLOT_WAIST, INVENTORY_SLOT_LEGS,
    INVENTORY_SLOT_FEET, INVENTORY_SLOT_WRIST, INVENTORY_SLOT_HAND,
    INVENTORY_SLOT_FINGER, INVENTORY_SLOT_TRINKET_1, INVENTORY_SLOT_TRINKET_2,
    INVENTORY_SLOT_BACK, INVENTORY_SLOT_MAINHAND, INVENTORY_SLOT_OFFHAND, INVENTORY_SLOT_RANGED
}

local TBC_SETS = {
    ["Aldor"] = {
        items = { 29068, 29069, 29070, 29071, 29072 },
        bonuses = { ["2"] = 1.05, ["4"] = 1.10 }
    },
    ["AldorRegalia"] = {
        items = { 30137, 30138, 30139, 30140, 30141 },
        bonuses = { ["2"] = 1.05, ["4"] = 1.10 }
    },
    ["AldorNethers"] = {
        items = { 30937, 30938, 30939, 30940, 30941 },
        bonuses = { ["2"] = 1.05, ["4"] = 1.10 }
    },
}

local function get_item_id_in_slot(me, slot_id)
    if not me then return nil end
    local ok, slot_info = pcall(function() return me:get_item_at_inventory_slot(slot_id) end)
    if not ok or not slot_info or not slot_info.object then return nil end
    local item = slot_info.object
    if not item or not item.is_valid or not item:is_valid() then return nil end
    local item_id = item.get_item_id and item:get_item_id()
    return item_id
end

local function get_equipped_items(me)
    local items = {}
    for _, slot in ipairs(ALL_EQUIP_SLOTS) do
        local item_id = get_item_id_in_slot(me, slot)
        if item_id and item_id > 0 then
            table.insert(items, item_id)
        end
    end
    return items
end

function utils.get_set_multiplier(me, set_name)
    if not me then return 1.0 end
    local set_def = TBC_SETS[set_name]
    if not set_def or not set_def.items or not set_def.bonuses then
        return 1.0
    end
    local items = get_equipped_items(me)
    local count = 0
    for _, item_id in ipairs(items) do
        for _, set_item_id in ipairs(set_def.items) do
            if item_id == set_item_id then
                count = count + 1
                break
            end
        end
    end
    if count >= 4 and set_def.bonuses["4"] then
        return set_def.bonuses["4"]
    elseif count >= 2 and set_def.bonuses["2"] then
        return set_def.bonuses["2"]
    end
    return 1.0
end

return utils
