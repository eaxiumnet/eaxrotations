-- session_recorder_sylvanas.lua — bounded, opt-in recording of a live quester session.
-- WHAT:  start/stop a fixed-capacity event ring; record log lines and structured state/navigation
--        events; export the chronological session as dependency-free JSONL.
-- WHEN:  a developer starts it from the live quester, reproduces a failure, then exports the
--        session for tools/replay_session.py. The recorder is inert until start() is called.
-- WHY:   a live quest-loop bug is a sequence of decisions, not one log line. A bounded recorder
--        preserves that sequence without adding per-tick allocations or requiring a client file
--        API; the replay runner can turn the export into a failing regression test.
-- SAFETY: opt-in and fail-soft. No io, os, network, or client mutation; the ring is preallocated;
--        malformed values are stringified and export is plain JSONL. Missing core.time is harmless.
-- DECISION: the recorder is deliberately separate from utils.debug_log: the quester can keep its
--        existing debug output policy, while a session explicitly opts into capture.

local M = {}

local CAPACITY = 2048
local FIELD_NAMES = {
    "message", "from", "to", "index", "x", "y", "z", "raw_z", "terrain_fixed",
    "distance_yds", "retry", "reason", "count", "capacity",
}

local _core_time = core and core.time or function() return 0 end
local _events = {}
for i = 1, CAPACITY do _events[i] = {} end

local _enabled = false
local _count = 0
local _next_index = 1
local _sequence = 0
local _started_at = 0

local function clock()
    local ok, value = pcall(_core_time)
    if ok and type(value) == "number" then return value end
    return 0
end

local function clear_slot(slot)
    slot.kind = nil
    slot.message = nil
    slot.seq = nil
    slot.t = nil
    for i = 1, #FIELD_NAMES do slot[FIELD_NAMES[i]] = nil end
end

local function append_event(kind, fields, at)
    if not _enabled then return false end

    local slot = _events[_next_index]
    clear_slot(slot)
    _next_index = _next_index + 1
    if _next_index > CAPACITY then _next_index = 1 end
    _count = _count + 1
    if _count > CAPACITY then _count = CAPACITY end
    _sequence = _sequence + 1

    slot.kind = tostring(kind or "event")
    slot.seq = _sequence
    slot.t = tonumber(at) or clock()
    if fields then
        for i = 1, #FIELD_NAMES do
            local name = FIELD_NAMES[i]
            local value = fields[name]
            if value ~= nil then slot[name] = value end
        end
    end
    return true
end

local function json_quote(value)
    value = tostring(value or "")
    local out = { '"' }
    for i = 1, #value do
        local c = value:sub(i, i)
        local code = value:byte(i)
        if c == '"' then
            out[#out + 1] = '\\"'
        elseif c == "\\" then
            out[#out + 1] = "\\\\"
        elseif c == "\n" then
            out[#out + 1] = "\\n"
        elseif c == "\r" then
            out[#out + 1] = "\\r"
        elseif c == "\t" then
            out[#out + 1] = "\\t"
        elseif code < 32 then
            out[#out + 1] = string.format("\\u%04x", code)
        else
            out[#out + 1] = c
        end
    end
    out[#out + 1] = '"'
    return table.concat(out)
end

local function json_value(value)
    local value_type = type(value)
    if value_type == "string" then return json_quote(value) end
    if value_type == "boolean" then return value and "true" or "false" end
    if value_type == "number" then
        if value ~= value or value == math.huge or value == -math.huge then return "null" end
        return tostring(value)
    end
    return "null"
end

local function event_json(slot)
    local parts = {
        '"seq":' .. tostring(slot.seq or 0),
        '"t":' .. tostring(slot.t or 0),
        '"kind":' .. json_quote(slot.kind or "event"),
    }
    for i = 1, #FIELD_NAMES do
        local name = FIELD_NAMES[i]
        local value = slot[name]
        if value ~= nil then
            parts[#parts + 1] = json_quote(name) .. ":" .. json_value(value)
        end
    end
    return "{" .. table.concat(parts, ",") .. "}"
end

--- Begin a new recording. Existing events are discarded, not appended across sessions.
function M.start(at)
    _enabled = true
    _count = 0
    _next_index = 1
    _sequence = 0
    _started_at = tonumber(at) or clock()
    append_event("session_start", { capacity = CAPACITY, count = 0 }, _started_at)
    return true
end

--- Record one existing debug/info message. Disabled recorders return false without doing work.
function M.record_log(message, at)
    if not _enabled then return false end
    return append_event("log", { message = tostring(message or "") }, at)
end

--- Record a bounded structured event. Only known scalar fields are retained.
function M.record_event(kind, fields, at)
    if not _enabled then return false end
    return append_event(kind, fields, at)
end

--- Export the current ring as JSONL without changing recording state.
function M.export_jsonl()
    local first = 1
    if _count == CAPACITY then first = _next_index end
    local lines = {}
    for i = 0, _count - 1 do
        local index = first + i
        if index > CAPACITY then index = index - CAPACITY end
        lines[#lines + 1] = event_json(_events[index])
    end
    return table.concat(lines, "\n") .. (_count > 0 and "\n" or "")
end

--- Finish the session and return its JSONL export. The stop marker is part of the export.
function M.stop(at)
    if not _enabled then return M.export_jsonl() end
    local final_count = _count + 1
    if final_count > CAPACITY then final_count = CAPACITY end
    append_event("session_stop", { count = final_count }, at)
    _enabled = false
    return M.export_jsonl()
end

--- Forget the session and disable capture. Primarily a test/development reset.
function M.reset()
    _enabled = false
    _count = 0
    _next_index = 1
    _sequence = 0
    _started_at = 0
    for i = 1, CAPACITY do clear_slot(_events[i]) end
end

function M.is_enabled() return _enabled end
function M.count() return _count end
function M.capacity() return CAPACITY end

_G.EaxAutoQuester = _G.EaxAutoQuester or {}
_G.EaxAutoQuester.session_recorder = M

return M
