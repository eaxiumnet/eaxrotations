-- Eax Rogue Combat | utils.lua

---@type spell_helper
local spell_helper = require("common/utility/spell_helper")
---@type spell_queue
local spell_queue = require("common/modules/spell_queue")
---@type buff_manager
local buff_manager = require("common/modules/buff_manager")

local utils = {}

-- Spell resolver with persistent caching (see ../eax_shared/spell_resolver.lua)
local spell_resolver = require("libraries/spell_resolver")

local throttle_timestamps = {}
local queue_timestamps = {}
local SPELL_QUEUE_INTERVAL_S = 0.25
local FAST_SPELL_QUEUE_INTERVAL_S = 0.10

-- Delegated to shared spell resolver with persistent cache
function utils.resolve_spell_id(rank_table)
    return spell_resolver.resolve_spell_id(rank_table)
end

function utils.invalidate_spell_cache()
    spell_resolver.invalidate_cache()
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


function utils.get_selected_mode(menu)
    local mode_index = menu.mode:get()
    if mode_index == 2 then
        return "solo"
    elseif mode_index == 3 then
        return "dungeon"
    elseif mode_index == 4 then
        return "raid"
    end

    return utils.detect_mode(core.object_manager.get_local_player())
end

-- Find the best hostile target using priority logic:
-- 1. Current target if it is a valid hostile
-- 2. A hostile unit that is actively targeting ME (attacking me)
-- 3. A hostile unit attacking any party member
-- 4. Any nearby hostile unit
-- Returns nil if no valid target found.
-- Max range for auto target acquisition.
-- Covers melee + max gap-closer range. Units beyond this are ignored
-- unless they are actively attacking us or party.
local MODE_DETECT_INTERVAL_S = 10.0
local AUTO_TARGET_MAX_RANGE = 40.0
local AUTO_TARGET_MAX_HOSTILES = 50
local mode_cache = "solo"
local mode_cache_refreshed_at = 0
local hostile_scan_cache_at = -1
local hostile_scan_cache_me = nil
local hostile_scan_cache_units = nil

function utils.detect_mode(me)
    local now = core.time()
    if mode_cache_refreshed_at > 0 and (now - mode_cache_refreshed_at) < MODE_DETECT_INTERVAL_S then
        return mode_cache
    end

    me = me or core.object_manager.get_local_player()
    local party_count = 0
    local objects = core.object_manager.get_all_objects()

    for i = 1, #objects do
        local obj = objects[i]
        if obj and obj:is_valid() and obj:is_unit() and not obj:is_dead() then
            local is_group_member = false

            if utils.is_group_member then
                is_group_member = utils.is_group_member(me, obj)
            elseif obj:is_party_member() then
                is_group_member = not (me and utils.same_unit and utils.same_unit(me, obj))
            end

            if is_group_member then
                party_count = party_count + 1
            end
        end
    end

    if party_count == 0 then
        mode_cache = "solo"
    elseif party_count <= 4 then
        mode_cache = "dungeon"
    else
        mode_cache = "raid"
    end

    mode_cache_refreshed_at = now
    return mode_cache
end

function utils.find_best_target(me)
    if not me or not me:is_valid() then return nil end

    local function is_hostile(unit)
        return unit and unit:is_valid() and not unit:is_dead() and me:can_attack(unit)
    end

    local current = me:get_target()
    if is_hostile(current) then
        return current
    end

    if not me:is_in_combat() then
        return nil
    end

    local pos_me = nil
    do
        local ok, value = pcall(function() return me:get_position() end)
        if ok then
            pos_me = value
        end
    end

    local function in_range(unit, max_range)
        if not pos_me then return true end

        local ok, pos_u = pcall(function() return unit:get_position() end)
        if not ok or not pos_u then return true end

        local dx = pos_me.x - pos_u.x
        local dy = pos_me.y - pos_u.y
        local dz = pos_me.z - pos_u.z
        return (dx * dx + dy * dy + dz * dz) <= (max_range * max_range)
    end

    local now = core.time()
    local hostile_units
    if hostile_scan_cache_at == now and hostile_scan_cache_me == me and hostile_scan_cache_units then
        hostile_units = hostile_scan_cache_units
    else
        hostile_units = {}
        local objects = core.object_manager.get_all_objects()
        local hostile_scanned = 0
        for i = 1, #objects do
            local obj = objects[i]
            if obj and obj:is_valid() and obj:is_unit() and is_hostile(obj) and in_range(obj, AUTO_TARGET_MAX_RANGE) then
                hostile_scanned = hostile_scanned + 1
                hostile_units[#hostile_units + 1] = obj
                if hostile_scanned >= AUTO_TARGET_MAX_HOSTILES then
                    break
                end
            end
        end
        hostile_scan_cache_at = now
        hostile_scan_cache_me = me
        hostile_scan_cache_units = hostile_units
    end

    local best_attacking_party = nil
    local best_any = nil

    for i = 1, #hostile_units do
        local obj = hostile_units[i]
        local obj_target = obj:get_target()
        if obj_target and utils.same_unit(obj_target, me) then
            return obj
        end

        if not best_attacking_party and obj_target and obj_target:is_valid() and obj_target:is_party_member() then
            best_attacking_party = obj
        elseif not best_any then
            best_any = obj
        end
    end

    return best_attacking_party or best_any
end

function utils.same_unit(a, b)
    if not a or not b then return false end
    if a == b then return true end
    if not a.is_valid or not b.is_valid or not a:is_valid() or not b:is_valid() then return false end
    -- GUID comparison is authoritative - two different mobs can share a name
    local function safe_guid(u)
        if type(u.get_guid) ~= "function" then return nil end
        local ok, g = pcall(function() return u:get_guid() end)
        return (ok and g ~= nil) and tostring(g) or nil
    end
    local ga, gb = safe_guid(a), safe_guid(b)
    if ga and gb then return ga == gb end
    -- Fallback: name match only for players (NPCs commonly share names)
    local a_player = type(a.is_player) == "function" and a:is_player()
    local b_player = type(b.is_player) == "function" and b:is_player()
    if a_player and b_player then
        local a_name = a:get_name() or ""
        local b_name = b:get_name() or ""
        return a_name ~= "" and a_name == b_name
    end
    return false
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

    return spell_helper:is_spell_castable(spell_id, me, target, true, false)
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
    local same_unit = utils.same_unit or function(a, b) return a == b end
    -- Never cast damage spells on self
    if same_unit(me, target) then return false end
    -- Target must be attackable by the player (fails for friendlies, self, neutral)
    if not me:can_attack(target) then return false end
    return utils.can_cast_target(spell_id, me, target)
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

function utils.has_buff(unit, id_table)
    if not unit or not unit:is_valid() or not id_table then
        return false
    end
    local data = buff_manager:get_buff_data(unit, id_table)
    return data ~= nil and data.is_active == true
end

function utils.has_debuff(unit, id_table)
    if not unit or not unit:is_valid() or not id_table then
        return false
    end
    local data = buff_manager:get_debuff_data(unit, id_table)
    return data ~= nil and data.is_active == true
end

function utils.is_melee_target(me, target)
    if not me or not target then return false end
    if not me:is_valid() or not target:is_valid() or target:is_dead() then return false end
    local me_pos = me:get_position()
    local target_pos = target:get_position()
    if not me_pos or not target_pos then return false end
    local threshold = 5 + (target:get_bounding_radius() or 0)
    return me_pos:dist_to(target_pos) <= threshold
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
        core.log("[Eax Rogue Combat] " .. message)
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
local INVENTORY_SLOT_MAINHAND = 16
local INVENTORY_SLOT_OFFHAND = 17
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
