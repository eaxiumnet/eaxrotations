-- header.lua
-- EAX Paladin Retribution  Loading guard

local plugin = {
    name = "EAX Paladin Retribution",
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
if not ok2 or player_class ~= 2 then  -- Paladin class ID is 2
    -- Safely log with pcall (core.log might not exist on all runtimes)
    pcall(function() core.log("[EAX Paladin Retribution] Player is not Paladin; disabling addon.") end)
    plugin.load = false
    return plugin
end

return plugin
