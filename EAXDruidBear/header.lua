-- Eax Druid Bear header.lua
-- Plugin metadata and load validation.

local plugin = {
    name = "EAX",
    version = "1.0.0",
    author = "Eax",
    load = true,
}

local local_player = core.object_manager.get_local_player()
if not local_player then
    plugin.load = false
    return plugin
end

-- Druid class ID is 11
if local_player:get_class() ~= 11 then
    plugin.load = false
    return plugin
end

return plugin
