# Evade Helper | Project Sylvanas

Source: https://docs.project-sylvanas.net/dev/api/evade-helper

## Overview

📘 Libraries
Mini Libs
Evade Helper

### Overview​

The Evade Helper provides an API for adding custom danger zones to the evade system and checking if positions are safe. You can define circles, rectangles, and cones that the evade system will recognize and avoid.

Key Features:

Multiple Geometries - Add circles, rectangles, and cones

Automatic Deduplication - Safe to call every frame; entries are deduplicated by key

Customizable Danger Levels - Set visual, low, medium, high, or extreme danger

Growth Animation - Support for expanding zones over time

Point Safety Checks - Query if a position is safe from danger zones and fall damage

### Importing The Module​

```
---@type evade_helperlocal evade = require("common/utility/evade_helper")
```

For direct database access (advanced usage):

```
local db = require("root/core_lua/proxy/evade/danger_database")
```

Method Access
Access evade_helper functions with : (colon), not . (dot).

#### evade:is_point_safe​

Check if a position is safe from all registered danger zones.

```
evade:is_point_safe(point: vec3): boolean
```

Example:

```
local evade = require("common/utility/evade_helper")local test_position = vec3.new(100, 200, 30)if evade:is_point_safe(test_position) then    core.log("Position is safe!")else    core.log("Position is dangerous!")end
```

#### evade:is_point_safe_full​

Extended safety check that also considers fall damage.

```
evade:is_point_safe_full(point: vec3, fall_threshold?: number): boolean
```

ParameterTypeDefaultDescriptionpointvec3RequiredPosition to checkfall_thresholdnumbernilMaximum safe fall distance in yards
The fall_threshold parameter is critical for movement abilities like Warrior Charge, DH Fel Rush, or Mage Blink. These abilities can move you to positions where you might fall off ledges or platforms. Setting a fall threshold (e.g., 16 yards) marks any position as dangerous if reaching it would cause a fall greater than that distance.

Example - Warrior Charge Safety:

```
---@type evade_helperlocal evade = require("common/utility/evade_helper")--- Get the end position where Charge would land uslocal function get_charge_end_position(target)    local player = core.object_manager.get_local_player()    if not player then        return vec3.new(0, 0, 0)    end    local target_pos = target:get_position()    local target_radius = target:get_bounding_radius()    local player_pos = player:get_position()        -- Charge lands at target's edge, facing the player    return target_pos:get_extended(player_pos, target_radius)end--- Check if it's safe to charge a targetlocal function is_charge_safe(target)    local end_pos = get_charge_end_position(target)        -- Check danger zones AND falls greater than 16 yards    return evade:is_point_safe_full(end_pos, 16)end-- Usage in rotationlocal function try_charge(target)    if not is_charge_safe(target) then        return false  -- Block charge - would land in danger or fall    end        -- Safe to charge    spell_queue:queue_spell_target(CHARGE, target, 1, "Charge")    return trueend
```

Example - Demon Hunter Fel Rush Safety:

```
---@type evade_helperlocal evade = require("common/utility/evade_helper")--- Get where Fel Rush would land us (considers direction and fall boost)local function get_fel_rush_end_position()    local player = core.object_manager.get_local_player()    if not player then        return vec3.new(0, 0, 0)    end    local player_pos = player:get_position()    local flat_direction = player:get_direction()    local movement_direction = player:get_movement_direction()    -- Determine if moving backwards (angle > 150 means roughly opposite direction)    local player_flat_velocity = player_pos + (flat_direction * 10)    local player_movement_velocity = player_pos + (movement_direction * 10)    local angle = player_flat_velocity:get_angle(player_movement_velocity, player_pos)    -- Use facing direction if moving backwards, otherwise use movement direction    local player_velocity = (angle and angle > 150) and player_flat_velocity or player_movement_velocity    local base_length = 17    -- Initial straight point    local center = player_pos:get_extended(player_velocity, base_length)    local center_raw = center:clone()    -- Height correction    center.z = center.z + 5    center.z = core.get_height_for_position(center)    -- Airborne forward boost (falling extends the dash distance)    local height_diff = center_raw.z - center.z    if height_diff > 3 then        local forward_boost = (height_diff / 3) * 3.3        center = player_pos:get_extended(player_velocity, base_length + forward_boost)        center.z = center.z + 5        center.z = core.get_height_for_position(center)    end    return centerend--- Check if Fel Rush is safelocal function is_fel_rush_safe()    local end_pos = get_fel_rush_end_position()        -- 20 yard fall threshold - Fel Rush can launch you off cliffs    return evade:is_point_safe_full(end_pos, 20)end
```

Example - Rogue Shadowstep Safety:

```
---@type evade_helperlocal evade = require("common/utility/evade_helper")--- Get where Shadowstep would land us (behind the target)local function get_shadowstep_end_position(target)    local player = core.object_manager.get_local_player()    if not player then        return vec3.new(0, 0, 0)    end    local target_pos = target:get_position()    local target_radius = target:get_bounding_radius()    local target_direction = target:get_direction()    local target_velocity = target_pos + target_direction    -- Shadowstep lands behind the target (negative radius = behind)    return target_pos:get_extended(target_velocity, -target_radius)end--- Check if Shadowstep is safelocal function is_shadowstep_safe(target)    local end_pos = get_shadowstep_end_position(target)        -- Check danger zones AND falls greater than 12 yards    return evade:is_point_safe_full(end_pos, 12)end
```

Fall Threshold Use Cases

Warrior Charge: 16 yards - prevents charging into pits

DH Fel Rush: 20 yards - prevents dashing off platforms (accounts for airborne boost)

Rogue Shadowstep: 12 yards - prevents teleporting behind enemies near edges

Mage Blink: 15 yards - prevents blinking off edges

Heroic Leap: Check the target position directly

#### Direct Database Access​

For full control, use the database module directly. This is useful for debugging or when you need all configuration options.

```
local db = require("root/core_lua/proxy/evade/danger_database")
```

#### Adding a Circle​

```
local db = require("root/core_lua/proxy/evade/danger_database")db.add_database("my_circle_zone", {    name = "My Circle Zone",        -- Geometry type    geometry_type = db.geometry_type_enum.circle,        -- Danger settings    danger_level = db.danger_level_enum.extreme,    danger_level_dropdown = db.danger_level_enum.extreme,        -- Menu elements (required)    enable_check = core.menu.checkbox(true, "my_circle_enable"),    color = core.menu.colorpicker(db.danger_level_colors.extreme, "my_circle_color"),        -- Identifiers    object_id = -1,    caster_id = 0,        -- Circle-specific    radius = 8.0,    time_alive = 10.0,    growth_ratio = 0.0,  -- Set > 0 for expanding circle        is_debug = true,  -- Enable debug visualization})
```

#### Adding a Rectangle​

```
local db = require("root/core_lua/proxy/evade/danger_database")db.add_database("my_rect_zone", {    name = "My Rectangle Zone",        -- Geometry type    geometry_type = db.geometry_type_enum.rect,        -- Danger settings    danger_level = db.danger_level_enum.high,    danger_level_dropdown = db.danger_level_enum.high,        -- Menu elements    enable_check = core.menu.checkbox(true, "my_rect_enable"),    color = core.menu.colorpicker(db.danger_level_colors.high, "my_rect_color"),        -- Identifiers    object_id = -1,    caster_id = 0,        -- Rectangle-specific    width = 4.0,    length = 15.0,    time_alive = 5.0,    is_projectile = false,    growth_ratio = 0.0,        is_debug = true,})
```

#### Adding a Cone​

```
local db = require("root/core_lua/proxy/evade/danger_database")db.add_database("my_cone_zone", {    name = "My Cone Zone",        -- Geometry type    geometry_type = db.geometry_type_enum.cone,        -- Danger settings    danger_level = db.danger_level_enum.extreme,    danger_level_dropdown = db.danger_level_enum.extreme,        -- Menu elements    enable_check = core.menu.checkbox(true, "my_cone_enable"),    color = core.menu.colorpicker(db.danger_level_colors.extreme, "my_cone_color"),        -- Identifiers    object_id = nil,    caster_id = -1,        -- Cone-specific    radius = 12.0,       -- Length of the cone    angle = 60,          -- Cone angle in degrees    time_alive = 3.0,    growth_ratio = 0.0,    anim_speed = 2.0,        is_debug = true,})
```

### evade_helper Convenience Functions​

The evade_helper module provides simpler functions that wrap the database calls:

#### evade:add_circle​

```
evade:add_circle(key: string, params: table): boolean, string
```

FieldTypeDefaultDescriptionnamestringnilDisplay nameradiusnumberRequiredCircle radius in yardstime_alivenumber5.0Duration in secondsgrowth_rationumber0.0Expansion rateobject_idintegernilFor deduplicationcaster_idinteger0Caster identifierdanger_levelintegervisualDanger level enumis_debugbooleanfalseDebug visualization
Example:

```
local evade = require("common/utility/evade_helper")local db = require("root/core_lua/proxy/evade/danger_database")local ok, reason = evade:add_circle("boss_aoe", {    name = "Boss Ground AoE",    radius = 8.0,    time_alive = 6.0,    danger_level = db.danger_level_enum.extreme,})if not ok then    core.log("Failed to add circle: " .. reason)end
```

#### evade:add_rect​

```
evade:add_rect(key: string, params: table): boolean, string
```

FieldTypeDefaultDescriptionnamestringnilDisplay namewidthnumberRequiredWidth in yardslengthnumberRequiredLength in yardstime_alivenumber5.0Duration in secondsis_projectilebooleanfalseMoving projectilegrowth_rationumber0.0Expansion ratedanger_levelintegervisualDanger level enumis_debugbooleanfalseDebug visualization
Example:

```
evade:add_rect("boss_beam", {    name = "Boss Beam",    width = 5.0,    length = 40.0,    time_alive = 3.0,    danger_level = db.danger_level_enum.extreme,})
```

#### evade:add_cone​

```
evade:add_cone(key: string, params: table): boolean, string
```

FieldTypeDefaultDescriptionnamestringnilDisplay nameradiusnumberRequiredCone length in yardsanglenumberRequiredCone angle in degreestime_alivenumber3.0Duration in secondsanim_speednumber2.0Animation speedgrowth_rationumber0.0Expansion ratedanger_levelintegervisualDanger level enumis_debugbooleanfalseDebug visualization
Example:

```
evade:add_cone("dragon_breath", {    name = "Dragon Breath",    radius = 20.0,    angle = 90.0,    time_alive = 2.5,    danger_level = db.danger_level_enum.extreme,})
```

### Danger Level Enum​

```
local db = require("root/core_lua/proxy/evade/danger_database")db.danger_level_enum.visual   -- Just visual, no avoidancedb.danger_level_enum.low      -- Low prioritydb.danger_level_enum.medium   -- Medium prioritydb.danger_level_enum.high     -- High prioritydb.danger_level_enum.extreme  -- Highest priority, always avoid
```

Matching colors:

```
db.danger_level_colors.visualdb.danger_level_colors.lowdb.danger_level_colors.mediumdb.danger_level_colors.highdb.danger_level_colors.extreme
```

#### evade:has_entry​

Check if a danger zone exists.

```
evade:has_entry(key: string): boolean
```

#### evade:clear_cache​

Clear all cached danger zone entries.

```
evade:clear_cache(): nil
```

#### Debug Functions​

```
evade:get_database_info()    -- Get database informationevade:get_geometry()         -- Get geometry dataevade:get_geometry_inst()    -- Get geometry instancesevade:get_customizations()   -- Get customization data
```

### Complete Example - Boss Encounter​

```
local evade = require("common/utility/evade_helper")local db = require("root/core_lua/proxy/evade/danger_database")local boss_zones_added = falselocal function handle_boss_mechanics()    -- Add zones once    if not boss_zones_added then        -- Frontal cone breath        evade:add_cone("boss_breath", {            name = "Boss Breath",            radius = 25.0,            angle = 120.0,            time_alive = 4.0,            danger_level = db.danger_level_enum.extreme,        })                -- Circular ground slam        evade:add_circle("boss_slam", {            name = "Ground Slam",            radius = 12.0,            time_alive = 3.0,            growth_ratio = 5.0,  -- Expands over time            danger_level = db.danger_level_enum.high,        })                -- Line attack        evade:add_rect("boss_laser", {            name = "Laser Beam",            width = 6.0,            length = 50.0,            time_alive = 2.0,            danger_level = db.danger_level_enum.extreme,        })                boss_zones_added = true    endend-- Check before using movement abilitieslocal function safe_charge(target)    local end_pos = get_charge_end_position(target)    if not end_pos then        return false    end        if not evade:is_point_safe_full(end_pos, 16) then        return false  -- Would land in danger zone or fall    end        return trueend
```

### Tips​

Unique Keys
Use unique keys for each danger zone. The system deduplicates by key, so reusing keys will update existing zones instead of creating new ones.

Fall Threshold
Always use is_point_safe_full with an appropriate fall threshold for movement abilities. Charging or dashing off a cliff is a common cause of deaths in Mythic+.

Debug Mode
Set is_debug = true when testing to see the danger zone visualization. Remember to disable it in production.

Previous
Icons Helper
Next
Fish Helper

Overview
Importing The Module
Safety Check Functionsevade:is_point_safe
evade:is_point_safe_full

Adding Danger ZonesDirect Database Access
Adding a Circle
Adding a Rectangle
Adding a Cone

evade_helper Convenience Functionsevade:add_circle
evade:add_rect
evade:add_cone

Danger Level Enum
Utility Functionsevade:has_entry
evade:clear_cache
Debug Functions

Complete Example - Boss Encounter
Tips
