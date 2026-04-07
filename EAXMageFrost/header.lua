local plugin = {}

plugin["name"]    = " Mage Frost"
plugin["version"] = "1.0.0"
plugin["author"]  = " Port"
plugin["load"]    = true

-- Check if local player exists
local local_player = core.object_manager.get_local_player()
if not local_player then
    plugin["load"] = false
    return plugin
end

---@type enums
local enums = require("common/enums")
local player_class = local_player:get_class()

-- Mage class check
if player_class ~= enums.class_id.MAGE then
    plugin["load"] = false
    return plugin
end

-- Spec check (Frost = 3)
local player_spec_id = core.spell_book.get_specialization_id()
if player_spec_id ~= 3 then
    plugin["load"] = false
    return plugin
end

return plugin


