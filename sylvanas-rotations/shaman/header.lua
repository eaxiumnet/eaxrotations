-- =============================================================================
-- SHAMAN PLUGIN HEADER - SYLVANAS FRAMEWORK
-- Minimal header for standalone plugin loading
-- =============================================================================

local core = _G.core
local enums = require("common/enums")

local plugin = {}
plugin.name = "Shaman Rotations"
plugin.version = "1.8.10"
plugin.author = "Flux Conversion"
plugin.load = true

local local_player = core.object_manager.get_local_player()
if not local_player then
    plugin.load = false
    return plugin
end

local player_class = local_player:get_class()
if player_class ~= enums.class_id.SHAMAN then
    plugin.load = false
    return plugin
end

return plugin


