-- header.lua — EaxRotations bootstrap: plugin metadata, version, and class load gate.
-- WHAT:  registers the addon with Project Sylvanas and gates class loading until core is ready.
-- WHEN:  addon load; runs before any class file is loaded.
-- WHY:   prevents class files from executing before the framework (NS, core.*) is initialized.
-- SAFETY: defers all class loading until core.time exists; no per-frame allocations.

local plugin = {}

plugin["name"] = "EaxRotations"
plugin["version"] = "2.7.4"
plugin["author"] = "Eax"
plugin["load"] = true

-- ============================================================================
-- VALIDATION CHECKS
-- ============================================================================

-- Defer player availability check to main.lua. Header should never
-- permanently disable the plugin just because the player object is nil
-- during a loading screen, zoning, or a race condition at injection time.
-- main.lua will re-check and exit gracefully each frame until ready.

-- Get player class (safe: nil player means we skip class detection)
local local_player = core.object_manager and core.object_manager.get_local_player and core.object_manager.get_local_player()
if not local_player then
    return plugin  -- load=true; main.lua will guard against nil player each frame
end

-- Get player class
local enums_ok, enums = pcall(require, "common/enums")
if not enums_ok or type(enums) ~= "table" or type(enums.class_id) ~= "table" then
    enums = { class_id = { WARRIOR = 1, PALADIN = 2, HUNTER = 3, ROGUE = 4, PRIEST = 5, SHAMAN = 7, MAGE = 8, WARLOCK = 9, DRUID = 11 } }
end

-- Guard get_class() with pcall (player proxy could be stale)
local class_ok, player_class = pcall(function() return local_player:get_class() end)
if not class_ok or type(player_class) ~= "number" then
    return plugin
end

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
    if core and type(core.log_warning) == "function" then
        core.log_warning("[EaxRotations] Class " .. tostring(player_class) .. " is not supported yet")
    end
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

return plugin
