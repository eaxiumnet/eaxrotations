-- EAX Warrior Arms | header.lua
-- Plugin metadata and load validation.

local plugin = {
    name = "EAX Warrior Arms",
    version = "1.0.0",
    author = "EAX",
    load = true,
}

local local_player = core.object_manager.get_local_player()
if not local_player then
    plugin.load = false
    return plugin
end

local enums = require("common/enums")
if local_player:get_class() ~= enums.class_id.WARRIOR then
    plugin.load = false
    return plugin
end

return plugin
