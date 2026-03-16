-- EAX Rogue Combat | header.lua

local plugin = {}

plugin["name"] = "EAX Rogue Combat"
plugin["version"] = "1.0.0"
plugin["author"] = "EAX"
plugin["load"] = true

local enums = require("common/enums")
local me = core.object_manager.get_local_player()

if not me then
    plugin["load"] = false
    return plugin
end

if me:get_class() ~= enums.class_id.ROGUE then
    plugin["load"] = false
    return plugin
end

return plugin
