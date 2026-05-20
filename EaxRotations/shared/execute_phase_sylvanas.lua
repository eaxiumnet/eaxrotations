-- ============================================================================
-- Shared Helper: Execute Phase & Low-HP Target Gating
-- ============================================================================
-- Compatibility shim: keep the legacy suffixed require path working.
local M = require("shared/execute_phase")
local _G = _G
if _G.EaxRotations then
    _G.EaxRotations.is_execute_phase = M.is_execute_phase
    _G.EaxRotations.is_target_above_hp = M.is_target_above_hp
end
_G.ExecutePhase = M
return M
