
-- Syntax / IntelliSense helper for: universal_kicks external filters
--
-- Example:
-- local kicks = require("common/utility/kick_external_filters_helper")
-- kicks: -> IntelliSense
-- Warning: Access with ":", not "."

-- ─────────────────────────────────────────────────
-- Filter callback signature
-- ─────────────────────────────────────────────────
-- function(local_player: game_object, solution_table: table, spell_to_kick_table: table,
--          kick_target: game_object, prediction_data: table): boolean, string|nil
--
-- Return false + reason to block, or true to allow.

-- ─────────────────────────────────────────────────
-- Filter options (opts parameter)
-- ─────────────────────────────────────────────────
-- {
--     type   = "block" | "allow",   -- block: return false to block. allow: at least one must return true.
--     label  = string,              -- human-readable label (optional)
--     time   = number,              -- auto-expire after N seconds (optional)
--     frames = number,              -- auto-expire after N frames (optional)
--     count  = number,              -- auto-expire after N checks (optional)
-- }

-- ─────────────────────────────────────────────────
-- Class Definition
-- ─────────────────────────────────────────────────

---@class kick_external_filters_helper
---@field is_available fun(self: kick_external_filters_helper): boolean                                                                                                                                                              Returns true if the universal kicks plugin is loaded.
---@field get_api fun(self: kick_external_filters_helper): table|nil                                                                                                                                                                 Returns the raw API, or nil.
---@field register fun(self: kick_external_filters_helper, name: string, func: fun(local_player: game_object, solution_table: table, spell_to_kick_table: table, kick_target: game_object, prediction_data: table): boolean, string|nil, opts: table|nil): boolean   Register a filter. Returns false if plugin not loaded.
---@field unregister fun(self: kick_external_filters_helper, name: string): boolean                                                                                                                                                  Unregister a filter by name.
---@field clear fun(self: kick_external_filters_helper): boolean                                                                                                                                                                     Remove all filters.
---@field list fun(self: kick_external_filters_helper): table|nil                                                                                                                                                                    Snapshot of active filters (for debug UIs).
---@field touch fun(self: kick_external_filters_helper, name: string, opts_patch: table): boolean                                                                                                                                    Extend/modify existing filter options.

--========================
-- Examples (copy-paste)
--========================

-- Example 1: block while stealthed
-- local kicks = require("common/utility/kick_external_filters_helper")
-- kicks:register("block_while_stealth",
--     function(local_player, solution_table, spell_to_kick_table, kick_target, prediction_data)
--         local data = buff_manager:get_buff_data(local_player, enums.buff_db.STEALTH, 50)
--         local is_stealthed = data and data.is_active == true
--         if is_stealthed then
--             return false, "stealth_active"
--         end
--         return true
--     end,
--     { type = "block", label = "No Kick While Stealth" }
-- )

-- Example 2: allow only boss target for 2 seconds (auto-expire)
-- local kicks = require("common/utility/kick_external_filters_helper")
-- local boss_ptr = core.units.boss1
-- kicks:register("allow_boss_for_2s",
--     function(_, _, _, kick_target)
--         return kick_target == boss_ptr
--     end,
--     { type = "allow", time = 2, label = "Boss Only 2s" }
-- )

-- Example 3: block a specific enemy cast id
-- local kicks = require("common/utility/kick_external_filters_helper")
-- kicks:register("block_cast_12345",
--     function(_, _, cast)
--         local allow = (cast.id ~= 12345)
--         return allow, allow and nil or "cast_12345"
--     end,
--     { type = "block", label = "Skip 12345" }
-- )

-- Example 4: block using frames/count/time expirations
-- local kicks = require("common/utility/kick_external_filters_helper")
-- kicks:register("block_once",
--     function() return false, "once" end,
--     { type = "block", frames = 1, label = "One Pass" }
-- )
-- kicks:register("block_next_5_checks",
--     function() return false, "next_5" end,
--     { type = "block", count = 5, label = "Next 5 Checks" }
-- )
-- kicks:register("mute_for_3s",
--     function() return false, "window_3s" end,
--     { type = "block", time = 3, label = "Mute 3s" }
-- )

-- Example 5: remove or extend existing filters
-- local kicks = require("common/utility/kick_external_filters_helper")
-- kicks:unregister("block_while_stealth")
-- kicks:touch("allow_boss_for_2s", { time = 4 })  -- extend window if still active

-- Tips:
-- • If you register ANY allow filter, kicks are permitted ONLY when at least one allow returns true.
-- • Prefer time or count expirations for temporary rules so you don't have to manually unregister.
-- • For debug UIs, use kicks:list() and show secs_left / calls / frames_used.

---@type kick_external_filters_helper
local tbl
return tbl
