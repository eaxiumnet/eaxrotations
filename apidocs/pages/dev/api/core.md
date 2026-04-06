# Core | Project Sylvanas

Source: https://docs.project-sylvanas.net/dev/api/core

## Overview

This module contains a collection of essential functions that you will probably need sooner or later in your scripts. This module includes utilities for logging, callbacks, time management, and accessing game information.

## Callbacks - Brief Explanation

This is essentially the most important part of scripting, since most of your code must be ran inside a callback.

### What is a Callback?

A callback is a function that you write, which you then pass to the game engine or framework. The engine doesn't execute this function immediately. Instead, it "calls back" to your function at a specific time or when a particular event occurs in the game.

Think of it like leaving your phone number with a friend (the game engine) and asking them to call you (execute your function) when a certain event happens.

### Why Use Callbacks?

Callbacks allow your game to respond to events without constantly checking for them. This makes your code more efficient and easier to manage. Instead of writing code that keeps asking, "Has the player pressed a button yet? Has an enemy appeared yet?" you can simply tell the game engine, "When this happens, run this function."

### Available Callbacks

| Callback | Description |
|----------|-------------|
| `On Update` | Run logic at reduced speed (not every frame). Ideal for spell casting decisions. |
| `On Render` | Called every frame for graphics rendering only. Do NOT put game logic here. |
| `On Render Menu` | Callback for rendering custom menu elements. |
| `On Render Control Panel` | Specialized callback for control panel elements only. |
| `On Spell Cast` | Triggers when any spell is cast (by player, allies, or enemies). |
| `On Legit Spell Cast` | Triggers only when player manually casts a spell. |

## Callback Functions

### core.register_on_pre_tick_callback

Syntax

```
core.register_on_pre_tick_callback(callback: function)
```

Parameters

callback: function - The function to be called before each game tick.

Description
Registers a callback function to be executed before each game tick.

### core.register_on_update_callback

Syntax

```
core.register_on_update_callback(callback: function)
```

Parameters

callback: function - The function to be called on each frame update.

Description
Registers a callback function to be executed on each frame update. This is where most rotation logic should run.

Example Usage

```lua
core.register_on_update_callback(function()
    -- Your rotation logic here
    local player = core.object_manager.get_local_player()
    if not player then return end
    
    -- Cast spell logic
end)
```

### core.register_on_render_callback

Syntax

```
core.register_on_render_callback(callback: function)
```

Parameters

callback: function - The function to be called during the render phase.

Description
Registers a callback function to be executed during the render phase. Use ONLY for drawing graphics, not game logic.

### core.register_on_spell_cast_callback

Syntax

```
core.register_on_spell_cast_callback(callback: function)
```

Parameters

callback: function - The function to be called when any spell is cast.

Description
Registers a callback function that is invoked whenever any spell is cast in the game, including spells cast by the player, allies, and enemies.

Callback Data Structure:

| Field | Type | Description |
|-------|------|-------------|
| spell_id | number | Unique identifier for the spell |
| caster | game_object\|nil | The game object that cast the spell |
| target | game_object\|nil | The game object targeted by the spell |
| spell_cast_time | number | The time when the spell was cast |

## Logging Functions

### core.log

Syntax

```
core.log(message: string)
```

Parameters

message: string - The message to log.

Description
Logs a standard message to the console.

Example Usage

```lua
core.log("This is a standard log message.")
core.log("Spell CD: " .. tostring(spell_cd) .. "s")
```

### core.log_error

Syntax

```
core.log_error(message: string)
```

Parameters

message: string - The error message to log.

Description
Logs an error message (usually shown in red).

### core.log_warning

Syntax

```
core.log_warning(message: string)
```

Parameters

message: string - The warning message to log.

Description
Logs a warning message (usually shown in yellow).

## Time and Performance Functions

### core.time

Syntax

```
core.time() -> number
```

Returns

number: The time in seconds since the PS injection happened.

Warning: Don't use this time to work with server info like buff_end_time, spell_cast_end_time, they work in milliseconds and only with core.game_time()

Description
Returns the time elapsed since the script was injected.

### core.game_time

Syntax

```
core.game_time() -> number
```

Returns

number: The time in milliseconds since the game started.

Note: This is the time that should be used to work with game info like buff_end_time, spell_cast_end_time, etc...

Description
Returns the time elapsed since the game started.

Example Usage

```lua
local game_time = core.game_time()
local cast_end_time = player:get_active_spell_cast_end_time()
if game_time <= cast_end_time then
    -- Still casting
end
```

### core.delta_time

Syntax

```
core.delta_time() -> number
```

Returns

number: The time in milliseconds since the last frame.

Description
Returns the time elapsed since the last frame.

### core.cpu_time

Syntax

```
core.cpu_time() -> number
```

Returns

number: The CPU time used.

Description
Retrieves the CPU time used for performance profiling.

### core.cpu_ticks

Syntax

```
core.cpu_ticks() -> number
```

Returns

number: The current CPU tick count.

Description
Retrieves the current CPU tick count. Useful for high-precision performance profiling.

Example Usage

```lua
local start_ticks = core.cpu_ticks()
-- ... code to profile ...
local end_ticks = core.cpu_ticks()
local elapsed = (end_ticks - start_ticks) / core.cpu_ticks_per_second()
core.log("Operation took: " .. elapsed .. " seconds")
```

### core.cpu_ticks_per_second

Syntax

```
core.cpu_ticks_per_second() -> number
```

Returns

number: The number of CPU ticks per second.

Description
Retrieves the number of CPU ticks per second. Use this in conjunction with core.cpu_ticks() for accurate performance measurements.

## Game Information Functions

### core.get_map_id

Syntax

```
core.get_map_id() -> number
```

Returns

number: The current map ID.

Description
Retrieves the ID of the current map.

### core.get_map_name

Syntax

```
core.get_map_name() -> string
```

Returns

string: The name of the current map.

Description
Retrieves the name of the current map.

### core.get_instance_id

Syntax

```
core.get_instance_id() -> integer
```

Returns

integer: The ID of the current instance.

Description
Retrieves the ID of the current instance.

### core.get_instance_name

Syntax

```
core.get_instance_name() -> string
```

Returns

string: The name of the current instance.

Description
Retrieves the name of the current instance.

### core.get_instance_type

Syntax

```
core.get_instance_type() -> string
```

Returns

string: The type of the current instance (e.g., "raid", "dungeon", "arena", "battleground", "none").

Description
Retrieves the type of the current instance.

### core.get_keystone_level

Syntax

```
core.get_keystone_level() -> integer
```

Returns

integer: The level of the Mythic+ keystone.

Description
Returns the Mythic+ keystone level of the current dungeon, if applicable.

### core.get_game_version

Syntax

```
core.get_game_version() -> string
```

Returns

string: The current game version ("Midnight", "Tbc", "Vanilla", "Mop", "Titan").

Description
Returns the current game version.

### core.is_main_menu_open

Syntax

```
core.is_main_menu_open() -> boolean
```

Returns

boolean: true if the main menu is open, false otherwise.

Description
Checks if the main menu is currently open.

### core.get_exact_game_version

Syntax

```
core.get_exact_game_version() -> string
```

Returns

string: The exact game version string (e.g. "11.1.0.59069").

Description
Returns the exact game version including build number.

### core.set_window_foremost

Syntax

```
core.set_window_foremost() -> nil
```

Description
Forces the game window to the foreground.

### core.is_textbox_focused

Syntax

```
core.is_textbox_focused() -> boolean
```

Returns

boolean: true if a textbox (such as chat) is currently focused.

Description
Returns whether a textbox (like chat) is currently focused. Useful for disabling keybinds while the player is typing.

### core.play_sound_by_id

Syntax

```
core.play_sound_by_id(id: number) -> nil
```

Parameters

id: number - The game sound ID to play.

Description
Plays a game sound by its sound ID.

### core.get_mouse_wheel_delta

Syntax

```
core.get_mouse_wheel_delta() -> number
```

Returns

number: The mouse wheel scroll delta for the current frame.

Description
Returns the mouse wheel scroll delta for the current frame. Positive values indicate scrolling up, negative values indicate scrolling down.

## HTTP Functions

### core.http_get

Syntax

```
core.http_get(url: string, callback: function)
core.http_get(url: string, headers: table, callback: function)
```

Parameters

url: string - The URL to fetch.
headers (optional): table - HTTP headers to send.
callback: function - Function called when the request completes.

Callback Parameters:

| Parameter | Type | Description |
|-----------|------|-------------|
| http_code | integer | HTTP status code (200, 404, etc). |
| content_type | string | Server content type |
| response_data | string | Raw response body |
| response_headers | string | Response headers dump |

Description
Performs an asynchronous HTTP GET request.

Example Usage

```lua
core.http_get("https://httpbin.org/get", function(http_code, content_type, response_data, response_headers)
    core.log("Status: " .. http_code)
    core.log("Response: " .. response_data)
end)
```

### core.http_post

Syntax

```
core.http_post(url: string, body: string, callback: function)
core.http_post(url: string, headers: table, body: string, callback: function)
```

Parameters

url: string - The URL to send the POST request to.
headers (optional): table - HTTP headers to send.
body: string - The request body to send.
callback: function - Function called when the request completes.

Description
Performs an asynchronous HTTP POST request.

## Inventory Functions

### core.inventory.get_items_in_bag

Syntax

```
core.inventory.get_items_in_bag(id: integer) -> table<item_slot_info>
```

Parameters

id: integer - The bag ID.

Returns

table: A table containing the item data. Each entry has .slot_id and .object (game_object).

Note: Bag IDs:
- -2 for the keyring
- -4 for the tokens bag
- 0 = backpack, 1 to 4 for the bags on the character
- While bank is opened: -1 for the bank content, 5 to 11 for bank bags

Description
Returns all the items in the bag with the ID that you pass as parameter.

### core.inventory.get_gold

Syntax

```
core.inventory.get_gold() -> integer
```

Returns

integer: The player's current gold in copper.

Description
Returns the player's total gold amount in copper. Divide by 10000 for gold, by 100 for silver.

## Character Functions

### core.character.get_combat_rating_bonus

Syntax

```
core.character.get_combat_rating_bonus(rating_index: integer) -> number
```

Parameters

rating_index: integer - The combat rating index (e.g. crit, haste, mastery).

Returns

number: The combat rating bonus for the given rating index.

Description
Returns the combat rating bonus for a given rating index (crit, haste, mastery, etc.).

## World Functions

### core.world.is_flyable_area

Syntax

```
core.world.is_flyable_area() -> boolean
```

Returns

boolean: true if the current area allows regular flying.

Description
Returns whether the current area allows regular flying.

### core.world.is_advanced_flyable_area

Syntax

```
core.world.is_advanced_flyable_area() -> boolean
```

Returns

boolean: true if the current area allows dynamic/skyriding flying.

Description
Returns whether the current area allows dynamic/skyriding flying.

### core.world.get_encounters_on_map

Syntax

```
core.world.get_encounters_on_map(ui_map_id: integer) -> encounter_info[]
```

Parameters

ui_map_id: integer - The UI map ID to query encounters for.

Returns

encounter_info[]: An array of encounter info tables.

| Field | Type | Description |
|-------|------|-------------|
| encounter_id | integer | The encounter ID |
| map_x | number | The X position on the map |
| map_y | number | The Y position on the map |

Description
Returns a list of encounters on the specified map.

## Complete Example

### Basic Plugin Structure

```lua
-- Cache hot-path APIs at load
local _core_time = core.time
local _get_local_player = core.object_manager.get_local_player

-- Debug toggle
local debug = false

-- Main update callback
core.register_on_update_callback(function()
    local player = _get_local_player()
    if not player then return end
    
    if debug then
        core.log("Player position: " .. tostring(player:get_position()))
    end
    
    -- Your rotation logic here
end)
```
