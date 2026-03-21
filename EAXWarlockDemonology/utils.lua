-- utils.lua
-- Helper routines for EAX Warlock Demonology.

---@type enums
---@type spell_queue
local spell_queue = require("common/modules/spell_queue")
---@type buff_manager
local buff_manager = require("common/modules/buff_manager")

local utils = {}

-- Spell resolver with persistent caching (see eax_shared/spell_resolver.lua)
local spell_resolver = require("eax_shared/spell_resolver")
local throttle_timestamps = {}
local queue_timestamps = {}
local SPELL_QUEUE_INTERVAL_S = 0.25

local function queue_key(kind, spell_id, target)
    return kind .. ":" .. tostring(spell_id) .. ":" .. tostring(target)
end

-- Delegated to shared spell resolver with persistent cache
function utils.resolve_spell_id(rank_table)
    return spell_resolver.resolve_spell_id(rank_table)
end

function utils.invalidate_spell_cache()
    spell_resolver.invalidate_cache()
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
    
    function utils.same_unit(a, b)
    if not a or not b then return false end
    if a == b then return true end
    if not a.is_valid or not b.is_valid or not a:is_valid() or not b:is_valid() then return false end
    -- GUID comparison is authoritative — two different mobs can share a name
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

return utils.can_cast_target(spell_id, me, target)
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
local AUTO_TARGET_MAX_RANGE = 30.0

function utils.find_best_target(me)
    if not me or not me:is_valid() then return nil end

    local function is_hostile(unit)
        return unit and unit:is_valid() and not unit:is_dead() and me:can_attack(unit)
    end

    local function in_range(unit, max_range)
        local ok1, pos_me = pcall(function() return me:get_position() end)
        local ok2, pos_u  = pcall(function() return unit:get_position() end)
        if not ok1 or not ok2 or not pos_me or not pos_u then return true end
        local dx = pos_me.x - pos_u.x
        local dy = pos_me.y - pos_u.y
        local dz = pos_me.z - pos_u.z
        return (dx*dx + dy*dy + dz*dz) <= (max_range * max_range)
    end

    -- Priority 1: keep current target if it is already a valid hostile
    local current = me:get_target()
    if is_hostile(current) then
        return current
    end

    local objects = core.object_manager.get_all_objects()
    local best_attacking_me    = nil
    local best_attacking_party = nil
    local best_any             = nil

    for i = 1, #objects do
        local obj = objects[i]
        if obj and obj:is_valid() and obj:is_unit() and is_hostile(obj) then
            local obj_target = obj:get_target()

            -- Priority 2: unit actively targeting me (no range cap)
            if obj_target and utils.same_unit(obj_target, me) then
                if not best_attacking_me then
                    best_attacking_me = obj
                end

            -- Priority 3: unit targeting a party member (no range cap)
            elseif obj_target and obj_target:is_valid()
                and obj_target:is_party_member() then
                if not best_attacking_party then
                    best_attacking_party = obj
                end

            -- Priority 4: any hostile within range only
            elseif in_range(obj, AUTO_TARGET_MAX_RANGE) then
                if not best_any then
                    best_any = obj
                end
            end
        end
    end

    return best_attacking_me or best_attacking_party or best_any
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

function utils.get_buff_remaining_ms(unit, id_table)
    if not unit or not id_table then
        return 0
    end
    local data = buff_manager:get_buff_data(unit, id_table)
    if data and data.is_active then
        return data.remaining or 0
    end
    return 0
end

function utils.has_buff(unit, id_table)
    if not unit or not id_table then
        return false
    end
    local data = buff_manager:get_buff_data(unit, id_table)
    return data ~= nil
end

function utils.get_mana_pct(unit)
    if not unit then
        return 0
    end
    local current = unit:get_power(0) or 0
    local maximum = unit:get_max_power(0) or 1
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
        core.log("[EAX Warlock Demonology] " .. message)
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
    ["Voidheart"] = {
        items = { 29024, 29025, 29026, 29027, 29028 },
        bonuses = { ["2"] = 1.05, ["4"] = 1.10 }
    },
    ["VoidheartRegalia"] = {
        items = { 30111, 30112, 30113, 30114, 30115 },
        bonuses = { ["2"] = 1.05, ["4"] = 1.10 }
    },
    ["Malefic"] = {
        items = { 30923, 30924, 30925, 30926, 30927 },
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
