-- Eax Warrior Arms | header.lua
-- Plugin metadata and load validation.

local plugin = {
    name = "Eax Warrior Arms",
    version = "1.0.0",
    author = "Eax",
    load = true,
}

local local_player = core.object_manager.get_local_player()
if not local_player then
    plugin.load = false
    return plugin
end

if local_player:get_class() ~= 1 then
    plugin.load = false
    return plugin
end

-- NOTE: We intentionally do NOT check for Mortal Strike here.
-- This addon must work for leveling warriors (1-70) who may not have
-- learned Mortal Strike yet. The rotation adapts dynamically.

return plugin
