# Plugin Helper | Project Sylvanas

Source: https://docs.project-sylvanas.net/dev/api/plugin-helper

## Overview

📘 Libraries
Mini Libs
Plugin Helper

### Overview​

The Plugin Helper is a core utility library for plugin development that provides essential functionality for keybind handling, cross-plugin defensive synchronization, UI text drawing, latency calculation, and combat duration tracking.

Key Features:

Smart Keybinds - Toggle and keybind state checking with special default behaviors

Defensive Sync - Prevent defensive ability overlap across multiple plugins

UI Drawing - Draw centered text at character position or custom screen locations

Latency Handling - Get current latency for timing calculations

Combat Tracking - Track combat duration in seconds or milliseconds

### Importing The Module​

```
---@type plugin_helperlocal plugin_helper = require("common/utility/plugin_helper")
```

Method Access
Access functions with : (colon), not . (dot).

#### Understanding Special Keybind Values​

The plugin helper uses special keybind values to create different default behaviors:

Key ValueVisibilityDefault StateUse Case7Hidden in Control PanelAlways trueFeatures that should be ON by default (e.g., "Enable Rotation")999Visible in Control Panelfalse (unbound)Features user should consciously enableOtherVisible in Control PanelNormal toggle behaviorStandard keybinds
Plug-and-Play Design
Using key 7 for essential features means users get a working plugin immediately without configuration. They can later change the keybind to any key, which automatically makes it a normal toggle (default false, user must press to enable).
Using key 999 shows the toggle in the Control Panel but doesn't enable it by default - perfect for optional features the user should discover and enable themselves.

#### plugin_helper:is_toggle_binded​

Syntax

```
plugin_helper:is_toggle_binded(element: keybind): boolean
```

Parameters

ParameterTypeDescriptionelementkeybindA keybind menu element
Returns

boolean - True if the toggle has an actual keybind assigned (not 7 or 999)

Description
Checks if a toggle menu element has a real keybind assigned. Returns false for special values 7 and 999.

#### plugin_helper:is_toggle_enabled​

Syntax

```
plugin_helper:is_toggle_enabled(element: keybind): boolean
```

Parameters

ParameterTypeDescriptionelementkeybindA keybind menu element
Returns

boolean - True if the toggle is considered enabled

Description
Checks if a toggle is enabled, with special handling:

Key 7: Always returns true (invisible, always-on default)

Key 999: Returns false unless user changed it (visible, off by default)

Other keys: Normal toggle state

Example Usage

```
-- In your menu setuplocal enable_rotation = core.menu.keybind(7, "enable_rotation", "Enable Rotation")local enable_cooldowns = core.menu.keybind(7, "enable_cooldowns", "Enable Cooldowns")local enable_burst = core.menu.keybind(999, "enable_burst", "Enable Burst Mode")-- In your logiclocal function on_update()    -- This is true by default (key 7)    if not plugin_helper:is_toggle_enabled(enable_rotation) then        return    end        -- This is also true by default (key 7)    if plugin_helper:is_toggle_enabled(enable_cooldowns) then        use_cooldowns()    end        -- This is false by default until user enables it (key 999)    if plugin_helper:is_toggle_enabled(enable_burst) then        execute_burst_rotation()    endend
```

#### plugin_helper:is_keybind_enabled​

Syntax

```
plugin_helper:is_keybind_enabled(element: keybind): boolean
```

Description
Checks if a keybind (not toggle) is currently pressed/active, with special case handling similar to toggles.

### Defensive Synchronization​

The defensive sync system allows multiple plugins to coordinate defensive ability usage, preventing wasteful overlap (e.g., using a trinket immediately after Ice Block).

Cross-Plugin Coordination
When you use plugin_helper for defensives, ALL plugins that also use it will respect the block time. This means:

Your rotation plugin won't use defensives while Universal Utility's defensive is active

A healer plugin won't waste Pain Suppression right after the target used their own defensive

#### plugin_helper:is_defensive_allowed​

Syntax

```
plugin_helper:is_defensive_allowed(): boolean
```

Returns

boolean - True if defensive abilities are allowed to be used

Description
Checks a global variable to determine if defensive actions are currently allowed. Returns false if another defensive was recently used and is still within its block time.

Example Usage

```
local function use_defensive()    -- Check if defensives are allowed globally    if not plugin_helper:is_defensive_allowed() then        return false    end        -- Use your defensive    if ice_block:cast() then        -- Block other defensives for 6 seconds (Ice Block lasts 8s)        plugin_helper:set_defensive_block_time(6)        return true    end        return falseend
```

#### plugin_helper:get_defensive_block_time​

Syntax

```
plugin_helper:get_defensive_block_time(): number
```

Returns

number - Remaining block time in seconds

#### plugin_helper:set_defensive_block_time​

Syntax

```
plugin_helper:set_defensive_block_time(extra_time: number): nil
```

Parameters

ParameterTypeDescriptionextra_timenumberSeconds to block other defensives
Description
Sets the defensive block time. Other plugins checking is_defensive_allowed() will return false until this time expires.

Smart Block Times
Set block time slightly LESS than the defensive duration so other defensives can be considered near the end:
DefensiveDurationRecommended Block TimeDivine Shield8s6sIce Block10s8sCloak of Shadows5s3sPain Suppression8s6sHealthstoneinstant1s

Example Usage

```
-- Using Divine Shield (8 second immunity)if divine_shield:cast() then    -- Block for 6 seconds, so near the end we can prepare next defensive    plugin_helper:set_defensive_block_time(6)end-- Using a Healthstone (instant, just prevent spam)if healthstone:use() then    plugin_helper:set_defensive_block_time(1)end
```

#### plugin_helper:draw_text_character_center​

Syntax

```
plugin_helper:draw_text_character_center(    text: string,    text_color?: color,    y_offset?: number,    is_static?: boolean,    counter_special_id?: string,    font_id?: integer): nil
```

Parameters

ParameterTypeDefaultDescriptiontextstringRequiredText to displaytext_colorcolorWhiteText colory_offsetnumber0Vertical offset from character centeris_staticbooleanfalseWhether text position is staticcounter_special_idstringnilUnique ID for counter/stackingfont_idintegernilFont identifier
Description
Draws centered text at the player character's screen position.

Example Usage

```
-- Simple status text above characterplugin_helper:draw_text_character_center("Burst Active!", color.red(), -50)-- With custom fontplugin_helper:draw_text_character_center("Ready", color.green(), -30, false, nil, 2)
```

#### plugin_helper:draw_text_message​

Syntax

```
plugin_helper:draw_text_message(    text: string,    text_color: color,    border_color: color,    screen_position: vec2,    size: vec2,    is_static: boolean,    add_rectangles: boolean,    unique_id: string,    counter_special_id?: string,    is_adding_text_size?: boolean,    font_id?: number): nil
```

Description
Draws text at a specific screen position with optional border and background rectangles.

#### plugin_helper:get_latency​

Syntax

```
plugin_helper:get_latency(): number
```

Returns

number - Current latency in seconds, clamped to a maximum value

Description
Calculates latency based on current ping. Useful for timing adjustments in spell casting.

Example Usage

```
local latency = plugin_helper:get_latency()local cast_time_with_latency = spell_cast_time + latency
```

#### plugin_helper:get_current_combat_length_seconds​

```
plugin_helper:get_current_combat_length_seconds(): number
```

Returns how long the player has been in combat, in seconds (using core.time()).

#### plugin_helper:get_current_combat_length_miliseconds​

```
plugin_helper:get_current_combat_length_miliseconds(): number
```

Returns how long the player has been in combat, in milliseconds (using core.game_time()).

#### Plugin with Smart Defaults​

```
local plugin_helper = require("common/utility/plugin_helper")-- Menu setup with smart defaultslocal menu = {    -- Key 7: ON by default, invisible until user changes it    enable_rotation = core.menu.keybind(7, "enable_rotation", "Enable Rotation"),    enable_interrupts = core.menu.keybind(7, "enable_interrupts", "Enable Interrupts"),        -- Key 999: OFF by default, visible so user can enable    enable_burst = core.menu.keybind(999, "enable_burst", "Burst Mode"),    enable_experimental = core.menu.keybind(999, "enable_experimental", "Experimental Features"),        -- Normal keybind: user must set it up    manual_cooldowns = core.menu.keybind(0, "manual_cooldowns", "Manual Cooldowns"),}local function on_update()    -- Always check rotation toggle first    if not plugin_helper:is_toggle_enabled(menu.enable_rotation) then        return    end        -- Run rotation...    execute_rotation()        -- Interrupts (on by default)    if plugin_helper:is_toggle_enabled(menu.enable_interrupts) then        check_interrupts()    end        -- Burst mode (user must enable)    if plugin_helper:is_toggle_enabled(menu.enable_burst) then        execute_burst()    endend
```

#### Defensive System Integration​

```
local plugin_helper = require("common/utility/plugin_helper")local defensives = {    { spell = ice_block, duration = 10, block_time = 8 },    { spell = mirror_image, duration = 40, block_time = 2 },    { spell = alter_time, duration = 10, block_time = 5 },}local function use_defensive_rotation()    -- Check global defensive state    if not plugin_helper:is_defensive_allowed() then        return false    end        local player = core.object_manager.get_local_player()    local health_pct = player:get_health_percent()        -- Low health - use major defensive    if health_pct < 30 then        if ice_block:cast() then            plugin_helper:set_defensive_block_time(8)  -- 10s duration, 8s block            return true        end    end        -- Medium health - use minor defensive    if health_pct < 60 then        if mirror_image:cast() then            plugin_helper:set_defensive_block_time(2)  -- Short block for minor CD            return true        end    end        return falseend
```

#### Combat Duration Based Logic​

```
local plugin_helper = require("common/utility/plugin_helper")local function should_use_long_cooldown()    local combat_time = plugin_helper:get_current_combat_length_seconds()        -- Don't use long CDs in first 5 seconds (might be a pull mistake)    if combat_time < 5 then        return false    end        -- Use CDs after 10 seconds of combat    if combat_time > 10 then        return true    end        return falseend
```

#### Status Display​

```
local plugin_helper = require("common/utility/plugin_helper")local color = require("common/color")local function on_render()    local status_parts = {}        if plugin_helper:is_toggle_enabled(menu.enable_rotation) then        table.insert(status_parts, "Rotation: ON")    end        if plugin_helper:is_toggle_enabled(menu.enable_burst) then        table.insert(status_parts, "BURST!")    end        if not plugin_helper:is_defensive_allowed() then        local remaining = plugin_helper:get_defensive_block_time()        table.insert(status_parts, string.format("Def CD: %.1fs", remaining))    end        local status_text = table.concat(status_parts, " | ")    plugin_helper:draw_text_character_center(status_text, color.white(), -40)end
```

Previous
Spell Helper
Next
Auto Attack Helper

Overview
Importing The Module
Keybind FunctionsUnderstanding Special Keybind Values
plugin_helper:is_toggle_binded
plugin_helper:is_toggle_enabled
plugin_helper:is_keybind_enabled

Defensive Synchronizationplugin_helper:is_defensive_allowed
plugin_helper:get_defensive_block_time
plugin_helper:set_defensive_block_time

UI Drawing Functionsplugin_helper:draw_text_character_center
plugin_helper:draw_text_message

Utility Functionsplugin_helper:get_latency
plugin_helper:get_current_combat_length_seconds
plugin_helper:get_current_combat_length_miliseconds

Complete ExamplesPlugin with Smart Defaults
Defensive System Integration
Combat Duration Based Logic
Status Display
