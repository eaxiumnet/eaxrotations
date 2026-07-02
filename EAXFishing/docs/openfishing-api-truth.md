# OpenFishing2 API Truth Ledger

> **Source of Truth for Sylvanas Runtime API Usage**
> 
> This document serves as the canonical reference for all runtime API calls used by OpenFishing2.
> Every API call must be documented here with its source of truth.
> 
> Last Updated: 2026-03-14
> Plugin Version: 1.5.0

---

## API Status Legend

| Status | Icon | Meaning |
|--------|------|---------|
| Approved | ✅ | Documented in official docs or verified working in runtime |
| Fallback | ⚠️ | Not in primary docs but has fallback chain |
| Conflict | ❌ | Banned - do not use, has replacement |
| Pending | ⏳ | Under investigation |

---

## Approved APIs

### Core Registration

#### `core.register_on_update_callback(callback)`
- **Status**: ✅ Approved
- **Source**: main.lua.bak, line 2377
- **Purpose**: Register main update loop
- **Usage**: `core.register_on_update_callback(function() ... end)`

#### `core.register_on_render_callback(callback)`
- **Status**: ✅ Approved
- **Source**: main.lua.bak, line 2388
- **Purpose**: Register render/ESP loop
- **Usage**: `core.register_on_render_callback(function() ... end)`

#### `core.register_on_render_menu_callback(callback)`
- **Status**: ✅ Approved
- **Source**: main.lua, line 66
- **Purpose**: Register PS menu callback
- **Usage**: `core.register_on_render_menu_callback(function() ... end)`

#### `core.register_on_render_control_panel_callback(callback)`
- **Status**: ✅ Approved
- **Source**: main.lua, line 74
- **Purpose**: Register control panel callback
- **Usage**: `core.register_on_render_control_panel_callback(function() return elements end)`

### Object Manager

#### `core.object_manager.get_local_player()`
- **Status**: ✅ Approved
- **Source**: main.lua.bak, line 1724
- **Purpose**: Get local player game object
- **Returns**: player object or nil
- **Usage**: `local me = core.object_manager.get_local_player()`

#### `core.object_manager.get_all_objects()`
- **Status**: ✅ Approved (Primary)
- **Source**: Fish Helper docs, Object Manager docs
- **Purpose**: Get all game objects in range
- **Note**: Use this instead of get_visible_objects()
- **Returns**: Array of game objects
- **Usage**: `local objects = core.object_manager.get_all_objects()`

#### `core.object_manager.get_visible_objects()`
- **Status**: ⚠️ Fallback
- **Source**: Currently used in engine.lua
- **Purpose**: Get visible objects
- **Note**: Marked as "not currently implemented" in some docs, but works in runtime
- **Migration**: Use get_all_objects() for new code
- **Usage**: `local objects = core.object_manager.get_visible_objects()`

### Game Object Methods

#### `game_object:is_valid()`
- **Status**: ✅ Approved
- **Source**: main.lua.bak, extensive usage
- **Purpose**: Check if object is valid
- **Returns**: boolean
- **Usage**: `if obj:is_valid() then ... end`

#### `game_object:get_name()`
- **Status**: ✅ Approved
- **Source**: main.lua.bak, line 1730
- **Purpose**: Get object name
- **Returns**: string
- **Usage**: `local name = obj:get_name()`

#### `game_object:get_position()`
- **Status**: ✅ Approved
- **Source**: main.lua.bak, line 1731
- **Purpose**: Get object position
- **Returns**: {x, y, z} table
- **Usage**: `local pos = obj:get_position()`

#### `game_object:get_creator_object()`
- **Status**: ✅ Approved
- **Source**: main.lua.bak, line 1758
- **Purpose**: Get object that created this object (for bobber ownership)
- **Returns**: game_object or nil
- **Usage**: `local creator = bobber:get_creator_object()`

#### `game_object:does_bobber_have_fish()`
- **Status**: ✅ Approved
- **Source**: main.lua.bak, line 2151
- **Purpose**: Check if bobber has fish biting
- **Returns**: boolean
- **Usage**: `if bobber:does_bobber_have_fish() then ... end`

#### `game_object:get_item_id()`
- **Status**: ✅ Approved
- **Source**: fishing/gear.lua
- **Purpose**: Get item ID from inventory item object
- **Returns**: number
- **Usage**: `local id = item.object:get_item_id()`

#### `game_object:get_item_at_inventory_slot(slot)`
- **Status**: ✅ Approved
- **Source**: main.lua.bak, line 1862
- **Purpose**: Get item at inventory slot
- **Params**: slot (16=main hand, 17=off hand)
- **Returns**: {object, bag, slot} table
- **Usage**: `local item = me:get_item_at_inventory_slot(16)`

#### `game_object:is_dead()`
- **Status**: ✅ Approved
- **Source**: fishing/engine.lua
- **Purpose**: Check if player is dead
- **Returns**: boolean

#### `game_object:is_ghost()`
- **Status**: ✅ Approved
- **Source**: fishing/engine.lua
- **Purpose**: Check if player is ghost
- **Returns**: boolean

#### `game_object:is_in_combat()`
- **Status**: ✅ Approved
- **Source**: main.lua.bak, line 1810
- **Purpose**: Check if player is in combat
- **Returns**: boolean

#### `game_object:is_casting_spell()`
- **Status**: ✅ Approved
- **Source**: main.lua.bak, line 1722
- **Purpose**: Check if player is casting
- **Returns**: boolean

#### `game_object:is_channelling_spell()`
- **Status**: ✅ Approved
- **Source**: main.lua.bak, line 1723
- **Purpose**: Check if player is channeling
- **Returns**: boolean

#### `game_object:is_moving()`
- **Status**: ✅ Approved
- **Source**: fishing/engine.lua
- **Purpose**: Check if player is moving
- **Returns**: boolean

#### `game_object:get_buffs()`
- **Status**: ✅ Approved
- **Source**: fishing/lures.lua
- **Purpose**: Get active buffs
- **Returns**: Array of buff tables {buff_id, buff_name, ...}

### Input APIs

#### `core.input.cast_target_spell(spell_id, target)`
- **Status**: ✅ Approved
- **Source**: main.lua.bak, line 2090
- **Purpose**: Cast a spell at target
- **Params**: spell_id (number), target (game_object)
- **Usage**: `core.input.cast_target_spell(fishing_id, me)`

#### `core.input.use_object(obj)`
- **Status**: ✅ Approved
- **Source**: main.lua.bak, line 2220
- **Purpose**: Interact with object (click bobber)
- **Params**: obj (game_object)
- **Usage**: `core.input.use_object(bobber)`

#### `core.input.look_at(pos)`
- **Status**: ✅ Approved
- **Source**: main.lua.bak, line 2068
- **Purpose**: Face position
- **Params**: pos {x, y, z}
- **Usage**: `core.input.look_at(pool_pos)`

#### `core.input.jump()`
- **Status**: ✅ Approved
- **Source**: fishing/engine.lua
- **Purpose**: Jump (for anti-AFK)
- **Usage**: `core.input.jump()`

#### `core.input.move_forward_stop()`
- **Status**: ✅ Approved
- **Source**: navigation/client.lua
- **Purpose**: Stop moving forward
- **Usage**: `core.input.move_forward_stop()`

#### `core.input.repair_all_items(merchant_open)`
- **Status**: ✅ Approved
- **Source**: Input docs, main.lua.bak
- **Purpose**: Repair all items
- **Params**: merchant_open (boolean)
- **Usage**: `core.input.repair_all_items(false)`

#### `core.input.loot_item(index)`
- **Status**: ✅ Approved
- **Source**: Input docs
- **Purpose**: Loot specific item by index
- **Params**: index (number, 0-based)
- **Usage**: `core.input.loot_item(0)`

### Inventory APIs

#### `core.inventory.get_total_repair_cost()`
- **Status**: ✅ Approved
- **Source**: Inventory docs, main.lua.bak
- **Purpose**: Get total repair cost
- **Returns**: number (copper)

#### `core.inventory.get_gold()`
- **Status**: ✅ Approved
- **Source**: Inventory docs, main.lua.bak
- **Purpose**: Get player gold amount
- **Returns**: number (copper)

#### `core.inventory.get_num_bag_slots()`
- **Status**: ✅ Approved
- **Source**: Inventory docs
- **Purpose**: Get number of bag slots
- **Returns**: number

#### `core.inventory.get_items_in_bag(bag_id)`
- **Status**: ✅ Approved
- **Source**: Inventory docs
- **Purpose**: Get items in specific bag
- **Returns**: Array of items

### Game UI APIs

#### `core.game_ui.get_loot_item_count()`
- **Status**: ✅ Approved
- **Source**: Game UI docs, fishing/loot.lua
- **Purpose**: Get number of items in loot window
- **Returns**: number

#### `core.game_ui.get_loot_is_gold(index)`
- **Status**: ✅ Approved
- **Source**: Game UI docs
- **Purpose**: Check if loot slot is gold
- **Returns**: boolean

#### `core.game_ui.get_loot_item_id(index)`
- **Status**: ✅ Approved
- **Source**: Game UI docs
- **Purpose**: Get item ID at loot slot
- **Returns**: number

#### `core.game_ui.get_loot_item_name(index)`
- **Status**: ✅ Approved
- **Source**: Game UI docs
- **Purpose**: Get item name at loot slot
- **Returns**: string

### Spell Book APIs

#### `core.spell_book.is_spell_learned(spell_id)`
- **Status**: ✅ Approved
- **Source**: Spell Helper docs
- **Purpose**: Check if spell is learned
- **Returns**: boolean

#### `core.spell_book.get_spells()`
- **Status**: ✅ Approved
- **Source**: Spell Helper docs
- **Purpose**: Get all learned spells
- **Returns**: Array of spell IDs

### Graphics APIs

#### `core.graphics.line_3d(from, to, color, thickness)`
- **Status**: ✅ Approved
- **Source**: ui/render.lua
- **Purpose**: Draw 3D line (ESP)

#### `core.graphics.text_3d(text, pos, size, color)`
- **Status**: ✅ Approved
- **Source**: ui/render.lua
- **Purpose**: Draw 3D text (ESP labels)

#### `core.graphics.text_2d(text, pos, size, color, centered)`
- **Status**: ✅ Approved
- **Source**: main.lua.bak, line 2326
- **Purpose**: Draw 2D HUD text

### Menu APIs

#### `core.menu.tree_node()`
- **Status**: ✅ Approved
- **Source**: config.lua
- **Purpose**: Create menu root node

#### `core.menu.checkbox(default, id)`
- **Status**: ✅ Approved
- **Source**: config.lua
- **Purpose**: Create checkbox menu item

#### `core.menu.slider_int(min, max, default, id)`
- **Status**: ✅ Approved
- **Source**: config.lua
- **Purpose**: Create integer slider

#### `core.menu.text_input(id, placeholder)`
- **Status**: ✅ Approved
- **Source**: config.lua
- **Purpose**: Create text input field

#### `core.menu.header()`
- **Status**: ✅ Approved
- **Source**: ui/menu.lua
- **Purpose**: Create menu header section

---

## Helper Modules

### IZI SDK

#### `izi.print(message)`
- **Status**: ✅ Approved
- **Source**: main.lua.bak
- **Purpose**: Print to console

#### `izi.now()`
- **Status**: ✅ Approved
- **Source**: main.lua.bak
- **Purpose**: Get current timestamp
- **Returns**: number (seconds since epoch)

#### `izi.item(item_id)`
- **Status**: ✅ Approved
- **Source**: main.lua.bak, fishing/gear.lua
- **Purpose**: Get item reference
- **Returns**: item object with methods:
  - `item:count()` - Get stack count
  - `item:use_self()` - Use item on self
  - `item:use_self_safe()` - Safe version
  - `item:use_on(target)` - Use on target
  - `item:use_on_safe(target)` - Safe version

#### `izi.get_terrain_height(x, y)`
- **Status**: ✅ Approved
- **Source**: IZI Maps docs
- **Purpose**: Get terrain height at position
- **Returns**: number (z height)

### Fish Helper

#### `fish_helper:is_fish_bobber(obj)`
- **Status**: ✅ Approved
- **Source**: Fish Helper docs
- **Purpose**: Check if object is a fishing bobber
- **Returns**: boolean

#### `fish_helper:does_bobber_have_fish(bobber)`
- **Status**: ✅ Approved
- **Source**: Fish Helper docs
- **Purpose**: Check if bobber has fish
- **Returns**: boolean

#### `fish_helper:loot_item(index)`
- **Status**: ✅ Approved
- **Source**: Fish Helper docs
- **Purpose**: Loot item at index

### Inventory Helper

#### `inventory_helper:get_total_free_slots()`
- **Status**: ✅ Approved
- **Source**: Inventory Helper docs, inventory/bags.lua
- **Purpose**: Get total free bag slots
- **Returns**: number

### Coords Helper

#### `coords_helper:get_terrain_height(x, y)`
- **Status**: ✅ Approved
- **Source**: Coords Helper docs
- **Purpose**: Get terrain height
- **Returns**: number (z height)

### Control Panel Helper

#### `control_panel_helper:on_update(menu)`
- **Status**: ✅ Approved
- **Source**: Control Panel docs, fishing/engine.lua
- **Purpose**: Update control panel state

#### `control_panel_helper:insert_key_checkbox_(elements, label, value, key, disabled, id)`
- **Status**: ✅ Approved
- **Source**: ui/control_panel.lua
- **Purpose**: Add checkbox to control panel

### Color Module

#### `color.new(r, g, b, a)`
- **Status**: ✅ Approved
- **Source**: ui/render.lua, main.lua.bak
- **Purpose**: Create color object

### Item Enchant Methods (for Lures)

#### `item:item_has_enchant()`
- **Status**: ✅ Approved
- **Source**: fishing/lures.lua
- **Purpose**: Check if item has temporary enchant
- **Returns**: boolean

#### `item:item_enchant_id()`
- **Status**: ✅ Approved
- **Source**: fishing/lures.lua
- **Purpose**: Get enchant ID
- **Returns**: number|nil

#### `item:item_enchant_expiration()`
- **Status**: ✅ Approved
- **Source**: fishing/lures.lua
- **Purpose**: Get enchant expiration time
- **Returns**: number|nil

#### `item:item_enchant_charges()`
- **Status**: ✅ Approved
- **Source**: fishing/lures.lua
- **Purpose**: Get enchant charges remaining
- **Returns**: number|nil

---

## Conflict APIs (BANNED - DO NOT USE)

### `core.vendor.repair_all()`
- **Status**: ❌ BANNED
- **Location**: inventory/vendor.lua:32
- **Replacement**: `core.input.repair_all_items(false)` with cost/gold checks
- **Reason**: Vendor API not in documented surface

### `core.input.loot_slot(slot)`
- **Status**: ❌ BANNED
- **Location**: fishing/loot.lua:60
- **Replacement**: `fish_helper:loot_item(index)` or `core.input.loot_item(index)`
- **Reason**: loot_slot not in Input docs, use documented alternatives

### `core.terrain.get_height(x, y)`
- **Status**: ❌ BANNED
- **Location**: navigation/terrain.lua:24
- **Replacement**: `coords_helper:get_terrain_height(x,y)` → `izi.get_terrain_height(x,y)` → `core.get_height_for_position(vec3)`
- **Reason**: Not in documented terrain APIs

### `core.input.equip_item(item_id, slot)`
- **Status**: ❌ BANNED
- **Location**: fishing/gear.lua:147,155
- **Replacement**: `izi.item(id):use_self_safe()` with slot validation
- **Reason**: Not in Input docs, use izi.item instead

### `me.get_inventory_item_id(me, slot_id)`
- **Status**: ❌ BANNED
- **Location**: fishing/gear.lua:84
- **Replacement**: `me:get_item_at_inventory_slot(slot).object:get_item_id()`
- **Reason**: Undocumented method, use documented slot access

### `bobber.is_animating(bobber)`
- **Status**: ❌ BANNED
- **Location**: fishing/engine.lua:393
- **Replacement**: REMOVE - use `bobber:does_bobber_have_fish()` or `fish_helper:does_bobber_have_fish(bobber)`
- **Reason**: Animation heuristic, not reliable, use documented fish detection

### `me.does_bobber_have_fish(me)`
- **Status**: ❌ BANNED
- **Location**: fishing/engine.lua:383
- **Replacement**: `bobber:does_bobber_have_fish()` or `fish_helper:does_bobber_have_fish(bobber)`
- **Reason**: Use bobber method or fish_helper, not player method

---

## Implementation Notes

### Safe API Usage Pattern

All API calls must be wrapped in `pcall` for safety:

```lua
local ok, result = pcall(api_function, args...)
if ok then
    -- Use result
else
    -- Handle error silently
end
```

### API Surface Pattern

All runtime API access should go through `core/api_surface.lua`:

```lua
local APISurface = require("core/api_surface")

-- Instead of direct core.* calls:
local me = core.object_manager.get_local_player()

-- Use adapter:
local me = APISurface.get_local_player()
```

### Fallback Chain Pattern

For non-critical features, implement fallback chains:

```lua
-- Try helper first
if inventory_helper and inventory_helper.get_total_free_slots then
    return inventory_helper:get_total_free_slots()
end

-- Fallback to core.inventory
if core.inventory and core.inventory.get_num_bag_slots then
    -- Manual calculation
end

-- Final fallback: assume space available
return 999
```

---

## Validation

To verify no banned APIs are in use:

```bash
grep -r "core\.vendor\.repair_all" .
grep -r "core\.input\.loot_slot" .
grep -r "core\.terrain\.get_height" .
grep -r "core\.input\.equip_item" .
grep -r "get_inventory_item_id" .
grep -r "is_animating" .
grep -r "me\.does_bobber_have_fish" .
```

All should return zero results.

---

## Changelog

| Date | Version | Changes |
|------|---------|---------|
| 2026-03-14 | 1.5.0 | Initial API truth ledger created |
