-- EAX Priest Shadow | header.lua
-- Plugin metadata and load validation.

local plugin = {
    name = "EAX Priest Shadow",
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

-- Class validation: check if player is Priest class
local class_ok = false
if local_player.get_class then
    local ok2, class_name = pcall(function() return local_player:get_class() end)
    if ok2 and class_name and string.lower(class_name) == "priest" then
        class_ok = true
    end
end

if not class_ok then
    plugin.load = false
    return plugin
end

return plugin
