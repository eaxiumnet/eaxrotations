# Inventory Helper | Project Sylvanas

Source: https://docs.project-sylvanas.net/dev/libraries/mini-libs/inventory-helper

## Overview

📘 Libraries
Mini Libs
Inventory Helper

### Overview​

The Inventory Helper module provides a comprehensive set of utility functions that aims to make your life easier when working with items. Below, we'll explore its functionality.

### Importing The Module​

As with all other LUA modules developed by us, you will need to import the Inventory Helper module into your project. To do so, you can use the following lines:

```
---@type inventory_helperlocal inventory_helper = require("common/utility/inventory_helper")
```

warning
To access the module's functions, you must use : instead of .
For example, this code is not correct:

```
---@type inventory_helperlocal inventory_helper = require("common/utility/pvp_helper")local function check_if_player(unit)    return inventory_helper.get_bank_slots(unit)end
```

And this would be the corrected code:

```
---@type inventory_helperlocal inventory_helper = require("common/utility/pvp_helper")local function check_if_player(unit)    return inventory_helper:get_bank_slots(unit)end
```

#### get_all_slots() -> table<slot_data>​

Retrieves all item slots available to the player, including both character bags and bank slots.

Returns:

slots (table<slot_data>): A table containing slot data for all items.

#### get_character_bag_slots() -> table<slot_data>​

Retrieves all item slots from the character's bags, excluding bank slots.

Returns:

slots (table<slot_data>): A table containing slot data for items in character bags.

#### get_bank_slots() -> table<slot_data>​

Retrieves all item slots from the bank.

Returns:

slots (table<slot_data>): A table containing slot data for items in the bank.

#### get_current_consumables_list() -> table<consumable_data>​

Retrieves a list of consumables currently in the player's inventory.

Returns:

consumables (table<consumable_data>): A table containing data for each consumable item.

#### update_consumables_list()​

Updates the internal list of consumables. Call this function whenever the inventory changes to refresh the consumables list.

Example:

```
---@type inventory_helperlocal inventory_helper = require("common/utility/pvp_helper")-- After picking up new consumablesinventory_helper:update_consumables_list()
```

#### debug_print_consumables()​

Prints the current consumables list to the debug log for debugging purposes.

#### Slot Data Structure 🎒​

The slot_data class represents an item slot in the inventory or bank.

##### Fields:​

item (game_object): The item object in this slot.

global_slot (number): Global slot identifier.

bag_id (integer): ID of the bag containing the item.

bag_slot (integer): Slot number within the bag.

stack_count (integer): Stack count of the item in this slot.

Example:

```
local slot = all_slots[1]core.log("Item: " .. slot.item:get_name())core.log("Stack Count: " .. tostring(slot.stack_count))
```

#### Consumable Data Structure 🧪​

The consumable_data class represents a consumable item in the inventory.

##### Fields:​

is_mana_potion (boolean): Whether the item is a mana potion.

is_health_potion (boolean): Whether the item is a health potion.

is_damage_bonus_potion (boolean): Whether the item is a damage bonus potion.

item (game_object): The item object for the consumable.

bag_id (integer): ID of the bag containing the item.

bag_slot (integer): Slot number within the bag.

stack_count (integer): Stack count of the item in this slot.

#### Iterating Over All Inventory Slots​

```
---@type inventory_helperlocal inventory = require("common/utility/inventory_helper")local function print_all_items()    local all_slots = inventory:get_all_slots()    for _, slot in ipairs(all_slots) do        core.log("Item: " .. slot.item:get_name() .. " in slot: " .. tostring(slot.global_slot))    endendprint_all_items()
```

Previous
Coords Helper
Next
Dungeons Helper

Overview
Importing The Module
Functionsget_all_slots() -> table<slot_data>
get_character_bag_slots() -> table<slot_data>
get_bank_slots() -> table<slot_data>
get_current_consumables_list() -> table<consumable_data>
update_consumables_list()
debug_print_consumables()

Data StructuresSlot Data Structure 🎒
Consumable Data Structure 🧪

ExamplesIterating Over All Inventory Slots
