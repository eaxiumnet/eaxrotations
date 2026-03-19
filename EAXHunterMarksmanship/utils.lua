local utils = {}

---@type spell_queue
local spell_queue = require("common/modules/spell_queue")
---@type buff_manager
local buff_manager = require("common/modules/buff_manager")

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
    -- Accept a plain spell ID (number) as well as a ranked table
    if type(rank_table) == "number" then
        return core.spell_book.is_spell_learned(rank_table) and rank_table or nil
    end
    for i = 1, #rank_table do
        local spell_id = rank_table[i]
        if spell_id and core.spell_book.is_spell_learned(spell_id) then
            return spell_id
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

--- Can the player cast an OFFENSIVE spell on target right now?
--- Extends can_cast_target with a hostility check (me:can_attack) and
--- a self-cast guard so damage spells never fire on friendly units.
---@param spell_id number|nil
---@param me game_object
---@param target game_object
---@return boolean
function utils.same_unit(a, b)
    if not a or not b then return false end
    if a == b then return true end
    if not a.is_valid or not b.is_valid or not a:is_valid() or not b:is_valid() then return false end
    local function safe_guid(u)
        if type(u.get_guid) ~= "function" then return nil end
        local ok, g = pcall(function() return u:get_guid() end)
        return (ok and g ~= nil) and tostring(g) or nil
    end
    local ga, gb = safe_guid(a), safe_guid(b)
    if ga and gb then return ga == gb end
    local a_player = type(a.is_player) == "function" and a:is_player()
    local b_player = type(b.is_player) == "function" and b:is_player()
    if a_player and b_player then
        local a_name = a:get_name() or ""
        local b_name = b:get_name() or ""
        return a_name ~= "" and a_name == b_name
    end
    return false
end

function utils.can_cast_hostile(spell_id, me, target)
    if not me or not target then return false end
    if utils.same_unit(me, target) then return false end
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



function utils.has_debuff(unit, debuff_table)
    if not unit or not unit:is_valid() or not debuff_table then return false end
    -- Try debuff first, fall back to aura (covers all unit types including dummies)
    local data = buff_manager:get_debuff_data(unit, debuff_table)
    if data and data.is_active then return true end
    data = buff_manager:get_aura_data(unit, debuff_table)
    return data ~= nil and data.is_active
end

function utils.has_buff(unit, buff_table)
    if not unit or not unit:is_valid() or not buff_table then
        return false
    end
    -- Use game_object API directly: check buff slot then aura slot
    local entry = unit:get_buff_data(buff_table)
    if entry and entry.is_active then return true end
    entry = unit:get_aura_data(buff_table)
    return entry ~= nil and entry.is_active == true
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
    if not spell_id or not me or not me:is_valid() then
        return false
    end
    if not can_issue_queue_request("spell_target", spell_id, me, SPELL_QUEUE_INTERVAL_S) then
        return false
    end
    spell_queue:queue_spell_target(spell_id, me, 1)
    return true
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
    ["Cryptstalker"] = {
        items = { 29055, 29056, 29057, 29058, 29059 },
        bonuses = { ["2"] = 1.05, ["4"] = 1.10 }
    },
    ["CryptstalkerBattlegear"] = {
        items = { 30103, 30104, 30105, 30106, 30107 },
        bonuses = { ["2"] = 1.05, ["4"] = 1.10 }
    },
    ["CryptstalkerVindication"] = {
        items = { 30914, 30915, 30916, 30917, 30918 },
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
