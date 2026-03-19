-- EAX Druid Feral | utils.lua
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
    -- Use a stable target identifier (GUID if available, else tostring)
    local target_key = tostring(target)
    if target and type(target) == "table" or type(target) == "userdata" then
        local ok, guid = pcall(function() return target:get_guid() end)
        if ok and guid and guid ~= "" then target_key = tostring(guid) end
    end
    local key = kind .. ":" .. tostring(spell_id) .. ":" .. target_key
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
-- Max range for auto target acquisition.
-- Melee (~5y) + feral charge range (~25y) + small buffer = 30y.
-- Units beyond this are ignored unless they are already targeting us/party.
local AUTO_TARGET_MAX_RANGE = 30.0

function utils.find_best_target(me)
    if not me or not me:is_valid() then return nil end

    local function is_hostile(unit)
        return unit and unit:is_valid() and not unit:is_dead() and me:can_attack(unit)
    end

    local function in_range(unit, max_range)
        local ok, pos_me  = pcall(function() return me:get_position() end)
        local ok2, pos_u  = pcall(function() return unit:get_position() end)
        if not ok or not ok2 or not pos_me or not pos_u then return true end
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

            -- Priority 2: unit actively targeting me (no range cap — if it's hitting us, engage)
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

    return best_attacking_me or best_attacking_party or (me:is_in_combat() and best_any or nil)
end



function utils.can_cast_self(spell_id, me)
    if not spell_id or not me then return false end
    if core.spell_book.get_spell_cooldown(spell_id) > 0 then return false end
    if not core.spell_book.is_usable_spell(spell_id) then return false end
    return true
end

function utils.can_cast_melee(spell_id, me)
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

function utils.cast_target_fast(spell_id, target)
    if not spell_id or not target or not target:is_valid() then return false end
    if not can_issue_queue_request("spell_target_fast", spell_id, target, FAST_SPELL_QUEUE_INTERVAL_S) then return false end
    spell_queue:queue_spell_target_fast(spell_id, target, 1)
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

function utils.get_energy(me)
    return me:get_power(3)
end

function utils.get_rage(me)
    return me:get_power(1)
end

function utils.get_mana_pct(me)
    if not me or not me:is_valid() then return 1.0 end
    local ok, max_mana = pcall(function() return me:get_max_power(0) end)
    if not ok or not max_mana or max_mana <= 0 then return 1.0 end
    local ok2, mana = pcall(function() return me:get_power(0) end)
    if not ok2 or not mana then return 1.0 end
    return mana / max_mana
end

function utils.get_health_pct(unit)
    if not unit or not unit:is_valid() then return 1.0 end
    local max_hp = unit:get_max_health()
    if max_hp <= 0 then return 1.0 end
    return unit:get_health() / max_hp
end

function utils.get_buff_data(unit, id_table)
    if not unit or not unit:is_valid() or not id_table then return nil end
    return buff_manager:get_buff_data(unit, id_table)
end

function utils.get_debuff_data(unit, id_table)
    if not unit or not unit:is_valid() or not id_table then return nil end
    return buff_manager:get_debuff_data(unit, id_table)
end

function utils.has_buff(unit, id_table)
    local data = utils.get_buff_data(unit, id_table)
    return data ~= nil and data.is_active or false
end

-- Prowl can appear as a buff, debuff, or aura depending on the server.
-- This checks all three paths to reliably detect stealth.
function utils.is_prowling(unit, prowl_ids)
    if not unit or not unit:is_valid() then return false end
    -- Check buff path
    local data = buff_manager:get_buff_data(unit, prowl_ids)
    if data and data.is_active then return true end
    -- Check debuff path (some servers register it here)
    data = buff_manager:get_debuff_data(unit, prowl_ids)
    if data and data.is_active then return true end
    -- Check generic aura path
    data = buff_manager:get_aura_data(unit, prowl_ids)
    if data and data.is_active then return true end
    return false
end

-- Returns true if the unit is in cat form OR prowling (prowl = stealthed cat form)
function utils.is_in_cat_form(unit, spells_ref)
    if not unit or not unit:is_valid() then return false end
    -- Check all paths — cat form may register as buff, debuff, or aura
    local ids = spells_ref.BUFF_CAT_FORM
    local data = buff_manager:get_buff_data(unit, ids)
    if data and data.is_active then return true end
    data = buff_manager:get_aura_data(unit, ids)
    if data and data.is_active then return true end
    -- Also count prowl as cat form
    if utils.is_prowling(unit, spells_ref.BUFF_PROWL) then return true end
    return false
end

function utils.has_debuff(unit, id_table)
    if not unit or not unit:is_valid() then return false end
    local data = buff_manager:get_debuff_data(unit, id_table)
    if data and data.is_active then return true end
    data = buff_manager:get_aura_data(unit, id_table)
    return data ~= nil and data.is_active
end

function utils.get_debuff_remaining_ms(unit, id_table)
    local data = utils.get_debuff_data(unit, id_table)
    if data and data.is_active then
        return data.remaining or 0
    end
    return 0
end

function utils.get_debuff_stacks(unit, id_table)
    local data = utils.get_debuff_data(unit, id_table)
    if data and data.is_active then
        return data.stacks or 0
    end
    return 0
end

-- Returns true if a debuff from id_table is active on unit AND was cast by someone
-- other than `me` with at least `min_remaining_ms` left.
-- Used to skip redundant Mangle casts when a party member already has it up.
function utils.debuff_applied_by_other(unit, id_table, me, min_remaining_ms)
    if not unit or not unit:is_valid() then return false end
    local min_ms = min_remaining_ms or 4000
    local ok, cache = pcall(function()
        return buff_manager:get_debuff_cache(unit, 100)
    end)
    if not ok or not cache then return false end
    -- Build a lookup set from id_table
    local id_set = {}
    if type(id_table) == "table" then
        for _, id in ipairs(id_table) do id_set[id] = true end
    elseif type(id_table) == "number" then
        id_set[id_table] = true
    end
    for _, aura in ipairs(cache) do
        if aura.is_active and id_set[aura.buff_id] then
            local remaining = aura.remaining or 0
            if remaining >= min_ms then
                -- Check if caster is someone other than me
                local caster = aura.caster
                if caster and caster:is_valid() then
                    if not utils.same_unit(caster, me) then
                        return true
                    end
                else
                    -- No caster info — assume it's from another player if active
                    return true
                end
            end
        end
    end
    return false
end


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

function utils.target_is_me(target, me)
    if not target or not target:is_valid() or not me then return false end
    local target_target = target:get_target()
    if not target_target or not target_target:is_valid() then return false end
    return utils.same_unit(target_target, me)
end

function utils.enemy_count_in_radius(me, radius)
    if not me or not me:is_valid() then return 0 end
    local my_pos = me:get_position()
    local count = 0
    local objects = core.object_manager.get_all_objects()

    for i = 1, #objects do
        local obj = objects[i]
        if obj
            and obj:is_valid()
            and obj:is_unit()
            and not obj:is_dead()
            and me:can_attack(obj)
        then
            local obj_pos = obj:get_position()
            local threshold = radius + obj:get_bounding_radius()
            local sq_dist = my_pos:squared_dist_to_ignore_z(obj_pos)
            if sq_dist <= (threshold * threshold) then
                count = count + 1
            end
        end
    end

    return count
end

function utils.is_melee_target(me, target)
    if not me or not target or not target:is_valid() then return false end
    local my_pos = me:get_position()
    local target_pos = target:get_position()
    local reach = me:get_combat_reach() + target:get_combat_reach() + 1.0
    local sq_dist = my_pos:squared_dist_to_ignore_z(target_pos)
    return sq_dist <= (reach * reach)
end

-- Returns true when 'me' is positioned behind 'target'.
-- Uses the target's rotation (yaw) from get_rotation() and vec3 dot product.
-- Behind = attacker is in the rear 180-degree arc (dot product with target forward < 0).
-- Falls back to true if rotation data unavailable so Shred is never permanently blocked.
function utils.is_behind_target(me, target)
    if not me or not target or not target:is_valid() then return false end
    local my_pos     = me:get_position()
    local target_pos = target:get_position()
    if not my_pos or not target_pos then return true end
    local ok, rotation = pcall(function() return target:get_rotation() end)
    if not ok or rotation == nil then return true end
    local fwd_x = math.cos(rotation)
    local fwd_y = math.sin(rotation)
    local to_me_x = my_pos.x - target_pos.x
    local to_me_y = my_pos.y - target_pos.y
    return (to_me_x * fwd_x + to_me_y * fwd_y) < 0
end

function utils.get_target_key(target)
    if not target or not target:is_valid() or not target.get_name then return nil end
    return target:get_name()
end

-- Purge all queued copies of a spell from the SpellQueue.
-- Useful after manually marking a spell pending to prevent the queue
-- from retrying it and causing double-casts.
function utils.purge_queued_spell(spell_id, target)
    if not spell_id then return end
    pcall(function()
        spell_queue:purge_by_spell(spell_id, target)
    end)
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
        core.log("[EAX Druid Feral] " .. msg)
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
    -- Caster druid sets
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
    -- Feral / Guardian sets (T4 Malorne Harness, T5 Nordrassil Harness, T6 Thunderheart)
    ["MalorneHarness"] = {
        -- T4 feral: Malorne Harness — 2pc: +5% Mangle damage; 4pc: reduce Mangle CD by 1s
        items = { 29075, 29076, 29077, 29078, 29079 },
        bonuses = { ["2"] = 1.05, ["4"] = 1.10 }
    },
    ["NordrassilBattlegear"] = {
        -- T5 feral: Nordrassil Battlegear — 2pc: +20% Shred damage; 4pc: -0.5s Mangle CD
        items = { 30214, 30215, 30216, 30217, 30218 },
        bonuses = { ["2"] = 1.10, ["4"] = 1.15 }
    },
    ["ThunderhearBattlegear"] = {
        -- T6 feral: Thunderheart Battlegear — 2pc: +6% Rip/Rake dmg; 4pc: Mangle boosts Shred
        items = { 31014, 31015, 31016, 31017, 31018 },
        bonuses = { ["2"] = 1.06, ["4"] = 1.12 }
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
