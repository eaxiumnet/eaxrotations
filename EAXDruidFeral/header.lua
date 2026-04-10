local plugin = {
    name = "EAX Druid Feral",
    version = "1.0.0",
    author = "Eax",
    load = true,
}

local ok, local_player = pcall(function() return core.object_manager.get_local_player() end)
if not ok or not local_player then
    plugin.load = false
    return plugin
end

local ok2, player_class = pcall(function() return local_player:get_class() end)
if not ok2 or player_class ~= 11 then
    core.log("[Eax Druid Feral ] Player is not Druid; disabling addon.")
    plugin.load = false
    return plugin
end

return plugin
