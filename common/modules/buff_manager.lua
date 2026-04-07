
-- Example:
-- ---@type buff_manager
-- local x = require("common/modules/buff_manager")
-- x: -> IntelliSense
-- Warning: Access with ":", not "."

---@class buff_manager_data
---@field is_active boolean
---@field stacks number
---@field remaining number                         -- remaining time in ms
---@field expire_time number                       -- engine time in ms when aura expires
---@field buff_id integer                          -- spell id of the aura
---@field count number                             -- alias of stacks in some contexts
---@field duration number
---@field caster game_object                       -- the unit that applied the aura
---@field ptr buff                                 -- raw buff pointer
---@field buff_name string                         -- name of the aura
---@field buff_type number                         -- type of the aura

---@class buff_manager_cache_data
---@field buff_id number
---@field count number
---@field expire_time number
---@field duration number
---@field caster game_object
---@field ptr buff
---@field buff_name string
---@field buff_type number
---@field is_undefined boolean
---@field is_active boolean
---@field stacks number
---@field remaining number                         -- remaining time in ms

---@class buff_manager
--- Gets the aura data for a unit, with caching.
---@field get_aura_data fun(self: buff_manager, unit: game_object, enum_key: buff_db | number[], custom_cache_duration_ms?: number): buff_manager_data
--- Gets the buff data for a unit, with caching.
---@field get_buff_data fun(self: buff_manager, unit: game_object, enum_key: buff_db | number[], custom_cache_duration_ms?: number): buff_manager_data
--- Gets the debuff data for a unit, with caching.
---@field get_debuff_data fun(self: buff_manager, unit: game_object, enum_key: buff_db | number[], custom_cache_duration_ms?: number): buff_manager_data
--- Gets the buff cache for a unit.
---@field get_buff_cache fun(self: buff_manager, unit: game_object, custom_cache_duration_ms?: number): buff_manager_cache_data[]
--- Gets the debuff cache for a unit.
---@field get_debuff_cache fun(self: buff_manager, unit: game_object, custom_cache_duration_ms?: number): buff_manager_cache_data[]
--- Gets the aura cache for a unit.
---@field get_aura_cache fun(self: buff_manager, unit: game_object, custom_cache_duration_ms?: number): buff_manager_cache_data[]

---@class buff_manager
--- Check if the spell is currently on cooldown.
---@field get_buff_value_from_description fun(self: buff_manager, description_text: string, ignore_percentage: boolean, ignore_flat: boolean): number

---@type buff_manager
local tbl
return tbl
