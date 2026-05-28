local plugin = {}

plugin["name"] = "EaxRotation2"
plugin["version"] = "2.0.0"
plugin["author"] = "Eax"
plugin["load"] = true

-- Check if local player exists before loading the script
local local_player = core.object_manager and core.object_manager.get_local_player and core.object_manager.get_local_player()
if not local_player then
    plugin["load"] = false
    return plugin
end

-- Get player class
local enums = require("common/enums")
if type(enums) ~= "table" or type(enums.class_id) ~= "table" then
    enums = { class_id = { WARRIOR = 1, PALADIN = 2, HUNTER = 3, ROGUE = 4, PRIEST = 5, SHAMAN = 7, MAGE = 8, WARLOCK = 9, DRUID = 11 } }
end
local player_class = local_player:get_class()

local SUPPORTED_CLASSES = {
    [enums.class_id.DRUID] = true,
    [enums.class_id.HUNTER] = true,
    [enums.class_id.MAGE] = true,
    [enums.class_id.PALADIN] = true,
    [enums.class_id.PRIEST] = true,
    [enums.class_id.ROGUE] = true,
    [enums.class_id.SHAMAN] = true,
    [enums.class_id.WARLOCK] = true,
    [enums.class_id.WARRIOR] = true,
}

local is_valid_class = SUPPORTED_CLASSES[player_class] or false

if not is_valid_class then
    core.log_warning("[EaxRotation2] Class " .. tostring(player_class) .. " is not supported yet")
    plugin["load"] = false
    return plugin
end

local CLASS_ID_TO_NAME = {
    [enums.class_id.DRUID] = "DRUID",
    [enums.class_id.HUNTER] = "HUNTER",
    [enums.class_id.MAGE] = "MAGE",
    [enums.class_id.PALADIN] = "PALADIN",
    [enums.class_id.PRIEST] = "PRIEST",
    [enums.class_id.ROGUE] = "ROGUE",
    [enums.class_id.SHAMAN] = "SHAMAN",
    [enums.class_id.WARLOCK] = "WARLOCK",
    [enums.class_id.WARRIOR] = "WARRIOR",
}

plugin["player_class_name"] = CLASS_ID_TO_NAME[player_class]
plugin["player_class_id"] = player_class

core.log("[EaxRotation2] Header validated - Class: " .. plugin["player_class_name"])

return plugin
