-- Sylvanas export layer for the shared DoT refresh helper.

local M = require("shared/dot_refresh")

local _G = _G
if _G.EaxRotations then
    _G.EaxRotations.should_refresh_dot = M.should_refresh_dot
    _G.EaxRotations.is_dot_active = M.is_dot_active
end

_G.DotRefresh = M
return M
