
-- Syntax / IntelliSense helper for: universal_dispels external filters
--
-- Example:
-- local dispels = require("common/utility/dispel_external_filters_helper")
-- dispels: -> IntelliSense
-- Warning: Access with ":", not "."

-- ─────────────────────────────────────────────────
-- Filter callback signature
-- ─────────────────────────────────────────────────
-- function(local_player: game_object, target: game_object, data_packet: table): boolean, string|nil
--
-- Return false + reason to block, or true to allow.
-- You never call apply yourself — the dispel system calls it during its decision pass.

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

---@class dispel_external_filters_helper
---@field is_available fun(self: dispel_external_filters_helper): boolean                                                                                                            Returns true if the universal dispels plugin is loaded.
---@field get_api fun(self: dispel_external_filters_helper): table|nil                                                                                                               Returns the raw API, or nil.
---@field get_priority_enum fun(self: dispel_external_filters_helper): table|nil                                                                                                      Returns priority_enum from the API, or nil.
---@field register fun(self: dispel_external_filters_helper, name: string, func: fun(local_player: game_object, target: game_object, data_packet: table): boolean, string|nil, opts: table|nil): boolean   Register a filter. Returns false if plugin not loaded.
---@field unregister fun(self: dispel_external_filters_helper, name: string): boolean                                                                                                Unregister a filter by name.
---@field clear fun(self: dispel_external_filters_helper): boolean                                                                                                                   Remove all filters.

--========================
-- Examples (copy-paste)
--========================

-- Example 1: block dispels while stealthed
-- local dispels = require("common/utility/dispel_external_filters_helper")
-- dispels:register("block_while_stealth",
--     function(local_player, target, data_packet)
--         local stealth_data = buff_manager:get_buff_data(local_player, enums.buff_db.STEALTH, 50)
--         local is_stealthed = stealth_data and stealth_data.is_active == true
--         if is_stealthed then
--             return false, "stealth_active"
--         end
--         return true
--     end,
--     { type = "block", label = "no dispel while stealth" }
-- )

-- Example 2: block low priority debuffs for a short window
-- local dispels = require("common/utility/dispel_external_filters_helper")
-- local priority_enum = dispels:get_priority_enum()
-- dispels:register("no_low_priority_for_0_7s",
--     function(_, _, data_packet)
--         local prio = (data_packet and data_packet.details and data_packet.details.priority) or 0
--         if priority_enum and prio <= priority_enum.medium then
--             return false, "priority_low"
--         end
--         return true
--     end,
--     { type = "block", time = 0.7, label = "low priority gate" }
-- )

-- Example 3: allow only a specific target pointer for 2s
-- local dispels = require("common/utility/dispel_external_filters_helper")
-- local my_unit_pointer = my_module and my_module.get_primary_target and my_module.get_primary_target() or nil
-- if my_unit_pointer then
--     dispels:register("allow_only_primary_target",
--         function(_, target)
--             return target == my_unit_pointer or false, "not_primary_target"
--         end,
--         { type = "allow", time = 2.0, label = "only primary target" }
--     )
-- end

-- Example 4: block a specific debuff id exactly once
-- local dispels = require("common/utility/dispel_external_filters_helper")
-- local blocked_id = 388392
-- dispels:register("ban_debuff_388392_once",
--     function(_, _, data_packet)
--         local id = data_packet and data_packet.details and data_packet.details.id
--         return id ~= blocked_id or false, "id_388392_blocked"
--     end,
--     { type = "block", count = 1, label = "ban 388392 once" }
-- )

-- Example 5: temporary global mute for next 3 checks
-- local dispels = require("common/utility/dispel_external_filters_helper")
-- dispels:register("block_next_3_checks",
--     function() return false, "temp_mute" end,
--     { type = "block", count = 3, label = "mute next 3" }
-- )

-- Example 6: single frame guard
-- local dispels = require("common/utility/dispel_external_filters_helper")
-- dispels:register("block_once_frame",
--     function() return false, "single_guard" end,
--     { type = "block", frames = 1, label = "single check guard" }
-- )

-- Example 7: allow only boss target for 1.5s
-- local dispels = require("common/utility/dispel_external_filters_helper")
-- local boss_ptr = encounter and encounter.get_boss_ptr and encounter.get_boss_ptr() or nil
-- if boss_ptr then
--     dispels:register("allow_only_boss",
--         function(_, target) return target == boss_ptr or false, "not_boss" end,
--         { type = "allow", time = 1.5, label = "boss only window" }
--     )
-- end

-- Example 8: class form — druid cat form disable (register on enter, unregister on exit)
-- local dispels = require("common/utility/dispel_external_filters_helper")
-- if is_cat_form then
--     dispels:register("druid_no_dispel",
--         function() return false, "cat_form" end,
--         { type = "block", label = "no dispel in cat form" }
--     )
-- else
--     dispels:unregister("druid_no_dispel")
-- end

-- Tips:
-- • If you register ANY allow filter, dispels are permitted ONLY when at least one allow returns true.
-- • Prefer time or count expirations for temporary rules so you don't have to manually unregister.
-- • Use dispels:get_priority_enum() to access priority levels for filtering by debuff priority.

---@type dispel_external_filters_helper
local tbl
return tbl
