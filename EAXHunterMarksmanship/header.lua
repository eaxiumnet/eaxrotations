local plugin = {
    name = "EAX Hunter Marksmanship",
    version = "1.0.0",
    author = "EAX",
    load = true,
}

local enums = require("common/enums")
local local_player = core.object_manager.get_local_player()
if not local_player then
    return plugin
end

if local_player:get_class() ~= enums.class_id.HUNTER then
    core.log("[EAX Hunter Marksmanship] Player is not Hunter; disabling addon.")
    plugin.load = false
    return plugin
end

return plugin
