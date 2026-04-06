# Coords Helper | Project Sylvanas

Source: https://docs.project-sylvanas.net/dev/api/coords-helper

## Overview

📘 Libraries
Mini Libs
Coords Helper

### Overview​

The Coords Helper is a utility library for converting between 2D map coordinates and 3D world positions. It provides functions for cursor position tracking, minimap interaction, and terrain height queries - essential for features like click-to-move, map-based waypoints, and position-aware automation.

Key Features:

Cursor World Position - Convert cursor screen position to 3D world coordinates

Map Coordinate Conversion - Convert normalized map coords to world positions

Minimap Detection - Check if cursor is over the minimap

Terrain Height - Query terrain elevation at any world coordinate

Multi-Floor Support - Handle buildings with multiple floors via height offsets

Higher-Level Alternative
For easier access to these functions, consider using the IZI SDK Maps module which wraps this helper with additional convenience features.

### Importing The Module​

```
---@type coords_helperlocal coords = require("common/utility/coords_helper")
```

Method Access
Access functions with : (colon), not . (dot).

### Understanding extra_height​

Several functions accept an extra_height parameter that controls where the terrain raycast starts. This is an offset from your current player Z position.

How it works:

```
raycast_start_z = player.z + extra_heightterrain_z = first solid ground found below raycast_start_z
```

Values:

ValueUse Casenil or 0Default +4, safe margin to avoid underground clipping+20, +50Find upper floors, rooftops, elevated platforms-10, -20Find lower floors, basements, underground areas
Example:

```
coords:get_cursor_world_pos()      -- Default +4, same floor as playercoords:get_cursor_world_pos(50)    -- Find roof/upper floor (+50 from player)coords:get_cursor_world_pos(-15)   -- Find basement/lower floor (-15 from player)
```

#### coords:get_cursor_world_pos​

Syntax

```
coords:get_cursor_world_pos(extra_height?: number): vec3|nil, string|nil
```

Parameters

ParameterTypeDefaultDescriptionextra_heightnumber4Height offset for raycast start
Returns

vec3|nil - World position under cursor, or nil on failure

string|nil - Error message if failed

Description
Converts the current cursor position on the minimap to a 3D world position. Uses raycasting from above the terrain to find the ground level.

Example Usage

```
local coords = require("common/utility/coords_helper")-- Basic usagelocal world_pos = coords:get_cursor_world_pos()if world_pos then    core.log(string.format("Clicked at: %.1f, %.1f, %.1f",         world_pos.x, world_pos.y, world_pos.z))end-- With error handlinglocal pos, err = coords:get_cursor_world_pos()if not pos then    core.log_error("Conversion failed: " .. (err or "unknown"))end
```

#### coords:map_to_world​

Syntax

```
coords:map_to_world(map_id: number, map_pos: vec2, extra_height?: number): vec3|nil, string|nil
```

Parameters

ParameterTypeDefaultDescriptionmap_idnumberRequiredThe UI map IDmap_posvec2RequiredNormalized map coordinates (0-1 range)extra_heightnumber4Height offset for raycast
Returns

vec3|nil - World position, or nil on failure

string|nil - Error message if failed

Description
Converts UI map coordinates to a 3D world position. Map coordinates are normalized (0-1 range) where (0,0) is top-left and (1,1) is bottom-right.

Example Usage

```
local coords = require("common/utility/coords_helper")local vec2 = require("common/geometry/vector_2")local map_id = coords:get_current_map_id()local map_pos = vec2.new(0.5, 0.5)  -- Center of maplocal world_pos, err = coords:map_to_world(map_id, map_pos)if world_pos then    core.log(string.format("Map center at: %.1f, %.1f, %.1f",         world_pos.x, world_pos.y, world_pos.z))end
```

#### coords:is_valid_map_coords​

Syntax

```
coords:is_valid_map_coords(cursor: vec2): boolean
```

Parameters

ParameterTypeDescriptioncursorvec2Normalized cursor position to validate
Returns

boolean - True if coordinates are within valid map bounds

Description
Checks if the given normalized coordinates represent a valid position on the current map. Rejects coordinates > 0.99 as invalid edge cases.

Example Usage

```
local cursor = coords:get_cursor_normalized()if cursor and coords:is_valid_map_coords(cursor) then    core.log("Cursor is on a valid map location")end
```

#### coords:get_current_map_id​

Syntax

```
coords:get_current_map_id(): number|nil
```

Returns

number|nil - Current minimap/UI map ID, or nil if unavailable

Example Usage

```
local map_id = coords:get_current_map_id()if map_id then    core.log("Current map ID: " .. map_id)end
```

#### coords:get_cursor_normalized​

Syntax

```
coords:get_cursor_normalized(): vec2|nil
```

Returns

vec2|nil - Normalized cursor position (0-1 range), or nil if unavailable

Example Usage

```
local cursor = coords:get_cursor_normalized()if cursor then    core.log(string.format("Cursor: %.2f, %.2f", cursor.x, cursor.y))end
```

#### coords:is_cursor_on_minimap​

Syntax

```
coords:is_cursor_on_minimap(): boolean
```

Returns

boolean - True if cursor is currently over the minimap

Example Usage

```
if coords:is_cursor_on_minimap() then    local world_pos = coords:get_cursor_world_pos()    if world_pos then        -- User is hovering over minimap, show position info    endend
```

#### coords:get_terrain_height​

Syntax

```
coords:get_terrain_height(x: number, y: number): number
```

Parameters

ParameterTypeDescriptionxnumberWorld X coordinateynumberWorld Y coordinate
Returns

number - Terrain height (Z coordinate) at the given position

Example Usage

```
local x, y = 1234.5, 5678.9local height = coords:get_terrain_height(x, y)core.log(string.format("Ground level: %.1f", height))
```

#### coords:to_3d (Legacy)​

Syntax

```
coords:to_3d(map_pos: vec2, extra_height?: number): vec3
```

Description
Legacy function that converts map position to world position. Prefer map_to_world for new code.

Previous
Spell Sequence Helper
Next
Inventory Helper

Overview
Importing The Module
Understanding extra_height
Functionscoords:get_cursor_world_pos
coords:map_to_world
coords:is_valid_map_coords
coords:get_current_map_id
coords:get_cursor_normalized
coords:is_cursor_on_minimap
coords:get_terrain_height
coords:to_3d (Legacy)
