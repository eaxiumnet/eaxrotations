-- header.lua
-- EAX Paladin Holy  Loading guard

local plugin = {
    name = "EAX Paladin Holy",
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
if not ok2 or player_class ~= 2 then
    core.log("[EAX Paladin Holy] Player is not Paladin; disabling addon.")
    plugin.load = false
    return plugin
end

return plugin
