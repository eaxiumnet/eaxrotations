print("EAX Warrior Fury header loading...")

local plugin       = {}
plugin["name"]     = "EAX Warrior Fury"
plugin["version"]  = "1.0.3"
plugin["author"]   = "EAX"
plugin["load"]     = true

local local_player = core.object_manager.get_local_player()

if local_player then
    local player_class = local_player:get_class()
    if player_class ~= 1 then
        print("[EAX Warrior Fury] Not a warrior, disabling load.")
        plugin["load"] = false
    end
else
    -- If no player yet, assume loading is fine and we will check again in main.lua
    print("[EAX Warrior Fury] No player yet, allowing load.")
end

return plugin
