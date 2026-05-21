-- ============================================================================
-- What: Shared helper for recording and replaying combat events
-- When: On event callbacks and replay/debug inspection
-- Why: Preserve fight flow for analysis and rotation debugging
-- Safety: Bounded state, nil-guarded lookups, and conservative fallbacks
-- ============================================================================
-- Shared Helper: Combat Replay (Sylvanas)
-- ============================================================================
local _G = _G
local core = _G.core or {}
local NS = _G.EaxRotations
if not NS then return nil end

local M = {}

local WINDOW_SECONDS = 60
local SNAPSHOT_INTERVAL = 0.5
local SNAPSHOT_COUNT = 120
local CAST_BUFFER_COUNT = 256
local SHORT_LIST_COUNT = 6

local _time = core.time
local _register_pre_tick = core.register_on_pre_tick_callback
local _register_combat_end = NS.register_on_combat_end
local _register_spell_cast = NS.register_on_spell_cast
local _get_local_player = core.object_manager and core.object_manager.get_local_player or nil
local _get_enemy_list = core.object_manager and core.object_manager.get_enemy_list or nil
local _get_spell_name = core.spell_book and core.spell_book.get_spell_name or nil
local _buff_manager = nil

do
    local ok, buff_manager = pcall(require, "common/modules/buff_manager")
    if ok and type(buff_manager) == "table" then
        _buff_manager = buff_manager
    end
end

local EMPTY = { n = 0 }

local snapshots = {}
local cast_events = {}
local snapshot_head = 1
local snapshot_count = 0
local cast_head = 1
local cast_count = 0
local recording = false
local frozen = false
local last_snapshot_time = 0
local session_time = 0
local freeze_time = 0
local _initialized = false

local last_cast = {
    spell_id = nil,
    spell_name = nil,
    timestamp = 0,
    target = nil,
}

local function now()
    if type(_time) == "function" then
        local ok, value = pcall(_time)
        if ok and type(value) == "number" then
            return value
        end
    end
    return 0
end

local function new_short_list()
    return { n = 0 }
end

local function new_snapshot()
    return {
        timestamp = 0,
        hp_pct = 0,
        mana_pct = 0,
        position_x = 0,
        position_y = 0,
        strategy_name = nil,
        last_cast_spell_id = nil,
        last_cast_spell_name = nil,
        last_cast_timestamp = 0,
        player_buffs = new_short_list(),
        target_debuffs = new_short_list(),
        spell_cooldowns = new_short_list(),
    }
end

local function new_cast_event()
    return {
        timestamp = 0,
        spell_id = nil,
        spell_name = nil,
        target = nil,
    }
end

local function clear_short_list(list)
    local prev = list.n or 0
    for i = 1, prev do
        local slot = list[i]
        if slot then
            slot.id = nil
            slot.name = nil
            slot.remaining = nil
            slot.stacks = nil
            slot.category = nil
        end
    end
    list.n = 0
end

local function ensure_slot(list, index)
    local slot = list[index]
    if not slot then
        slot = {}
        list[index] = slot
    end
    return slot
end

local function resolve_time_reference()
    if frozen and freeze_time > 0 then
        return freeze_time
    end
    return now()
end

local function get_player()
    if type(_get_local_player) ~= "function" then
        return nil
    end
    local ok, player = pcall(_get_local_player)
    if ok and player then
        return player
    end
    return nil
end

local function get_enemy_target(player)
    if not player or type(player.get_target) ~= "function" then
        return nil
    end
    local ok, target = pcall(function()
        return player:get_target()
    end)
    if ok then
        return target
    end
    return nil
end

local function call_unit_number(unit, method_name)
    if not unit or type(unit[method_name]) ~= "function" then
        return 0
    end
    local ok, value = pcall(function()
        return unit[method_name](unit)
    end)
    if ok and type(value) == "number" then
        return value
    end
    return 0
end

local function call_position(unit)
    if not unit or type(unit.get_position) ~= "function" then
        return nil
    end
    local ok, pos = pcall(function()
        return unit:get_position()
    end)
    if not ok or type(pos) ~= "table" then
        return nil
    end
    return pos
end

local function push_cast_event(timestamp, spell_id, spell_name, target)
    local entry = cast_events[cast_head]
    if not entry then
        entry = new_cast_event()
        cast_events[cast_head] = entry
    end
    entry.timestamp = timestamp
    entry.spell_id = spell_id
    entry.spell_name = spell_name
    entry.target = target

    cast_head = cast_head + 1
    if cast_head > CAST_BUFFER_COUNT then
        cast_head = 1
    end
    if cast_count < CAST_BUFFER_COUNT then
        cast_count = cast_count + 1
    end
end

local function capture_short_list(dest, source, max_items, kind)
    clear_short_list(dest)
    local count = 0
    if type(source) == "table" then
        local limit = #source
        if limit > max_items then
            limit = max_items
        end
        for i = 1, limit do
            local item = source[i]
            if item then
                count = count + 1
                local slot = ensure_slot(dest, count)
                slot.id = item.buff_id or item.debuff_id or item.spell_id or item.id
                slot.name = item.buff_name or item.debuff_name or item.spell_name or item.name or tostring(slot.id or "?")
                slot.remaining = item.duration or item.remaining or item.remains or 0
                slot.stacks = item.count or item.stacks or 0
                slot.category = kind
            end
        end
    end
    dest.n = count
end

local function capture_cooldowns(dest)
    clear_short_list(dest)
    if type(NS.cooldown_registry) ~= "table" then
        return
    end
    local count = 0
    local limit = #NS.cooldown_registry
    if limit > SHORT_LIST_COUNT then
        limit = SHORT_LIST_COUNT
    end
    for i = 1, limit do
        local entry = NS.cooldown_registry[i]
        if entry and entry.spell then
            count = count + 1
            local slot = ensure_slot(dest, count)
            slot.id = type(entry.spell) == "number" and entry.spell or entry.spell.id or nil
            slot.name = entry.name or (slot.id and tostring(slot.id)) or "cooldown"
            slot.remaining = type(NS.cooldown_remains) == "function" and (NS.cooldown_remains(entry.spell) or 0) or 0
            slot.stacks = 0
            slot.category = entry.category or "cooldown"
        end
    end
    dest.n = count
end

local function ensure_snapshot(index)
    local snapshot = snapshots[index]
    if not snapshot then
        snapshot = new_snapshot()
        snapshots[index] = snapshot
    end
    return snapshot
end

local function reset_ring()
    snapshot_head = 1
    snapshot_count = 0
    cast_head = 1
    cast_count = 0
    last_snapshot_time = 0
    session_time = now()
    freeze_time = 0
    frozen = false
    recording = true
    last_cast.spell_id = nil
    last_cast.spell_name = nil
    last_cast.timestamp = 0
    last_cast.target = nil

    for i = 1, SNAPSHOT_COUNT do
        local snapshot = ensure_snapshot(i)
        snapshot.timestamp = 0
        snapshot.hp_pct = 0
        snapshot.mana_pct = 0
        snapshot.position_x = 0
        snapshot.position_y = 0
        snapshot.strategy_name = nil
        snapshot.last_cast_spell_id = nil
        snapshot.last_cast_spell_name = nil
        snapshot.last_cast_timestamp = 0
        clear_short_list(snapshot.player_buffs)
        clear_short_list(snapshot.target_debuffs)
        clear_short_list(snapshot.spell_cooldowns)
    end
end

local function capture_snapshot()
    if not recording or frozen then
        return
    end

    local player = get_player()
    if not player then
        return
    end

    if type(player.is_in_combat) ~= "function" then
        return
    end
    local ok_combat, in_combat = pcall(function()
        return player:is_in_combat()
    end)
    if not ok_combat or not in_combat then
        return
    end

    local t = now()
    if last_snapshot_time > 0 and (t - last_snapshot_time) < SNAPSHOT_INTERVAL then
        return
    end
    last_snapshot_time = t

    local snapshot = ensure_snapshot(snapshot_head)
    snapshot.timestamp = t
    snapshot.hp_pct = call_unit_number(player, "get_health_percentage")
    snapshot.mana_pct = call_unit_number(player, "get_mana_percentage")

    local pos = call_position(player)
    if pos then
        snapshot.position_x = tonumber(pos.x or pos[1]) or 0
        snapshot.position_y = tonumber(pos.y or pos[2]) or 0
    else
        snapshot.position_x = 0
        snapshot.position_y = 0
    end

    snapshot.strategy_name = tostring(NS.current_strategy or "unknown")
    snapshot.last_cast_spell_id = last_cast.spell_id
    snapshot.last_cast_spell_name = last_cast.spell_name
    snapshot.last_cast_timestamp = last_cast.timestamp

    local buffs = nil
    if _buff_manager and type(_buff_manager.get_buff_cache) == "function" then
        local ok, cache = pcall(_buff_manager.get_buff_cache, _buff_manager, player)
        if ok and type(cache) == "table" then
            buffs = cache
        end
    end
    capture_short_list(snapshot.player_buffs, buffs or EMPTY, SHORT_LIST_COUNT, "buff")

    local target = get_enemy_target(player)
    local debuffs = nil
    if target and _buff_manager and type(_buff_manager.get_debuff_cache) == "function" then
        local ok, cache = pcall(_buff_manager.get_debuff_cache, _buff_manager, target)
        if ok and type(cache) == "table" then
            debuffs = cache
        end
    end
    capture_short_list(snapshot.target_debuffs, debuffs or EMPTY, SHORT_LIST_COUNT, "debuff")

    capture_cooldowns(snapshot.spell_cooldowns)

    snapshot_head = snapshot_head + 1
    if snapshot_head > SNAPSHOT_COUNT then
        snapshot_head = 1
    end
    if snapshot_count < SNAPSHOT_COUNT then
        snapshot_count = snapshot_count + 1
    end
end

function M.get_snapshot_at_time(seconds_ago)
    local offset = tonumber(seconds_ago) or 0
    if offset < 0 then
        offset = 0
    elseif offset > WINDOW_SECONDS then
        offset = WINDOW_SECONDS
    end

    local target_time = resolve_time_reference() - offset
    local best = nil
    local best_time = -1

    for i = 1, snapshot_count do
        local index = snapshot_head - i
        if index < 1 then
            index = index + SNAPSHOT_COUNT
        end
        local snapshot = snapshots[index]
        if snapshot and snapshot.timestamp > 0 and snapshot.timestamp <= target_time and snapshot.timestamp > best_time then
            best = snapshot
            best_time = snapshot.timestamp
        end
    end

    if best then
        return best
    end

    if snapshot_count > 0 then
        local index = snapshot_head - snapshot_count
        while index < 1 do
            index = index + SNAPSHOT_COUNT
        end
        return snapshots[index]
    end

    return nil
end

function M.get_spell_casts_in_window(start_seconds_ago, end_seconds_ago)
    local start_ago = tonumber(start_seconds_ago) or 0
    local end_ago = tonumber(end_seconds_ago) or 0
    if start_ago < end_ago then
        start_ago, end_ago = end_ago, start_ago
    end
    if start_ago < 0 then start_ago = 0 end
    if end_ago < 0 then end_ago = 0 end
    if start_ago > WINDOW_SECONDS then start_ago = WINDOW_SECONDS end
    if end_ago > WINDOW_SECONDS then end_ago = WINDOW_SECONDS end

    local ref_time = resolve_time_reference()
    local window_start = ref_time - start_ago
    local window_end = ref_time - end_ago

    local results = { n = 0 }
    local out = 0
    local ordered = {}

    for i = 1, cast_count do
        local index = cast_head - i
        if index < 1 then
            index = index + CAST_BUFFER_COUNT
        end
        local entry = cast_events[index]
        if entry and entry.timestamp >= window_start and entry.timestamp <= window_end then
            out = out + 1
            ordered[out] = entry
        end
    end

    for i = out, 1, -1 do
        local src = ordered[i]
        local slot = results[results.n + 1]
        if not slot then
            slot = {}
            results[results.n + 1] = slot
        end
        results.n = results.n + 1
        slot.timestamp = src.timestamp
        slot.seconds_ago = math.max(0, ref_time - src.timestamp)
        slot.spell_id = src.spell_id
        slot.spell_name = src.spell_name
        slot.target = src.target
    end

    return results
end

local function draw_line_safe(x1, y1, x2, y2, color)
    local gfx = core.graphics
    if not gfx then return end
    if type(gfx.draw_line) == "function" then
        pcall(gfx.draw_line, x1, y1, x2, y2, color)
    end
end

local function draw_rect_safe(x, y, w, h, color)
    local gfx = core.graphics
    if not gfx then return end
    if type(gfx.draw_rect) == "function" then
        pcall(gfx.draw_rect, x, y, w, h, color)
    elseif type(gfx.draw_rectangle) == "function" then
        pcall(gfx.draw_rectangle, x, y, w, h, color)
    elseif type(gfx.fill_rect) == "function" then
        pcall(gfx.fill_rect, x, y, w, h, color)
    end
end

function M.render_timeline(width, height)
    local w = tonumber(width) or 0
    local h = tonumber(height) or 0
    if w <= 0 or h <= 0 then
        return
    end

    local ref_time = resolve_time_reference()
    local axis_y = h * 0.5
    draw_line_safe(0, axis_y, w, axis_y, { 255, 255, 255, 120 })

    if cast_count == 0 then
        return
    end

    for i = 1, cast_count do
        local index = cast_head - i
        if index < 1 then
            index = index + CAST_BUFFER_COUNT
        end
        local entry = cast_events[index]
        if entry and entry.timestamp > 0 then
            local age = ref_time - entry.timestamp
            if age >= 0 and age <= WINDOW_SECONDS then
                local x = w - ((age / WINDOW_SECONDS) * w)
                draw_rect_safe(x - 1, axis_y - 6, 2, 12, { 255, 120, 60, 220 })
            end
        end
    end
end

function M.on_combat_end()
    if not recording then
        return
    end
    frozen = true
    recording = false
    freeze_time = now()
end

function M.init()
    if _initialized then
        return true
    end
    _initialized = true

    reset_ring()

    if type(_register_spell_cast) == "function" then
        _register_spell_cast(function(spell_id, target, data)
            if not recording or frozen then
                return
            end
            local t = now()
            local spell_name = nil
            if data and type(data.spell_name) == "string" then
                spell_name = data.spell_name
            elseif type(_get_spell_name) == "function" and spell_id then
                local ok, name = pcall(_get_spell_name, spell_id)
                if ok and type(name) == "string" then
                    spell_name = name
                end
            end
            last_cast.spell_id = spell_id
            last_cast.spell_name = spell_name or (spell_id and tostring(spell_id) or nil)
            last_cast.timestamp = t
            last_cast.target = target
            push_cast_event(t, spell_id, last_cast.spell_name, target)
        end)
    end

    if type(_register_combat_end) == "function" then
        _register_combat_end(function()
            M.on_combat_end()
        end)
    end

    if type(_register_pre_tick) == "function" then
        _register_pre_tick(function()
            local player = get_player()
            local in_combat = false
            if player and type(player.is_in_combat) == "function" then
                local ok, value = pcall(function()
                    return player:is_in_combat()
                end)
                in_combat = ok and value == true
            end

            if in_combat then
                if not recording then
                    reset_ring()
                end
                capture_snapshot()
            elseif recording and snapshot_count > 0 then
                -- keep the current ring intact until combat-end callback freezes it
                last_snapshot_time = 0
            end
        end)
    end

    NS.CombatReplay = M
    NS.combat_replay = M
    return true
end

M.init()

return M
