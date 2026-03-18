-- EAX Druid Restoration | utils.lua
-- Shared helpers validated against documented Project Sylvanas APIs.

---@type enums
---@type spell_queue
local spell_queue = require("common/modules/spell_queue")
---@type buff_manager
local buff_manager = require("common/modules/buff_manager")

local utils = {}

local throttle_timestamps = {}
local queue_request_timestamps = {}
local SPELL_QUEUE_INTERVAL_S = 0.25
local FAST_SPELL_QUEUE_INTERVAL_S = 0.10

function utils.resolve_spell_id(rank_table)
    if not rank_table then return nil end
    -- Accept a plain spell ID (number) as well as a ranked table
    if type(rank_table) == "number" then
        return core.spell_book.is_spell_learned(rank_table) and rank_table or nil
    end
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


-- Find the best hostile target using priority logic:
-- 1. Current target if it is a valid hostile
-- 2. A hostile unit that is actively targeting ME (attacking me)
-- 3. A hostile unit attacking any party member
-- 4. Any nearby hostile unit
-- Returns nil if no valid target found.
function utils.find_best_target(me)
    if not me or not me:is_valid() then return nil end

    local function is_hostile(unit)
        return unit and unit:is_valid() and not unit:is_dead() and me:can_attack(unit)
    end

    -- Priority 1: keep current target if it is already a valid hostile
    local current = me:get_target()
    if is_hostile(current) then
        return current
    end

    local objects = core.object_manager.get_all_objects()
    local best_attacking_me   = nil
    local best_attacking_party = nil
    local best_any            = nil

    for i = 1, #objects do
        local obj = objects[i]
        if obj and obj:is_valid() and obj:is_unit() and is_hostile(obj) then
            local obj_target = obj:get_target()

            -- Priority 2: unit actively targeting me
            if obj_target and utils.same_unit(obj_target, me) then
                if not best_attacking_me then
                    best_attacking_me = obj
                end

            -- Priority 3: unit targeting a party member
            elseif obj_target and obj_target:is_valid()
                and obj_target:is_party_member() then
                if not best_attacking_party then
                    best_attacking_party = obj
                end

            -- Priority 4: any hostile (fallback)
            else
                if not best_any then
                    best_any = obj
                end
            end
        end
    end

    return best_attacking_me or best_attacking_party or best_any
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

function utils.can_cast_unit(spell_id, me, target)
    if utils.same_unit(me, target) then
        return utils.can_cast_self(spell_id, me)
    end
    return utils.can_cast_target(spell_id, me, target)
end

function utils.cast_unit(spell_id, me, target)
    if utils.same_unit(me, target) then
        return utils.cast_self(spell_id, me)
    end
    return utils.cast_target(spell_id, target)
end

function utils.get_health_pct(unit)
    if not unit or not unit:is_valid() then return 1.0 end
    local max_hp = unit:get_max_health()
    if max_hp <= 0 then return 1.0 end
    return unit:get_health() / max_hp
end

function utils.get_mana_pct(unit)
    if not unit or not unit:is_valid() then return 0 end
    local max_mana = unit:get_max_power(0)
    if max_mana <= 0 then return 0 end
    return unit:get_power(0) / max_mana
end

function utils.get_buff_data(unit, id_table)
    if not unit or not unit:is_valid() or not id_table then return nil end
    return buff_manager:get_buff_data(unit, id_table)
end

function utils.has_buff(unit, id_table)
    local data = utils.get_buff_data(unit, id_table)
    return data ~= nil and data.is_active or false
end

function utils.get_buff_remaining_ms(unit, id_table)
    local data = utils.get_buff_data(unit, id_table)
    if data and data.is_active then
        return data.remaining or 0
    end
    return 0
end

function utils.get_buff_stacks(unit, id_table)
    local data = utils.get_buff_data(unit, id_table)
    if data and data.is_active then
        return data.stacks or 0
    end
    return 0
end

function utils.get_group_units(me, include_self)
    local units = {}
    local seen = {}

    local function push(unit)
        if not unit or not unit:is_valid() or unit:is_dead() then return end
        local key = unit.get_name and unit:get_name() or tostring(unit)
        if seen[key] then return end
        seen[key] = true
        units[#units + 1] = unit
    end

    if include_self and me and me:is_valid() then
        push(me)
    end

    local objects = core.object_manager.get_all_objects()
    for i = 1, #objects do
        local obj = objects[i]
        if obj
            and obj:is_valid()
            and obj:is_unit()
            and not obj:is_dead()
            and obj:is_party_member()
        then
            push(obj)
        end
    end

    return units
end

function utils.get_lowest_health_unit(units)
    local best = nil
    local best_pct = math.huge
    for i = 1, #units do
        local unit = units[i]
        local hp_pct = utils.get_health_pct(unit)
        if hp_pct < best_pct then
            best = unit
            best_pct = hp_pct
        end
    end
    return best, best_pct == math.huge and 1.0 or best_pct
end

function utils.count_injured_units(units, hp_threshold)
    local count = 0
    for i = 1, #units do
        if utils.get_health_pct(units[i]) <= hp_threshold then
            count = count + 1
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
        core.log("[EAX Druid Restoration] " .. msg)
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
    ["Nordrassil"] = {
        items = { 29085, 29086, 29087, 29088, 29089 },
        bonuses = { ["2"] = 1.05, ["4"] = 1.10 }
    },
    ["NordrassilHarness"] = {
        items = { 30219, 30220, 30221, 30222, 30223 },
        bonuses = { ["2"] = 1.05, ["4"] = 1.10 }
    },
    ["Malorne"] = {
        items = { 30883, 30884, 30885, 30886, 30887 },
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
