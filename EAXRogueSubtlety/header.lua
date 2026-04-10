-- Eax Rogue Subtlety  header.lua
-- Plugin metadata and load validation.

local plugin_info = require("plugin_info")
local plugin = {}

plugin["name"] = plugin_info.plugin_load_name
plugin["version"] = plugin_info.plugin_version
plugin["author"] = plugin_info.author
plugin["load"] = true

local ok, local_player = pcall(function() return core.object_manager.get_local_player() end)
if not ok or not local_player then
    plugin["load"] = false
    return plugin
end

-- Rogue class_id = 4, Subtlety spec_id = 3
local ok2, player_class = pcall(function() return local_player:get_class() end)
if not ok2 or player_class ~= 4 then
    plugin["load"] = false
    return plugin
end

return plugin
