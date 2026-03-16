-- header.lua
-- EAX Shaman Enhancement | Load guard
-- Validates class/spec before running the melee logic

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

local enums = require("common/enums")
local player_class = local_player:get_class()
if player_class ~= enums.class_id.SHAMAN then
    plugin["load"] = false
    return plugin
end

return plugin
