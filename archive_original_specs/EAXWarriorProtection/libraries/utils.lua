-- Eax Warrior Protection | utils.lua
-- Helper functions validated against .api/core.lua, .api/game_object.lua,
-- sylvanas-dev-docs-llm/pages/dev/api/auto-attack-helper.md,
-- sylvanas-dev-docs-llm/pages/dev/api/game-object.md,
-- sylvanas-dev-docs-llm/pages/dev/api/object-manager.md,
-- and sylvanas-dev-docs-llm/pages/dev/api/spellbook.md.

---@type enums
---@type auto_attack_helper
local auto_attack = require("common/utility/auto_attack_helper")
---@type spell_queue
local spell_queue = require("common/modules/spell_queue")
---@type buff_manager
local buff_manager = require("common/modules/buff_manager")

local spells = require("libraries/spells")

local utils = {}

-- Spell resolver with persistent caching (see spell_resolver.lua)
local spell_resolver = require("libraries/spell_resolver")
utils._tracked_stance = nil

local INVENTORY_SLOT_TRINKET_1 = 13
local INVENTORY_SLOT_TRINKET_2 = 14

local throttle_timestamps = {}
local queue_request_timestamps = {}
local SPELL_QUEUE_INTERVAL_S = 0.25
local FAST_SPELL_QUEUE_INTERVAL_S = 0.10

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

-- Delegated to shared spell resolver with persistent cache
function utils.resolve_spell_id(rank_table)
    return spell_resolver.resolve_spell_id(rank_table)
end

function utils.invalidate_spell_cache()
    spell_resolver.invalidate_cache()
end

function utils.has_buff(unit, id_table)
    if not unit or not unit:is_valid() or not id_table then return false end
    local data = buff_manager:get_buff_data(unit, id_table)
    return data ~= nil and data.is_active
end

function utils.has_debuff(unit, id_table)
    if not unit or not unit:is_valid() or not id_table then return false end
    local data = buff_manager:get_debuff_data(unit, id_table)
    if data and data.is_active then return true end
    data = buff_manager:get_aura_data(unit, id_table)
    return data ~= nil and data.is_active
end

--- Check if the player is pacified (cannot cast spells).
---@param me game_object
---@return boolean
function utils.is_pacified(me)
    if not me or not me:is_valid() then return false end
    return utils.has_debuff(me, spells.PACIFY_BUFFS)
end

--- Can the player cast this spell on a hostile target right now?
---@param spell_id number|nil
---@param me game_object
---@param target game_object
---@return boolean
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
    local same_unit = utils.same_unit or function(a, b) return a == b end
    -- Never cast damage spells on self
    if same_unit(me, target) then return false end
    -- Target must be attackable by the player (fails for friendlies, self, neutral)
    if not me:can_attack(target) then return false end
    return utils.can_cast_target(spell_id, me, target)
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



--- Can the player cast this spell on a hostile target without checking `is_usable_spell`.
---@param spell_id number|nil
---@param me game_object
---@param target game_object
---@return boolean
function utils.can_cast_target_no_usable(spell_id, me, target)
    if not spell_id or not me or not target or not target:is_valid() then return false end
    if core.spell_book.get_spell_cooldown(spell_id) > 0 then return false end
    if not core.spell_book.is_spell_in_range(spell_id, target, me) then return false end
    return true
end

--- Can the player cast this spell on self right now?
---@param spell_id number|nil
---@param me game_object
---@return boolean
function utils.can_cast_self(spell_id, me)
    if not spell_id or not me then return false end
    if core.spell_book.get_spell_cooldown(spell_id) > 0 then return false end
    if not core.spell_book.is_usable_spell(spell_id) then return false end
    return true
end

--- Can the player cast this melee spell right now? (skips spell range data)
---@param spell_id number|nil
---@param me game_object
---@return boolean
function utils.can_cast_melee(spell_id, me)
    if not spell_id or not me then return false end
    if core.spell_book.get_spell_cooldown(spell_id) > 0 then return false end
    if not core.spell_book.is_usable_spell(spell_id) then return false end
    return true
end

--- Cast a spell on a hostile target.
---@param spell_id number
---@param target game_object
---@return boolean
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

function utils.cast_target(spell_id, me, target)
    local can_cast, reason = utils.can_cast_target(spell_id, me, target)
    if not can_cast then
        return false, reason
    end
    spell_queue:queue_spell_target(spell_id, target, 1)
    return true
end

--- Cast a spell on self.
---@param spell_id number
---@param me game_object
---@return boolean
function utils.cast_self(spell_id, me)
    if not spell_id or not me then return false end
    if not can_issue_queue_request("spell_self", spell_id, me, SPELL_QUEUE_INTERVAL_S) then return false end

    spell_queue:queue_spell_target(spell_id, me, 1)
    return true
end

--- Queue a target spell that should ignore GCD sequencing.
---@param spell_id number
---@param target game_object
---@return boolean
function utils.cast_target_fast(spell_id, target)
    if not spell_id or not target or not target:is_valid() then return false end
    if not can_issue_queue_request("spell_target_fast", spell_id, target, FAST_SPELL_QUEUE_INTERVAL_S) then return false end

    spell_queue:queue_spell_target_fast(spell_id, target, 1)
    return true
end

--- Queue a self spell that should ignore GCD sequencing.
---@param spell_id number
---@param me game_object
---@return boolean
function utils.cast_self_fast(spell_id, me)
    if not spell_id or not me then return false end
    if not can_issue_queue_request("spell_self_fast", spell_id, me, FAST_SPELL_QUEUE_INTERVAL_S) then return false end

    spell_queue:queue_spell_target_fast(spell_id, me, 1)
    return true
end

--- Get current rage.
---@param me game_object
---@return number
function utils.get_rage(me)
    return me:get_power(1)
end

--- Get health as a fraction 0..1.
---@param unit game_object
---@return number
function utils.get_health_pct(unit)
    local max_hp = unit:get_max_health()
    if max_hp <= 0 then return 1.0 end
    return unit:get_health() / max_hp
end

--- Get remaining duration of a buff in milliseconds (0 if not active).
---@param unit game_object
---@param id_table number[]
---@return number
function utils.get_buff_remaining_ms(unit, id_table)
    local data = buff_manager:get_buff_data(unit, id_table)
    if data and data.is_active then
        return data.remaining or 0
    end
    return 0
end

--- Check if a buff is active on a unit.
---@param unit game_object
---@param id_table number[]
---@return boolean
function utils.has_buff(unit, id_table)
    local data = buff_manager:get_buff_data(unit, id_table)
    return data ~= nil and data.is_active
end

--- Get remaining duration of a debuff in milliseconds (0 if not active).
---@param unit game_object
---@param id_table number[]
---@return number
function utils.get_debuff_remaining_ms(unit, id_table)
    local data = buff_manager:get_debuff_data(unit, id_table)
    if data and data.is_active then
        return data.remaining or 0
    end
    return 0
end

--- Check if a debuff is active on a unit.
---@param unit game_object
---@param id_table number[]
---@return boolean
function utils.has_debuff(unit, id_table)
    if not unit or not unit:is_valid() then return false end
    local data = buff_manager:get_debuff_data(unit, id_table)
    if data and data.is_active then return true end
    data = buff_manager:get_aura_data(unit, id_table)
    return data ~= nil and data.is_active
end

--- Count hostile attackable units within `radius` yards of the player.
---@param me game_object
---@param radius number
---@return number
function utils.enemy_count_in_radius(me, radius)
    local my_pos = me:get_position()
    local count = 0
    local objects = core.object_manager.get_visible_objects()

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

--- Is the target within melee range of the player?
---@param me game_object
---@param target game_object
---@return boolean
function utils.is_melee_target(me, target)
    if not me or not target or not target:is_valid() then return false end

    local my_pos = me:get_position()
    local target_pos = target:get_position()
    local reach = me:get_combat_reach() + target:get_combat_reach() + 1.0
    local sq_dist = my_pos:squared_dist_to_ignore_z(target_pos)
    return sq_dist <= (reach * reach)
end

--- Is the unit currently casting or channelling?
---@param unit game_object
---@return boolean
function utils.is_casting_or_channeling(unit)
    return unit:is_casting_spell() or unit:is_channelling_spell()
end

--- Is this spell already active (is_current_spell check only)?
---@param spell_id number|nil
---@return boolean
function utils.is_spell_already_queued(spell_id)
    if not spell_id then return false end
    return core.spell_book.is_current_spell(spell_id)
end

--- Simple keyed throttle.
---@param key string
---@param interval_s number
---@return boolean
function utils.throttle(key, interval_s)
    local now = core.time()
    local last = throttle_timestamps[key] or 0
    if (now - last) >= interval_s then
        throttle_timestamps[key] = now
        return true
    end
    return false
end

--- Log a message only when the debug checkbox is enabled.
---@param menu_ref table
---@param msg string
function utils.log_debug(menu_ref, msg)
    if menu_ref.debug:get_state() then
        core.log("[Eax Warrior Protection] " .. msg)
    end
end

--- Get the time until the next swing in milliseconds.
---@param me game_object
---@param weapon_count number|nil
---@return number
function utils.get_next_swing_ms(me, weapon_count)
    if not me then return math.huge end

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

--- Returns true if the next swing is inside the provided window.
---@param me game_object
---@param weapon_count number|nil
---@param window_ms number
---@return boolean
function utils.is_next_swing_within_ms(me, weapon_count, window_ms)
    return utils.get_next_swing_ms(me, weapon_count) <= window_ms
end

--- Ensure melee auto attack is started on the current target.
---@param me game_object
---@param target game_object
---@return boolean
function utils.ensure_melee_auto_attack(me, target)
    if not me or not me:is_in_combat() or not target or not target:is_valid() or target:is_dead() then
        return false
    end

    if auto_attack:is_auto_attacking(target) then
        return true
    end

    if not utils.throttle("ensure_melee_auto_attack", 0.30) then
        return false
    end

    return auto_attack:start_attack(target, auto_attack.ATTACK_TYPE.MELEE)
end

--- Get the item id equipped in a specific inventory slot.
---@param me game_object
---@param slot_id number
---@return number|nil
function utils.get_equipped_item_id_in_slot(me, slot_id)
    if not me then return nil end

    local slot_info = me:get_item_at_inventory_slot(slot_id)
    if not slot_info or not slot_info.object then
        return nil
    end

    local item = slot_info.object
    if item.is_valid and not item:is_valid() then
        return nil
    end

    local item_id = item:get_item_id()
    if item_id and item_id > 0 then
        return item_id
    end

    return nil
end

--- Get ready self-cast trinkets from the equipped trinket slots.
---@param me game_object
---@return table
function utils.get_self_cast_trinket_ids(me)
    local ready = {}
    local slots = { INVENTORY_SLOT_TRINKET_1, INVENTORY_SLOT_TRINKET_2 }

    for i = 1, #slots do
        local slot_id = slots[i]
        local item_id = utils.get_equipped_item_id_in_slot(me, slot_id)
        if item_id
            and core.spell_book.is_item_usable(item_id)
            and not core.spell_book.has_item_range(item_id)
        then
            ready[#ready + 1] = {
                slot_id = slot_id,
                item_id = item_id,
            }
        end
    end

    return ready
end

--- Use a self-cast trinket if it is ready.
---@param item_id number|nil
---@return boolean
function utils.use_item_if_ready(item_id)
    if not item_id then return false end
    if not core.spell_book.is_item_usable(item_id) then return false end
    if core.spell_book.has_item_range(item_id) then return false end
    return core.input.use_item(item_id)
end

--- Check whether a bag consumable exists and is currently ready.
---@param me game_object
---@param item_id number|nil
---@return boolean
function utils.is_consumable_ready(me, item_id)
    if not me or not item_id then return false end
    if not me:has_item(item_id) then return false end
    if me:get_item_cooldown(item_id) > 0 then return false end
    if not core.spell_book.is_item_usable(item_id) then return false end
    return true
end

--- Use a consumable item if it exists in bags and is ready.
---@param me game_object
---@param item_id number|nil
---@return boolean
function utils.use_consumable_if_ready(me, item_id)
    if not utils.is_consumable_ready(me, item_id) then return false end
    return core.input.use_item(item_id)
end

--- Returns true when Slam can fit before the next swing plus a user buffer.
---@param me game_object
---@param slam_id number|nil
---@param safety_buffer_ms number
---@return boolean
function utils.can_slam_without_clipping(me, slam_id, safety_buffer_ms)
    if not me or not slam_id then return false end

    local cast_time_s = core.spell_book.get_spell_cast_time(slam_id)
    if not cast_time_s or cast_time_s <= 0 then return false end

    local cast_time_ms = cast_time_s * 1000
    local next_swing_ms = utils.get_next_swing_ms(me, 2)
    return next_swing_ms > (cast_time_ms + safety_buffer_ms)
end

--- Persist the last stance we successfully identified or cast.
---@param stance_name string|nil
function utils.set_tracked_stance(stance_name)
    utils._tracked_stance = stance_name
end

--- Normalize a stance value (string or number) to a canonical name.
---@param value any
---@return string|nil
local function normalize_stance(value)
    if type(value) == "string" then
        local s = string.lower(value)
        if string.find(s, "battle", 1, true) then return "battle" end
        if string.find(s, "berserker", 1, true) then return "berserker" end
        if string.find(s, "defensive", 1, true) then return "defensive" end
        return nil
    end

    if type(value) == "number" then
        if value == 1 then return "battle" end
        if value == 2 then return "defensive" end
        if value == 3 then return "berserker" end
    end

    return nil
end

--- Detect the player's current stance.
--- COMPLIANT VERSION: Uses only documented get_buff_data API.
---@param me game_object
---@return string|nil
function utils.get_current_stance(me)
    if not me then return utils._tracked_stance end

    -- PRIMARY: Use GetShapeshiftForm() API - most reliable for stances
    -- This returns: 0=no form, 1=Battle, 2=Defensive, 3=Berserker for warriors
    local ok, form_index = pcall(function() return GetShapeshiftForm() end)
    if ok and form_index and form_index > 0 then
        if form_index == 1 then
            utils._tracked_stance = "battle"
            return "battle"
        elseif form_index == 2 then
            utils._tracked_stance = "defensive"
            return "defensive"
        elseif form_index == 3 then
            utils._tracked_stance = "berserker"
            return "berserker"
        end
    end

    -- FALLBACK 1: Buff detection via buff_manager
    if utils.has_buff(me, spells.BUFF_BATTLE_STANCE) then
        utils._tracked_stance = "battle"
        return "battle"
    end
    if utils.has_buff(me, spells.BUFF_BERSERKER_STANCE) then
        utils._tracked_stance = "berserker"
        return "berserker"
    end
    if utils.has_buff(me, spells.BUFF_DEFENSIVE_STANCE) then
        utils._tracked_stance = "defensive"
        return "defensive"
    end

    -- FALLBACK 2: Usability probe (stance you're IN is not usable)
    local battle_id    = spells.BATTLE_STANCE and spells.BATTLE_STANCE[1] or nil
    local defensive_id = spells.DEFENSIVE_STANCE and spells.DEFENSIVE_STANCE[1] or nil
    local berserker_id = spells.BERSERKER_STANCE and spells.BERSERKER_STANCE[1] or nil

    local battle_usable    = battle_id    and core.spell_book.is_usable_spell(battle_id)    or false
    local defensive_usable = defensive_id and core.spell_book.is_usable_spell(defensive_id) or false
    local berserker_usable = berserker_id and core.spell_book.is_usable_spell(berserker_id) or false

    local usable_count = (battle_usable and 1 or 0)
                       + (defensive_usable and 1 or 0)
                       + (berserker_usable and 1 or 0)

    -- Only trust the probe if exactly two stances are usable (the third = current)
    if usable_count == 2 then
        if not battle_usable then
            utils._tracked_stance = "battle"; return "battle"
        end
        if not berserker_usable then
            utils._tracked_stance = "berserker"; return "berserker"
        end
        if not defensive_usable then
            utils._tracked_stance = "defensive"; return "defensive"
        end
    end

    return utils._tracked_stance
end

--- Detect retained rage after a stance swap from Tactical Mastery ranks.
---@return number
function utils.get_stance_swap_retention()
    if core.spell_book.is_spell_learned(spells.TACTICAL_MASTERY[1]) then
        return 25
    end

    if core.spell_book.is_spell_learned(spells.TACTICAL_MASTERY[2]) then
        return 20
    end

    if core.spell_book.is_spell_learned(spells.TACTICAL_MASTERY[3]) then
        return 15
    end

    return 10
end

--- Check whether we can afford a stance swap and still cast the planned ability.
---@param rage number
---@param ability_cost number
---@param buffer number|nil
---@param retained_rage number|nil
---@return boolean
function utils.can_stance_dance_for_cost(rage, ability_cost, buffer, retained_rage)
    local retained = retained_rage or utils.get_stance_swap_retention()
    local available_after_swap = math.min(rage, retained)
    return available_after_swap >= (ability_cost + (buffer or 0))
end

--- Get planar distance to a target in yards.
---@param me game_object
---@param target game_object
---@return number
function utils.get_distance_to_target(me, target)
    if not me or not target or not target:is_valid() then return math.huge end

    local my_pos = me:get_position()
    local target_pos = target:get_position()
    local sq_dist = my_pos:squared_dist_to_ignore_z(target_pos)
    return math.sqrt(sq_dist)
end

--- Find the highest-health melee-valid enemy in range for AoE abilities.
---@param me game_object
---@param fallback_target game_object|nil
---@param radius number
---@return game_object|nil
function utils.find_best_aoe_target(me, fallback_target, radius)
    local best_target = nil
    local best_health = -1
    local my_pos = me:get_position()
    local objects = core.object_manager.get_visible_objects()

    for i = 1, #objects do
        local obj = objects[i]
        if obj
            and obj:is_valid()
            and obj:is_unit()
            and not obj:is_dead()
            and me:can_attack(obj)
            and utils.is_melee_target(me, obj)
        then
            local obj_pos = obj:get_position()
            local threshold = radius + obj:get_bounding_radius()
            local sq_dist = my_pos:squared_dist_to_ignore_z(obj_pos)
            if sq_dist <= (threshold * threshold) then
                local obj_health = obj:get_health()
                if obj_health > best_health then
                    best_target = obj
                    best_health = obj_health
                end
            end
        end
    end

    if best_target then
        return best_target
    end

    if fallback_target
        and fallback_target:is_valid()
        and not fallback_target:is_dead()
        and me:can_attack(fallback_target)
    then
        return fallback_target
    end

    return nil
end

--- Find the lowest-health melee-valid execute target below 20% in range.
---@param me game_object
---@param fallback_target game_object|nil
---@param radius number
---@return game_object|nil
function utils.find_execute_snipe_target(me, fallback_target, radius)
    if not me then return nil end

    local best_target = nil
    local lowest_health = math.huge
    local my_pos = me:get_position()
    local objects = core.object_manager.get_visible_objects()

    for i = 1, #objects do
        local obj = objects[i]
        if obj
            and obj:is_valid()
            and obj:is_unit()
            and not obj:is_dead()
            and me:can_attack(obj)
            and utils.is_melee_target(me, obj)
            and utils.get_health_pct(obj) < 0.20
        then
            local obj_pos = obj:get_position()
            local threshold = radius + obj:get_bounding_radius()
            local sq_dist = my_pos:squared_dist_to_ignore_z(obj_pos)
            if sq_dist <= (threshold * threshold) then
                local obj_health = obj:get_health()
                if obj_health < lowest_health then
                    best_target = obj
                    lowest_health = obj_health
                end
            end
        end
    end

    if best_target then
        return best_target
    end

    if fallback_target
        and fallback_target:is_valid()
        and not fallback_target:is_dead()
        and me:can_attack(fallback_target)
        and utils.is_melee_target(me, fallback_target)
        and utils.get_health_pct(fallback_target) < 0.20
    then
        return fallback_target
    end

    return nil
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
    ["Warbringer"] = {
        items = { 29061, 29062, 29063, 29064, 29065 },
        bonuses = { ["2"] = 1.05, ["4"] = 1.10 }
    },
    ["WarbringerBattlegear"] = {
        items = { 30175, 30176, 30177, 30178, 30179 },
        bonuses = { ["2"] = 1.05, ["4"] = 1.10 }
    },
    ["Ymirjar"] = {
        items = { 31193, 31194, 31195, 31196, 31197 },
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
