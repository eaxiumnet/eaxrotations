-- EAX Paladin Retribution | utils.lua
-- Helper utilities used by the retri rotation.

local auto_attack = require("common/utility/auto_attack_helper")
local spell_queue = require("common/modules/spell_queue")
---@type buff_manager
local buff_manager = require("common/modules/buff_manager")

local utils = {}

-- Spell resolver with persistent caching (see eax_shared/spell_resolver.lua)
local spell_resolver = require("eax_shared/spell_resolver")

local queue_request_timestamps = {}
local throttle_timestamps = {}
local SPELL_QUEUE_INTERVAL_S = 0.25

local function can_issue_queue_request(kind, spell_id, target_key, interval)
    local key = kind .. ":" .. tostring(spell_id) .. ":" .. tostring(target_key)
    local now = core.time()
    local last = queue_request_timestamps[key] or 0
    if (now - last) < interval then
        return false
    end
    queue_request_timestamps[key] = now
    return true
end

-- Delegated to shared spell resolver with persistent cache
function utils.resolve_spell_id(rank_table)
    return spell_resolver.resolve_spell_id(rank_table)
end

function utils.invalidate_spell_cache()
    spell_resolver.invalidate_cache()
end

function utils.cast_target(spell_id, target)
    if not spell_id or not target or not target:is_valid() then
        return false
    end
    if not can_issue_queue_request("cast_target", spell_id, target, SPELL_QUEUE_INTERVAL_S) then
        return false
    end

    spell_queue:queue_spell_target(spell_id, target, 1)
    return true
end

function utils.cast_self(spell_id, me)
    if not spell_id or not me then
        return false
    end
    if not can_issue_queue_request("cast_self", spell_id, me, SPELL_QUEUE_INTERVAL_S) then
        return false
    end

    spell_queue:queue_spell_target(spell_id, me, 1)
    return true
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
    if menu_ref and menu_ref.debug and menu_ref.debug:get_state() then
        core.log("[EAX Paladin Retribution] " .. msg)
    end
end

function utils.get_next_swing_ms(me)
    if not me then
        return math.huge
    end
    local next_attack_time = auto_attack:get_next_attack_game_time(me, 1)
    if not next_attack_time or next_attack_time <= 0 then
        return math.huge
    end
    local remaining = next_attack_time - core.game_time()
    if remaining < 0 then
        return 0
    end
    return remaining
end

function utils.is_melee_target(me, target)
    if not me or not target or not target:is_valid() or target:is_dead() then
        return false
    end
    local my_pos = me:get_position()
    local target_pos = target:get_position()
    if not my_pos or not target_pos then
        return false
    end
    local reach = (me:get_combat_reach() or 0) + (target:get_combat_reach() or 0) + 1.0
    local sq_dist = my_pos:squared_dist_to_ignore_z(target_pos)
    return sq_dist <= (reach * reach)
end

function utils.ensure_melee_auto_attack(me, target)
    if not me or not target or not target:is_valid() or target:is_dead() then
        return false
    end
    if auto_attack:is_auto_attacking(target) then
        return true
    end
    if not utils.throttle("paladin:ensure_auto_attack", 0.30) then
        return false
    end
    return auto_attack:start_attack(target, auto_attack.ATTACK_TYPE.MELEE)
end

function utils.has_buff(unit, id_table)
    if not unit or not id_table then
        return false
    end
    local data = buff_manager:get_buff_data(unit, id_table)
    return data ~= nil and data.is_active
end

function utils.has_debuff(unit, id_table)
    if not unit or not id_table then
        return false
    end
    local data = buff_manager:get_debuff_data(unit, id_table)
    if data and data.is_active then return true end
    data = buff_manager:get_aura_data(unit, id_table)
    return data ~= nil and data.is_active
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
local MODE_DETECT_INTERVAL_S = 5.0
local AUTO_TARGET_MAX_RANGE = 40.0
local AUTO_TARGET_MAX_HOSTILES = 50
local mode_cache = "solo"
local mode_cache_refreshed_at = 0

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

    local objects = core.object_manager.get_all_objects()
    local best_attacking_party = nil
    local best_any = nil
    local hostile_scanned = 0

    for i = 1, #objects do
        local obj = objects[i]
        if obj and obj:is_valid() and obj:is_unit() and is_hostile(obj) and in_range(obj, AUTO_TARGET_MAX_RANGE) then
            hostile_scanned = hostile_scanned + 1

            local obj_target = obj:get_target()
            if obj_target and utils.same_unit(obj_target, me) then
                return obj
            end

            if not best_attacking_party and obj_target and obj_target:is_valid() and obj_target:is_party_member() then
                best_attacking_party = obj
            elseif not best_any then
                best_any = obj
            end

            if hostile_scanned >= AUTO_TARGET_MAX_HOSTILES then
                break
            end
        end
    end

    return best_attacking_party or best_any
end



return utils
