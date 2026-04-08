local plugin = {
    name = "EAX Druid Feral",
    version = "1.0.0",
    author = "Eax",
    load = true,
}

local local_player = core.object_manager.get_local_player()
if not local_player then
    return plugin
end

if local_player:get_class() ~= 11 then
    core.log("[Eax Druid Feral ] Player is not Druid; disabling addon.")
    plugin.load = false
    return plugin
end

return plugin
