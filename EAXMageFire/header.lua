local plugin = {}

plugin["name"]    = " Mage Fire"
plugin["version"] = "1.0.0"
plugin["author"]  = " Port"
plugin["load"]    = true

-- Check if local player exists
local local_player = core.object_manager.get_local_player()
if not local_player then
    plugin["load"] = false
    return plugin
end

local player_class = local_player:get_class()

-- Mage class check (class ID 8)
if player_class ~= 8 then
    plugin["load"] = false
    return plugin
end

-- Spec check (Fire = 2)
local player_spec_id = core.spell_book.get_specialization_id()
if player_spec_id ~= 2 then
    plugin["load"] = false
    return plugin
end

return plugin


