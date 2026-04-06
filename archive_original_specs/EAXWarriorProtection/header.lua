print("Eax Warrior Protection header loading v1.2.3...")

local plugin       = {}
plugin["name"]     = "Eax Warrior Protection"
plugin["version"]  = "1.2.3"
plugin["author"]   = "Eax"
plugin["load"]     = true

local local_player = core.object_manager.get_local_player()

if local_player then
    local player_class = local_player:get_class()
    if player_class ~= 1 then
        print("[Eax Warrior Protection] Not a warrior, disabling load.")
        plugin["load"] = false
    end
else
    -- If no player yet, assume loading is fine and we will check again in main.lua
    print("[Eax Warrior Protection] No player yet, allowing load.")
end

return plugin
