-- Eax Paladin Retribution | utils.lua
-- Helpers validated against documented Sylvanas APIs.

---@type auto_attack_helper
local auto_attack = require("common/utility/auto_attack_helper")
---@type spell_queue
local spell_queue = require("common/modules/spell_queue")
---@type buff_manager
local buff_manager = require("common/modules/buff_manager")

local utils = {}

-- Spell resolver with persistent caching (see spell_resolver.lua)
local spell_resolver = require("libraries/spell_resolver")

local queue_request_timestamps = {}
local throttle_timestamps = {}
local SPELL_QUEUE_INTERVAL_S = 0.25
local FAST_SPELL_QUEUE_INTERVAL_S = 0.10

function utils.same_unit(a, b)
    if not a or not b then return false end
    if a == b then return true end

    local a_is_player = type(a.is_player) == "function" and a:is_player()
    local b_is_player = type(b.is_player) == "function" and b:is_player()
    if a_is_player and b_is_player then
        local a_name = type(a.get_name) == "function" and (a:get_name() or "") or ""
        local b_name = type(b.get_name) == "function" and (b:get_name() or "") or ""
        return a_name ~= "" and a_name == b_name
    end

    return false
end

local function can_issue_queue_request(kind, spell_id, target_key, interval_s)
    local key = kind .. ":" .. tostring(spell_id) .. ":" .. tostring(target_key)
    local now = core.time()
    local last = queue_request_timestamps[key] or 0
    if (now - last) < interval_s then
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

function utils.is_known_spell(spell_id)
    return spell_id ~= nil and core.spell_book.is_spell_learned(spell_id)
end

function utils.can_cast_target(spell_id, me, target)
    if not spell_id or not me or not target or not target:is_valid() then
        return false
    end
    if not utils.is_known_spell(spell_id) then
        return false
    end
    if core.spell_book.get_spell_cooldown(spell_id) > 0 then return false end
    if not core.spell_book.is_usable_spell(spell_id) then return false end
    if not core.spell_book.is_spell_in_range(spell_id, target, me) then return false end
    return true
end

--- Can the player cast an offensive spell on target right now?
---@param spell_id number|nil
---@param me game_object
---@param target game_object
---@return boolean
function utils.can_cast_hostile(spell_id, me, target)
    if not me or not target then return false end
    if utils.same_unit(me, target) then return false end
    if not me:can_attack(target) then return false end
    return utils.can_cast_target(spell_id, me, target)
end

function utils.can_cast_self(spell_id, me)
    if not spell_id or not me then return false end
    if not utils.is_known_spell(spell_id) then
        return false
    end
    if core.spell_book.get_spell_cooldown(spell_id) > 0 then return false end
    if not core.spell_book.is_usable_spell(spell_id) then return false end
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

function utils.cast_self(spell_id, me)
    if not utils.can_cast_self(spell_id, me) then return false end
    if not can_issue_queue_request("spell_self", spell_id, me, SPELL_QUEUE_INTERVAL_S) then
        return false
    end
    spell_queue:queue_spell_target(spell_id, me, 1)
    return true
end

function utils.cast_self_fast(spell_id, me)
    if not utils.can_cast_self(spell_id, me) then return false end
    if not can_issue_queue_request("spell_self_fast", spell_id, me, FAST_SPELL_QUEUE_INTERVAL_S) then
        return false
    end
    spell_queue:queue_spell_target_fast(spell_id, me, 1)
    return true
end

function utils.cast_unit(spell_id, me, unit)
    if not spell_id or not me or not unit or not unit:is_valid() or unit:is_dead() then
        return false
    end
    if not can_issue_queue_request("spell_unit", spell_id, unit, SPELL_QUEUE_INTERVAL_S) then
        return false
    end
    spell_queue:queue_spell_target(spell_id, unit, 1)
    return true
end

function utils.get_health_pct(unit)
    if not unit or not unit:is_valid() then return 0 end
    local ok, pct = pcall(function()
        local max_health = unit:get_max_health()
        if max_health <= 0 then return 0 end
        return unit:get_health() / max_health
    end)
    return (ok and type(pct) == "number") and math.max(0, math.min(1, pct)) or 0
end

function utils.get_mana_pct(me)
    if not me or not me:is_valid() then return 1.0 end
    local ok, pct = pcall(function()
        local max_mana = me:get_max_power(0)
        if max_mana <= 0 then return 1.0 end
        return me:get_power(0) / max_mana
    end)
    return (ok and type(pct) == "number") and math.max(0, math.min(1, pct)) or 1.0
end

function utils.has_buff(unit, id_table)
    if not unit or not id_table then return false end
    local data = buff_manager:get_buff_data(unit, id_table)
    return data ~= nil and data.is_active
end

function utils.has_debuff(unit, id_table)
    if not unit or not id_table then return false end
    local data = buff_manager:get_debuff_data(unit, id_table)
    if data and data.is_active then return true end
    data = buff_manager:get_aura_data(unit, id_table)
    return data ~= nil and data.is_active
end

function utils.get_buff_remaining_ms(unit, id_table)
    if not unit or not unit:is_valid() or not id_table then return 0 end
    local data = buff_manager:get_buff_data(unit, id_table)
    if data and data.is_active then
        return data.remaining_time or 0
    end
    return 0
end

function utils.is_valid_hostile_target(me, target)
    return target
        and target:is_valid()
        and not target:is_dead()
        and me:can_attack(target)
end

function utils.count_enemies_within_radius(me, radius)
    if not me or not radius or radius <= 0 then
        return 0
    end

    local center_pos = me:get_position()
    local count = 0
    local objects = core.object_manager.get_visible_objects()

    for i = 1, #objects do
        local obj = objects[i]
        if utils.is_valid_hostile_target(me, obj) and obj:is_in_combat() then
            local obj_pos = obj:get_position()
            local threshold = radius + (obj:get_bounding_radius() or 0)
            local sq_dist = center_pos:squared_dist_to_ignore_z(obj_pos)
            if sq_dist <= (threshold * threshold) then
                count = count + 1
            end
        end
    end

    return count
end

function utils.enemy_count_in_radius(me, radius)
    return utils.count_enemies_within_radius(me, radius)
end

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
                is_group_member = not utils.same_unit(me, obj)
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
        if me:is_in_combat() then
            return current
        end
        return nil
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

function utils.get_next_swing_ms(me, weapon_count)
    if not me then
        return math.huge
    end

    local next_attack_time = auto_attack:get_next_attack_game_time(me, weapon_count or 1)
    if not next_attack_time or next_attack_time <= 0 then
        return math.huge
    end

    local remaining = next_attack_time - core.game_time()
    if remaining < 0 then
        return 0
    end

    return remaining
end

function utils.is_next_swing_within_ms(me, window_ms, floor_ms, weapon_count)
    local remaining = utils.get_next_swing_ms(me, weapon_count)
    if remaining == math.huge then
        return false
    end
    if floor_ms and remaining <= floor_ms then
        return false
    end
    return remaining <= window_ms
end

function utils.get_gcd_value_ms()
    local gcd_value = auto_attack:get_global_value_game_time()
    if not gcd_value or gcd_value <= 0 then
        return 1500
    end
    return gcd_value
end

function utils.get_gcd_remaining_ms()
    local next_global_time = auto_attack:get_next_global_game_time()
    if not next_global_time or next_global_time <= 0 then
        return 0
    end

    local remaining = next_global_time - core.game_time()
    if remaining < 0 then
        return 0
    end

    return remaining
end

function utils.would_new_gcd_cross_swing_window(me, window_ms, input_delay_ms)
    local next_swing_ms = utils.get_next_swing_ms(me)
    if next_swing_ms == math.huge then
        return false
    end

    local floor_ms = input_delay_ms or 0
    if next_swing_ms <= floor_ms then
        return true
    end

    return next_swing_ms <= (window_ms + utils.get_gcd_value_ms() + floor_ms)
end

function utils.ensure_melee_auto_attack(me, target)
    if not me or not me:is_in_combat() or not target or not target:is_valid() or target:is_dead() then
        return false
    end

    if auto_attack:is_auto_attacking(target) then
        return true
    end

    if not utils.throttle("paladin_ret:ensure_melee_auto_attack", 0.30) then
        return false
    end

    return auto_attack:start_attack(target, auto_attack.ATTACK_TYPE.MELEE)
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

function utils.throttle(key, interval_s)
    if not key or not interval_s then return false end
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
        core.log("[Eax Paladin Retribution] " .. tostring(msg))
    end
end

return utils
