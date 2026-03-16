-- header.lua
-- EAX Warlock Affliction | Header
-- Validate class/spec before loading the plugin.

local plugin = {
    ["name"] = "EAX Warlock Affliction",
    ["version"] = "1.0.0",
    ["author"] = "EAX",
    ["load"] = true,
}

local enums = require("common/enums")
local local_player = core.object_manager.get_local_player()

if not local_player then
    plugin["load"] = false
    return plugin
end

if local_player:get_class() ~= enums.class_id.WARLOCK then
    plugin["load"] = false
    return plugin
end

return plugin
