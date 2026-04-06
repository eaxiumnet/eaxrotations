
--[[
Example:
---@type inventory_helper
local inventory = require("common/utility/inventory_helper")
inventory: -> IntelliSense
Warning: Access with ":", not "."
]]

-- This library centralizes inventory management.
-- Simplifying access to items in all bags, bank slots, and tracking specific consumables like potions and elixirs.
-- Character bags are 1-4. Bag 1 has an internal slot offset (0-34 are equipped gear/bag objects).

---@class slot_data
---@field item game_object          -- The item object in this slot
---@field global_slot number        -- Global slot identifier
---@field bag_id integer            -- ID of the bag containing the item
---@field bag_slot integer          -- Slot number within the bag
---@field stack_count integer       -- Stack count of the item in this slot

---@class consumable_data
---@field is_mana_potion boolean    -- Whether the item is a mana potion
---@field is_health_potion boolean  -- Whether the item is a health potion
---@field is_damage_bonus_potion boolean -- Whether the item is a damage bonus potion
---@field is_food_or_drink boolean  -- Whether the item is food or a drink
---@field item game_object          -- The item object for the consumable
---@field bag_id integer            -- ID of the bag containing the item
---@field bag_slot integer          -- Slot number within the bag
---@field stack_count integer       -- Stack count of the item in this slot

---@class inventory_helper
---@field get_all_slots fun(self: inventory_helper): slot_data[]                          -- Returns all items from character bags (1-4) and bank slots
---@field get_character_bag_slots fun(self: inventory_helper): slot_data[]                 -- Returns all items from character bags (1-4)
---@field get_bank_slots fun(self: inventory_helper): slot_data[]                          -- Returns all items from bank content (-1) and bank bags (5-11)
---@field get_current_consumables_list fun(self: inventory_helper): consumable_data[]      -- Returns the cached consumables list
---@field update_consumables_list fun(self: inventory_helper)                              -- Refreshes the consumables list from bags (throttled to every 2s)
---@field debug_print_consumables fun(self: inventory_helper)                              -- Logs all current consumables to core.log
---@field get_total_bag_capacity fun(self: inventory_helper): integer                      -- Returns total usable slot count across all character bags (1-4)
---@field get_total_free_slots fun(self: inventory_helper): integer                        -- Returns total empty slots across all character bags (1-4)
---@field get_total_used_slots fun(self: inventory_helper): integer                        -- Returns total occupied slots across all character bags (1-4)
---@field get_bag_info fun(self: inventory_helper, bag_id: integer): integer, integer      -- Returns capacity and free slots for a specific bag (1-4)

---@type inventory_helper
local tbl
return tbl
