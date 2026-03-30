-- Eax Rogue Combat | header.lua

local plugin = {}

plugin["name"] = "Eax Rogue Combat"
plugin["version"] = "1.0.0"
plugin["author"] = "Eax"
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
