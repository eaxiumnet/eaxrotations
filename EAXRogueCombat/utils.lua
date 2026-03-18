-- EAX Rogue Combat | utils.lua

---@type spell_helper
local spell_helper = require("common/utility/spell_helper")
---@type spell_queue
local spell_queue = require("common/modules/spell_queue")
---@type buff_manager
local buff_manager = require("common/modules/buff_manager")

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

function utils.get_buff_remaining_ms(unit, ids)
    if not unit or not unit:is_valid() then
        return 0
    end

    local data = buff_manager:get_buff_data(unit, ids)
    if data and data.is_active then
        return data.remaining or data.remaining_time or 0
    end

    return 0
end

function utils.get_debuff_remaining_ms(unit, ids)
    if not unit or not unit:is_valid() then
        return 0
    end

    local data = buff_manager:get_debuff_data(unit, ids)
    if data and data.is_active then
        return data.remaining or data.remaining_time or 0
    end

    return 0
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

function utils.enemy_count_in_radius(me, radius)
    if not me or not me:is_valid() then
        return 0
    end

    local my_pos = me:get_position()
    local objects = core.object_manager.get_all_objects()
    local count = 0

    for i = 1, #objects do
        local obj = objects[i]
        if obj and obj:is_valid() and obj:is_unit() and not obj:is_dead() and me:can_attack(obj) then
            local threshold = radius + (obj:get_bounding_radius() or 0)
            local sq_dist = my_pos:squared_dist_to_ignore_z(obj:get_position())
            if sq_dist <= (threshold * threshold) then
                count = count + 1
            end
        end
    end

    return count
end

function utils.log_debug(menu, message)
    if menu.debug:get_state() then
        core.log("[EAX Rogue Combat] " .. message)
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
    ["Deathmantle"] = {
        items = { 29036, 29037, 29038, 29039, 29040 },
        bonuses = { ["2"] = 1.05, ["4"] = 1.10 }
    },
    ["DeathmantleBattlegear"] = {
        items = { 30156, 30157, 30158, 29140, 30159 },
        bonuses = { ["2"] = 1.05, ["4"] = 1.10 }
    },
    ["Terror"] = {
        items = { 31074, 31075, 31076, 31077, 31078 },
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
