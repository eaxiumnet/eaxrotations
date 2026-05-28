-- =========================================================================
-- EaxRotations File Version: 1.1.1
-- Last Modified: 2026-05-27
-- Change: File version stamp for runtime load verification
-- =========================================================================
local __eax_file = "helpers_sylvanas.lua"
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
-- runtime module.
-- ============================================================================
-- What: Shared helper import module that maps short NS aliases to runtime helpers
-- When: Loaded by class files during startup
-- Why: Keep helper naming consistent across many class modules
-- Safety: Must load after core_sylvanas.lua, and missing aliases fall back conservatively
-- ============================================================================

-- ============================================================================
-- EaxRotations - Shared Helper Import Module
-- ============================================================================
-- Centralizes the NS → local alias mapping used across 50+ class files.
--
-- Usage in class files:
--   local spell_exists, spell_ready, buff_up = NS.import_helpers(
--       "spell_exists", "spell_ready", "buff_up"
--   )
--
-- Rename mappings (e.g. health_pct → NS.unit_health_pct) are defined here
-- so class files always use the short, consistent local name.
--
-- IMPORTANT: This module MUST load after core_sylvanas.lua (order 10+).
-- ============================================================================

local _G = _G
local NS = _G.EaxRotations
if not NS then return end

-- ============================================================================
-- RENAME MAP
-- Local alias name → actual NS field name
-- If a local name is NOT in this map, it maps to NS[local_name] directly.
-- ============================================================================
local ALIASES = {
    health_pct       = "unit_health_pct",
    get_health_pct   = "unit_health_pct",
    mana_pct_fn      = "mana_pct",
    get_mana_pct     = "mana_pct",
    get_buff_remains = "buff_remains",
    get_cast_time    = "spell_cast_time",
}

-- ============================================================================
-- import_helpers(...)
-- Resolves each helper name to its NS function, asserts on missing, and
-- returns them as multiple values for direct local assignment.
--
-- Uses unpack(results, 1, n) to avoid the Lua 5.1 nil-truncation trap
-- where unpack stops at the first nil value.
-- ============================================================================
function NS.import_helpers(...)
    local n = select('#', ...)
    if n == 0 then return end

    local results = {}
    for i = 1, n do
        local key = select(i, ...)
        local ns_key = ALIASES[key] or key
        results[i] = NS[ns_key]

        -- [#43] Return nil instead of error() on missing key.
        -- error() propagates uncaught through require() and crashes the entire
        -- class module load. Use import_helpers_safe for silent nil returns,
        -- or check the result in the calling code.
        if results[i] == nil then
            NS.log_warning("helpers_sylvanas: Unknown helper '" .. tostring(key)
                .. "' (looked up NS." .. tostring(ns_key) .. ")")
        end
    end

    return unpack(results, 1, n)
end

-- ============================================================================
-- import_helpers_safe(...)
-- Same as import_helpers but returns nil instead of erroring on missing keys.
-- Useful for optional helpers that only some specs use (e.g. cooldown_remains).
-- ============================================================================
function NS.import_helpers_safe(...)
    local n = select('#', ...)
    if n == 0 then return end

    local results = {}
    for i = 1, n do
        local key = select(i, ...)
        local ns_key = ALIASES[key] or key
        results[i] = NS[ns_key]
    end

    return unpack(results, 1, n)
end

NS.log("Helper import module loaded")
