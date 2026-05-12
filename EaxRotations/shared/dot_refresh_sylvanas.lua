-- Decision notes:
--   Shared helpers stay pure or dependency-injected where practical so class files can reuse them safely.
--   Inputs are plain tables/numbers instead of live game objects unless a caller explicitly passes adapters.
--   Keeping this logic outside playstyles makes edge cases testable without a Sylvanas runtime.

-- Readability notes:
--   What: Sylvanas export layer for the shared DoT refresh helper.
--   When: runtime code needs NS.should_refresh_dot / NS.is_dot_active.
--   Why: keeps old require paths working while exposing the helper through the framework namespace.
--   Safety: registration is nil-guarded and the pure helper remains the source of truth.
local M = require("shared/dot_refresh")

local _G = _G
if _G.EaxRotations then
    _G.EaxRotations.should_refresh_dot = M.should_refresh_dot
    _G.EaxRotations.is_dot_active = M.is_dot_active
end

_G.DotRefresh = M
return M
