-- =========================================================================
-- EaxRotations File Version: 1.1.1
-- Last Modified: 2026-05-27
-- Change: File version stamp for runtime load verification
-- =========================================================================
local __eax_file = "shared/combat_forecast_gate_sylvanas.lua"
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
local M = {}

function M.should_use_long_cd(context, spell_cooldown_seconds)
    if not context or not context.combat_length_forecast then return true end
    local forecast = context.combat_length_forecast
    local is_boss = false
    if context.target and type(context.target.is_boss) == "function" then
        is_boss = context.target:is_boss() == true
    end
    if is_boss then return true end
    if spell_cooldown_seconds >= 180 and forecast < 60 then return false end
    if spell_cooldown_seconds >= 120 and forecast < 45 then return false end
    if spell_cooldown_seconds >= 60 and forecast < 30 then return false end
    return true
end

_G.CombatForecastGate = M
if _G.EaxRotations then _G.EaxRotations.should_use_long_cd = M.should_use_long_cd end
return M
