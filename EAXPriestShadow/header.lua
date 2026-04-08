-- EAX Priest Shadow | header.lua
-- Plugin metadata and load validation.

local plugin = {
    name = "EAX Priest Shadow",
    version = "1.0.0",
    author = "Eax",
    load = true,
}

local local_player = core.object_manager.get_local_player()
if not local_player then
    plugin.load = false
    return plugin
end

-- Class validation: check if player is Priest class
local class_ok = false
if local_player.get_class then
    local ok, class_name = pcall(function() return local_player:get_class() end)
    if ok and class_name and string.lower(class_name) == "priest" then
        class_ok = true
    end
end

if not class_ok then
    plugin.load = false
    return plugin
end

return plugin
