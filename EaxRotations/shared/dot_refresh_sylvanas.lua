-- =========================================================================
-- EaxRotations File Version: 1.1.1
-- Last Modified: 2026-05-27
-- Change: File version stamp for runtime load verification
-- =========================================================================
local __eax_file = "shared/dot_refresh_sylvanas.lua"
local __eax_version = "1.1.1"
local __eax_modified = "2026-05-27"
local __eax_change = "File version stamp for runtime load verification"
local __eax_versions = rawget(_G, "EaxRotationsFileVersions") or {}
_G.EaxRotationsFileVersions = __eax_versions
__eax_versions[__eax_file] = { version = __eax_version, modified = __eax_modified, change = __eax_change }
local __eax_core = rawget(_G, "core")
if type(__eax_core) == "table" and type(__eax_core.log) == "function" then
    pcall(__eax_core.log, "[EaxRotations] Loaded " .. __eax_file .. " v" .. __eax_version)
end
local __eax_ns = rawget(_G, "EaxRotations")
if type(__eax_ns) == "table" then __eax_ns.file_versions = __eax_versions end
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

-- Export to NS namespace (Sylvanas production path)
local _G = _G
_G.DotRefresh = M
if _G.EaxRotations then
    _G.EaxRotations.should_refresh_dot = M.should_refresh_dot
    _G.EaxRotations.is_dot_active = M.is_dot_active
end

return M
