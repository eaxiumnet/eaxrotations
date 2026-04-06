
-- Note: If you need additional data exposed from ConRoc
-- DM @blue_silvi to request an expansion on core.addons.conroc.
--
-- Example:
-- ---@type conroc_tracker
-- local conroc = require("common/modules/conroc_tracker")
-- conroc: -> IntelliSense
-- Warning: Access with ":" not "."

---@class conroc_spell_entry
---@field id number      -- The spell or item ID (always positive).
---@field is_item boolean -- Whether this entry is an item (true) or a spell (false).

---@class conroc_tracker
---@field spell_list conroc_spell_entry[] -- The current rotation suggestion. Up to 10 entries. Refreshed by read().
---@field is_hooked fun(self: conroc_tracker): boolean -- Returns whether ConROC is loaded and has suggestion data.
---@field read fun(self: conroc_tracker): nil -- Reads the current rotation suggestion from ConROC. Populates spell_list.
---@field get_def_spells fun(self: conroc_tracker): integer[] -- Returns the current defensive/buff suggestion spell IDs from ConROC.

---@type conroc_tracker
local tbl
return tbl
