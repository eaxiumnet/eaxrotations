# IZI - Spell | Project Sylvanas

Source: https://docs.project-sylvanas.net/dev/libraries/izi/izi-spells

## Overview

📘 Libraries
IZI
Spell

### Overview​

The IZI Spell system provides a powerful object-oriented approach to spell management and casting in World of Warcraft. Instead of working with raw spell IDs and manually checking multiple conditions or writing your own helpers, you create spell objects that encapsulate all the intelligence needed for smart, reliable spell casting.

Key Features:

Smart Casting - Automatic validation of facing, range, cooldowns, charges, resources, and more

Flexible Validation - Fine-grained control over which checks to skip or enforce via cast options

Unit & Position Casting - Cast spells on targets or ground positions with built-in prediction

AoE Optimization - Intelligent position prediction for maximizing hits with area-effect spells

Buff/Debuff Tracking - Monitor spell effects on units with configurable tracking

Cooldown Management - Query remaining cooldowns, charges, and charge fractional states

Resource Awareness - Automatic cost checking for mana, energy, rage, and other resources

LOS & Facing - Built-in line-of-sight and facing requirement validation

Whether you're building a damage rotation, healing routine, or utility automation, the izi_spell class eliminates boilerplate code and provides a consistent, intuitive interface for all your spell casting needs. Create a spell object once, then use its methods throughout your code for clean, maintainable spell management.

#### izi.spell​

Syntax

```
-- Overload 1: Single spell IDizi.spell(id: integer)-- Overload 2: Multiple spell IDs (variadic)izi.spell(id1: integer, id2: integer, ...: integer)-- Overload 3: Array of spell IDsizi.spell(ids: integer[])
```

Parameters

Overload 1:

id: integer - A single spell ID to create a spell object for

Overload 2:

id1: integer - The first spell ID

id2: integer - The second spell ID

...: integer - Additional spell IDs (useful for spell ranks or alternatives)

Overload 3:

ids: integer[] - A table (array) of spell IDs

Returns

izi_spell - A new spell object with built-in casting utilities and validation methods

Description
Creates a new spell object that encapsulates all the functionality needed for intelligent spell casting. The spell object provides methods for casting, validation, cooldown checking, buff/debuff tracking, and more.

You can provide a single spell ID, multiple spell IDs (for spell ranks or alternatives), or an array of spell IDs. When multiple IDs are provided, the spell object will automatically use the first available and castable spell from the list.

Example Usage

```
local izi = require("common/izi_sdk")-- Create a spell with a single IDlocal fireball = izi.spell(133)-- Create a spell with multiple IDs (spell ranks or alternatives)local frostbolt = izi.spell(116, 61087, 228597)-- Create a spell from a table (array) of IDslocal polymorph = izi.spell({ 118, 28272, 28271 })-- Use the spell object to castif fireball:cast_safe(target) then    izi.print("Cast Fireball!")end-- Check if spell is ready to castif frostbolt:is_castable() then    izi.print("Frostbolt is ready!")end-- Get cooldown informationlocal cd_remaining = polymorph:cooldown()izi.printf("Polymorph cooldown: %.1f seconds", cd_remaining)
```

### Fields​

Once you've created an izi_spell object, you can access the following fields to inspect its state and configuration:

#### ids​

Type

```
integer[]
```

Description
The candidate spell IDs that this spell object can cast. When multiple IDs are provided during creation, the spell object will attempt to use the first available and castable spell from this list.

Example Usage

```
local frostbolt = izi.spell(116, 205021, 228597)izi.printf("Frostbolt has %d spell variants", #frostbolt.ids)
```

#### max_enemies​

Type

```
integer
```

Description
A utility knob for controlling AoE heuristics and optimization. This field influences how the spell object calculates optimal positions for area-effect spells when using position prediction.

Example Usage

```
local blizzard = izi.spell(190356)blizzard.max_enemies = 8  -- Optimize for hitting up to 8 enemies
```

#### last_cast_time​

Type

```
number
```

Description
The last time (in seconds) this spell was queued to cast. Useful for tracking spell usage patterns and implementing custom cooldown logic or cast frequency limits.

Example Usage

```
local fireball = izi.spell(133)fireball:cast(target)-- Check when the spell was last castlocal time_since_cast = izi.now() - fireball.last_cast_timeizi.printf("Fireball was cast %.2f seconds ago", time_since_cast)
```

#### minimum_range​

Type

```
number
```

Description
The minimum range from the spellbook for this spell. Returns 0 if the spell has no minimum range requirement. This is automatically populated from the spell's data.

Example Usage

```
local charge = izi.spell(100)if charge.minimum_range > 0 then    izi.printf("Charge requires at least %.1f yards", charge.minimum_range)end
```

#### maximum_range​

Type

```
number
```

Description
The maximum range from the spellbook for this spell. Returns 0 if the spell has no maximum range (unlimited range). This is automatically populated from the spell's data.

Example Usage

```
local frostbolt = izi.spell(116)izi.printf("Frostbolt max range: %.1f yards", frostbolt.maximum_range)-- Check if target is in rangelocal target = izi.target()if target and target:get_distance() <= frostbolt.maximum_range then    izi.print("Target is in range!")end
```

### Helpers​

Once you've created an izi_spell object, you can call the following helpers to interact with and query the spell:

#### id​

Syntax

```
spell:id(): integer
```

Returns

integer - The active spell ID

Description
Returns the currently active spell ID. When multiple IDs are provided during spell creation, this returns the first available and usable spell ID from the list.

Example Usage

```
local frostbolt = izi.spell(116, 205021, 228597)izi.printf("Active spell ID: %d", frostbolt:id())
```

#### name​

Syntax

```
spell:name(): string
```

Returns

string - The spell name

Description
Returns the name of the spell from the game's spell database.

Example Usage

```
local fireball = izi.spell(133)izi.printf("Spell name: %s", fireball:name())  -- Output: "Spell name: Fireball"
```

#### is_learned​

Aliases

is_available

Syntax

```
spell:is_learned(): boolean
```

Returns

boolean - True if the spell is learned

Description
Checks if the player has learned this spell. Returns true if the spell is in the player's spellbook.

Example Usage

```
local polymorph = izi.spell(118)if polymorph:is_learned() then    izi.print("Polymorph is available in spellbook")end
```

#### is_usable​

Syntax

```
spell:is_usable(): boolean
```

Returns

boolean - True if the spell is usable

Description
Checks if the spell can be used right now, considering factors like resources, cooldown, and player state.

Example Usage

```
local fireball = izi.spell(133)if fireball:is_usable() then    izi.print("Fireball is ready to cast")end
```

#### cast_time​

Syntax

```
spell:cast_time(): integer
```

Returns

integer - The spell's cast time in seconds

Description
Returns the cast time of the spell in seconds.

Example Usage

```
local frostbolt = izi.spell(spell)izi.printf("Frostbolt cast time: %d seconds", frostbolt:cast_time())
```

#### cast_time_ms​

Syntax

```
spell:cast_time_ms(): integer
```

Returns

integer - The spell's cast time in miliseconds

Description
Returns the cast time of the spell in miliseconds.

Example Usage

```
local frostbolt = izi.spell(spell)izi.printf("Frostbolt cast time: %d miliseconds", frostbolt:cast_time_ms())
```

#### charges​

Syntax

```
spell:charges(): integer
```

Returns

integer - Current number of charges

Description
Returns the current number of charges available for the spell. Returns 0 if the spell doesn't have a charge system.

Example Usage

```
local fire_blast = izi.spell(108853)izi.printf("Fire Blast charges: %d", fire_blast:charges())
```

#### max_charges​

Syntax

```
spell:max_charges(): integer
```

Returns

integer - Maximum number of charges

Description
Returns the maximum number of charges this spell can hold. Returns 0 if the spell doesn't have a charge system.

Example Usage

```
local fire_blast = izi.spell(108853)izi.printf("Fire Blast: %d/%d charges", fire_blast:charges(), fire_blast:max_charges())
```

#### charges_info​

Syntax

```
spell:charges_info(): charge_info
```

Returns

current: integer - Current number of charges

maximum: integer - Maximum number of charges

start_ms: integer - Recharge start time in milliseconds

duration_ms: integer - Recharge duration in milliseconds

mod_rate: number - Recharge rate modifier

Description
Returns detailed information about the spell's charge system, including timing data for charge regeneration.

Example Usage

```
local fire_blast = izi.spell(108853)local cur, max, start_ms, duration_ms, mod_rate = fire_blast:charges_info()izi.printf("Charges: %d/%d, Recharge: %dms", cur, max, duration_ms)
```

#### charges_fractional​

Syntax

```
spell:charges_fractional(recharge_ms?: number): number
```

Parameters

recharge_ms?: number - Optional override for recharge time in milliseconds

Returns

number - Fractional charge count (e.g., 1.5 means 1 charge + 50% progress to next)

Description
Returns the current charge count including fractional progress towards the next charge. Useful for precise timing decisions.

Example Usage

```
local fire_blast = izi.spell(108853)local fractional = fire_blast:charges_fractional()izi.printf("Fire Blast charges: %.2f", fractional)  -- Output: "Fire Blast charges: 1.75"
```

#### recharge​

Syntax

```
spell:recharge(): number
```

Returns

number - Time in seconds until next charge is available

Description
Returns the time remaining until the next charge becomes available. Returns 0 if the spell is at max charges or doesn't use charges.

Example Usage

```
local fire_blast = izi.spell(108853)local recharge_time = fire_blast:recharge()if recharge_time > 0 then    izi.printf("Next charge in %.1f seconds", recharge_time)end
```

#### cooldown_remains​

Aliases

cooldown

Syntax

```
spell:cooldown_remains(): numberspell:cooldown(): number
```

Returns

number - Time in seconds remaining on cooldown

Description
Returns the remaining cooldown time in seconds. Returns 0 if the spell is not on cooldown.

Example Usage

```
local combustion = izi.spell(190319)local cd = combustion:cooldown_remains()if cd > 0 then    izi.printf("Combustion ready in %.1f seconds", cd)end
```

#### cooldown_up​

Syntax

```
spell:cooldown_up(): boolean
```

Returns

boolean - True if the spell is ready (not on cooldown)

Description
Returns true if the spell is not on cooldown and can be cast (cooldown-wise). This is the opposite of cooldown_down().

Example Usage

```
local combustion = izi.spell(190319)if combustion:cooldown_up() then    izi.print("Combustion is ready!")end
```

#### cooldown_down​

Syntax

```
spell:cooldown_down(): boolean
```

Returns

boolean - True if the spell is on cooldown

Description
Returns true if the spell is currently on cooldown. This is the opposite of cooldown_up().

Example Usage

```
local combustion = izi.spell(190319)if combustion:cooldown_down() then    izi.print("Combustion is on cooldown")end
```

#### get_gcd​

Syntax

```
spell:get_gcd(): number
```

Returns

number - The global cooldown duration in seconds

Description
Returns the global cooldown (GCD) duration that will be triggered when this spell is cast.

Example Usage

```
local fireball = izi.spell(133)izi.printf("Fireball GCD: %.2f seconds", fireball:get_gcd())
```

#### skips_gcd​

Syntax

```
spell:skips_gcd(): boolean
```

Returns

boolean - True if the spell doesn't trigger GCD

Description
Returns true if the spell can be cast without triggering the global cooldown. Off-GCD spells can be used between other abilities.

Example Usage

```
local fire_blast = izi.spell(108853)if fire_blast:skips_gcd() then    izi.print("Fire Blast is off-GCD!")end
```

#### is_usable_while_moving​

Syntax

```
spell:is_usable_while_moving(): boolean
```

Returns

boolean - True if the spell can be cast while moving

Description
Returns true if the spell can be cast while the player is moving. Instant cast spells typically return true.

Example Usage

```
local scorch = izi.spell(2948)if scorch:is_usable_while_moving() then    izi.print("Scorch can be cast while moving")end
```

#### requires_back​

Syntax

```
spell:requires_back(): boolean
```

Returns

boolean - True if the spell requires positioning behind the target

Description
Returns true if the spell requires the player to be behind the target to cast (e.g., Backstab, Ambush).

Example Usage

```
local backstab = izi.spell(53)if backstab:requires_back() then    izi.print("Need to be behind target for Backstab")end
```

#### since_last_cast​

Syntax

```
spell:since_last_cast(): number
```

Returns

number - Time in seconds since the spell was last cast

Description
Returns the time elapsed since this spell was last queued to cast. Useful for tracking spell usage patterns.

Example Usage

```
local fireball = izi.spell(133)local time_since = fireball:since_last_cast()izi.printf("Last Fireball cast: %.1f seconds ago", time_since)
```

#### in_gcd_window​

Syntax

```
spell:in_gcd_window(threshold?: number): boolean
```

Parameters

threshold?: number - Optional threshold in seconds (default varies by implementation)

Returns

boolean - True if within the GCD window

Description
Returns true if the current time is within the GCD window, allowing for predictive spell queueing. The threshold parameter allows customization of the timing window.

Example Usage

```
local fireball = izi.spell(133)if fireball:in_gcd_window(0.3) then    izi.print("Can queue next spell")end
```

#### in_recharge​

Syntax

```
spell:in_recharge(): boolean
```

Returns

boolean - True if the spell is currently recharging

Description
Returns true if the spell is currently recharging a charge. Only applicable to spells with charge systems.

Example Usage

```
local fire_blast = izi.spell(108853)if fire_blast:in_recharge() then    izi.print("Fire Blast is recharging")end
```

#### has_charges_at​

Syntax

```
spell:has_charges_at(t?: number): boolean
```

Parameters

t?: number - Optional time in the future (seconds from now) to check

Returns

boolean - True if charges will be available at the specified time

Description
Returns true if the spell will have at least one charge available at the specified time. If no time is provided, checks current availability.

Example Usage

```
local fire_blast = izi.spell(108853)if fire_blast:has_charges_at(2.5) then    izi.print("Fire Blast will have a charge in 2.5 seconds")end
```

#### track_debuff​

Syntax

```
spell:track_debuff(spec: (number|number[])|nil): izi_spell
```

Parameters

spec: (number|number[])|nil - Debuff ID(s) to track, or nil to track the spell's own ID

Returns

izi_spell - Returns self for method chaining

Description
Configures the spell to track specific debuff IDs on targets. Useful when a spell applies a debuff with a different ID than the spell itself. Pass nil to track the spell's own ID.

Example Usage

```
local immolate = izi.spell(348)local immolate_debuff_id = 157736 -- Immolate's debuff is different than its spell ID-- Track the Immolate debuff (different ID than cast spell)-- This will allow other helper functions such as izi.spread_dot track the debuffs for this DOT approprietlyimmolate:track_debuff(immolate_debuff_id)
```

#### track_buff​

Syntax

```
spell:track_buff(spec: (number|number[])|nil): izi_spell
```

Parameters

spec: (number|number[])|nil - Buff ID(s) to track, or nil to track the spell's own ID

Returns

izi_spell - Returns self for method chaining

Description
Configures the spell to track specific buff IDs. Useful when a spell applies a buff with a different ID than the spell itself. Pass nil to track the spell's own ID.

Example Usage

```
-- Track multiple possible buff variantslocal heroism = izi.spell(32182)heroism:track_buff({ heroism:id(), 2825, 80353 })
```

#### get_tracked_debuff_spec​

Syntax

```
spell:get_tracked_debuff_spec(): number|number[]
```

Returns

number|number[] - The debuff ID(s) currently being tracked

Description
Returns the debuff ID specification that this spell is currently tracking. Returns either a single ID or an array of IDs.

Example Usage

```
local immolate = izi.spell(348)immolate:track_debuff(157736)local tracked = immolate:get_tracked_debuff_spec()izi.printf("Tracking debuff ID: %d", tracked)
```

#### get_tracked_buff_spec​

Syntax

```
spell:get_tracked_buff_spec(): number|number[]
```

Returns

number|number[] - The buff ID(s) currently being tracked

Description
Returns the buff ID specification that this spell is currently tracking. Returns either a single ID or an array of IDs.

Example Usage

```
local bloodlust = izi.spell(2825)bloodlust:track_buff(2825)local tracked = bloodlust:get_tracked_buff_spec()izi.printf("Tracking buff ID: %d", tracked)
```

#### is_castable​

Syntax

```
spell:is_castable(opts?: cast_opts): boolean
```

Parameters

opts?: cast_opts - Optional casting options to customize validation checks

Returns

boolean - True if the spell can be cast

Description
Checks if the spell is castable right now based on basic validation criteria like charges, learned status, usability, player state (moving, mounted, casting, channeling), and positional requirements. This method performs general castability checks without requiring a target or position.

Example Usage

```
local fireball = izi.spell(133)-- Basic castability checkif fireball:is_castable() then    izi.print("Fireball can be cast")end-- Skip certain checksif fireball:is_castable({ skip_moving = true }) then    izi.print("Fireball can be cast (ignoring movement)")end-- Skip multiple checksif fireball:is_castable({    skip_moving = true,    skip_casting = true}) then    izi.print("Fireball can be cast (ignoring movement and casting state)")end
```

#### is_castable_to_unit​

Syntax

```
spell:is_castable_to_unit(target?: game_object, opts?: unit_cast_opts): boolean
```

Parameters

target?: game_object - Optional target unit (defaults to current target if not provided)

opts?: unit_cast_opts - Optional casting options to customize validation checks

Returns

boolean - True if the spell can be cast on the target unit

Description
Checks if the spell can be cast on a specific unit target. This method performs all basic castability checks plus unit-specific validation like facing requirements, range checks, and target-specific conditions. If no target is provided, it uses the player's current target.

Example Usage

```
local frostbolt = izi.spell(116)local target = izi.target()-- Check if we can cast on current targetif frostbolt:is_castable_to_unit() then    izi.print("Can cast Frostbolt on target")end-- Check if we can cast on a specific unitlocal enemy = izi.enemies(40)[1]if enemy and frostbolt:is_castable_to_unit(enemy) then    izi.print("Can cast Frostbolt on enemy")end-- Skip facing requirementif frostbolt:is_castable_to_unit(target, { skip_facing = true }) then    izi.print("Can cast (ignoring facing)")end-- Skip range and GCD checksif frostbolt:is_castable_to_unit(target, {    skip_range = true,    skip_gcd = true}) then    izi.print("Can cast (ignoring range and GCD)")end
```

#### is_castable_to_position​

Syntax

```
spell:is_castable_to_position(target?: game_object, cast_pos?: vec3, opts?: pos_cast_opts): boolean
```

Parameters

target?: game_object - Optional context target (defaults to current target or self)

cast_pos?: vec3 - Optional cast position (if nil, uses target's position)

opts?: pos_cast_opts - Optional casting options including prediction settings

Returns

boolean - True if the spell can be cast at the position

Description
Checks if the spell can be cast at a specific ground position. This method performs all castability checks plus position-specific validation like range to position, line of sight, and optional prediction calculations for optimal AoE placement. Ideal for ground-targeted spells, AoE abilities, and skillshots.

Example Usage

```
local blizzard = izi.spell(190356)local target = izi.target()-- Check if we can cast at target's positionif blizzard:is_castable_to_position(target) then    izi.print("Can cast Blizzard at target location")end-- Check if we can cast at a specific positionlocal custom_pos = vec3(100, 100, 0)if blizzard:is_castable_to_position(nil, custom_pos) then    izi.print("Can cast at custom position")end-- Use prediction to find optimal positionif blizzard:is_castable_to_position(target, nil, {        use_prediction = true,        prediction_type = "MOST_HITS",        min_hits = 3    }) then    izi.print("Can cast with optimal prediction for 3+ hits")end-- Custom AoE radius and geometryif blizzard:is_castable_to_position(target, nil, {        geometry = "CIRCLE",        aoe_radius = 10,        check_los = true    }) then    izi.print("Can cast with custom radius and LOS check")end-- Override cast time and projectile speedif blizzard:is_castable_to_position(target, nil, {        cast_time = 2000,  -- 2 seconds in milliseconds        projectile_speed = 20, -- 20 game units/sec        use_prediction = true    }) then    izi.print("Can cast with custom timing values")end
```

#### cast​

Syntax

```
spell:cast(target?: game_object, message?: string, opts?: pos_cast_opts): boolean, izi_cast_meta
```

Parameters

target?: game_object - Optional target unit (defaults to player target or self)

message?: string - Optional message to display in the queue

opts?: pos_cast_opts - Optional position cast options (only used for positional spells; ignored for targeted spells)

Returns

boolean - True if the spell was successfully queued to cast

izi_cast_meta - Metadata about the cast attempt

Description
Casts the spell on a target or at a position. For positional spells, the opts parameter enables prediction, geometry customization, and other advanced features. For targeted spells, opts is ignored and standard safety checks should be handled via cast_safe() instead.

Example Usage

```
local fireball = izi.spell(133)local blizzard = izi.spell(190356)local target = izi.target()-- Cast on targetif fireball:cast(target) then    izi.print("Cast Fireball!")end-- Cast with custom messageif fireball:cast(target, "Fireball on primary target") then    izi.print("Queued Fireball")end-- Cast positional spell with predictionif blizzard:cast(target, "Blizzard AoE",        {            use_prediction = true,            prediction_type = "MOST_HITS",            min_hits = 3        }) then    izi.print("Cast Blizzard at optimal position")end-- Cast positional spell with custom geometryif blizzard:cast(target, nil,        {            geometry = "CIRCLE",            aoe_radius = 10,            check_los = true        }) then    izi.print("Cast Blizzard with custom radius")end
```

#### cast_safe​

Syntax

```
spell:cast_safe(target?: game_object, message?: string, opts?: unit_cast_opts|pos_cast_opts): boolean, izi_cast_meta
```

Parameters

target?: game_object - Optional target unit (defaults to player target or self)

message?: string - Optional message to display in the queue

opts?: unit_cast_opts|pos_cast_opts - Optional casting options with full safety checks

Returns

boolean - True if the spell was successfully queued to cast

izi_cast_meta - Metadata about the cast attempt

Description
Safe casting with full validation gates including facing, range, GCD, and other checks. For positional spells, also supports prediction and line of sight validation via opts. This method performs comprehensive safety checks before casting, making it ideal for production rotations.

Example Usage

```
local frostbolt = izi.spell(116)local blizzard = izi.spell(190356)local target = izi.target()-- Safe cast on target with full validationif frostbolt:cast_safe(target) then    izi.print("Safely cast Frostbolt")end-- Safe cast with custom message and skip some checksif frostbolt:cast_safe(target, "Frostbolt priority",        {            skip_facing = true,            skip_moving = true        }) then    izi.print("Cast Frostbolt (skipped facing and movement)")endif blizzard:cast_safe(target, "Blizzard optimal",        {            use_prediction = true,            prediction_type = "MOST_HITS",            min_hits = 3,            check_los = true        }) then    izi.print("Safely cast Blizzard with prediction")end
```

#### cast_target_if​

Syntax

```
spell:cast_target_if(    units: game_object[],    mode: sort_mode,    filter: fun(u: game_object): number|nil,    adv_condition?: boolean|fun(u: game_object): boolean|nil,    another_condition?: boolean,    max_attempts?: integer,    message?: string): boolean, izi_cast_meta
```

Parameters

units: game_object[] - Array of units to evaluate

mode: sort_mode - "max" for highest score, "min" for lowest score

filter: fun(u: game_object): number|nil - Scoring function; return nil to exclude unit

adv_condition?: boolean|fun(u: game_object): boolean|nil - Optional advanced condition per unit or global boolean

another_condition?: boolean - Optional global veto condition (early exit if false)

max_attempts?: integer - Maximum number of units to try (default: 3)

message?: string - Optional queue message

Returns

boolean - True if the spell was successfully cast on a target

izi_cast_meta - Metadata about the cast attempt

Description
Ranks units by the scoring function in descending order for "max" mode or ascending for "min" mode, then attempts to cast on the top N units using the raw cast() method (no safety gates). Uses an internal blacklist to avoid repeatedly trying failed targets. This is a performance-optimized method for target selection.

Note: This method does not accept opts parameter and performs minimal validation.

Example Usage

```
local fireball = izi.spell(133)local enemies = izi.enemies(40)-- Cast on enemy with lowest healthif fireball:cast_target_if(enemies, "min", function(u) return u:get_health_percentage() end) then    izi.print("Cast Fireball on lowest HP enemy")end-- Cast on enemy with highest health, with conditionsif fireball:cast_target_if(        enemies,        "max",        function(u) return u:get_health_percentage() end,        function(u) return not u:is_casting() end, -- Skip casting enemies        true,                                      -- Global condition        5,                                         -- Try up to 5 targets        "Fireball max HP"    ) then    izi.print("Cast Fireball on highest HP non-casting enemy")end-- Cast on enemy furthest awayif fireball:cast_target_if(enemies, "max", function(u) return u:distance() end, nil, true, 3, "Fireball distant target") then    izi.print("Cast on furthest enemy")end
```

#### cast_target_if_safe​

Syntax

```
spell:cast_target_if_safe(    units: game_object[],    mode: sort_mode,    filter: fun(u: game_object): number|nil,    adv_condition?: boolean|fun(u: game_object): boolean|nil,    another_condition?: boolean,    max_attempts?: integer,    message?: string,    opts?: unit_cast_opts|pos_cast_opts): boolean, izi_cast_meta
```

Parameters

units: game_object[] - Array of units to evaluate

mode: sort_mode - "max" for highest score, "min" for lowest score

filter: fun(u: game_object): number|nil - Scoring function; return nil to exclude unit

adv_condition?: boolean|fun(u: game_object): boolean|nil - Optional advanced condition per unit or global boolean

another_condition?: boolean - Optional global veto condition (early exit if false)

max_attempts?: integer - Maximum number of units to try (default: 3)

message?: string - Optional queue message

opts?: unit_cast_opts|pos_cast_opts - Optional casting options with full safety checks

Returns

boolean - True if the spell was successfully cast on a target

izi_cast_meta - Metadata about the cast attempt

Description
Same as cast_target_if() but uses cast_safe() internally and forwards the opts parameter for full validation gates including facing, range, GCD, and other safety checks. This is the recommended method for production rotations that need smart target selection with comprehensive validation.

Example Usage

```
local fireball = izi.spell(133)local enemies = izi.enemies(40)-- Cast on enemy with lowest healthif fireball:cast_target_if_safe(enemies, "min", function(u) return u:get_health_percentage() end) then    izi.print("Cast Fireball on lowest HP enemy")end-- Cast on enemy with highest health, with conditionsif fireball:cast_target_if_safe(        enemies,        "max",        function(u) return u:get_health_percentage() end,        function(u) return not u:is_casting() end, -- Skip casting enemies        true,                                      -- Global condition        5,                                         -- Try up to 5 targets        "Fireball max HP"    ) then    izi.print("Cast Fireball on highest HP non-casting enemy")end-- Cast on enemy furthest awayif fireball:cast_target_if_safe(enemies, "max", function(u) return u:distance() end, nil, true, 3, "Fireball distant target") then    izi.print("Cast on furthest enemy")end
```

#### cast_defensive​

Syntax

```
spell:cast_defensive(    target: game_object,    filters?: defensive_filters,    message?: string,    opts?: unit_cast_opts): boolean
```

Parameters

target: game_object - The target to cast the defensive spell on

filters?: defensive_filters - Optional filters table to decide if the cast should proceed

message?: string - Optional custom message for the action queue

opts?: unit_cast_opts - Optional casting options that are forwarded to cast_safe

Returns

boolean - True if the spell was successfully cast, false otherwise

Description
Casts this spell as a defensive on self with extra filters to decide if the cast should proceed. Prevents casting more than one defensive within the block time. This is a convenience method that wraps izi.cast_defensive() for use directly on spell objects.

Example Usage

```
local ice_block = izi.spell(45438)  -- Mage Ice Blocklocal player = izi.get_player()-- Cast Ice Block with custom health thresholdslocal filters = {    block_time = 2,                                  -- Block further defensives for 2 seconds    health_percentage_threshold_raw = 25,            -- Cast if current HP <= 25%    health_percentage_threshold_incoming = 20,       -- Cast if forecasted HP <= 20%}if ice_block:cast_defensive(player, filters, "Emergency Ice Block!") then    izi.print("Ice Block activated!")end-- Simple usage with default filterslocal divine_protection = izi.spell(498)  -- Paladin Divine Protectionif divine_protection:cast_defensive(player) then    izi.print("Divine Protection activated!")end-- With damage type filterslocal anti_magic_shell = izi.spell(48707)  -- DK Anti-Magic Shelllocal magic_filters = {    health_percentage_threshold_raw = 60,    magical_damage_percentage_threshold = 50,  -- Only cast if 50%+ incoming damage is magical}if anti_magic_shell:cast_defensive(player, magic_filters, "AMS vs Magic") then    izi.print("Anti-Magic Shell activated against heavy magic damage!")end
```

#### izi.cast_charge_spell​

Syntax

```
izi.cast_charge_spell(    spell: izi_spell,    stage: 1|2|3|4,    target?: game_object,    message?: string,    opts?: unit_cast_opts|pos_cast_opts): boolean
```

Parameters

spell: izi_spell - The empowered spell wrapper (created via izi.spell())

stage: 1|2|3|4 - Target empower stage to release at (1-4)

target?: game_object - Optional target, or nil to use player target or self

message?: string - Optional queue message for logging

opts?: unit_cast_opts|pos_cast_opts - Options forwarded to :cast_safe for the initial press

Returns

boolean - True if the spell was successfully started/released

Description
Handles Evoker empowered spell casting by managing the charge-up and release mechanics. This function automatically:

Initiates the empowered spell cast via cast_safe

Tracks the charge-up progress

Releases at the specified empower stage

Use this for Evoker abilities like Fire Breath, Eternity Surge, and other empowered spells that require holding and releasing at specific stages.

Example Usage

```
local izi = require("common/izi_sdk")-- Create Evoker empowered spell wrapperslocal fire_breath = izi.spell(357208)      -- Fire Breathlocal eternity_surge = izi.spell(359073)   -- Eternity Surgelocal target = izi.target()-- Cast Fire Breath at stage 3 for maximum damageif izi.cast_charge_spell(fire_breath, 3, target, "Fire Breath R3") then    izi.print("Fire Breath charging to stage 3!")end-- Cast Eternity Surge at stage 2 for balance of damage/cast timeif izi.cast_charge_spell(eternity_surge, 2, target, "Eternity Surge R2") then    izi.print("Eternity Surge at stage 2!")end-- With casting optionsif izi.cast_charge_spell(fire_breath, 4, target, "Max Fire Breath", {    skip_facing = true  -- Allow starting cast while not facing (will face during channel)}) then    izi.print("Charging Fire Breath to maximum!")end
```

Stage Selection

Stage 1: Fastest release, lowest potency

Stage 2: Balanced speed and power

Stage 3: High potency, longer charge

Stage 4: Maximum potency, full charge time

Choose the stage based on your rotation needs and available time window.

#### izi.spread_dot​

Syntax

```
izi.spread_dot(spell: izi_spell|integer, radius?: number, count?: integer, players_only?: boolean, predicate?: unit_predicate): game_object|nil
```

Parameters

ParameterTypeDefaultDescriptionspellizi_spell|integerRequiredThe DoT spell to spreadradiusnumber40Search radius in yardscountinteger1Minimum number of missing targets to return a resultplayers_onlybooleanfalseOnly consider player targetspredicateunit_predicatenilOptional filter function
Returns

game_object|nil - A valid target missing the DoT, or nil if none found

Description
Finds an enemy target that is missing the specified DoT spell. Useful for multi-dotting rotations where you want to maintain DoTs on multiple targets.

Example Usage

```
local izi = require("common/izi_sdk")local corruption = izi.spell(172)local dot_target = izi.spread_dot(corruption, 40, 1, false, function(unit)    return unit:get_health_percent() > 20  -- Don't dot dying targetsend)if dot_target then    corruption:cast_safe(dot_target, "Spreading Corruption")end
```

```
-- Multi-DoT rotation examplelocal agony = izi.spell(980)local corruption = izi.spell(172)local siphon_life = izi.spell(63106)local function spread_dots()    -- Spread Agony first (highest priority)    local agony_target = izi.spread_dot(agony, 40, 1, false)    if agony_target and agony:cast_safe(agony_target) then        return true    end        -- Then Corruption    local corruption_target = izi.spread_dot(corruption, 40, 1, false)    if corruption_target and corruption:cast_safe(corruption_target) then        return true    end        -- Finally Siphon Life    local siphon_target = izi.spread_dot(siphon_life, 40, 1, false)    if siphon_target and siphon_life:cast_safe(siphon_target) then        return true    end        return falseend
```

#### izi.cast_defensive​

Syntax

```
izi.cast_defensive(spell: izi_spell|integer, unit?: game_object, filters?: defensive_filters): boolean
```

Parameters

ParameterTypeDefaultDescriptionspellizi_spell|integerRequiredThe defensive spell to castunitgame_objectPlayerTarget unit (defaults to player)filtersdefensive_filtersnilOptional filtering criteria
Returns

boolean - True if the spell was cast successfully

Description
Intelligently casts a defensive spell based on configurable filters. Checks health thresholds, recent damage intake, and damage types before casting. Prevents multiple defensives from being cast within a block time to avoid wasting cooldowns.

Example Usage

```
local izi = require("common/izi_sdk")local barkskin = izi.spell(22812)local player = izi.get_player()-- Cast Barkskin with health and damage filtersizi.cast_defensive(barkskin, player, {    block_time = 1,                              -- 1 second block after use    health_percentage_threshold_raw = 50,        -- Cast if HP <= 50%    health_percentage_threshold_incoming = 40,   -- Cast if forecasted HP <= 40%})
```

```
-- Damage-type specific defensivelocal anti_magic_shell = izi.spell(48707)local player = izi.get_player()izi.cast_defensive(anti_magic_shell, player, {    block_time = 2,    health_percentage_threshold_raw = 70,    magical_damage_percentage_threshold = 50,  -- Only cast if 50%+ incoming is magical})
```

```
-- Simple usage with defaultslocal divine_protection = izi.spell(498)if izi.cast_defensive(divine_protection) then    izi.print("Divine Protection activated!")end
```

#### cast_opts​

Fields

skip_charges?: boolean - Skip spell charge validation

skip_learned?: boolean - Skip spell learned validation

skip_usable?: boolean - Skip spell usable validation

skip_back?: boolean - Skip target behind validation (validated in is_castable_to_unit)

skip_moving?: boolean - Skip moving validation

skip_mount?: boolean - Skip mount validation

skip_casting?: boolean - Skip casting state validation

skip_channeling?: boolean - Skip channeling state validation

skip_immune_check?: boolean - Skip target immunity validation entirely

damage_type?: integer - Override damage type for immunity check (use enums.damage_type_flags)

Description
Options for customizing spell casting validation. These flags allow you to bypass specific validation checks when determining if a spell can be cast. Useful for basic spell validation without target or position requirements.

Immunity Check Behavior
The immunity check works as follows:

Always blocks if target is immune to ALL damage (Divine Shield, Ice Block)

Auto-detects damage type from spell school for obvious cases:

Pure Physical school → checks physical immunity

Pure magical (Fire/Nature/Frost/Shadow/Arcane) → checks magic immunity

Holy or mixed schools → no auto-detection (ambiguous)

Developer can override with damage_type field

Use skip_immune_check = true to bypass entirely

#### unit_cast_opts​

Fields

skip_facing?: boolean - Skip facing requirement validation

skip_range?: boolean - Skip range validation

skip_usable?: boolean - Skip spell usable validation

skip_gcd?: boolean - Skip global cooldown validation

skip_learned?: boolean - Skip spell learned validation

skip_charges?: boolean - Skip spell charge validation

skip_back?: boolean - Skip target behind validation

skip_moving?: boolean - Skip moving validation

skip_mount?: boolean - Skip mount validation

skip_casting?: boolean - Skip casting state validation

skip_channeling?: boolean - Skip channeling state validation

skip_immune_check?: boolean - Skip target immunity validation entirely

damage_type?: integer - Override damage type for immunity check (use enums.damage_type_flags)

Description
Options for customizing spell casting validation when targeting a unit. Extends basic cast options with additional unit-specific checks like facing and range requirements. Use these flags to bypass specific validation checks when casting spells on a target.

#### pos_cast_opts​

Fields

skip_facing?: boolean - Skip facing requirement validation

skip_range?: boolean - Skip range validation

skip_usable?: boolean - Skip spell usable validation

skip_gcd?: boolean - Skip global cooldown validation

skip_learned?: boolean - Skip spell learned validation

skip_charges?: boolean - Skip spell charge validation

skip_moving?: boolean - Skip moving validation

skip_mount?: boolean - Skip mount validation

skip_casting?: boolean - Skip casting state validation

skip_channeling?: boolean - Skip channeling state validation

skip_immune_check?: boolean - Skip target immunity validation entirely

damage_type?: integer - Override damage type for immunity check (use enums.damage_type_flags)

check_los?: boolean - Enable line of sight validation

use_prediction?: boolean - Enable position prediction (default: true for position casts)

prediction_type?: prediction_type - Prediction algorithm: "auto" | "ACCURACY" | "MOST_HITS" | number

geometry?: geometry_type - Spell geometry: "CIRCLE" | "LINE" | number

aoe_radius?: number - Override the default AoE radius

min_hits?: integer - Minimum required hits (default: 1)

source_position?: vec3 - Custom origin point for prediction calculations

cast_time?: number - Override cast time in milliseconds (skips SDK lookup)

projectile_speed?: number - Override projectile speed in game units/sec (0 = instant)

is_heal?: boolean - Prediction becomes for allies instead of enemies

use_intersection?: boolean - Use intersection position instead of center (for accuracy type)

max_range?: number - Override the maximum range

Description
Advanced options for position-based spell casting with support for prediction and geometry customization. This type extends unit cast options with additional fields for controlling spell prediction algorithms, geometry shapes, and AoE calculations. Ideal for ground-targeted spells and skillshots that require precise positioning and hit detection.

#### izi_cast_meta​

Fields

cast_position?: vec3 - Set if a skillshot was queued

hit_time?: number - Cast time plus projectile travel, if available

predicted?: boolean - True if position came from prediction

hits?: integer - Predicted amount of hits, if available

prediction_meta?: table - Raw prediction block from _compute_cast_position

target?: game_object - Target for targeted casts

unit?: game_object - Candidate unit for *_target_if helpers

rank_index?: integer - Index chosen in ranked lists

attempted?: integer - How many candidates were attempted

reason?: string - Failure reason code on false

err?: string - Optional lower level error string

Description
Metadata returned from spell casting operations. This type provides detailed information about the cast attempt, including prediction data, targeting information, and diagnostic details for failed casts. Useful for debugging spell behavior and understanding why a cast succeeded or failed.

Previous
Item
Next
Spell Sequences

Overview
Creating a new Spellizi.spell

Fieldsids
max_enemies
last_cast_time
minimum_range
maximum_range

Helpersid
name
is_learned
is_usable
cast_time
cast_time_ms
charges
max_charges
charges_info
charges_fractional
recharge
cooldown_remains
cooldown_up
cooldown_down
get_gcd
skips_gcd
is_usable_while_moving
requires_back
since_last_cast
in_gcd_window
in_recharge
has_charges_at
track_debuff
track_buff
get_tracked_debuff_spec
get_tracked_buff_spec

Castingis_castable
is_castable_to_unit
is_castable_to_position
cast
cast_safe
cast_target_if
cast_target_if_safe
cast_defensive

Evoker Empowered Spellsizi.cast_charge_spell

DoT Spreadingizi.spread_dot

Defensive Castingizi.cast_defensive

Typescast_opts
unit_cast_opts
pos_cast_opts
izi_cast_meta
