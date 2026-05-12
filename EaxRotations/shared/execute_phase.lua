-- Readability notes:
--   What: pure execute phase helper.
--   When: used by rotations and tests.
--   Why: all specs should agree that the threshold is inclusive.
--   Safety: nil HP is treated as 100 and never triggers execute.

-- Decision notes:
--   Shared helpers stay pure or dependency-injected where practical so class files can reuse them safely.
--   Inputs are plain tables/numbers instead of live game objects unless a caller explicitly passes adapters.
--   Keeping this logic outside playstyles makes edge cases testable without a Sylvanas runtime.
local M = {}
function M.is_execute_phase(target_hp, threshold) return (target_hp or 100) <= (threshold or 20) end
function M.is_target_above_hp(target_hp, threshold) return (target_hp or 100) > (threshold or 0) end
if _G.EaxRotations then
    _G.EaxRotations.is_execute_phase = M.is_execute_phase
    _G.EaxRotations.is_target_above_hp = M.is_target_above_hp
end
_G.ExecutePhase = M
return M
