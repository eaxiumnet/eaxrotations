# IZI - Spell Sequences | Project Sylvanas

Source: https://docs.project-sylvanas.net/dev/libraries/izi/izi-spells-sequences

## Overview

📘 Libraries
IZI
Spell Sequences

### Overview​

The IZI Spell Sequence system allows you to chain multiple spells together with precise timing control. From simple A→B combos to complex server-confirmed sequences, this system handles the coordination automatically.

Key Features:

Simple Combos - Chain two spells with automatic timing

Multi-Spell Sequences - Execute lists of spells in order

Advanced Entries - Configure each spell with custom conditions and delays

Server Confirmation - Wait for server acknowledgment before continuing

Progress Tracking - Monitor sequence state and progress

Cooldown Management - Prevent sequence spam with built-in cooldowns

#### Simple A→B Combo​

```
local izi = require("common/izi_sdk")local shadowstep = izi.spell(36554)local kidney_shot = izi.spell(408)-- Shadowstep, then immediately Kidney Shotif izi.a_into_b(shadowstep, target, kidney_shot, target) then    izi.print("Shadowstep -> Kidney combo started!")end
```

#### Multi-Spell Sequence​

```
local izi = require("common/izi_sdk")local spells = {    izi.spell(1856),   -- Vanish    izi.spell(1784),   -- Stealth (auto-applied)    izi.spell(8676),   -- Ambush}local targets = { me, me, target }if izi.simple_sequence(spells, targets) then    izi.print("Vanish -> Ambush sequence started!")end
```

#### izi.a_into_b​

Syntax

```
izi.a_into_b(    spell_a: izi_spell,     target_a: game_object,     spell_b: izi_spell,     target_b: game_object,     delay?: number,     timeout?: number,     debug_name?: string,     cooldown?: number): boolean
```

Parameters

ParameterTypeDefaultDescriptionspell_aizi_spellrequiredFirst spell to casttarget_agame_objectrequiredTarget for first spellspell_bizi_spellrequiredSecond spell to casttarget_bgame_objectrequiredTarget for second spelldelaynumber0Delay in seconds between spellstimeoutnumber3.0Maximum time to complete sequencedebug_namestringnilName for debug loggingcooldownnumber0Cooldown before sequence can be used again
Returns

boolean - True if the sequence was successfully started

Description
Executes a simple two-spell combo. Casts spell A, then immediately (or after a delay) casts spell B. The sequence times out if spell B cannot be cast within the timeout period.

Example Usage

```
local izi = require("common/izi_sdk")local charge = izi.spell(100)local hamstring = izi.spell(1715)-- Charge then immediately Hamstringizi.a_into_b(charge, target, hamstring, target, 0, 2.0, "Charge->Hamstring")-- With a slight delay for GCDlocal heroic_leap = izi.spell(6544)local shockwave = izi.spell(46968)izi.a_into_b(heroic_leap, target, shockwave, me, 0.5, 3.0, "Leap->Shockwave")
```

#### izi.simple_sequence​

Syntax

```
izi.simple_sequence(    spells: izi_spell[],     targets: game_object[],     delay?: number,     timeout?: number,     debug_name?: string,     cooldown?: number): boolean
```

Parameters

ParameterTypeDefaultDescriptionspellsizi_spell[]requiredArray of spells to cast in ordertargetsgame_object[]requiredArray of targets (one per spell)delaynumber0Delay between each spelltimeoutnumber5.0Maximum time to complete sequencedebug_namestringnilName for debug loggingcooldownnumber0Cooldown before sequence can be used again
Returns

boolean - True if the sequence was successfully started

Description
Executes a sequence of multiple spells in order. Each spell is cast on its corresponding target. The sequence proceeds as fast as possible (respecting GCD) unless a delay is specified.

Example Usage

```
local izi = require("common/izi_sdk")-- Mage burst: Icy Veins -> Frozen Orb -> Blizzardlocal me = izi.me()local target = izi.ts()local burst_spells = {    izi.spell(12472),   -- Icy Veins    izi.spell(84714),   -- Frozen Orb    izi.spell(190356),  -- Blizzard}local burst_targets = { me, target, target }if izi.simple_sequence(burst_spells, burst_targets, 0, 5.0, "Frost Burst") then    izi.print("Frost burst sequence started!")end
```

#### izi.advanced_sequence​

Syntax

```
izi.advanced_sequence(    entries: advanced_spell_entry[],     opts?: advanced_sequence_opts): boolean
```

Parameters

entries: advanced_spell_entry[] - Array of spell entries with individual configurations

opts?: advanced_sequence_opts - Optional sequence-level options

Entry Structure: advanced_spell_entry

```
{    spell: izi_spell,              -- The spell to cast    target: game_object,           -- Target for the spell    delay?: number,                -- Delay before this spell    condition?: function|boolean,  -- Condition to check before casting    on_cast?: function,            -- Callback when spell is cast    on_skip?: function,            -- Callback if spell is skipped    cast_opts?: unit_cast_opts     -- Options passed to cast_safe}
```

Options Structure: advanced_sequence_opts

```
{    timeout?: number,      -- Maximum sequence duration (default 5.0)    cooldown?: number,     -- Cooldown after sequence completes    debug_name?: string,   -- Name for debug logging    on_complete?: function -- Callback when sequence finishes}
```

Returns

boolean - True if the sequence was successfully started

Description
Executes a complex sequence with per-spell configuration. Each entry can have its own delay, condition, and callbacks. Spells can be conditionally skipped without aborting the sequence.

Example Usage

```
local izi = require("common/izi_sdk")local me = izi.me()local target = izi.ts()-- Complex opener with conditionslocal entries = {    {        spell = izi.spell(1856),  -- Vanish        target = me,        condition = function() return me:is_in_combat() end,        on_cast = function() izi.print("Vanished!") end    },    {        spell = izi.spell(8676),  -- Ambush        target = target,        delay = 0.1,  -- Small delay to ensure stealth        condition = function() return target:is_valid_enemy() end    },    {        spell = izi.spell(703),   -- Garrote        target = target,        condition = function()             return target:debuff_down(703) -- Only if not already applied        end,        on_skip = function() izi.print("Skipped Garrote - already applied") end    }}local opts = {    timeout = 5.0,    cooldown = 30.0,  -- 30 second cooldown    debug_name = "Rogue Opener",    on_complete = function() izi.print("Opener complete!") end}izi.advanced_sequence(entries, opts)
```

#### izi.confirmed_sequence​

Syntax

```
izi.confirmed_sequence(    steps: confirmed_step[],     opts?: confirmed_sequence_opts): boolean
```

Parameters

steps: confirmed_step[] - Array of steps requiring server confirmation

opts?: confirmed_sequence_opts - Optional sequence options

Step Structure: confirmed_step

```
{    spell: izi_spell,        -- The spell to cast    target: game_object,     -- Target for the spell    confirm_buff?: integer,  -- Buff ID to confirm success    confirm_debuff?: integer,-- Debuff ID to confirm success    timeout?: number,        -- Per-step timeout    cast_opts?: unit_cast_opts}
```

Options Structure: confirmed_sequence_opts

```
{    timeout?: number,       -- Total sequence timeout    cooldown?: number,      -- Cooldown after sequence    debug_name?: string,    -- Name for debug logging    on_step?: function,     -- Called after each step confirms    on_complete?: function, -- Called when sequence finishes    on_timeout?: function   -- Called if sequence times out}
```

Returns

boolean - True if the sequence was successfully started

Description
Executes a sequence that waits for server confirmation before proceeding to each next step. This is ideal for combos where you need to verify a buff/debuff was applied before continuing.

Example Usage

```
local izi = require("common/izi_sdk")local me = izi.me()local target = izi.ts()-- Confirmed combo: Colossus Smash must land before Mortal Strikelocal steps = {    {        spell = izi.spell(167105),  -- Colossus Smash        target = target,        confirm_debuff = 208086,    -- Wait for debuff        timeout = 2.0    },    {        spell = izi.spell(12294),   -- Mortal Strike        target = target,        -- No confirmation needed, just cast    }}local opts = {    timeout = 5.0,    debug_name = "CS -> MS Combo",    on_step = function(step_index)        izi.printf("Step %d confirmed", step_index)    end,    on_complete = function()        izi.print("Combo complete!")    end}izi.confirmed_sequence(steps, opts)
```

#### izi.is_sequence_active​

```
izi.is_sequence_active(): boolean
```

Returns true if ANY sequence (native or confirmed) is currently running.

#### izi.is_confirmed_active​

```
izi.is_confirmed_active(): boolean
```

Returns true if a confirmed sequence specifically is running.

#### izi.cancel_sequence​

```
izi.cancel_sequence(): nil
```

Cancels the active native sequence (a_into_b, simple, or advanced).

#### izi.cancel_confirmed​

```
izi.cancel_confirmed(): nil
```

Cancels the active confirmed sequence.

#### izi.get_sequence_progress​

```
izi.get_sequence_progress(): integer|nil, integer|nil
```

Returns current_step, total_steps for the active sequence. Confirmed sequences take priority.

#### izi.get_confirmed_progress​

```
izi.get_confirmed_progress(): integer|nil, integer|nil
```

Returns progress specifically for confirmed sequences.

#### izi.get_sequence_type​

```
izi.get_sequence_type(): string|nil
```

Returns the type of active sequence: "confirmed", "a_into_b", "simple", "advanced", or nil.

#### izi.is_sequence_on_cooldown​

```
izi.is_sequence_on_cooldown(): boolean
```

Returns true if any sequence is on cooldown (preventing new sequences).

#### izi.get_sequence_cooldown_remaining​

```
izi.get_sequence_cooldown_remaining(): number
```

Returns the remaining cooldown time in seconds.

#### izi.set_sequence_debug​

```
izi.set_sequence_debug(enabled: boolean): nil
```

Enables or disables debug logging for native sequences.

#### izi.get_sequence_debug​

```
izi.get_sequence_debug(): boolean
```

Returns whether native sequence debugging is enabled.

#### izi.set_confirmed_debug​

```
izi.set_confirmed_debug(enabled: boolean): nil
```

Enables or disables debug logging for confirmed sequences.

#### izi.get_confirmed_debug​

```
izi.get_confirmed_debug(): boolean
```

Returns whether confirmed sequence debugging is enabled.

#### izi.on_spell_cast​

```
izi.on_spell_cast(data: table): nil
```

Feed spell cast callback data to the sequence system. This is typically connected to the spell success callback to track sequence progress.

Example Usage

```
-- Connect to spell success eventsizi.on_spell_success(function(event)    local me = izi.me()    if event.caster == me then        izi.on_spell_cast(event)    endend)
```

#### izi.CAST_POLICY​

Constants for configuring cast behavior in advanced sequences.

```
izi.CAST_POLICY.NORMAL      -- Standard castingizi.CAST_POLICY.FORCE       -- Force cast regardless of stateizi.CAST_POLICY.SKIP_GCD    -- Skip GCD check
```

#### izi.sequence​

Direct access to the underlying spell_sequence_helper module for advanced usage.

```
local sequence_helper = izi.sequence-- Access internal functions if needed
```

### Complete Example​

```
local izi = require("common/izi_sdk")-- Enable debug loggingizi.set_sequence_debug(true)izi.set_confirmed_debug(true)-- Warrior burst sequencelocal function execute_burst()    local me = izi.me()    local target = izi.ts()        if not target or not target:is_valid_enemy() then        return false    end        -- Check if we're already in a sequence    if izi.is_sequence_active() then        local step, total = izi.get_sequence_progress()        izi.printf("Sequence in progress: %d/%d", step or 0, total or 0)        return false    end        -- Check sequence cooldown    if izi.is_sequence_on_cooldown() then        local remaining = izi.get_sequence_cooldown_remaining()        izi.printf("Sequence on cooldown: %.1fs", remaining)        return false    end        -- Define the burst sequence    local burst_entries = {        {            spell = izi.spell(227847),  -- Bladestorm (Avatar talent)            target = me,            condition = function()                 return #izi.enemies(8) >= 2             end,            on_skip = function()                izi.print("Skipped Bladestorm - not enough targets")            end        },        {            spell = izi.spell(167105),  -- Colossus Smash            target = target,            delay = 0.1        },        {            spell = izi.spell(1719),    -- Recklessness            target = me,            delay = 0.05        },        {            spell = izi.spell(12294),   -- Mortal Strike            target = target,            condition = function()                return target:get_health_percentage() > 20            end        },        {            spell = izi.spell(163201),  -- Execute            target = target,            condition = function()                return target:get_health_percentage() <= 20            end        }    }        local opts = {        timeout = 8.0,        cooldown = 45.0,  -- Don't spam burst        debug_name = "Warrior Burst",        on_complete = function()            izi.print("Burst sequence complete!")        end    }        return izi.advanced_sequence(burst_entries, opts)end-- Cancel buttonizi.on_key_release(0x1B, function()  -- Escape key    if izi.is_sequence_active() then        local seq_type = izi.get_sequence_type()        if seq_type == "confirmed" then            izi.cancel_confirmed()        else            izi.cancel_sequence()        end        izi.print("Sequence cancelled!")    endend)-- Trigger burst on keybindizi.on_key_release(0x52, function()  -- R key    execute_burst()end)
```

Previous
Spell
Next
Game Object Extensions

Overview
Quick StartSimple A→B Combo
Multi-Spell Sequence

Basic Functionsizi.a_into_b
izi.simple_sequence

Advanced Sequencesizi.advanced_sequence
izi.confirmed_sequence

Sequence Managementizi.is_sequence_active
izi.is_confirmed_active
izi.cancel_sequence
izi.cancel_confirmed
izi.get_sequence_progress
izi.get_confirmed_progress
izi.get_sequence_type

Cooldown Managementizi.is_sequence_on_cooldown
izi.get_sequence_cooldown_remaining

Debug Functionsizi.set_sequence_debug
izi.get_sequence_debug
izi.set_confirmed_debug
izi.get_confirmed_debug

Spell Cast Callbackizi.on_spell_cast

Cast Policy Constantsizi.CAST_POLICY

Module Accessizi.sequence

Complete Example
