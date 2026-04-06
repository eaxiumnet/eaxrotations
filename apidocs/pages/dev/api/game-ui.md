# Game UI | Project Sylvanas

Source: https://docs.project-sylvanas.net/dev/api/game-ui

## Overview

👨‍💻 Lua Scripting API
Game UI

### Overview​

The core.game_ui module provides functions for interacting with the World of Warcraft game interface. This includes accessing loot windows, battlefield information, cursor positions, and map utilities.

#### core.game_ui.get_loot_item_count​

Syntax

```
core.game_ui.get_loot_item_count() -> integer
```

Returns

integer: The number of lootable items currently available in the loot window.

Description
Retrieves the number of items currently available in the loot window.

Example Usage

```
local item_count = core.game_ui.get_loot_item_count()core.log("Lootable items: " .. item_count)
```

#### core.game_ui.get_loot_item_id​

Syntax

```
core.game_ui.get_loot_item_id(index: integer) -> integer
```

Parameters

index: integer - The index of the loot item.

Returns

integer: The ID of the lootable item.

Description
Retrieves the item ID of a lootable item at the specified index.

Example Usage

```
local item_id = core.game_ui.get_loot_item_id(0)core.log("First loot item ID: " .. item_id)
```

#### core.game_ui.get_loot_item_name​

Syntax

```
core.game_ui.get_loot_item_name(index: integer) -> string
```

Parameters

index: integer - The index of the loot item.

Returns

string: The name of the lootable item.

Description
Retrieves the name of the lootable item at the specified index.

Example Usage

```
local item_name = core.game_ui.get_loot_item_name(0)core.log("First loot item: " .. item_name)
```

#### core.game_ui.get_loot_is_gold​

Syntax

```
core.game_ui.get_loot_is_gold(index: integer) -> boolean
```

Parameters

index: integer - The index of the loot item.

Returns

boolean: true if the item is gold; otherwise, false.

Description
Checks if the lootable item at the specified index is gold.

Example Usage

```
if core.game_ui.get_loot_is_gold(0) then    core.log("First loot slot contains gold!")end
```

### Loot Window - Complete Example​

```
local function process_loot()    local count = core.game_ui.get_loot_item_count()        for i = 0, count - 1 do        if core.game_ui.get_loot_is_gold(i) then            core.log("Slot " .. i .. ": Gold")        else            local name = core.game_ui.get_loot_item_name(i)            local id = core.game_ui.get_loot_item_id(i)            core.log("Slot " .. i .. ": " .. name .. " (ID: " .. id .. ")")        end    endend
```

#### core.game_ui.get_battlefield_status​

Syntax

```
core.game_ui.get_battlefield_status(index: integer) -> string
```

Parameters

index: integer - The battlefield queue index.

Returns

string: The status of the battlefield queue.

Description
Retrieves the status of a battlefield queue at the specified index.

Possible Return Values:

ValueDescription"confirm"Battlefield is ready to join"queued"Currently in queue"active"Currently in the battlefield"error"Error state"none"Not queued
Example Usage

```
local status = core.game_ui.get_battlefield_status(1)if status == "confirm" then    core.log("Battlefield ready! Accept the queue.")elseif status == "queued" then    core.log("Waiting in queue...")end
```

#### core.game_ui.get_battlefield_state​

Syntax

```
core.game_ui.get_battlefield_state() -> integer
```

Returns

integer: The current state of the battlefield.

Description
Retrieves the current state of the battlefield.

State Values:

ValueDescription2Preparation phase3Active/In progress5Finished
Example Usage

```
local state = core.game_ui.get_battlefield_state()if state == 2 then    core.log("Battlefield starting soon - preparation phase")elseif state == 3 then    core.log("Battlefield in progress!")elseif state == 5 then    core.log("Battlefield finished")end
```

#### core.game_ui.get_battlefield_run_time​

Syntax

```
core.game_ui.get_battlefield_run_time() -> number
```

Returns

number: Timer in milliseconds since the battlefield started.

Description
Retrieves the time elapsed since the battlefield started.

Example Usage

```
local run_time = core.game_ui.get_battlefield_run_time()local minutes = math.floor(run_time / 60000)local seconds = math.floor((run_time % 60000) / 1000)core.log(string.format("Battlefield running for: %d:%02d", minutes, seconds))
```

#### core.game_ui.get_battlefield_winner​

Syntax

```
core.game_ui.get_battlefield_winner() -> integer|nil
```

Returns

integer|nil: The winner of the battlefield, or nil if no winner yet.

Description
Retrieves the winner of the battlefield.

Return Values:

ValueDescriptionnilNo winner yet (match in progress)0Horde won1Alliance won2Tie
Example Usage

```
local winner = core.game_ui.get_battlefield_winner()if winner == nil then    core.log("Match still in progress")elseif winner == 0 then    core.log("Horde wins!")elseif winner == 1 then    core.log("Alliance wins!")elseif winner == 2 then    core.log("It's a tie!")end
```

#### core.game_ui.get_wow_cursor_position​

Syntax

```
core.game_ui.get_wow_cursor_position() -> vec2
```

Returns

vec2: The cursor position in WoW UI coordinates.

Description
Retrieves the current WoW cursor position in UI coordinates.

Example Usage

```
local cursor = core.game_ui.get_wow_cursor_position()core.log(string.format("WoW Cursor: (%.2f, %.2f)", cursor.x, cursor.y))
```

#### core.game_ui.get_normalized_cursor_position​

Syntax

```
core.game_ui.get_normalized_cursor_position() -> vec2
```

Returns

vec2: The cursor position normalized to 0-1 range.

Description
Retrieves the current cursor position in normalized coordinates (0-1 range).

Example Usage

```
local cursor = core.game_ui.get_normalized_cursor_position()-- cursor.x and cursor.y will be between 0 and 1core.log(string.format("Normalized Cursor: (%.3f, %.3f)", cursor.x, cursor.y))
```

#### core.game_ui.normalize_ui_position​

Syntax

```
core.game_ui.normalize_ui_position(pos: vec2) -> vec2
```

Parameters

pos: vec2 - The UI position to normalize.

Returns

vec2: The normalized position (0-1 range).

Description
Normalizes a UI position to the 0-1 range.

Example Usage

```
local ui_pos = vec2.new(960, 540)local normalized = core.game_ui.normalize_ui_position(ui_pos)core.log(string.format("Normalized: (%.3f, %.3f)", normalized.x, normalized.y))
```

#### core.game_ui.get_current_map_id​

Syntax

```
core.game_ui.get_current_map_id() -> integer
```

Returns

integer: The ID of the current map.

Description
Retrieves the ID of the current map from the game UI context.

Example Usage

```
local map_id = core.game_ui.get_current_map_id()core.log("Current UI map ID: " .. map_id)
```

#### core.game_ui.is_map_open​

Syntax

```
core.game_ui.is_map_open() -> boolean
```

Returns

boolean: true if the world map is currently open; otherwise, false.

Description
Checks whether the world map UI is currently open.

Example Usage

```
if core.game_ui.is_map_open() then    core.log("Map is open - player is checking their location")else    core.log("Map is closed")end
```

Example: Pause Navigation While Map Open

```
local function update_navigation()    -- Don't process movement while player is looking at the map    if core.game_ui.is_map_open() then        return    end        -- Continue with navigation logic...    movement:process()end
```

#### core.game_ui.get_world_pos_from_map_pos​

Syntax

```
core.game_ui.get_world_pos_from_map_pos(map_id: integer, map_pos: vec2) -> vec2
```

Parameters

map_id: integer - The map ID.

map_pos: vec2 - The position on the map (normalized 0-1 coordinates).

Returns

vec2: The X/Y world position (Z height not included).

Description
Converts a map position to world coordinates. Returns a vec2 with X and Y in 3D world format - note that the Z (height) component is not included.

Example Usage

```
local map_id = core.game_ui.get_current_map_id()local map_pos = vec2.new(0.5, 0.5) -- Center of the maplocal world_pos = core.game_ui.get_world_pos_from_map_pos(map_id, map_pos)core.log(string.format("World position: (%.2f, %.2f)", world_pos.x, world_pos.y))-- To get the Z coordinate, use:local full_pos = vec3.new(world_pos.x, world_pos.y, 0)local height = core.get_height_for_position(full_pos)
```

#### core.game_ui.get_map_top_left​

Syntax

```
core.game_ui.get_map_top_left() -> vec2
```

Returns

vec2: The top-left corner of the world map frame in UI coordinates.

Description
Returns the top-left corner position of the world map frame in UI coordinates.

#### core.game_ui.get_map_bottom_right​

Syntax

```
core.game_ui.get_map_bottom_right() -> vec2
```

Returns

vec2: The bottom-right corner of the world map frame in UI coordinates.

Description
Returns the bottom-right corner position of the world map frame in UI coordinates.

#### core.game_ui.ui_pos_to_screen_pos​

Syntax

```
core.game_ui.ui_pos_to_screen_pos(ui_pos: vec2) -> vec2
```

Parameters

ui_pos: vec2 - The position in UI coordinates.

Returns

vec2: The corresponding screen-space position in pixels.

Description
Converts a UI-space position to screen-space pixel coordinates.

#### core.game_ui.world_pos_to_map_pos_normalized​

Syntax

```
core.game_ui.world_pos_to_map_pos_normalized(world_pos: vec3) -> vec2
```

Parameters

world_pos: vec3 - A world position.

Returns

vec2: The normalized map position (0-1 range).

Description
Converts a 3D world position to normalized map coordinates.

#### core.game_ui.get_effective_scale​

Syntax

```
core.game_ui.get_effective_scale() -> number
```

Returns

number: The effective UI scale factor.

Description
Retrieves the effective UI scale factor. This is used internally to convert between raw UI coordinates and screen-space coordinates.

Example Usage

```
local scale = core.game_ui.get_effective_scale()core.log("Effective UI scale: " .. scale)
```

#### core.game_ui.get_vendor_item_count​

Syntax

```
core.game_ui.get_vendor_item_count() -> integer
```

Returns

integer: The total number of items the current vendor has for sale.

Description
Returns how many items the currently open vendor window contains.

Example Usage

```
local count = core.game_ui.get_vendor_item_count()core.log("Vendor has " .. count .. " items for sale")
```

#### core.game_ui.get_vendor_item_info​

Syntax

```
core.game_ui.get_vendor_item_info(vendor_item_id: integer) -> vendor_item_info
```

Parameters

vendor_item_id: integer - The 1-based index of the vendor item.

Returns

vendor_item_info: A table containing the vendor item details.

vendor_item_info Properties:

FieldTypeDescriptioncostintegerThe cost of the item in copperis_usablebooleanWhether the item is usable by the playeritem_idintegerThe item IDitem_namestringThe name of the itemquantityintegerThe quantity availablevendor_item_indexintegerThe vendor slot index
Description
Retrieves detailed information about a specific vendor item. The vendor_item_id parameter is 1-indexed (internally adjusted to 0-indexed).

Example Usage

```
local count = core.game_ui.get_vendor_item_count()for i = 1, count do    local info = core.game_ui.get_vendor_item_info(i)    local gold = math.floor(info.cost / 10000)    local silver = math.floor((info.cost % 10000) / 100)    core.log(string.format("%s - %dg %ds (qty: %d)", info.item_name, gold, silver, info.quantity))end
```

#### core.game_ui.get_resurrect_corpse_delay​

Syntax

```
core.game_ui.get_resurrect_corpse_delay() -> number
```

Returns

number: The delay in seconds before resurrection is possible.

Description
Retrieves the remaining time before the player can resurrect at their corpse.

Example Usage

```
local delay = core.game_ui.get_resurrect_corpse_delay()if delay > 0 then    core.log("Can resurrect in " .. delay .. " seconds")else    core.log("Ready to resurrect!")end
```

#### core.game_ui.get_corpse_position​

Syntax

```
core.game_ui.get_corpse_position() -> vec3
```

Returns

vec3: The position of the player's corpse.

Description
Retrieves the position of the player's corpse as a 3D vector.

Example Usage

```
local corpse_pos = core.game_ui.get_corpse_position()core.log(string.format("Corpse at: (%.2f, %.2f, %.2f)", corpse_pos.x, corpse_pos.y, corpse_pos.z))-- Calculate distance to corpselocal player = core.object_manager.get_local_player()if player then    local player_pos = player:get_position()    local distance = player_pos:dist_to(corpse_pos)    core.log("Distance to corpse: " .. string.format("%.1f", distance) .. " yards")end
```

#### core.game_ui.get_quest_log_count​

Syntax

```
core.game_ui.get_quest_log_count() -> integer
```

Returns

integer: The total number of entries in the quest log (including headers).

Description
Returns the total number of entries in the quest log. This count includes both quest entries and zone header entries.

Example Usage

```
local count = core.game_ui.get_quest_log_count()core.log("Quest log entries: " .. count)
```

#### core.game_ui.get_quest_log_info​

Syntax

```
core.game_ui.get_quest_log_info(quest_log_id: integer) -> quest_log_info
```

Parameters

quest_log_id: integer - The 1-based index of the quest log entry.

Returns

quest_log_info: A table containing the quest log entry details.

quest_log_info Properties:

FieldTypeDescriptiontitlestringThe title of the questlevelintegerThe level of the questsuggested_groupstringThe suggested group size for the questis_headerbooleanWhether this entry is a header (zone name) rather than a questis_collapsedbooleanWhether this header is collapsedis_completeintegerQuest completion status (1 = complete, -1 = failed, 0 = in progress)frequencyintegerThe quest frequency (0 = normal, 1 = daily, 2 = weekly)quest_idintegerThe unique quest IDstart_eventbooleanWhether the quest has a start eventdisplay_quest_idbooleanWhether the quest ID should be displayedis_on_mapbooleanWhether the quest is shown on the maphas_local_poibooleanWhether the quest has a local point of interestis_taskbooleanWhether the quest is a bonus objective / world quest taskis_bountybooleanWhether the quest is a bounty (emissary) questis_storybooleanWhether the quest is part of the zone story lineis_hiddenbooleanWhether the quest is hiddenis_scalingbooleanWhether the quest scales with the player's level
Description
Retrieves detailed information about a quest log entry. The quest_log_id parameter is 1-indexed (internally adjusted to 0-indexed). Note that quest log entries include both zone headers and actual quests — use is_header to distinguish between them.

Example Usage

```
local count = core.game_ui.get_quest_log_count()for i = 1, count do    local info = core.game_ui.get_quest_log_info(i)    if info.is_header then        core.log("--- " .. info.title .. " ---")    else        local status = info.is_complete == 1 and "COMPLETE" or "In Progress"        core.log(string.format("  [%d] %s (Lv %d) - %s", info.quest_id, info.title, info.level, status))    endend
```

#### core.game_ui.get_all_completed_quest_ids​

Syntax

```
core.game_ui.get_all_completed_quest_ids() -> integer[]
```

Returns

integer[]: An array of completed quest IDs.

Description
Returns a list of all quest IDs the player has completed. This queries the server's completed quest history, not just the current quest log.

Example Usage

```
local completed = core.game_ui.get_all_completed_quest_ids()core.log("Total completed quests: " .. #completed)-- Check if a specific quest was completedlocal target_quest_id = 12345for _, quest_id in ipairs(completed) do    if quest_id == target_quest_id then        core.log("Quest " .. target_quest_id .. " has been completed!")        break    endend
```

#### Example: Auto-Loot System​

```
local function auto_loot()    local count = core.game_ui.get_loot_item_count()    if count == 0 then return end        for i = 0, count - 1 do        -- Always loot gold        if core.game_ui.get_loot_is_gold(i) then            core.input.loot_item(i)        else            local item_id = core.game_ui.get_loot_item_id(i)            -- Add your item filter logic here            if should_loot_item(item_id) then                core.input.loot_item(i)            end        end    endend
```

#### Example: Battlefield Status Monitor​

```
local function check_battlefield_status()    -- Check all queue slots    for i = 1, 3 do        local status = core.game_ui.get_battlefield_status(i)                if status == "confirm" then            core.graphics.add_notification(                "bg_ready_" .. i,                "Battlefield Ready!",                "Queue " .. i .. " is ready to join",                5000,                color.new(0, 255, 0, 255)            )        end    end        -- If in battlefield, show timer    local state = core.game_ui.get_battlefield_state()    if state == 3 then -- Active        local run_time = core.game_ui.get_battlefield_run_time()        local minutes = math.floor(run_time / 60000)        local seconds = math.floor((run_time % 60000) / 1000)        -- Display timer...    endend
```

#### Example: Corpse Run Helper​

```
local function corpse_run_helper()    local player = core.object_manager.get_local_player()    if not player or not player:is_dead() then return end        local corpse_pos = core.game_ui.get_corpse_position()    local player_pos = player:get_position()    local distance = player_pos:dist_to(corpse_pos)        -- Draw line to corpse    core.graphics.line_3d(player_pos, corpse_pos, color.new(255, 255, 0, 200), 2)        -- Draw circle at corpse    core.graphics.circle_3d(corpse_pos, 5, color.new(255, 255, 0, 200), 2)        -- Show distance    local screen_pos = core.graphics.w2s(corpse_pos)    if screen_pos then        core.graphics.text_2d(            string.format("%.0f yards", distance),            screen_pos,            16,            color.new(255, 255, 255, 255),            true        )    end        -- Check resurrection delay    local delay = core.game_ui.get_resurrect_corpse_delay()    if delay > 0 then        core.log("Wait " .. delay .. " seconds to resurrect")    endend
```

#### Example: Vendor Auto-Buy​

```
local function buy_from_vendor(item_name, quantity)    local count = core.game_ui.get_vendor_item_count()    for i = 1, count do        local info = core.game_ui.get_vendor_item_info(i)        if info.item_name == item_name and info.is_usable then            core.input.buy_item(i, quantity)            local gold = math.floor(info.cost * quantity / 10000)            core.log(string.format("Bought %dx %s for %dg", quantity, item_name, gold))            return true        end    end    core.log("Item not found at vendor: " .. item_name)    return falseend
```

Previous
File I/O
Next
Input

Overview
Loot Window Functions 💰core.game_ui.get_loot_item_count
core.game_ui.get_loot_item_id
core.game_ui.get_loot_item_name
core.game_ui.get_loot_is_gold

Loot Window - Complete Example
Battlefield Functions ⚔️core.game_ui.get_battlefield_status
core.game_ui.get_battlefield_state
core.game_ui.get_battlefield_run_time
core.game_ui.get_battlefield_winner

Cursor Functions 🖱️core.game_ui.get_wow_cursor_position
core.game_ui.get_normalized_cursor_position
core.game_ui.normalize_ui_position

Map Functions 🗺️core.game_ui.get_current_map_id
core.game_ui.is_map_open
core.game_ui.get_world_pos_from_map_pos
core.game_ui.get_map_top_left
core.game_ui.get_map_bottom_right
core.game_ui.ui_pos_to_screen_pos
core.game_ui.world_pos_to_map_pos_normalized

UI Scale Functions 📐core.game_ui.get_effective_scale

Vendor Functions 🏪core.game_ui.get_vendor_item_count
core.game_ui.get_vendor_item_info

Death & Resurrection Functions 💀core.game_ui.get_resurrect_corpse_delay
core.game_ui.get_corpse_position

Quest Log Functions 📜core.game_ui.get_quest_log_count
core.game_ui.get_quest_log_info
core.game_ui.get_all_completed_quest_ids

Complete Examples 📚Example: Auto-Loot System
Example: Battlefield Status Monitor
Example: Corpse Run Helper
Example: Vendor Auto-Buy
