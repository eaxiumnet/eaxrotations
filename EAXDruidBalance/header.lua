local plugin = {
    name = "EAX",
    version = "1.0.0",
    author = "Eax",
    load = true,
}

-- Safely get local player
local ok, local_player = pcall(function() return core.object_manager.get_local_player() end)
if not ok or not local_player then
    plugin.load = false
    return plugin
end

-- Safely check class
local ok2, player_class = pcall(function() return local_player:get_class() end)
if not ok2 or player_class ~= 11 then
    plugin.load = false
    return plugin
end

return plugin
