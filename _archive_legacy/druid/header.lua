-- =============================================================================
-- DRUID PLUGIN HEADER - SYLVANAS FRAMEWORK
-- Minimal header for standalone plugin loading
-- =============================================================================

local core = _G.core
local enums = require("common/enums")

-- Plugin metadata table
local plugin = {}
plugin.name = "Druid Rotations"
plugin.version = "1.8.10"
plugin.author = "Flux Conversion"
plugin.load = true

-- Check if local player exists (user is on loading screen / not ingame)
local local_player = core.object_manager.get_local_player()
if not local_player then
    plugin.load = false
    return plugin
end

-- Check class - must be Druid
-- Note: TBC has no spec system - user selects playstyle (Cat/Bear/Balance/Resto) via menu
local player_class = local_player:get_class()
if player_class ~= enums.class_id.DRUID then
    plugin.load = false
    return plugin
end

return plugin



