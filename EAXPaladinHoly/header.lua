-- header.lua
-- EAX Paladin Holy | Header
-- Plugin metadata and load validation

local plugin_info = require("plugin_info")
local plugin = {}

plugin["name"] = plugin_info.plugin_load_name
plugin["version"] = plugin_info.plugin_version
plugin["author"] = plugin_info.author

-- By default, we load the plugin always
plugin["load"] = true

-- If there is no local player (eg. user injected before being in-game or is in loading screen)
-- then we don't load the script
local local_player = core.object_manager.get_local_player()
if not local_player then
    plugin["load"] = false
    return plugin
end

-- We check if the class that is being played currently matches our script's intended class
local enums = require("common/enums")
local player_class = local_player:get_class()
local TARGET_CLASS_ID = enums.class_id.PALADIN
local is_valid_class = player_class == TARGET_CLASS_ID

if not is_valid_class then
    plugin["load"] = false
    return plugin
end

return plugin
