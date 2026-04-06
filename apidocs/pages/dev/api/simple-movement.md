# Simple Movement | Project Sylvanas

Source: https://docs.project-sylvanas.net/dev/api/simple-movement

## Overview

📘 Libraries
Mini Libs
Simple Movement

### Overview​

Simple Movement is a utility library for point A-to-B movement without dealing with the complexity of raw movement flags. It uses smooth look_at-based direction control for natural-looking movement along paths.

Key Features:

Dual Movement Systems - Choose between smooth look_at or legacy turn_left/right

Tab-Out Detection - Auto-resumes movement when game window loses focus

Path Smoothing - Catmull-Rom spline smoothing for curved paths

Waypoint Navigation - Navigate through multiple waypoints with loop support

Flying Support - Work in Progress (not yet functional)

Speed-Adaptive - Automatically adjusts turning based on movement speed

Not for Combat
This module is designed for out-of-combat navigation, not combat movement adjustments. For combat micro-movements (pausing for casts, facing targets), use Movement Handler instead.

### Importing The Module​

```
---@type simple_movementlocal movement = require("common/utility/simple_movement")
```

Method Access
Access functions with : (colon), not . (dot).

#### Move to Single Position​

```
local movement = require("common/utility/simple_movement")local vec3 = require("common/geometry/vector_3")local target = vec3.new(100, 200, 30)movement:move_to_position(target)-- Call process() every frame in your update looplocal function on_update()    local reached = movement:process()    if reached then        core.log("Arrived at destination!")    endend
```

#### Navigate Through Waypoints​

```
local waypoints = {    vec3.new(100, 200, 30),    vec3.new(150, 250, 35),    vec3.new(200, 300, 30)}-- Navigate with optional loopmovement:navigate(waypoints, false)  -- false = don't loopmovement:navigate(waypoints, true)   -- true = loop back to start-- The path will be automatically smoothed using Catmull-Rom splines
```

##### movement:move_to_position​

```
movement:move_to_position(position: vec3): boolean
```

Move to a single world position.

##### movement:navigate​

```
movement:navigate(waypoints: vec3[], is_loop?: boolean, start_from_beginning?: boolean): boolean
```

Navigate through a sequence of waypoints. Path smoothing is automatically applied if enabled and there are 3+ waypoints.

Parameters

ParameterTypeDefaultDescriptionwaypointsvec3[]RequiredArray of positionsis_loopbooleanfalseLoop back to start when finishedstart_from_beginningbooleanfalseForce start from waypoint 1 (otherwise uses closest)

##### movement:restart_from_beginning​

```
movement:restart_from_beginning(): boolean
```

Restart navigation from waypoint 1. Useful for implementing loops.

##### movement:process​

```
movement:process(): boolean
```

Must be called every frame in your update loop. Handles movement updates and tab-out detection. Returns true when destination is reached.

##### movement:stop​

```
movement:stop(): nil
```

Stop all movement immediately.

##### movement:clear_navigation​

```
movement:clear_navigation(): nil
```

Clear current navigation, stop movement, and reset all waypoints.

##### movement:pause / movement:resume​

```
movement:pause(): nilmovement:resume(): nil
```

Pause movement temporarily (can be resumed later).

#### Movement System Selection​

Simple Movement supports two movement systems for ground navigation:

##### movement:set_use_look_at​

```
movement:set_use_look_at(use_look_at: boolean): nil
```

Select which movement system to use:

true (default) - look_at system: Smooth interpolated direction using core.input.look_at(). Recommended for natural-looking movement.

false - turns system: Legacy system using turn_left_start()/turn_right_stop().

Turn System Behavior:
The turn system is designed to look more natural by:

Always keeping forward movement when roughly facing the target (accepts being slightly off-path)

Only stopping to turn when facing completely away from target

If stopping is needed, stays stopped for at least 0.6 seconds before resuming (prevents robotic start/stop jitter)

##### movement:is_using_look_at​

```
movement:is_using_look_at(): boolean
```

Returns true if using look_at system, false if using turns system.

##### movement:is_moving​

```
movement:is_moving(): boolean
```

Returns true if currently moving or paused (has an active destination).

##### movement:is_tabbed_out​

```
movement:is_tabbed_out(): boolean
```

Returns true if the game window has lost focus. The module automatically re-sends movement commands when this happens.

##### movement:get_target​

```
movement:get_target(): vec3|nil
```

Get the current target waypoint.

##### movement:get_remaining_waypoints​

```
movement:get_remaining_waypoints(): vec3[]
```

Get array of remaining waypoints (after smoothing).

##### movement:get_original_waypoints​

```
movement:get_original_waypoints(): vec3[]
```

Get the original waypoints before smoothing was applied.

##### movement:get_progress​

```
movement:get_progress(): number
```

Get progress as percentage (0-100).

##### movement:get_current_index​

```
movement:get_current_index(): number
```

Get current waypoint index.

##### movement:get_waypoint_count​

```
movement:get_waypoint_count(): number
```

Get total waypoint count (after smoothing).

##### movement:skip_waypoint​

```
movement:skip_waypoint(): boolean
```

Skip the current waypoint and advance to the next one.

##### movement:strafe​

```
movement:strafe(direction: string|nil): boolean
```

Strafe in a direction: "left", "right", or nil to stop.

##### movement:get_state​

```
movement:get_state(): table
```

Returns complete internal state for debugging:

```
{    state = "idle" | "moving" | "paused",    current_index = number,    waypoint_count = number,    original_waypoint_count = number,    target = vec3 | nil,    is_moving_forward = boolean,    is_strafing_left = boolean,    is_strafing_right = boolean,    is_tabbed_out = boolean,    flying_enabled = boolean,    smooth_enabled = boolean}
```

##### movement:set_smoothing_enabled​

```
movement:set_smoothing_enabled(enabled: boolean): nil
```

Enable or disable Catmull-Rom path smoothing (enabled by default).

##### movement:is_smoothing_enabled​

```
movement:is_smoothing_enabled(): boolean
```

##### movement:set_smoothing_subdivisions​

```
movement:set_smoothing_subdivisions(subdivisions: number): nil
```

Set how many interpolated points to add between waypoints. Higher = smoother curves but more processing. Default is 6, range is 1-20.

##### movement:get_smoothing_subdivisions​

```
movement:get_smoothing_subdivisions(): number
```

##### movement:set_threshold​

```
movement:set_threshold(threshold: number): nil
```

Set distance to consider a waypoint "reached" during path following. Default is 3.5 yards, range 1-10.

##### movement:set_final_threshold​

```
movement:set_final_threshold(threshold: number): nil
```

Set distance to consider the final destination reached. This is smaller than the waypoint threshold to ensure the character actually arrives at the endpoint rather than stopping early. Default is 1.0 yard, range 0.5-5.

##### movement:set_turn_speed​

```
movement:set_turn_speed(speed: number): nil
```

Set how quickly to interpolate direction (0.05-0.5). Higher = faster turning. Default is 0.18.

##### movement:set_look_distance​

```
movement:set_look_distance(distance: number): nil
```

Set look-ahead distance for smooth movement. Default is 12, range 5-50.

##### movement:set_debug​

```
movement:set_debug(enabled: boolean): boolean
```

Enable or disable debug logging.

#### Flying Mode (Work In Progress)​

Flying Not Available
Flying mode is currently work in progress and not functional. Both legacy flying and Dragonriding are not yet implemented.

The flying API exists but always returns false/nil:

##### movement:set_flying_enabled​

```
movement:set_flying_enabled(enabled: boolean, flying_mod?: table): boolean
```

Attempts to enable flying mode. Currently always returns false as flying is not implemented.

##### movement:is_flying_enabled​

```
movement:is_flying_enabled(): boolean
```

Always returns false (flying not implemented).

##### movement:get_flying_state​

```
movement:get_flying_state(): string|nil
```

Always returns nil (flying not implemented).

#### Legacy API (Backward Compatibility)​

These functions are kept for backward compatibility:

##### movement:set_constants / movement:get_constants​

```
movement:set_constants(constants: table): booleanmovement:get_constants(): table
```

Old way to customize movement. Use the new specific setters instead:

```
-- Old style (still works)movement:set_constants({    POSITION = { THRESHOLD = 3.5 },    ANGLE = { TURN_THRESHOLD = 0.18 }})-- New style (recommended)movement:set_threshold(3.5)movement:set_turn_speed(0.18)
```

### Tab-Out Detection​

Simple Movement automatically detects when the game window loses focus (minimized/tabbed out) using core.input.is_input_bit_active. When detected:

Movement commands are periodically re-sent every 0.2 seconds

The is_tabbed_out flag is set to true

Movement continues normally when focus returns

This prevents the character from stopping when you alt-tab during navigation.

```
-- Check if currently tabbed outif movement:is_tabbed_out() then    core.log("Game window not focused, but movement continues!")end
```

#### Patrol Route with Loop​

```
local movement = require("common/utility/simple_movement")local vec3 = require("common/geometry/vector_3")movement:set_debug(true)local patrol_route = {    vec3.new(100, 200, 30),    vec3.new(200, 300, 35),    vec3.new(300, 200, 40),    vec3.new(200, 100, 35),}-- Start looping patrolmovement:navigate(patrol_route, true)local function on_update()    local reached = movement:process()    -- With loop=true, reached will only be true if you call stop()endcore.register_on_update_callback(on_update)
```

#### Movement with Progress Tracking​

```
local movement = require("common/utility/simple_movement")local vec3 = require("common/geometry/vector_3")local waypoints = { --[[ ... ]] }movement:navigate(waypoints)local function on_update()    local reached = movement:process()        if movement:is_moving() then        local progress = movement:get_progress()        local index = movement:get_current_index()        local total = movement:get_waypoint_count()                core.log(string.format("Progress: %d%% (waypoint %d/%d)",             progress, index, total))    end        if reached then        core.log("Arrived!")    endend
```

#### Customized Movement Settings​

```
local movement = require("common/utility/simple_movement")-- Faster turning, tighter pathsmovement:set_turn_speed(0.3)movement:set_threshold(2.0)-- More path smoothingmovement:set_smoothing_subdivisions(10)-- Or disable smoothing for exact waypoint followingmovement:set_smoothing_enabled(false)
```

Previous
Movement Handler
Next
Barney's Basic Guide (With examples) 🎯

Overview
Importing The Module
Basic UsageMove to Single Position
Navigate Through Waypoints

FunctionsCore Movement
Movement System Selection
State Queries
Path Smoothing
Advanced Settings
Flying Mode (Work In Progress)
Legacy API (Backward Compatibility)

Tab-Out Detection
Complete ExamplesPatrol Route with Loop
Movement with Progress Tracking
Customized Movement Settings
