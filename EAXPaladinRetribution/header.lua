-- header.lua
-- EAX Paladin Retribution | Loading guard

local plugin = {
    name = "EAX Paladin Retribution",
    version = "1.0.0",
    author = "EAX Development Team",
    load = true,
}

local enums = require("common/enums")
local local_player = core.object_manager.get_local_player()

if local_player then
    local player_class = local_player:get_class()
    if player_class ~= enums.class_id.PALADIN then
        plugin.load = false
        return plugin
    end
end

return plugin
