-- =========================================================================
-- EaxRotations File Version: 1.1.1
-- Last Modified: 2026-05-27
-- Change: File version stamp for runtime load verification
-- =========================================================================
local __eax_file = "shared/execute_phase_sylvanas.lua"
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
-- Shared Helper: Execute Phase & Low-HP Target Gating
-- ============================================================================
-- Pure functions extracted from 8+ class modules that all check
-- target HP < threshold (typically 20%) for execute-phase abilities.
-- No NS/api/ dependencies — safe for unit testing.
--
-- APL convention: execute phase = target HP <= threshold (inclusive).
-- Oracle: sim/core/sim.go IsExecutePhase20() returns hp <= 20.
-- Common thresholds: Warrior Execute/Hammer of Wrath at 20%.
--
--   local is_execute_phase = NS.is_execute_phase
--   if is_execute_phase(context.target_hp, 20) then ... end
--
-- Usage (unit test — dofile pattern):
--   dofile("EaxRotations/shared/execute_phase_sylvanas.lua")
--   local is_execute_phase = _G.ExecutePhase.is_execute_phase
--   ...same as above...
-- ============================================================================

local M = {}

--- Check if target is in execute phase (HP at or below threshold).
-- APL convention: target HP <= threshold for Execute/HoW etc.
-- APL convention: <= (inclusive), matching WoW's behavior at exactly 20%.
-- Nil-safe: missing target_hp defaults to 100 (not in execute).
-- @param target_hp  number — target health percentage (0-100) or nil
-- @param threshold  number — HP% threshold (default: 20)
-- @return boolean — true if target is at or below threshold
function M.is_execute_phase(target_hp, threshold)
    return (target_hp or 100) <= (threshold or 20)
end

--- Check if target HP is above a given threshold (for ability gating).
-- Useful for "only cast when target is above threshold HP" type conditions.
-- Nil-safe: missing target_hp defaults to 100 (above any threshold).
-- @param target_hp  number — target health percentage (0-100) or nil
-- @param threshold  number — HP% threshold
-- @return boolean — true if target HP is above threshold
function M.is_target_above_hp(target_hp, threshold)
    return (target_hp or 100) > (threshold or 0)
end

-- Export to NS namespace (Sylvanas production path)
local _G = _G
_G.ExecutePhase = M
if _G.EaxRotations then
    _G.EaxRotations.is_execute_phase = M.is_execute_phase
    _G.EaxRotations.is_target_above_hp = M.is_target_above_hp
end

return M
