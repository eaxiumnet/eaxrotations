-- =========================================================================
-- EaxRotations File Version: 1.1.1
-- Last Modified: 2026-05-27
-- Change: File version stamp for runtime load verification
-- =========================================================================
local __eax_file = "classes/hunter/debugui_sylvanas.lua"
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
-- optional Hunter debug facade.

-- ============================================================================
-- What: Optional Hunter debug facade for logging snapshots and state
-- When: Loaded once; used only when debug output is enabled
-- Why: Keeps debug-only logging separate from combat logic
-- Safety: No combat actions; NS.log only; disabled by default
-- ============================================================================

local NS = _G.EaxRotations
if not NS then return nil end

local M = { enabled = false }

function M.set_enabled(value)
    M.enabled = value == true
end

function M.log(message)
    if M.enabled then NS.log("[HUNTER DEBUG] " .. tostring(message or "")) end
end

function M.snapshot(context)
    if not M.enabled then return end
    M.log(string.format(
        "hp=%.1f mana=%.1f target=%s enemies=%d",
        tonumber(context and context.hp) or 0,
        tonumber(context and context.mana_pct) or 0,
        tostring(context and context.has_valid_enemy_target),
        tonumber(context and context.enemy_count) or 0
    ))
end

NS.HunterDebugUI = M
return M
