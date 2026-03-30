local plugin = {
    name = "Eax Hunter Marksmanship",
    version = "1.0.0",
    author = "Eax",
    load = true,
}

local local_player = core.object_manager.get_local_player()
if not local_player then
    return plugin
end

if local_player:get_class() ~= 3 then
    core.log("[Eax Hunter Marksmanship] Player is not Hunter; disabling addon.")
    plugin.load = false
    return plugin
end

return plugin
