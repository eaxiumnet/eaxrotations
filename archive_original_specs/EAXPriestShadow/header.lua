-- Eax Priest Shadow | header.lua
-- Plugin metadata and spec guard for Shadow Priest.

local plugin = {
    name = "Eax Priest Shadow",
    version = "1.0.0",
    author = "Eax",
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
