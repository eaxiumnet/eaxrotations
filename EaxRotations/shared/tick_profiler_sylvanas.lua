-- tick_profiler_sylvanas.lua -- capture observed tick periods and report histograms.
-- WHAT:   capture observed tick periods and report histograms
-- WHEN:   diagnostic; called only when menu flag set
-- WHY:    lets user verify we are not missing ticks in cluttered fights
-- SAFETY: no allocations in tick path; opt-in only
-- DECISION: pure helper consumed via require() by specs; no on_update side-effects.

-- Tick Profiler: measures per-tick CPU time of the rotation dispatcher.
--
-- What:  Wraps on_rotation_update() with core.cpu_time() timing, stores rolling
--        statistics (min/avg/max) in a ring buffer, and exposes formatted
--        lines for the dashboard custom_lines display.
-- When:  Every tick, at the top and bottom of the main dispatcher.
-- Why:   Lets users see the real-world CPU impact of the rotation system
--        directly in-game via the dashboard overlay.
-- Safety:Stateless ring buffer (no allocations after init). core.cpu_time() has
--        ns precision and negligible call overhead. os library is unavailable
--        in the Sylvanas sandbox.
-- Decision:Separate module so the dispatcher stays clean. Dashboard reads
--        via custom_lines function references (lazy eval each frame).

local _G = _G
local NS = _G.EaxRotations
if not NS then return nil end

local core = _G.core
local _cpu_time = core and core.cpu_time

local M = {}

-- Ring buffer capacity — last N tick timings
local RING_SIZE = 60
local _times = {}
local _head = 0
local _count = 0

-- Running statistics, computed lazily
local _cached_min = 0
local _cached_max = 0
local _cached_avg = 0
local _dirty = true

-- Peak tracking (60-second sliding window, 1-second buckets)
local PEAK_BUCKETS = 60          -- 60 × 1s buckets = 60s window
local _peak_buckets = {}
local _peak_head = 0

-- ============================================================================
-- Public API
-- ============================================================================

--- Called at the START of the dispatcher, returns a timestamp for pairing.
function M.begin_tick()
    if _cpu_time then return _cpu_time() end
    return 0
end

--- Called at the END of the dispatcher with the begin_tick() value.
--- Records elapsed time in the ring buffer.
function M.end_tick(begin)
    local now = _cpu_time and _cpu_time() or 0
    local elapsed = now - begin
    local us = elapsed / 1e3  -- convert ns to microseconds

    -- Ring buffer insert
    _head = _head + 1
    if _head > RING_SIZE then _head = 1 end
    _times[_head] = us
    if _count < RING_SIZE then _count = _count + 1 end

    _dirty = true

    -- Peak tracking: store elapsed in current 1-second bucket
    now = NS.time_now and NS.time_now() or 0
    local bucket_index = math.floor(now) % PEAK_BUCKETS + 1
    _peak_buckets[bucket_index] = math.max(_peak_buckets[bucket_index] or 0, us)
end

--- Recompute min/avg/max from ring buffer.
local function recompute()
    if _count == 0 then
        _cached_min, _cached_max, _cached_avg = 0, 0, 0
        _dirty = false
        return
    end

    local sum = 0
    local min_val, max_val = 1e9, 0
    for i = 1, _count do
        local v = _times[i] or 0
        sum = sum + v
        min_val = math.min(min_val, v)
        max_val = math.max(max_val, v)
    end

    _cached_min = min_val
    _cached_max = max_val
    _cached_avg = sum / _count
    _dirty = false
end

--- Returns { min_us, avg_us, max_us, peak_60s_us, sample_count }.
function M.get_metrics()
    if _dirty then recompute() end

    -- Peak from sliding 60s window: scan all recent buckets
    local peak_60s = 0
    for i = 1, PEAK_BUCKETS do
        local v = _peak_buckets[i] or 0
        if v > peak_60s then peak_60s = v end
    end

    return {
        min_us = _cached_min,
        avg_us = _cached_avg,
        max_us = _cached_max,
        peak_60s_us = peak_60s,
        sample_count = _count,
    }
end

--- Returns a formatted one-line summary for the dashboard.
--- Example: "Tick: 42.3us (avg 38.1us | peak 156.2us)"
function M.get_tick_line()
    local m = M.get_metrics()
    if m.sample_count == 0 then return "Tick: ..." end
    return string.format("Tick: %.1fus (avg %.1f | peak %.1f) n=%d",
        m.min_us, m.avg_us, m.peak_60s_us, m.sample_count)
end

--- Returns estimated FPS impact line.
--- At 60fps, each frame has ~16.67ms budget. At 10 ticks/sec, each tick
--- consumes its avg_us portion of that budget.
--- Example: "FPS impact: 0.2% (avg) | 0.9% (peak)"
function M.get_fps_line()
    local m = M.get_metrics()
    if m.sample_count == 0 then return "FPS: ..." end

    -- At 10 ticks/sec = 100ms between ticks
    -- Frame budget at 60fps = 16.67ms
    local frame_budget_us = 16666.67  -- 16.67ms in us
    local avg_pct = (m.avg_us / frame_budget_us) * 100
    local peak_pct = (m.peak_60s_us / frame_budget_us) * 100

    return string.format("FPS impact: %.2f%% (avg) | %.2f%% (peak 60s)",
        avg_pct, peak_pct)
end

--- Reset all data.
function M.reset()
    for i = 1, RING_SIZE do _times[i] = nil end
    for i = 1, PEAK_BUCKETS do _peak_buckets[i] = nil end
    _head = 0
    _count = 0
    _dirty = true
end

-- ============================================================================
-- Register dashboard custom lines (lazy — called each render frame)
-- ============================================================================
if NS.SetDashboardConfig then
    NS.SetDashboardConfig({
        custom_lines = {
            function() return M.get_tick_line() end,
            function() return M.get_fps_line() end,
        }
    })
end

NS.TickProfiler = M
M.reset()

return M
