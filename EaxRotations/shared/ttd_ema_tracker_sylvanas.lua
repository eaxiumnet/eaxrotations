-- ============================================================================
-- Shared Helper: Exponential Moving Average Time-To-Die (TTD) Tracker
-- ============================================================================
-- What:   Computes per-unit incoming DPS using an exponential moving average
--         over recent combat-log events, then derives TTD = current_hp / ema_dps.
-- When:   Called every tick for enemy targets (TTD) and party members (incoming DPS).
-- Why:    Replaces the naive hp/incoming_dps formula used in healer specs with
--         actual observed damage data smoothed by EMA, reducing jitter and
--         improving predictive accuracy for stop-cast and triage decisions.
-- Safety: No API calls inside hot loop; queries the existing combat_log_parser
--         rolling buffer. Falls back to 0 DPS / nil TTD when data is insufficient.
--
-- Usage:
--   local ema = require("shared/ttd_ema_tracker_sylvanas")
--   local state = ema.update(target, NS.time_now())
--   local ttd = ema.get_ttd(target, NS.time_now())
--   local incoming = ema.get_incoming_dps(target)
-- ============================================================================

local M = {}

local _G = _G
local NS = _G.EaxRotations

-- Lazy-load parser to avoid circular dependency at module init time
local function get_parser()
    if M._parser then return M._parser end
    local ok, parser = pcall(require, "shared/combat_log_parser_sylvanas")
    if ok and type(parser) == "table" then
        M._parser = parser
        return parser
    end
    return nil
end

-- Per-unit state: { last_update, ema_dps, last_instant_dps, sample_count }
local _state = {}

-- Configuration
local EMA_ALPHA = 0.35           -- Higher = more responsive to damage spikes
local DEFAULT_WINDOW = 5.0       -- Seconds of event history to consider
local MIN_WINDOW = 1.5         -- Need at least this much elapsed time
local MIN_SAMPLES = 2          -- Need at least this many damage events
local MAX_TTD = 300              -- Cap TTD at 5 minutes
local PRUNE_INTERVAL = 30.0    -- How often to prune stale entries
local PRUNE_AGE = 120.0        -- Remove units not updated in 2 minutes

local _last_prune = 0

-- ============================================================================
-- Safe unit GUID / token extraction
-- ============================================================================
local function unit_guid(unit)
    if not unit then return nil end
    local ok, guid = pcall(function()
        return unit.get_guid and unit:get_guid()
            or unit.guid
            or unit.id
    end)
    if ok and guid and guid ~= "" then return tostring(guid) end
    -- Fallback: try name-based identifiers (avoid tostring(unit) which uses recycled pointer addresses)
    local ok2, name = pcall(function()
        return unit.get_name and unit:get_name()
            or unit.get_display_name and unit:get_display_name()
            or unit.name
    end)
    if ok2 and name and name ~= "" then return "unit:" .. tostring(name) end
    return nil
end

-- ============================================================================
-- Prune stale unit entries to prevent unbounded growth
-- ============================================================================
local function prune_stale(now)
    if now - _last_prune < PRUNE_INTERVAL then return end
    _last_prune = now
    for guid, st in pairs(_state) do
        if type(st.last_update) == "number" and (now - st.last_update) > PRUNE_AGE then
            _state[guid] = nil
        end
    end
end

-- ============================================================================
-- Query combat log parser for damage events against target in window
-- ============================================================================
local function get_damage_to_target(target, window)
    local parser = get_parser()
    if not parser or not parser.get_events_by_target then return 0, 0, 0 end

    local events = parser.get_events_by_target(target)
    if type(events) ~= "table" then return 0, 0, 0 end

    local now = (NS and NS.time_now and NS.time_now()) or os.clock()
    local cutoff = now - window
    local total = 0
    local count = 0
    local earliest = now

    for i = 1, #events do
        local e = events[i]
        if type(e) == "table" then
            local ts = tonumber(e.timestamp) or now
            if ts >= cutoff then
                -- Count non-heal damage. Guard against events where amount is nil or non-numeric.
                local dmg = tonumber(e.amount) or tonumber(e.damage) or 0
                local is_heal = e.amount_kind == "HEAL" or e.is_heal == true
                if not is_heal and dmg > 0 then
                    total = total + dmg
                    count = count + 1
                    if ts < earliest then earliest = ts end
                end
            end
        end
    end

    local elapsed = now - earliest
    return total, count, elapsed
end

-- ============================================================================
-- Core update: compute EMA DPS for a unit
-- ============================================================================
function M.update(target, now, window_seconds)
    if not target or not now then return nil end

    local guid = unit_guid(target)
    if not guid then return nil end

    local window = type(window_seconds) == "number" and window_seconds or DEFAULT_WINDOW
    local total, count, elapsed = get_damage_to_target(target, window)

    local st = _state[guid]
    if not st then
        st = { ema_dps = 0, last_update = now, sample_count = 0 }
        _state[guid] = st
    end

    prune_stale(now)

    -- Not enough data: preserve previous EMA but mark as stale
    if count < MIN_SAMPLES or elapsed < MIN_WINDOW then
        st.last_update = now
        st.sample_count = count
        return { incoming_dps = st.ema_dps, sample_count = count, elapsed = elapsed, reliable = false }
    end

    local instant_dps = total / math.max(elapsed, 0.001)

    -- Bootstrap: first reliable sample seeds EMA directly
    if st.sample_count == 0 or st.ema_dps == 0 then
        st.ema_dps = instant_dps
    else
        st.ema_dps = EMA_ALPHA * instant_dps + (1.0 - EMA_ALPHA) * st.ema_dps
    end

    st.last_update = now
    st.sample_count = count
    st.last_instant_dps = instant_dps

    return { incoming_dps = st.ema_dps, sample_count = count, elapsed = elapsed, reliable = true }
end

-- ============================================================================
-- Get cached incoming DPS (does NOT refresh from parser)
-- ============================================================================
function M.get_incoming_dps(target)
    if not target then return 0 end
    local guid = unit_guid(target)
    if not guid then return 0 end
    local st = _state[guid]
    return st and st.ema_dps or 0
end

-- ============================================================================
-- Compute TTD using cached EMA DPS and current unit HP
-- ============================================================================
function M.get_ttd(target, now)
    if not target then return nil end
    local incoming = M.get_incoming_dps(target)
    if incoming <= 0 then return nil end

    local hp = 0
    local max_hp = 0

    -- Try health APIs safely
    local ok1, h = pcall(function()
        return target.get_health and target:get_health() or target.hp
    end)
    local ok2, m = pcall(function()
        return target.get_max_health and target:get_max_health() or target.max_hp
    end)
    if ok1 and type(h) == "number" then hp = h end
    if ok2 and type(m) == "number" and m > 0 then max_hp = m end

    if hp <= 0 or max_hp <= 0 then
        -- Fall back to percentage only: cannot compute absolute TTD without max HP
        -- because division (pct / incoming) would treat percentage as raw HP, giving
        -- wildly incorrect results (e.g. 50% HP / 100 DPS = 0.5s instead of actual TTD).
        -- Return nil and let callers fall through to regression/engine/simple TTD.
        return nil
    end

    local ttd = hp / incoming
    if ttd > MAX_TTD then ttd = MAX_TTD end
    if ttd <= 0 then return nil end
    return ttd
end

-- ============================================================================
-- Reset state for a specific unit (e.g. on target swap / death)
-- ============================================================================
function M.reset(target_or_guid)
    local guid = type(target_or_guid) == "string" and target_or_guid or unit_guid(target_or_guid)
    if guid then _state[guid] = nil end
end

-- ============================================================================
-- Wipe all tracked state (e.g. on /reload or profile swap)
-- ============================================================================
function M.clear_all()
    for k in pairs(_state) do _state[k] = nil end
    _last_prune = 0
end

-- ============================================================================
-- Export to NS namespace
-- ============================================================================
_G.TTDEmaTracker = M
if NS then
    NS.TTDEmaTracker = M
end

return M
