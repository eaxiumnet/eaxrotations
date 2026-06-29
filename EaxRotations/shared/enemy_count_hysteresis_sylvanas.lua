-- enemy_count_hysteresis_sylvanas.lua
-- WHAT:  Sliding-window enemy count with rise/drop hysteresis.
-- WHEN:  Called every frame/update to smooth raw enemy count readings.
-- WHY:   Prevents rapid ST↔AoE oscillation when enemies spike in/out of range.
-- SAFETY: Static state table — zero allocations per call. Nil-safe defaults.
-- DECISION: anti-flap target-count buffer; pure setter/getter.

local M = {}

-- Configurable hold windows (ms). Defaults match TBC raid-DPS latency budget.
M.RISE_HOLD_MS = 500
M.DROP_HOLD_MS = 2000

-- Static state — reused every frame (AGENTS Pattern 4)
local _state = {
    smoothed = 0,
    pending = 0,
    rise_until = 0,
    drop_until = 0,
}

local function clamp_nonneg(n)
    if type(n) ~= "number" then return 0 end
    return n < 0 and 0 or n
end

--- Tune hold windows at runtime. Negative inputs clamp to 0 (no filter).
function M.configure(opts)
    if type(opts) ~= "table" then return end
    if opts.rise_hold_ms ~= nil then M.RISE_HOLD_MS = clamp_nonneg(opts.rise_hold_ms) end
    if opts.drop_hold_ms ~= nil then M.DROP_HOLD_MS = clamp_nonneg(opts.drop_hold_ms) end
    -- NOTE: do NOT reset _state.rise_until / _state.drop_until here.
    -- main_sylvanas.lua calls configure() every frame (to pick up live setting
    -- changes); resetting the hold timers each frame defeats the drop/rise hold
    -- windows (now >= 0 is always true on the 2nd frame of a drop). Tests call
    -- M.reset() explicitly for isolation, so a timer reset here is redundant AND
    -- harmful. Tuning hold windows must not disturb active holds.
end

--- Update with raw enemy count and current time (ms epoch).
function M.update(raw_count, now_ms)
    raw_count = raw_count or 0
    now_ms = now_ms or 0

    if raw_count > _state.smoothed then
        if _state.pending <= _state.smoothed then
            _state.pending = raw_count
            _state.rise_until = now_ms + M.RISE_HOLD_MS
        elseif raw_count > _state.pending then
            _state.pending = raw_count
        end
        if now_ms >= _state.rise_until then
            _state.smoothed = _state.pending
        end
    elseif raw_count < _state.smoothed then
        if _state.pending >= _state.smoothed then
            _state.pending = raw_count
            _state.drop_until = now_ms + M.DROP_HOLD_MS
        elseif raw_count < _state.pending then
            _state.pending = raw_count
        end
        if now_ms >= _state.drop_until then
            _state.smoothed = _state.pending
        end
    else
        _state.pending = raw_count
        _state.rise_until = now_ms
        _state.drop_until = now_ms
    end
end

--- Return the smoothed enemy count (integer >= 0, never nil).
function M.smoothed_count()
    return _state.smoothed or 0
end

--- Hard reset of internal state (useful on combat exit / test isolation).
function M.reset()
    _state.smoothed = 0
    _state.pending = 0
    _state.rise_until = 0
    _state.drop_until = 0
end

_G.EnemyCountHysteresis = M

return M
