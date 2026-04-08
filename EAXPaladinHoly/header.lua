-- header.lua
-- EAX Paladin Holy  Loading guard

local plugin = {
    name = "EAX Paladin Holy",
    version = "1.0.0",
    author = "Eax",
    load = true,
}

local local_player = core.object_manager.get_local_player()
if not local_player then
    return plugin
end

if local_player:get_class() ~= 2 then
    core.log("[EAX Paladin Holy] Player is not Paladin; disabling addon.")
    plugin.load = false
    return plugin
end

return plugin
