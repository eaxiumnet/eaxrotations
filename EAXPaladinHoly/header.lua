-- header.lua
-- EAX Paladin Holy  Loading guard

local plugin = {
    name = "EAX",
    version = "1.0.0",
    author = "Eax",
    load = true,
}

local local_player = core.object_manager.get_local_player()

if local_player then
    local player_class = local_player:get_class()
    if player_class ~= 2 then
        plugin.load = false
        return plugin
    end
end

return plugin
