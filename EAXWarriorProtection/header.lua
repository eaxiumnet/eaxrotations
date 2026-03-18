print("EAX Warrior Protection header loading v1.2.3...")

local plugin       = {}
plugin["name"]     = "EAX Warrior Protection"
plugin["version"]  = "1.2.3"
plugin["author"]   = "EAX"
plugin["load"]     = true

local local_player = core.object_manager.get_local_player()

if local_player then
    local player_class = local_player:get_class()
    if player_class ~= 1 then
        print("[EAX Warrior Protection] Not a warrior, disabling load.")
        plugin["load"] = false
    end
else
    print("[EAX Warrior Protection] No player yet, allowing load.")
end

return plugin
