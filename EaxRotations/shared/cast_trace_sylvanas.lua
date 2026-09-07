-- cast_trace_sylvanas.lua — In-game "why is it casting X" trace subsystem.
-- WHAT:  bounded ring buffer of recent rotation casts (the rule that fired +
--        the key state behind it), toggle-gated so the disabled path costs
--        nothing. Owns the full trace surface: record, ring, readout
--        formatting, clear/print actions.
-- WHEN:  required by main_sylvanas (dispatch hook records per executed cast)
--        and by core/diagnostics (thin delegation so NS.CastTrace exists in
--        any boot order); the Diagnostics sections of main.lua and the
--        declarative menu consume NS.CastTrace for the Last-Casts readout.
-- WHY:   a player in combat should be able to ask why a spell just fired and
--        get the decision rule + live state (e.g. "Rip: rip_remains=0.4,
--        combo_points=5"). Subsystem home is shared/ (sibling of
--        control_panel_sylvanas.lua etc.), NOT boot-critical core code.
-- SAFETY: recording only happens while NS._TRACE_CASTS is true (Diagnostics
--        "Trace Casts" checkbox, synced per tick by main.lua). The disabled
--        path is an early return before any allocation; the enabled path
--        writes into preallocated ring slots (last 32), so the hot path costs
--        nothing when the toggle is off.

local NS = _G.EaxRotations or {}
local M = {}

local MAX_ENTRIES = 32
local _slots = {}
for i = 1, MAX_ENTRIES do
    _slots[i] = { t = 0, list = "", lane = "", detail = "", seq = 0 }
end
local _head = 1    -- next slot to write (ring cursor)
local _count = 0   -- live entries (grows to MAX_ENTRIES, then stays)
local _seq = 0     -- monotonically increasing write counter
local _probe = 0   -- record() invocation counter (zero-alloc test observer)
local CT_EMPTY = {}  -- shared empty return: idle readout path allocates nothing per frame

-- Enabled when the Diagnostics "Trace Casts" checkbox is on (main.lua syncs
-- the widget to NS._TRACE_CASTS every tick, same pattern as _DEBUG_SWING_TIMER).
function M.enabled()
    return NS._TRACE_CASTS == true
end

-- Format one state value for a one-line readout.
local function fmt_value(v)
    local tv = type(v)
    if tv == "number" then
        if v ~= v then return "?" end -- NaN
        if math.abs(v) >= 100 or v == math.floor(v) then
            return string.format("%.0f", v)
        end
        return string.format("%.1f", v)
    elseif tv == "boolean" then
        return v and "true" or "false"
    elseif tv == "string" then
        return v ~= "" and v or nil
    end
    return nil
end

-- Build the "why" detail: for strategies compiled from the declarative DSL the
-- compiler attaches strategy._dsl_watch — the state/context fields its
-- conditions read (max 4). Read their live values at cast time. Non-DSL lanes
-- carry no watch list and fall back to lane-name-only entries.
local function build_detail(strategy, context, state)
    local watch = strategy and strategy._dsl_watch
    if not watch or #watch == 0 then return "" end
    local parts = {}
    for i = 1, #watch do
        local w = watch[i]
        local value
        if w.src == "state" then
            value = state and state[w.field]
        else
            value = context and context[w.field]
        end
        if value ~= nil then
            local text = fmt_value(value)
            if text then parts[#parts + 1] = w.field .. "=" .. text end
        end
        if #parts >= 4 then break end
    end
    return table.concat(parts, " ")
end

-- Record one executed cast. Early-returns before any allocation when the trace
-- is off, so the disabled path costs nothing beyond the call itself.
function M.record(list_name, strategy, context, state)
    _probe = _probe + 1
    if not M.enabled() then return end
    local slot = _slots[_head]
    slot.t = (NS.time_now and NS.time_now()) or 0
    slot.list = list_name or ""
    slot.lane = tostring(strategy and strategy.name or "?")
    slot.detail = build_detail(strategy, context, state)
    slot.seq = _seq
    _seq = _seq + 1
    _head = _head % MAX_ENTRIES + 1
    if _count < MAX_ENTRIES then _count = _count + 1 end
end

-- Newest-first structured copies of the last n entries (n capped at 32).
-- Returns the shared CT_EMPTY table when nothing is recorded so the idle
-- readout path performs zero per-frame allocation.
function M.recent(n)
    if _count == 0 then return CT_EMPTY end
    n = n and math.min(n, MAX_ENTRIES) or MAX_ENTRIES
    local out = {}
    -- Newest written slot is always (_head - 1) wrapped (the ring cursor
    -- points at the next slot to write). Walk backwards from it.
    local idx = _head - 1
    if idx == 0 then idx = MAX_ENTRIES end
    for i = 1, math.min(n, _count) do
        local slot = _slots[idx]
        out[#out + 1] = { t = slot.t, list = slot.list, lane = slot.lane, detail = slot.detail }
        idx = idx - 1
        if idx < 1 then idx = MAX_ENTRIES end
    end
    return out
end

-- One-line rendering of the last n entries (newest first), e.g.
--   [rotation] Rip: rip_remains=0.4 combo_points=5
--   [rotation] FerociousBite
function M.lines(n)
    local entries = M.recent(n)
    if #entries == 0 then return CT_EMPTY end
    local out = {}
    for i = 1, #entries do
        local e = entries[i]
        local line = "[" .. e.list .. "] " .. e.lane
        if e.detail and e.detail ~= "" then
            line = line .. ": " .. e.detail
        end
        out[#out + 1] = line
    end
    return out
end

-- Clear the trace.
function M.clear()
    _head = 1
    _count = 0
    _seq = 0
end

-- Live entry count (test surface).
function M.count()
    return _count
end

-- record() invocation counter — lets the zero-alloc test assert the disabled
-- path never reaches the recorder body, independent of GC measurement.
function M.probe()
    return _probe
end

-- Player-facing print of the last n casts through the addon log.
function M.print_recent(n)
    local lines = M.lines(n)
    if #lines == 0 then
        if NS.log then NS.log("[CastTrace] no casts recorded (enable Diagnostics -> Trace Casts while fighting)") end
        return
    end
    for i = 1, #lines do
        if NS.log then NS.log("[CastTrace] " .. lines[i]) end
    end
end

NS.CastTrace = M
return M
