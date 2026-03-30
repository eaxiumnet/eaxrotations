
-- Note: If you need additional data exposed from BigWigs
-- DM @blue_silvi to request an expansion on core.addons.bigwigs.
--
-- Example:
-- ---@type wigs_tracker
-- local bars = require("common/modules/wigs_tracker")
-- bars: -> IntelliSense
-- Warning: Access with ":" not "."

---@alias bar_data_table bar_data[]

---@class bar_data
---@field key number         -- The identifier (id) of the bar.
---@field text string        -- The label or message associated with the bar.
---@field duration number    -- The original duration of the bar (in milliseconds).
---@field created_at number  -- The time (in milliseconds) when the bar was created.
---@field expire_time number -- The time (in milliseconds) when the bar will expire.
---@field remaining number   -- The remaining time (in milliseconds).

---@class wigs_tracker
---@field lookup_by_text fun(self: wigs_tracker, search_text: string): bar_data_table -- Finds all active bars whose text contains the given substring.
---@field lookup_by_key fun(self: wigs_tracker, key: number): bar_data_table -- Finds all active bars with a matching key (spell/ability ID).
---@field get_all fun(self: wigs_tracker): bar_data_table -- Returns the full list of all currently tracked (non-expired) bars.
---@field on_process fun(self: wigs_tracker): nil -- Main loop (no-op, kept for backwards compatibility).

---@type wigs_tracker
local tbl
return tbl
