-- =============================================================================
-- header.lua — Plugin manifest / loader gate for EaxProfession.
-- =============================================================================
-- WHAT:  Declares plugin identity + load gate for the Sylvanas runtime loader.
-- WHEN:  Loaded FIRST by the Sylvanas loader before main.lua.
-- WHY:   PS loader contract: header.lua must return plugin["load"] = true or
--        the runtime never calls main.lua (confirmed by EaxESP/header.lua
--        and EAXFishing/header.lua). EaxProfession was missing this file —
--        the plugin was invisible to the runtime as a standalone entry.
-- SAFETY: Pure data return; never errors. Missing player short-circuits to a
--         still-loadable manifest (mirrors EaxESP).
-- =============================================================================

local plugin = {}

plugin["name"]        = "EaxProfession"
plugin["version"]     = "1.0.0"
plugin["author"]      = "EAX"
plugin["load"]        = true
plugin["api"]         = "sylvanas"
plugin["description"] = "Eax's Profession — automated crafting for Sylvanas (Alchemy, Blacksmithing, Leatherworking, Tailoring, Engineering, Enchanting, Cooking, First Aid, Jewelcrafting). Mass-craft, recipe filter, skill-gain mode."

-- Mirror EaxESP: probe local player but never block load if absent.
local om = rawget(_G, "core")
if type(om) == "table" and type(om.object_manager) == "table"
   and type(om.object_manager.get_local_player) == "function" then
  local ok = pcall(om.object_manager.get_local_player)
  _ = ok  -- presence probe only; do not gate load on it
end

return plugin