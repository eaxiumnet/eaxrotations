local plugin = {}

plugin["name"]    = "EAX Mage Frost"
plugin["version"] = "1.0.0"
plugin["author"]  = "EAX"
plugin["load"]    = true

-- Safely get local player (pcall protects against API differences between retail and Sylvanas)
local ok, local_player = pcall(function() return core.object_manager.get_local_player() end)
if not ok or not local_player then
    plugin["load"] = false
    return plugin
end

-- Safely check class (pcall protects against method differences)
local ok2, player_class = pcall(function() return local_player:get_class() end)
if not ok2 or player_class ~= 8 then
    plugin["load"] = false
    return plugin
end

-- Spec check (Frost = 3)
local ok3, player_spec_id = pcall(function() return core.spell_book.get_specialization_id() end)
if not ok3 or player_spec_id ~= 3 then
    plugin["load"] = false
    return plugin
end

return plugin
