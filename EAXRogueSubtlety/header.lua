-- EAX Rogue Subtlety | header.lua

local plugin = {}

plugin["name"] = "EAX Rogue Subtlety"
plugin["version"] = "1.0.0"
plugin["author"] = "EAX"
plugin["load"] = true

local me = core.object_manager.get_local_player()

if not me then
    plugin["load"] = false
    return plugin
end

if me:get_class() ~= 4 then
    plugin["load"] = false
    return plugin
end

return plugin
