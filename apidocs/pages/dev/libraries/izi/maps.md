# IZI - Maps | Project Sylvanas

Source: https://docs.project-sylvanas.net/dev/libraries/izi/maps

## Overview

📘 Libraries
IZI
Maps

### Overview​

The IZI Maps module provides utilities for working with world coordinates, map positions, cursor tracking, and terrain data. These functions bridge the gap between UI map coordinates and 3D world positions, enabling features like click-to-move, minimap interaction, and terrain-aware positioning.

Key Features:

Cursor Tracking - Get cursor position in screen, map, or world coordinates

Coordinate Conversion - Convert between UI map coordinates and 3D world positions

Minimap Integration - Detect cursor over minimap and get map IDs

Terrain Queries - Get terrain height at any world position

#### izi.get_cursor_world_pos​

Syntax

```
izi.get_cursor_world_pos(extra_height?: number): vec3|nil, string|nil
```

Parameters

ParameterTypeDefaultDescriptionextra_heightnumber4Additional height above terrain for raycast
Returns

vec3|nil - World position under cursor, or nil on failure

string|nil - Error message if failed

Description
Converts the current cursor screen position to a 3D world position. Uses raycasting from above the terrain. The extra_height parameter controls how high above the terrain to start the raycast - useful for multi-floor buildings or underground areas.

Example Usage

```
-- Basic usagelocal world_pos = izi.get_cursor_world_pos()if world_pos then    izi.printf("Cursor at: %.1f, %.1f, %.1f", world_pos.x, world_pos.y, world_pos.z)end-- Custom height for rooftopslocal roof_pos = izi.get_cursor_world_pos(50)-- Basement/undergroundlocal basement_pos = izi.get_cursor_world_pos(-20)-- Handle errorslocal pos, err = izi.get_cursor_world_pos()if not pos then    izi.printf("Failed: %s", err)end
```

#### izi.get_cursor_normalized​

Syntax

```
izi.get_cursor_normalized(): vec2|nil
```

Returns

vec2|nil - Normalized cursor position (0-1 range), or nil if unavailable

Description
Returns the cursor position normalized to the screen (0-1 range for both x and y).

Example Usage

```
local cursor = izi.get_cursor_normalized()if cursor then    izi.printf("Cursor: %.2f, %.2f", cursor.x, cursor.y)end
```

#### izi.is_cursor_on_minimap​

Syntax

```
izi.is_cursor_on_minimap(): boolean
```

Returns

boolean - True if the cursor is currently over the minimap

Description
Checks if the mouse cursor is currently positioned over the minimap UI element.

Example Usage

```
if izi.is_cursor_on_minimap() then    local world_pos = izi.get_cursor_world_pos()    if world_pos then        -- User clicked on minimap, get world position    endend
```

#### izi.map_to_world​

Syntax

```
izi.map_to_world(map_id: number, map_pos: vec2, extra_height?: number): vec3|nil, string|nil
```

Parameters

ParameterTypeDefaultDescriptionmap_idnumberRequiredThe UI map IDmap_posvec2RequiredNormalized map coordinates (0-1)extra_heightnumber4Additional height above terrain
Returns

vec3|nil - World position, or nil on failure

string|nil - Error message if failed

Description
Converts UI map coordinates to a 3D world position. Map coordinates are normalized (0-1 range) where (0,0) is top-left and (1,1) is bottom-right.

Example Usage

```
local map_id = izi.get_minimap_id()local map_pos = izi.vec2(0.5, 0.5)  -- Center of maplocal world_pos, err = izi.map_to_world(map_id, map_pos)if world_pos then    izi.printf("Center of map: %.1f, %.1f, %.1f", world_pos.x, world_pos.y, world_pos.z)end
```

#### izi.is_valid_map_coords​

Syntax

```
izi.is_valid_map_coords(cursor: vec2): boolean
```

Parameters

ParameterTypeDefaultDescriptioncursorvec2RequiredNormalized cursor position to validate
Returns

boolean - True if the coordinates are valid map coordinates

Description
Checks if the given normalized coordinates represent a valid position on the current map.

Example Usage

```
local cursor = izi.get_cursor_normalized()if cursor and izi.is_valid_map_coords(cursor) then    izi.print("Cursor is on a valid map location")end
```

#### izi.get_minimap_id​

Syntax

```
izi.get_minimap_id(): number|nil
```

Returns

number|nil - The current minimap/UI map ID, or nil if unavailable

Description
Returns the UI map ID of the currently displayed minimap. Useful for map coordinate conversions.

Example Usage

```
local map_id = izi.get_minimap_id()if map_id then    izi.printf("Current minimap ID: %d", map_id)end
```

#### izi.get_terrain_height​

Syntax

```
izi.get_terrain_height(x: number, y: number): number
```

Parameters

ParameterTypeDefaultDescriptionxnumberRequiredWorld X coordinateynumberRequiredWorld Y coordinate
Returns

number - Terrain height (Z coordinate) at the given position

Description
Returns the terrain height at the specified world coordinates. Useful for ground-level calculations and placing effects.

Example Usage

```
local x, y = 1234.5, 5678.9local height = izi.get_terrain_height(x, y)local ground_pos = izi.vec3(x, y, height)izi.printf("Ground level at position: %.1f", height)
```

Previous
Types
Next
Units

Overview
Cursor Functionsizi.get_cursor_world_pos
izi.get_cursor_normalized
izi.is_cursor_on_minimap

Map Coordinate Conversionizi.map_to_world
izi.is_valid_map_coords
izi.get_minimap_id

Terrainizi.get_terrain_height
