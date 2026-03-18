-- EAX Priest Discipline | header.lua
-- Metadata loader that validates the local player is a Discipline Priest.

local plugin = {
    name = "EAX Priest Discipline",
    version = "1.0.0",
    author = "EAX",
    load = true,
}

local local_player = core.object_manager.get_local_player()

if not local_player then
    plugin["load"] = false
    return plugin
end

if local_player:get_class() ~= 5 then
    plugin["load"] = false
    return plugin
end

return plugin
