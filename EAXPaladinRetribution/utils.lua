-- EAX Paladin Retribution | utils.lua
-- Helper utilities used by the retri rotation.

local auto_attack = require("common/utility/auto_attack_helper")
local spell_queue = require("common/modules/spell_queue")
---@type buff_manager
local buff_manager = require("common/modules/buff_manager")

local utils = {}

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



return utils
