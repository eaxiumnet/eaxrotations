-- Eax Rogue Combat  header.lua
-- Plugin metadata and load validation.

local plugin_info = require("plugin_info")
local plugin = {}

plugin["name"] = plugin_info.plugin_load_name
plugin["version"] = plugin_info.plugin_version
plugin["author"] = plugin_info.author
plugin["load"] = true

local local_player = core.object_manager.get_local_player()
if not local_player then
    plugin["load"] = false
    return plugin
end

-- Rogue class_id = 4, Combat spec_id = 2
if local_player:get_class() ~= 4 then
    plugin["load"] = false
    return plugin
end

return plugin
