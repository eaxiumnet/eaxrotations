# Auto Attack Helper | Project Sylvanas

Source: https://docs.project-sylvanas.net/dev/api/auto-attack-helper

## Overview

📘 Libraries
Mini Libs
Auto Attack Helper

### Overview​

The Auto Attack Helper is a utility library for tracking melee and ranged auto attack timing. It provides precise swing timer information, global cooldown tracking, and combat state management - essential for optimizing ability weaving between auto attacks.

Key Features:

Swing Timer Tracking - Track last and next auto attack times for any unit

Multiple Attack Types - Support for melee, ranged, and wand attacks

GCD Tracking - Monitor global cooldown state and timing

Combat Duration - Track how long a unit has been in combat

Attack Control - Start, stop, or toggle auto attacks programmatically

Use Case
This helper is particularly useful for melee classes that need to weave abilities between auto attacks (e.g., Warriors, Rogues, Enhancement Shamans) or for tracking enemy swing timers for defensive purposes.

### Importing The Module​

```
---@type auto_attack_helperlocal auto_attack = require("common/utility/auto_attack_helper")
```

Method Access
Access functions with : (colon), not . (dot).

### Attack Type Constants​

The helper provides constants for different attack types:

```
auto_attack.ATTACK_TYPE.MELEE   -- 6603 (Melee auto attack)auto_attack.ATTACK_TYPE.RANGED  -- 75   (Ranged auto attack)auto_attack.ATTACK_TYPE.WAND    -- 5019 (Wand attack)
```

##### auto_attack:is_spell_auto_attack​

```
auto_attack:is_spell_auto_attack(spell_id: number): boolean
```

Checks if a spell ID corresponds to an auto attack spell.

Example Usage

```
if auto_attack:is_spell_auto_attack(spell_id) then    core.log("This is an auto attack!")end
```

##### auto_attack:get_last_attack_core_time​

```
auto_attack:get_last_attack_core_time(unit: game_object): number
```

Returns the core.time() timestamp of the unit's last auto attack swing.

##### auto_attack:get_last_attack_game_time​

```
auto_attack:get_last_attack_game_time(unit: game_object): number
```

Returns the core.game_time() timestamp (milliseconds) of the unit's last auto attack swing.

##### auto_attack:get_next_attack_core_time​

```
auto_attack:get_next_attack_core_time(unit: game_object, weapon_count?: number): number
```

Returns the predicted core.time() when the unit's next auto attack will occur.

Parameters

ParameterTypeDefaultDescriptionunitgame_objectRequiredThe unit to checkweapon_countnumber1Number of weapons (2 for dual-wield)

##### auto_attack:get_next_attack_game_time​

```
auto_attack:get_next_attack_game_time(unit: game_object, weapon_count?: number): number
```

Returns the predicted core.game_time() (milliseconds) when the unit's next auto attack will occur.

Example Usage

```
local player = core.object_manager.get_local_player()local next_swing = auto_attack:get_next_attack_game_time(player)local now = core.game_time()if next_swing - now < 200 then    -- Next swing is within 200ms, delay ability to not clip swing    core.log("Waiting for swing...")end
```

##### auto_attack:get_global_value_core_time​

```
auto_attack:get_global_value_core_time(): number
```

Returns the GCD duration value using core.time() reference.

##### auto_attack:get_global_value_game_time​

```
auto_attack:get_global_value_game_time(): number
```

Returns the GCD duration value using core.game_time() reference.

##### auto_attack:get_last_global_core_time​

```
auto_attack:get_last_global_core_time(): number
```

Returns the core.time() when the last GCD started.

##### auto_attack:get_last_global_game_time​

```
auto_attack:get_last_global_game_time(): number
```

Returns the core.game_time() when the last GCD started.

##### auto_attack:get_next_global_core_time​

```
auto_attack:get_next_global_core_time(): number
```

Returns the predicted core.time() when the current GCD will end.

##### auto_attack:get_next_global_game_time​

```
auto_attack:get_next_global_game_time(): number
```

Returns the predicted core.game_time() when the current GCD will end.

##### auto_attack:get_combat_start_core_time​

```
auto_attack:get_combat_start_core_time(): number
```

Returns the core.time() when combat started.

##### auto_attack:get_combat_start_game_time​

```
auto_attack:get_combat_start_game_time(): number
```

Returns the core.game_time() when combat started.

##### auto_attack:get_current_combat_core_time​

```
auto_attack:get_current_combat_core_time(): number
```

Returns how long the player has been in combat (in seconds, using core.time()).

##### auto_attack:get_current_combat_game_time​

```
auto_attack:get_current_combat_game_time(): number
```

Returns how long the player has been in combat (in milliseconds, using core.game_time()).

Example Usage

```
local combat_duration = auto_attack:get_current_combat_game_time()if combat_duration > 10000 then    -- Been in combat for more than 10 seconds    core.log("Extended combat - consider using cooldowns")end
```

##### auto_attack:is_auto_attacking​

```
auto_attack:is_auto_attacking(object: game_object): boolean
```

Checks if the specified unit is currently auto attacking.

##### auto_attack:start_attack​

```
auto_attack:start_attack(target: game_object, attack_type: integer): boolean
```

Starts auto attacking the specified target.

Parameters

ParameterTypeDescriptiontargetgame_objectTarget to attackattack_typeintegerAttack type constant (MELEE, RANGED, or WAND)

##### auto_attack:stop_attack​

```
auto_attack:stop_attack(target: game_object, attack_type: integer): boolean
```

Stops auto attacking the specified target.

##### auto_attack:toggle_auto_attack​

```
auto_attack:toggle_auto_attack(target: game_object, attack_type: integer): boolean
```

Toggles auto attack on/off for the specified target.

Example Usage

```
local target = core.object_manager.get_target()if target and not auto_attack:is_auto_attacking(target) then    auto_attack:start_attack(target, auto_attack.ATTACK_TYPE.MELEE)end
```

#### Swing Timer Display​

```
local auto_attack = require("common/utility/auto_attack_helper")local function on_update()    local player = core.object_manager.get_local_player()    if not player then return end        local now = core.game_time()    local next_swing = auto_attack:get_next_attack_game_time(player)    local time_to_swing = math.max(0, next_swing - now)        if time_to_swing > 0 then        core.log(string.format("Next swing in: %dms", time_to_swing))    endendcore.register_on_update_callback(on_update)
```

#### Ability Weaving (Don't Clip Swings)​

```
local auto_attack = require("common/utility/auto_attack_helper")local function should_cast_ability()    local player = core.object_manager.get_local_player()    local now = core.game_time()    local next_swing = auto_attack:get_next_attack_game_time(player)        -- Don't cast if swing is within 100ms (avoid clipping)    if next_swing - now < 100 then        return false    end        return trueend
```

### Fields​

The helper also exposes some internal state for advanced usage:

FieldTypeDescriptionattacks_logstableCache of attack timing per unitlast_global_cooldown_valuenumberLast recorded GCD durationlast_global_cooldown_core_timenumberLast GCD start (core.time)last_global_cooldown_game_timenumberLast GCD start (game_time)combat_start_core_timenumberCombat start (core.time)combat_start_game_timenumberCombat start (game_time)

Previous
Plugin Helper
Next
Spell Sequence Helper

Overview
Importing The Module
Attack Type Constants
FunctionsSwing Timer Functions
Global Cooldown Functions
Combat Duration Functions
Attack Control Functions

Complete ExampleSwing Timer Display
Ability Weaving (Don't Clip Swings)

Fields
