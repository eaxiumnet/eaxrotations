-- EAXPriestSmite header.lua
-- Plugin metadata and load validation.

local plugin = {
    name = "EAX",
    version = "1.0.0",
    author = "Eax",
    load = true,
}

-- Safely get local player (pcall protects against API differences between retail and Sylvanas)
local ok, local_player = pcall(function() return core.object_manager.get_local_player() end)
if not ok or not local_player then
    plugin.load = false
    return plugin
end

-- Safely check class (pcall protects against method differences)
local ok2, player_class = pcall(function() return local_player:get_class() end)
if not ok2 or player_class ~= 5 then  -- Priest class ID is 5
    plugin.load = false
    return plugin
end

return plugin
