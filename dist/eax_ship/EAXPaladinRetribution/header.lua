-- header.lua
-- Eax Paladin Retribution | Loading guard

local plugin = {
    name = "Eax Paladin Retribution",
    version = "1.0.0",
    author = "Eax Development Team",
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
