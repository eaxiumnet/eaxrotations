-- ============================================================================
-- EaxAutoQuester - Header File
-- Project Sylvanas API - Script Registration
--
-- Standalone autonomous questing plugin.
-- Not tied to any specific class -- works for all classes.
-- ============================================================================

local plugin = {}

plugin["name"] = "EaxAutoQuester"
plugin["version"] = "1.0.0"
plugin["author"] = "Eax"
plugin["load"] = true

-- Check if local player exists (defer if at login screen)
local local_player = core.object_manager and core.object_manager.get_local_player and core.object_manager.get_local_player()
if not local_player then
    return plugin -- load=true; main.lua guards against nil player
end

-- Class-agnostic plugin: works for ALL classes
if core and type(core.log) == "function" then
    core.log("[EaxAutoQuester] Header validated — class: " .. tostring(local_player:get_class()))
end

return plugin
