
-- Note: If you need additional data exposed from Questie
-- DM @blue_silvi to request an expansion on core.addons.questie.
--
-- Example:
-- ---@type questie_tracker
-- local questie = require("common/modules/questie_tracker")
-- questie: -> IntelliSense
-- Warning: Access with ":" not "."

---@class questie_obj_entry
---@field id number -- The NPC or object ID associated with a quest objective.

---@class questie_tracker
---@field obj_list questie_obj_entry[] -- Cached list of quest objective NPC/object IDs. Refreshed automatically.
---@field is_hooked fun(self: questie_tracker): boolean -- Returns whether Questie is loaded and has quest log data.
---@field get_list_ids fun(self: questie_tracker): questie_obj_entry[] -- Returns the current quest objective NPC/object IDs as a list of { id = number } entries.
---@field is_quest_object fun(self: questie_tracker, obj: game_object): boolean -- Checks if the given game object is a quest target. Refreshes internal cache at most once per second.

---@type questie_tracker
local tbl
return tbl
