-- =========================================================================
-- EaxRotations File Version: 1.1.1
-- Last Modified: 2026-05-27
-- Change: File version stamp for runtime load verification
-- =========================================================================
local __eax_file = "header.lua"
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
-- early plugin metadata and class load gate.
-- ============================================================================
-- What: Bootstrap gate that validates the player exists and the class is supported
-- When: Loaded first by the Sylvanas runtime before other framework code
-- Why: Fail fast on partial state and skip unsupported classes safely
-- Safety: Nil-guarded API checks and enum fallback if common/enums is missing
-- ============================================================================
-- ============================================================================
-- What: EaxRotations bootstrap gate — validates player exists and class is supported
-- When: Loaded first by Sylvanas runtime; runs before any other framework code
-- Why: Fail-fast prevents crashes from partial state; class filter avoids loading unsupported modules
-- Safety: Nil-guarded API call; enum fallback if common/enums missing
-- ============================================================================
-- ============================================================================
-- EaxRotations - Header File
-- Project Sylvanas API - Script Registration
-- ============================================================================

local plugin = {}

plugin["name"] = "EaxRotations"
plugin["version"] = "1.1.1"
plugin["author"] = "Eax"
plugin["load"] = true

-- ============================================================================
-- VALIDATION CHECKS
-- ============================================================================

-- Check if local player exists before loading the script
-- (user is on loading screen / not ingame)
local local_player = core.object_manager and core.object_manager.get_local_player and core.object_manager.get_local_player()
if not local_player then
    plugin["load"] = false
    return plugin
end

-- Get player class
local enums = require("common/enums")
if type(enums) ~= "table" or type(enums.class_id) ~= "table" then
    enums = { class_id = { WARRIOR = 1, PALADIN = 2, HUNTER = 3, ROGUE = 4, PRIEST = 5, SHAMAN = 7, MAGE = 8, WARLOCK = 9, DRUID = 11 } }
end
local player_class = local_player:get_class()

-- ============================================================================
-- SUPPORTED CLASSES
-- ============================================================================

local SUPPORTED_CLASSES = {
    [enums.class_id.DRUID] = true,
    [enums.class_id.HUNTER] = true,
    [enums.class_id.MAGE] = true,
    [enums.class_id.PALADIN] = true,
    [enums.class_id.PRIEST] = true,
    [enums.class_id.ROGUE] = true,
    [enums.class_id.SHAMAN] = true,
    [enums.class_id.WARLOCK] = true,
    [enums.class_id.WARRIOR] = true,
}

-- Check if player's class is supported
local is_valid_class = SUPPORTED_CLASSES[player_class] or false

if not is_valid_class then
    core.log_warning("[EaxRotations] Class " .. tostring(player_class) .. " is not supported yet")
    plugin["load"] = false
    return plugin
end

-- ============================================================================
-- CLASS MAPPING FOR INTERNAL USE
-- ============================================================================

local CLASS_ID_TO_NAME = {
    [enums.class_id.DRUID] = "DRUID",
    [enums.class_id.HUNTER] = "HUNTER",
    [enums.class_id.MAGE] = "MAGE",
    [enums.class_id.PALADIN] = "PALADIN",
    [enums.class_id.PRIEST] = "PRIEST",
    [enums.class_id.ROGUE] = "ROGUE",
    [enums.class_id.SHAMAN] = "SHAMAN",
    [enums.class_id.WARLOCK] = "WARLOCK",
    [enums.class_id.WARRIOR] = "WARRIOR",
}

-- Store class name for main.lua to use
plugin["player_class_name"] = CLASS_ID_TO_NAME[player_class]
plugin["player_class_id"] = player_class

-- ============================================================================
-- SPEC CHECK
-- TBC does not expose a meaningful specialization id through this API.
-- Treat non-positive values as unsupported rather than a real spec.
-- ============================================================================

local raw_spec_id = core.spell_book and core.spell_book.get_specialization_id and core.spell_book.get_specialization_id() or nil
local player_spec_id = (type(raw_spec_id) == "number" and raw_spec_id > 0) and raw_spec_id or nil

plugin["player_spec_id"] = player_spec_id
plugin["spec_api_supported"] = player_spec_id ~= nil

local spec_label = player_spec_id and tostring(player_spec_id) or "unsupported"
core.log("[EaxRotations] Header validated - Class: " .. plugin["player_class_name"] .. " | Spec API: " .. spec_label)

if type(core) == "table" and type(core.log) == "function" then pcall(core.log, "[EaxRotations] Loaded header.lua v1.1.1") end

return plugin
