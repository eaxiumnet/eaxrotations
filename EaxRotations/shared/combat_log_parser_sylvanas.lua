-- combat_log_parser_sylvanas.lua -- rolling combat-log parser used by damage meter + recount.
-- WHAT:   rolling combat-log parser used by damage meter + recount.
-- WHEN:   called on every combat log event (throttled to 5 ev/sec)
-- WHY:    centralises CL parsing into a single queue
-- SAFETY: bounded ring buffer; nil-guarded dest/source unit
-- DECISION: pure helper consumed via require() by specs; no on_update side-effects.


-- shared combat log parser and rolling buffer.


local core = _G.core

local M = {}

local WINDOW_SECONDS = 60
local entries = {}
local head = 1
local tail = 0

local function now_seconds()
    if core and core.time then
        return core.time()
    end

    return 0
end

local function clamp_window(seconds)
    seconds = tonumber(seconds) or WINDOW_SECONDS
    if seconds < 0 then
        seconds = 0
    end

    if seconds > WINDOW_SECONDS then
        seconds = WINDOW_SECONDS
    end

    return seconds
end

local function normalize_token(value)
    if value == nil then
        return nil
    end

    local kind = type(value)
    if kind == "string" or kind == "number" or kind == "boolean" then
        return string.lower(tostring(value))
    end

    local ok, resolved = pcall(function()
        if type(value.get_name) == "function" then
            return value:get_name()
        end

        if type(value.get_display_name) == "function" then
            return value:get_display_name()
        end

        if type(value.get_guid) == "function" then
            return value:get_guid()
        end

        return tostring(value)
    end)

    if ok and resolved ~= nil then
        return string.lower(tostring(resolved))
    end

    return string.lower(tostring(value))
end

local function resolve_label(value)
    if value == nil then
        return nil
    end

    local kind = type(value)
    if kind == "string" or kind == "number" or kind == "boolean" then
        return tostring(value)
    end

    local ok, resolved = pcall(function()
        if type(value.get_name) == "function" then
            return value:get_name()
        end

        if type(value.get_display_name) == "function" then
            return value:get_display_name()
        end

        if type(value.get_guid) == "function" then
            return value:get_guid()
        end

        return tostring(value)
    end)

    if ok and resolved ~= nil then
        return tostring(resolved)
    end

    return tostring(value)
end

local function get_spell_name(spell_id)
    if core and core.spell_book and core.spell_book.get_spell_name then
        local ok, name = pcall(core.spell_book.get_spell_name, spell_id)
        if ok and name and name ~= "" then
            return name
        end
    end

    return nil
end

local function get_amount(data)
    local amount = data.amount or data.damage or data.heal or data.heal_amount or data.value or data.total_amount or 0
    return tonumber(amount) or 0
end

local function get_amount_kind(data)
    if data.is_heal or data.heal ~= nil or data.heal_amount ~= nil or data.amount_kind == "HEAL" then
        return "HEAL"
    end

    return "DAMAGE"
end

local function get_event_type(data, amount_kind)
    if data.event_type == "MISS" or data.is_miss or data.miss or data.result == "MISS" then
        return "MISS"
    end

    if data.event_type == "CRIT" or data.is_crit or data.crit or data.is_critical then
        return "CRIT"
    end

    return amount_kind
end

local function compact_if_needed()
    if head <= 1 then
        return
    end

    if head <= 64 and head <= (tail - head) then
        return
    end

    local next_entries = {}
    local next_tail = 0

    for i = head, tail do
        next_tail = next_tail + 1
        next_entries[next_tail] = entries[i]
    end

    entries = next_entries
    head = 1
    tail = next_tail
end

local function prune(now)
    local cutoff = now - WINDOW_SECONDS

    while head <= tail do
        local entry = entries[head]
        if entry and entry.timestamp >= cutoff then
            break
        end

        entries[head] = nil
        head = head + 1
    end

    compact_if_needed()
end

local function push_entry(entry)
    tail = tail + 1
    entries[tail] = entry
    prune(entry.timestamp)
end

local function iter_window(seconds)
    local window = clamp_window(seconds)
    local cutoff = now_seconds() - window

    return function()
        local index = head - 1

        return function()
            while index < tail do
                index = index + 1
                local entry = entries[index]
                if entry and entry.timestamp >= cutoff then
                    return entry
                end
            end
        end
    end
end

local function build_entry(data)
    local spell_id = tonumber(data.spell_id)
    if not spell_id then
        return nil
    end

    local timestamp = tonumber(data.spell_cast_time) or now_seconds()
    local amount_kind = get_amount_kind(data)
    local amount = get_amount(data)
    local event_type = get_event_type(data, amount_kind)

    local caster = data.caster
    local target = data.target

    return {
        spell_id = spell_id,
        spell_name = data.spell_name or get_spell_name(spell_id) or tostring(spell_id),
        caster = caster,
        target = target,
        caster_token = normalize_token(caster) or "unknown",
        target_token = normalize_token(target) or "unknown",
        caster_label = resolve_label(caster) or "unknown",
        target_label = resolve_label(target) or "unknown",
        amount = amount,
        amount_kind = amount_kind,
        timestamp = timestamp,
        event_type = event_type,
    }
end

local function get_events_for_window(seconds)
    local results = {}
    local count = 0

    for entry in iter_window(seconds)() do
        count = count + 1
        results[count] = entry
    end

    return results
end

function M.get_last_n_events(n)
    n = tonumber(n) or 0
    if n <= 0 then
        return {}
    end

    local results = {}
    local count = 0

    for i = tail, head, -1 do
        local entry = entries[i]
        if entry then
            count = count + 1
            results[count] = entry
            if count >= n then
                break
            end
        end
    end

    return results
end

function M.get_events_by_spell(spell_id)
    spell_id = tonumber(spell_id)
    if not spell_id then
        return {}
    end

    local results = {}
    local count = 0

    for entry in iter_window(WINDOW_SECONDS)() do
        if entry.spell_id == spell_id then
            count = count + 1
            results[count] = entry
        end
    end

    return results
end

function M.get_events_by_target(target)
    local target_token = normalize_token(target)
    if not target_token then
        return {}
    end

    local results = {}
    local count = 0

    for entry in iter_window(WINDOW_SECONDS)() do
        if entry.target_token == target_token then
            count = count + 1
            results[count] = entry
        end
    end

    return results
end

function M.get_dps_hps_per_unit(seconds)
    local window = clamp_window(seconds)
    local now = now_seconds()
    local cutoff = now - window
    local per_unit = {}

    for entry in iter_window(window)() do
        local key = entry.caster_token or "unknown"
        local bucket = per_unit[key]

        if not bucket then
            bucket = {
                unit = entry.caster,
                unit_label = entry.caster_label,
                damage = 0,
                healing = 0,
                events = 0,
                misses = 0,
                crits = 0,
                first_timestamp = entry.timestamp,
                last_timestamp = entry.timestamp,
            }
            per_unit[key] = bucket
        end

        bucket.events = bucket.events + 1
        bucket.last_timestamp = entry.timestamp

        if entry.amount_kind == "HEAL" then
            bucket.healing = bucket.healing + entry.amount
        else
            bucket.damage = bucket.damage + entry.amount
        end

        if entry.event_type == "MISS" then
            bucket.misses = bucket.misses + 1
        elseif entry.event_type == "CRIT" then
            bucket.crits = bucket.crits + 1
        end
    end

    for _, bucket in pairs(per_unit) do
        bucket.dps = bucket.damage / math.max(window, 0.001)
        bucket.hps = bucket.healing / math.max(window, 0.001)
        bucket.window = window
        bucket.since = cutoff
    end

    return per_unit
end

function M.get_top_damage_abilities(seconds, caster)
    local window = clamp_window(seconds)
    local caster_token = normalize_token(caster)
    if not caster_token then
        return { total_damage = 0, abilities = {} }
    end

    local totals = {}
    local total_damage = 0

    for entry in iter_window(window)() do
        if entry.caster_token == caster_token and entry.amount_kind ~= "HEAL" and entry.amount > 0 then
            local key = entry.spell_name or tostring(entry.spell_id)
            local bucket = totals[key]

            if not bucket then
                bucket = {
                    spell_id = entry.spell_id,
                    spell_name = entry.spell_name or tostring(entry.spell_id),
                    damage = 0,
                    hits = 0,
                }
                totals[key] = bucket
            end

            bucket.damage = bucket.damage + entry.amount
            bucket.hits = bucket.hits + 1
            total_damage = total_damage + entry.amount
        end
    end

    local abilities = {}
    local count = 0

    for _, bucket in pairs(totals) do
        count = count + 1
        abilities[count] = bucket
    end

    table.sort(abilities, function(a, b)
        if a.damage == b.damage then
            if a.hits == b.hits then
                return tostring(a.spell_name) < tostring(b.spell_name)
            end
            return a.hits > b.hits
        end

        return a.damage > b.damage
    end)

    local top = {}
    local top_count = math.min(3, #abilities)
    for i = 1, top_count do
        local bucket = abilities[i]
        top[i] = {
            spell_id = bucket.spell_id,
            spell_name = bucket.spell_name,
            damage = bucket.damage,
            hits = bucket.hits,
            damage_pct = total_damage > 0 and (bucket.damage / total_damage) * 100 or 0,
        }
    end

    return {
        window = window,
        total_damage = total_damage,
        abilities = top,
    }
end

function M.get_summary_for_window(seconds)
    local window = clamp_window(seconds)
    local now = now_seconds()
    local cutoff = now - window

    local summary = {
        window = window,
        since = cutoff,
        until_time = now,
        total_events = 0,
        damage_events = 0,
        heal_events = 0,
        miss_events = 0,
        crit_events = 0,
        total_damage = 0,
        total_healing = 0,
        dps = 0,
        hps = 0,
        per_unit = {},
    }

    for entry in iter_window(window)() do
        summary.total_events = summary.total_events + 1

        if entry.event_type == "MISS" then
            summary.miss_events = summary.miss_events + 1
        elseif entry.event_type == "CRIT" then
            summary.crit_events = summary.crit_events + 1
        elseif entry.amount_kind == "HEAL" then
            summary.heal_events = summary.heal_events + 1
        else
            summary.damage_events = summary.damage_events + 1
        end

        local key = entry.caster_token or "unknown"
        local bucket = summary.per_unit[key]

        if not bucket then
            bucket = {
                unit = entry.caster,
                unit_label = entry.caster_label,
                damage = 0,
                healing = 0,
                events = 0,
                misses = 0,
                crits = 0,
            }
            summary.per_unit[key] = bucket
        end

        bucket.events = bucket.events + 1

        if entry.amount_kind == "HEAL" then
            bucket.healing = bucket.healing + entry.amount
            summary.total_healing = summary.total_healing + entry.amount
        else
            bucket.damage = bucket.damage + entry.amount
            summary.total_damage = summary.total_damage + entry.amount
        end

        if entry.event_type == "MISS" then
            bucket.misses = bucket.misses + 1
        elseif entry.event_type == "CRIT" then
            bucket.crits = bucket.crits + 1
        end
    end

    local safe_window = math.max(window, 0.001)
    summary.dps = summary.total_damage / safe_window
    summary.hps = summary.total_healing / safe_window

    for _, bucket in pairs(summary.per_unit) do
        bucket.dps = bucket.damage / safe_window
        bucket.hps = bucket.healing / safe_window
        bucket.window = window
        bucket.since = cutoff
    end

    return summary
end

function M.get_damage_meter_replacement(seconds)
    return M.get_dps_hps_per_unit(seconds)
end

function M.get_replay(seconds)
    local window = clamp_window(seconds)
    local now = now_seconds()
    local since = now - window
    local source_events = get_events_for_window(window)
    local replay = {
        window = window,
        since = since,
        until_time = now,
        total_events = #source_events,
        events = {},
    }

    for i = 1, #source_events do
        local entry = source_events[i]
        replay.events[i] = {
            timestamp = entry.timestamp,
            offset = entry.timestamp - since,
            spell_id = entry.spell_id,
            spell_name = entry.spell_name,
            caster = entry.caster,
            caster_label = entry.caster_label,
            target = entry.target,
            target_label = entry.target_label,
            amount = entry.amount,
            amount_kind = entry.amount_kind,
            event_type = entry.event_type,
        }
    end

    return replay
end

M.get_replay_frames = M.get_replay

function M._handle_spell_cast(data)
    if type(data) ~= "table" then
        return
    end

    local entry = build_entry(data)
    if not entry then
        return
    end

    push_entry(entry)
end

if core and core.register_on_spell_cast_callback then
    core.register_on_spell_cast_callback(M._handle_spell_cast)
end

M._entries = entries

-- ---------------------------------------------------------------------------
-- Subscriber hooks for other modules (e.g. incoming heal predictor)
-- ---------------------------------------------------------------------------

M._subscribers = {}

function M.subscribe(callback)
    if type(callback) == "function" then
        table.insert(M._subscribers, callback)
    end
end

function M._notify_subscribers(entry)
    for i = 1, #M._subscribers do
        local cb = M._subscribers[i]
        if cb then
            pcall(cb, entry)
        end
    end
end

local _original_push_entry = push_entry
local function push_entry(entry)
    tail = tail + 1
    entries[tail] = entry
    prune(entry.timestamp)
    M._notify_subscribers(entry)
end

return M
