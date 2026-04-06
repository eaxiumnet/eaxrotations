-- =============================================================================
-- WARRIOR PLUGIN HEADER - SYLVANAS FRAMEWORK
-- Minimal header for standalone plugin loading
-- =============================================================================

local core = _G.core
local enums = require("common/enums")

local plugin = {}
plugin.name = "Warrior Rotations"
plugin.version = "1.8.10"
plugin.author = "Flux Conversion"
plugin.load = true

local local_player = core.object_manager.get_local_player()
if not local_player then
    plugin.load = false
    return plugin
end

-- Check class - must be Warrior
-- Note: TBC has no spec system - user selects playstyle (Arms/Fury/Prot) via menu
local player_class = local_player:get_class()
if player_class ~= enums.class_id.WARRIOR then
    plugin.load = false
    return plugin
end

return plugin
