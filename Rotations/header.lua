-- header.lua
-- TBC Anniversary 2.5.5 Shaman Elemental | Load guard
-- Validates class (Shaman = 7) before loading the rotation
-- Single file plugin (paired with main.lua)

local plugin = {}
plugin["name"] = "TBC Shaman Elemental"
plugin["version"] = "1.0.0"
plugin["author"] = "EaxRotations"
plugin["load"] = true

local local_player = core.object_manager and core.object_manager.get_local_player and core.object_manager.get_local_player()
if not local_player then
    plugin["load"] = false
    return plugin
end

local player_class = local_player:get_class()
-- Class 7 = Shaman (matches EaxRotations header.lua convention)
if player_class ~= 7 then
    plugin["load"] = false
    return plugin
end

return plugin
