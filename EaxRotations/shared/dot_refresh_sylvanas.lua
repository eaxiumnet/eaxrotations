-- dot_refresh_sylvanas.lua -- APL-formula-driven DoT refresh gating helper.
-- WHAT:   APL-formula-driven DoT refresh gating helper.
-- WHEN:   called per-frame in shadow/affliction/balance specs
-- WHY:    centralises pandemic refresh math into one shared helper
-- SAFETY: uses NS.tbc_time; nil-guarded
-- DECISION: pure helper consumed via require() by specs; no on_update side-effects.

-- ============================================================================
-- Shared Helper: DoT Refresh Logic (APL Formula)
-- ============================================================================
-- Pure function implementing the APL's haste-aware DoT refresh formula:
--   dotRemaining < refresh_window AND remainingTime >= refresh_window + dotBaseDuration
--
-- For casted DoTs (Immolate, VT, UA): refresh_window = spell_cast_time (haste-aware)
-- For instant DoTs (Corruption, Curse, SW:P): refresh_window = early-refresh buffer (1.0-1.5s)
--
-- No NS/api/ dependencies — safe for unit testing.
--
--   local should_refresh_dot = NS.should_refresh_dot
--   local spell_cast_time = NS.spell_cast_time
--   -- Casted DoT (haste-aware):
--   if should_refresh_dot(dot_remaining, spell_cast_time(SPELLS.Immolate, 1.5), ttd, 15) then
--   -- Instant DoT (early-refresh buffer):
--   if should_refresh_dot(dot_remaining, 1.5, ttd, 18) then
--
-- Usage (unit test — dofile pattern):
--   dofile("EaxRotations/shared/dot_refresh_sylvanas.lua")
--   local should_refresh_dot = _G.DotRefresh.should_refresh_dot
--   ...same as above...
-- ============================================================================

local M = {}

-- ============================================================================
-- Wowhead DoT Tick Data Integration (Embedded)
-- ============================================================================
-- Reads periodic damage data from embedded spell detail tables.
-- to enrich DoT refresh decisions with tick interval and damage per tick.

local _dot_cache = {}  -- [spell_id] = {interval, amount, school, duration, total_ticks, total_damage} or false (miss)

---@class SpellDetailEntry
---Positional fields from bridge.spell_detail:
---  1=cost_type, 2=cost_amount, 3=range, 4=cast_time, 5=duration,
---  6=periodic_amount, 7=periodic_school, 8=periodic_interval, 9=flags, 10=school

-- Data bridge — loads embedded spell data (ship-safe Lua tables)
local _bridge = nil
local function get_bridge()
    if _bridge then return _bridge end
    local ok, mod = pcall(require, "shared/wowhead_data_bridge_sylvanas")
    if ok and type(mod) == "table" then
        _bridge = mod
        return mod
    end
    return nil
end

--- Get periodic damage (tick) data for a spell from embedded data.
-- Returns {interval, amount, school, duration, total_ticks, total_damage} or nil.
-- Cached after first read — safe to call every frame.
-- @param spell_id  number — spell ID
-- @return table|nil — {interval, amount, school, duration, total_ticks, total_damage} or nil if no periodic data
function M.get_dot_tick_data(spell_id)
    if not spell_id then return nil end
    local cached = _dot_cache[spell_id]
    if cached ~= nil then
        return cached or nil  -- cached is false for misses, table for hits
    end

    local bridge = get_bridge()
    if not bridge or not bridge.spell_detail then
        _dot_cache[spell_id] = false
        return nil
    end

    local detail = bridge.spell_detail[spell_id]
    if not detail then
        _dot_cache[spell_id] = false
        return nil
    end

    -- Bridge detail format: positional array
    -- 5=duration, 6=periodic_amount, 7=periodic_school, 8=periodic_interval
    local interval = detail[8] or 0
    local amount = detail[6] or 0
    local school = detail[7] or ""
    local duration = detail[5] or 0

    if interval <= 0 then
        _dot_cache[spell_id] = false
        return nil
    end

    local total_ticks = (duration > 0) and math.floor(duration / interval) or 0
    local result = {
        interval = interval,
        amount = amount,
        school = school,
        duration = duration,
        total_ticks = total_ticks,
        total_damage = amount * total_ticks,
    }
    _dot_cache[spell_id] = result
    return result
end

--- Get the total periodic damage for a spell (amount * total_ticks).
-- @param spell_id  number — spell ID
-- @return number|nil — total periodic damage over full duration, or nil if no data
function M.get_dot_total_damage(spell_id)
    local tick = M.get_dot_tick_data(spell_id)
    if not tick or tick.interval <= 0 then return nil end
    if tick.total_damage and tick.total_damage > 0 then return tick.total_damage end
    -- Fallback: per-tick amount (caller must multiply by tick count)
    return tick.amount
end

--- Get the DPS (damage per second) for a DoT spell from wowhead tick data.
-- Returns damage_per_tick / tick_interval, or nil if no data.
-- Useful for comparing DoT efficiency or calculating damage contribution.
-- @param spell_id  number — spell ID
-- @return number|nil — DPS from periodic damage, or nil if no data
function M.get_dot_dps(spell_id)
    local tick = M.get_dot_tick_data(spell_id)
    if not tick or not tick.amount or tick.interval <= 0 then return nil end
    return tick.amount / tick.interval
end

--- Determine whether a DoT should be refreshed using the APL formula.
-- APL: dotRemaining < refresh_window AND remainingTime >= refresh_window + dotBaseDuration
--
-- The refresh_window is the key parameter that varies:
--   - Casted DoTs: spell_cast_time(spell, default) — haste-aware, shrinks under Bloodlust
--   - Instant DoTs: early-refresh buffer (1.0-1.5s) — not haste-dependent
--
-- Nil-safe: missing dot_remaining defaults to 0 (needs refresh),
--           missing ttd defaults to 999 (target will live long enough).
--
-- @param dot_remaining    number — DoT remaining duration in seconds (or nil = 0)
-- @param refresh_window   number — refresh threshold: spell_cast_time for casted, buffer for instant
-- @param time_to_die      number — target TTD in seconds (or nil = 999)
-- @param dot_base_duration number — DoT base duration in seconds (e.g., 15 for Immolate, 18 for Corruption)
-- @return boolean — true if DoT should be refreshed
function M.should_refresh_dot(dot_remaining, refresh_window, time_to_die, dot_base_duration)
    dot_remaining = dot_remaining or 0
    time_to_die = time_to_die or 999
    refresh_window = refresh_window or 1.5
    dot_base_duration = dot_base_duration or 15

    -- APL: dotRemaining < refresh_window (haste-aware for casted DoTs)
    if dot_remaining >= refresh_window then return false end

    -- APL: remainingTime >= refresh_window + dotBaseDuration
    -- Don't refresh if target will die before the DoT pays off
    if time_to_die < (refresh_window + dot_base_duration) then return false end

    return true
end

--- Convenience: check if DoT is active with remaining duration > threshold.
-- Useful for "only cast Earth Shock when Flame Shock > 2s" type conditions.
-- Nil-safe: missing dot_remaining defaults to 0 (not active).
-- @param dot_remaining  number — DoT remaining duration in seconds (or nil = 0)
-- @param threshold      number — minimum remaining to consider "active enough" (default: 0)
-- @return boolean — true if DoT is active with remaining > threshold
function M.is_dot_active(dot_remaining, threshold)
    return (dot_remaining or 0) > (threshold or 0)
end

--- Tick-based refresh check: should we refresh based on remaining ticks?
-- Uses wowhead tick data to determine if the DoT has few enough ticks remaining
-- that refreshing now would be efficient (avoids wasting ticks via Pandemic-style clipping).
--
-- Typical threshold: 2 remaining ticks (last 6s of an 18s/3s-interval DoT).
-- This complements the APL formula — use for instant DoTs where cast time is 0.
--
-- @param spell_id        number — spell ID (for tick data lookup)
-- @param dot_remaining   number — DoT remaining duration in seconds
-- @param threshold_ticks number — refresh when remaining ticks <= this (default: 2)
-- @return boolean|nil — true if refresh recommended, nil if no tick data available
function M.should_refresh_dot_by_ticks(spell_id, dot_remaining, threshold_ticks)
    if not spell_id or not dot_remaining then return nil end
    local tick = M.get_dot_tick_data(spell_id)
    if not tick or tick.interval <= 0 then return nil end
    threshold_ticks = threshold_ticks or 2
    local remaining_ticks = math.floor(dot_remaining / tick.interval)
    return remaining_ticks <= threshold_ticks
end

-- Export to NS namespace (Sylvanas production path)
local _G = _G
_G.DotRefresh = M
if _G.EaxRotations then
    _G.EaxRotations.should_refresh_dot = M.should_refresh_dot
    _G.EaxRotations.is_dot_active = M.is_dot_active
    _G.EaxRotations.get_dot_tick_data = M.get_dot_tick_data
    _G.EaxRotations.get_dot_total_damage = M.get_dot_total_damage
    _G.EaxRotations.get_dot_dps = M.get_dot_dps
    _G.EaxRotations.should_refresh_dot_by_ticks = M.should_refresh_dot_by_ticks
end

return M
