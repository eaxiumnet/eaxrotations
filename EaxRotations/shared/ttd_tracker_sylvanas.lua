-- ============================================================================
-- Shared Helper: Linear Regression Time-To-Die (TTD) Tracker
-- ============================================================================
-- What:   Estimates how long a target will live by fitting a line to recent
--         health-percentage samples and extrapolating to 0%.
-- When:   Called every tick while in combat with a valid enemy target.
-- Why:    Engine-provided TTD (time_to_die / get_time_to_death) is often
--         missing or inaccurate on private servers. A local regression model
--         gives reliable boss-fight decisions for dot refresh, execute phase,
--         and cooldown gating.
-- Safety: Pure Lua math — no API calls inside regression. Samples are throttled
--         and windowed to prevent unbounded memory. Returns nil when data is
--         insufficient or the slope implies the target is healing.
--
-- Usage (production):
--   local ttd_tracker = require("shared/ttd_tracker_sylvanas")
--   local ttd = ttd_tracker.update(target, NS.time_now(), context.settings)
--   -- ttd is nil (unknown) or a positive number (seconds)
--
-- Usage (test — dofile pattern):
--   dofile("EaxRotations/shared/ttd_tracker_sylvanas.lua")
--   local M = _G.TTDTracker
-- ============================================================================

local M = {}

-- Static buffers for linear regression (Pattern 4 — eliminate per-call allocation)
local _xs, _ys = {}, {}
-- Per-target rolling sample history.
-- Keys are target GUID strings; values are arrays of { t = timestamp, hp = hp_pct }.
local _samples = {}

-- Throttle: last sample time per target GUID.
local _last_sample_time = {}

-- Remember the last target GUID so we can detect target swaps.
local _last_guid = nil

-- Default constants (overridden by settings when provided)
local DEFAULT_SAMPLE_INTERVAL = 0.5   -- seconds between samples
local DEFAULT_WINDOW          = 12    -- keep samples from last N seconds
local DEFAULT_MIN_SAMPLES     = 4     -- need at least this many points
local DEFAULT_MAX_TTD         = 300   -- cap predictions at 5 minutes

-- ============================================================================
-- Simple least-squares linear regression on two pre-allocated arrays.
-- Computes slope (m) and intercept (b) for y = m*x + b.
-- Returns (slope, intercept) or (nil, nil) if computation is impossible.
-- ============================================================================
local function linear_regression(xs, ys, n)
    if n < 2 then return nil, nil end

    local sum_x, sum_y, sum_xy, sum_xx = 0, 0, 0, 0
    for i = 1, n do
        local x = xs[i]
        local y = ys[i]
        sum_x  = sum_x + x
        sum_y  = sum_y + y
        sum_xy = sum_xy + x * y
        sum_xx = sum_xx + x * x
    end

    local denom = n * sum_xx - sum_x * sum_x
    if denom == 0 then return nil, nil end

    local slope = (n * sum_xy - sum_x * sum_y) / denom
    local intercept = (sum_y - slope * sum_x) / n
    return slope, intercept
end

-- ============================================================================
-- Extract a target GUID safely.
-- ============================================================================
local function target_guid(target)
    if not target then return nil end
    local ok, guid = pcall(function()
        return target.get_guid and target:get_guid()
            or target.guid
            or target.id
            or tostring(target)
    end)
    if ok and guid and guid ~= "" then return tostring(guid) end
    return nil
end

-- ============================================================================
-- Read target HP % safely.
-- ============================================================================
local function target_hp_pct(target)
    if not target then return nil end
    -- Prefer NS.unit_health_pct if available (standard Eax helper)
    local NS = _G.EaxRotations
    if NS and NS.unit_health_pct then
        local ok, hp = pcall(NS.unit_health_pct, target)
        if ok and type(hp) == "number" then return hp end
    end
    -- Direct field fallbacks
    local ok, hp = pcall(function()
        return target.get_health_percentage and target:get_health_percentage()
            or target.get_health and target:get_health()
    end)
    if ok and type(hp) == "number" then return hp end
    return nil
end

-- ============================================================================
-- Clean up samples older than the rolling window.
-- ============================================================================
local function prune_old_samples(guid, now, window)
    local history = _samples[guid]
    if not history then return end
    local cutoff = now - window
    local write_i = 1
    for read_i = 1, #history do
        local sample = history[read_i]
        if sample.t >= cutoff then
            history[write_i] = sample
            write_i = write_i + 1
        end
    end
    for i = write_i, #history do history[i] = nil end
    if write_i == 1 then
        _samples[guid] = nil
        _last_sample_time[guid] = nil
    end
end

-- ============================================================================
-- Remove all state for a target (e.g. on combat end or target swap).
-- ============================================================================
function M.reset(target_or_guid)
    local guid = type(target_or_guid) == "string" and target_or_guid or target_guid(target_or_guid)
    if guid then
        _samples[guid] = nil
        _last_sample_time[guid] = nil
    end
    if _last_guid == guid then _last_guid = nil end
end

-- ============================================================================
-- Wipe everything (useful on /reload or profile swap).
-- ============================================================================
function M.clear_all()
    for k in pairs(_samples) do _samples[k] = nil end
    for k in pairs(_last_sample_time) do _last_sample_time[k] = nil end
    _last_guid = nil
end

-- ============================================================================
-- Main entry: update the sample history for `target` and return the current
-- linear-regression TTD estimate (seconds), or nil if unavailable.
--
-- @param target   game_object — the enemy unit (may be nil).
-- @param now      number      — current time in seconds (e.g. NS.time_now()).
-- @param settings table|nil   — optional settings (see schema defaults).
-- @return number|nil          — estimated seconds until death, or nil.
-- ============================================================================
function M.update(target, now, settings)
    if not target or not now then return nil end

    local guid = target_guid(target)
    if not guid then return nil end

    -- Detect target swap: discard old target's history immediately.
    if _last_guid and _last_guid ~= guid then
        M.reset(_last_guid)
    end
    _last_guid = guid

    -- Resolve configurable parameters.
    local enabled = true
    local interval = DEFAULT_SAMPLE_INTERVAL
    local window = DEFAULT_WINDOW
    local min_samples = DEFAULT_MIN_SAMPLES
    local max_ttd = DEFAULT_MAX_TTD
    if type(settings) == "table" then
        if settings.ttd_linear_enabled == false then enabled = false end
        if type(settings.ttd_sample_interval) == "number" then interval = settings.ttd_sample_interval / 10 end
        if type(settings.ttd_window) == "number" then window = settings.ttd_window end
        if type(settings.ttd_min_samples) == "number" then min_samples = settings.ttd_min_samples end
        if type(settings.ttd_max_ttd) == "number" then max_ttd = settings.ttd_max_ttd end
    end
    if not enabled then return nil end

    -- Throttle sampling.
    local last_t = _last_sample_time[guid]
    if last_t and (now - last_t) < interval then
        -- Not time to sample yet; still try to compute from existing data.
    else
        local hp = target_hp_pct(target)
        if hp and hp > 0 and hp <= 100 then
            local history = _samples[guid]
            if not history then
                history = {}
                _samples[guid] = history
            end
            history[#history + 1] = { t = now, hp = hp }
            _last_sample_time[guid] = now
        end
    end

    -- Prune stale samples.
    prune_old_samples(guid, now, window)

    local history = _samples[guid]
    if not history or #history < min_samples then return nil end

    -- Build x,y arrays using time-since-first-sample for numerical stability.
    local n = #history
    local t0 = history[1].t
    -- Reuse static buffers (Pattern 4)
    for i = #_xs, 1, -1 do _xs[i] = nil end
    for i = #_ys, 1, -1 do _ys[i] = nil end
    for i = 1, n do
        _xs[i] = history[i].t - t0
        _ys[i] = history[i].hp
    end

    local slope, intercept = linear_regression(_xs, _ys, n)
    if not slope or not intercept then return nil end

    -- Slope must be negative (HP dropping) for a meaningful death prediction.
    -- A very flat slope also produces absurd TTD; require at least 0.01% per second.
    if slope >= -0.01 then return nil end

    -- Extrapolate to HP = 0:  0 = slope * x + intercept  =>  x = -intercept / slope
    local x_at_zero = -intercept / slope  -- seconds since first sample when HP hits 0
    local ttd = x_at_zero - (now - t0)       -- seconds from *now* until predicted death

    -- Sanity bounds.
    if ttd <= 0 then return nil end
    if ttd > max_ttd then return max_ttd end

    return ttd
end

-- ============================================================================
-- Returns the current HP decay rate in % per second for the tracked target.
-- Positive value = losing HP. Negative = gaining. Nil = insufficient data.
-- @param target_or_guid game_object|string
-- @return number|nil  HP% loss per second (positive = losing health)
-- ============================================================================
function M.get_decay_rate(target_or_guid)
    local guid = type(target_or_guid) == "string" and target_or_guid or target_guid(target_or_guid)
    if not guid then return nil end

    local history = _samples[guid]
    if not history or #history < 2 then return nil end

    local first = history[1]
    local last = history[#history]
    local dt = last.t - first.t
    if dt <= 0 then return nil end

    local dhp = first.hp - last.hp  -- positive = health dropped
    return dhp / dt
end

-- ============================================================================
-- Export to NS namespace (production path)
-- ============================================================================
local _G = _G
_G.TTDTracker = M
if _G.EaxRotations then
    _G.EaxRotations.TTDTracker = M
end

return M
