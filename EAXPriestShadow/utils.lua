-- EAX Priest Shadow | utils.lua
-- Helpers for spell resolution, mode detection, and health/buff utilities.

local spell_queue = require("common/modules/spell_queue")

local MODE_DETECT_INTERVAL_MS = 1500

local utils = {}

local function safe_value(value)
    return value or 0
end

function utils.resolve_spell_id(rank_table)
    if type(rank_table) ~= "table" then
        return nil
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

    local max_hp = unit:get_max_health() or 0
    if max_hp <= 0 then
        return 0
    end

    return unit:get_health() / max_hp
end

function utils.get_buff_remaining_ms(unit, ids)
    if not unit or not unit:is_valid() or not ids then
        return 0
    end

    local data = unit:get_buff_data(ids)
    if data and data.is_active then
        return data.remaining or 0
    end

    return 0
end

function utils.has_buff(unit, ids)
    return utils.get_buff_remaining_ms(unit, ids) > 0
end

function utils.get_party_units(me)
    local pool = {}
    local objects = core.object_manager.get_all_objects()

    for i = 1, #objects do
        local obj = objects[i]
        if obj and obj:is_valid() and obj:is_unit() and not obj:is_dead() then
            if obj == me or obj:is_party_member() then
                pool[#pool + 1] = obj
            end
        end
    end

    return pool
end

function utils.find_low_health_ally(me, max_pct, include_self)
    local threshold = max_pct or 1
    local winner = nil
    local winner_pct = threshold
    local units = utils.get_party_units(me)

    for i = 1, #units do
        local unit = units[i]
        if unit then
            if unit ~= me or include_self then
                local pct = utils.get_health_pct(unit)
                if pct <= threshold and pct <= winner_pct then
                    winner = unit
                    winner_pct = pct
                end
            end
        end
    end

    return winner
end

function utils.find_ally_missing_buff(me, buff_ids, include_self, refresh_window_ms)
    local window = refresh_window_ms or 0
    local units = utils.get_party_units(me)

    for i = 1, #units do
        local unit = units[i]
        if unit then
            if unit ~= me or include_self then
                if utils.get_buff_remaining_ms(unit, buff_ids) <= window then
                    return unit
                end
            end
        end
    end

    return nil
end

local function detect_mode_internal()
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
    end

    if party_count <= 4 then
        return "dungeon"
    end

    return "raid"
end

function utils.get_effective_mode(menu, runtime)
    local choice = menu.mode:get()
    if choice == 2 then
        return "solo"
    end
    if choice == 3 then
        return "dungeon"
    end
    if choice == 4 then
        return "raid"
    end

    local now = core.game_time()
    if not runtime.last_mode_check or (now - runtime.last_mode_check) >= MODE_DETECT_INTERVAL_MS then
        runtime.last_mode_check = now
        runtime.mode_cache = detect_mode_internal()
    end

    return runtime.mode_cache or "solo"
end

local function is_spell_castable(spell_id)
    if not spell_id then
        return false
    end

    if not core.spell_book.is_spell_learned(spell_id) then
        return false
    end

    if core.spell_book.get_spell_cooldown(spell_id) > 0 then
        return false
    end

    if core.spell_book.get_global_cooldown() > 0 then
        return false
    end

    if core.spell_book.is_current_spell(spell_id) then
        return false
    end

    return true
end

function utils.can_cast_target(spell_id, me, target)
    if not me or not target then
        return false
    end

    if not is_spell_castable(spell_id) then
        return false
    end

    if target:is_dead() or not target:is_valid() then
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

function utils.cast_target(spell_id, me, target)
    if not utils.can_cast_target(spell_id, me, target) then
        return false
    end

    spell_queue:queue_spell_target(spell_id, target, 1)
    return true
end

function utils.can_cast_self(spell_id, me)
    if not me then
        return false
    end

    if not is_spell_castable(spell_id) then
        return false
    end

    if not core.spell_book.is_usable_spell(spell_id) then
        return false
    end

    return true
end

function utils.cast_self(spell_id, me)
    if not utils.can_cast_self(spell_id, me) then
        return false
    end

    spell_queue:queue_spell_target(spell_id, me, 1)
    return true
end

function utils.log_debug(menu_ref, message)
    if menu_ref and menu_ref.debug and menu_ref.debug:get_state() and message then
        core.log("[EAX Priest Shadow] " .. message)
    end
end

return utils
