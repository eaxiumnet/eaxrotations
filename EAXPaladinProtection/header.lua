-- header.lua
-- EAX PaladinProtection | Header
-- Plugin metadata and load validation
-- APIs validated against:
--   .api/core.lua
--   .api/game_object.lua
--   sylvanas-dev-docs-llm/pages/dev/api/spellbook.md
--   sylvanas-dev-docs-llm/pages/dev/api/object-manager.md

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

local player_class = local_player:get_class()
local is_valid_class = player_class == 2

if not is_valid_class then
    plugin["load"] = false
    return plugin
end

return plugin
