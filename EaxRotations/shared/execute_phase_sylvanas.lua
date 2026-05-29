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
