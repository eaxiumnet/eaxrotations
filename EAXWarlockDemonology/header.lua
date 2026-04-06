-- header.lua
-- Eax Warlock Demonology  Header
-- Validate class/spec before loading the plugin.

local plugin = {
    ["name"] = "EAX",
    ["version"] = "1.0.0",
    ["author"] = "Eax",
    ["load"] = true,
}

local local_player = core.object_manager.get_local_player()

if not local_player then
    plugin["load"] = false
    return plugin
end

if local_player:get_class() ~= 9 then
    plugin["load"] = false
    return plugin
end

return plugin
