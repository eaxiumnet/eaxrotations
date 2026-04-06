# Spell Helper | Project Sylvanas

Source: https://docs.project-sylvanas.net/dev/api/spell-helper

## Overview

📘 Libraries
Mini Libs
Spell Helper

### Overview​

The Spell Helper is a utility library that provides spell validation functions for checking cooldowns, range, line-of-sight, facing, and castability. It's a lower-level helper for direct spell queries without the object-oriented wrapper that higher-level systems provide.

Key Features:

Spell Validation - Check if spells are learned, on cooldown, usable

Range & LOS Checks - Verify targets are in range and line-of-sight

Facing Validation - Check if caster is facing the target correctly

Cost Checking - Verify resource availability for spells

Tooltip Parsing - Extract damage/healing values from spell tooltips

Modern Alternative
For a more streamlined experience, consider using the IZI SDK Spell System which provides an object-oriented wrapper around these functions with additional features like automatic immunity checking, prediction, and smart casting.

```
-- spell_helper (this library)local can_cast = spell_helper:is_spell_castable(spell_id, caster, target, false, false)-- IZI SDK (recommended)local fireball = izi.spell(133)if fireball:is_castable_to_unit(target) then    fireball:cast_safe(target)end
```

### Importing The Module​

```
---@type spell_helperlocal spell_helper = require("common/utility/spell_helper")
```

Method Access
Access functions with : (colon), not . (dot).

#### spell_helper:has_spell_equipped​

Syntax

```
spell_helper:has_spell_equipped(spell_id: number): boolean
```

Checks if the spell is in the player's spellbook.

#### spell_helper:is_spell_on_cooldown​

Syntax

```
spell_helper:is_spell_on_cooldown(spell_id: number, skip_usable?: boolean, skip_controller?: boolean): boolean
```

Parameters

ParameterTypeDefaultDescriptionspell_idnumberRequiredSpell ID to checkskip_usablebooleanfalseSkip usability checkskip_controllerbooleanfalseSkip controller check
Returns true if the spell is currently on cooldown.

#### spell_helper:is_spell_in_range​

Syntax

```
spell_helper:is_spell_in_range(spell_id: number, target: game_object, source: vec3, destination: vec3): boolean
```

Checks if the target is within castable range for the spell.

#### spell_helper:is_spell_within_angle​

Syntax

```
spell_helper:is_spell_within_angle(spell_id: number, caster: game_object, target: game_object, caster_position: vec3, target_position: vec3): boolean
```

Checks if the target is within the permissible angle for casting (facing requirement).

#### spell_helper:is_spell_in_line_of_sight​

Syntax

```
spell_helper:is_spell_in_line_of_sight(spell_id: number, caster: game_object, target: game_object): boolean
```

Checks if the caster has line-of-sight to the target.

#### spell_helper:is_spell_in_line_of_sight_position​

Syntax

```
spell_helper:is_spell_in_line_of_sight_position(spell_id: number, caster: game_object, cast_position: vec3): boolean
```

Checks if the caster has line-of-sight to a world position (for ground-targeted spells).

#### spell_helper:get_spell_cost​

Syntax

```
spell_helper:get_spell_cost(spell_id: number): table
```

Returns the resource cost(s) of a spell.

#### spell_helper:can_afford_spell​

Syntax

```
spell_helper:can_afford_spell(unit: game_object, spell_id: number, spell_costs: table): boolean
```

Checks if the unit has enough resources to cast the spell.

#### spell_helper:is_spell_castable​

Syntax

```
spell_helper:is_spell_castable(    spell_id: number,    caster: game_object,    target: game_object,    skip_facing: boolean,    skip_range: boolean,    skip_usable?: boolean,    skip_controller?: boolean,    skip_learned?: boolean): boolean
```

Parameters

ParameterTypeDefaultDescriptionspell_idnumberRequiredSpell ID to checkcastergame_objectRequiredThe casting unittargetgame_objectRequiredThe target unitskip_facingbooleanRequiredSkip facing requirement checkskip_rangebooleanRequiredSkip range validationskip_usablebooleanfalseSkip usability checkskip_controllerbooleanfalseSkip controller checkskip_learnedbooleanfalseSkip "spell learned" check
Comprehensive check if a spell can be cast considering cooldown, range, facing, resources, and more.

#### spell_helper:is_spell_castable_position​

Syntax

```
spell_helper:is_spell_castable_position(    spell_id: number,    caster: game_object,    target: game_object,    cast_position: vec3,    skip_facing: boolean,    skip_range: boolean,    is_queue?: boolean,    skip_usable?: boolean,    skip_controller?: boolean,    skip_learned?: boolean): boolean
```

Same as is_spell_castable but for ground-targeted spells at a specific position.

#### spell_helper:is_spell_queueable​

Syntax

```
spell_helper:is_spell_queueable(    spell_id: number,    caster: game_object,    target: game_object,    skip_facing: boolean,    skip_range: boolean,    skip_usable?: boolean,    skip_controller?: boolean,    skip_learned?: boolean): boolean
```

Checks if a spell can be queued (slightly different timing than castable).

#### spell_helper:get_spell_damage​

Syntax

```
spell_helper:get_spell_damage(spell_id: number, ignore_percentage?: boolean, ignore_flat?: boolean): number
```

Parses tooltip to extract damage value. Not precise for all spells.

#### spell_helper:get_spell_healing​

Syntax

```
spell_helper:get_spell_healing(spell_id: number, ignore_percentage?: boolean, ignore_flat?: boolean): number
```

Parses tooltip to extract healing value. Not precise for all spells.

#### spell_helper:get_remaining_charge_cooldown​

Syntax

```
spell_helper:get_remaining_charge_cooldown(spell_id: number): number, number
```

Returns

number - Cooldown remaining on current charge

number - Total cooldown for all remaining charges

### Troubleshooting: "My Spell Won't Cast!"​

This section covers common issues when spells fail to cast and how to diagnose/fix them.

#### 1. Framework Says "Spell Not Learned" (Common)​

Cause: Blizzard's spellbook data is sometimes wrong. Their internal API reports spells as not learned even when they clearly are in your spellbook. Our validation trusts that data, so your cast request gets blocked.

Symptoms:

Spell is visibly in your spellbook

You can manually cast it with no issues

Your script fails with "not learned" or similar

Diagnosis:

```
local spell_id = 12345core.log("Is learned: " .. tostring(core.spell_book.is_learned(spell_id)))core.log("Has spell: " .. tostring(core.spell_book.has_spell(spell_id)))
```

Solutions:

Use skip_learned option (if available in your casting system):

```
-- With spell_helperspell_helper:is_spell_castable(spell_id, caster, target, false, false, false, false, true)--                                                                              ^^^^ skip_learned-- With IZI SDKspell:cast_safe(target, "message", { skip_learned = true })
```

Add a pre-cast check for a related buff or talent:

```
-- Instead of relying on is_learned, check if you have the talentlocal has_talent = player:has_talent(talent_id)if has_talent then    -- Proceed with castend
```

When to Report: If this affects a common spell and you've confirmed with screenshots that it's learned, report to Silvi with:

Spell name and ID

Screenshot of spellbook showing it's learned

Your code snippet

The error message

#### 2. Framework Says "Spell Not Owned" (Rare)​

Cause: Similar to "not learned" but even rarer. Blizzard API quality issue.

Solutions: Same as above - use skip_learned or add alternative checks.

#### 3. Wrong Spell ID (Very Common)​

Cause: Even with tooltip addons like IDTip, the displayed ID isn't always what you need to cast. Some spells are UI-driven spaghetti where the icon changes, tooltip changes, even the spell name changes, but internally the game expects the ORIGINAL spell ID.

Symptoms:

Your spell ID looks correct from the tooltip

Cast attempts fail or cast the wrong spell

Manual casting works fine

Diagnosis:

```
-- Register a callback to see what spell ID actually gets cast when you do it manuallycore.register_on_spell_cast_callback(function(data)    core.log(string.format("Cast spell: %s (ID: %d)",         data.spell_name or "unknown",         data.spell_id))end)
```

Cast the spell manually and compare the logged ID with what your script is trying to cast.

#### 4. Double-Cast Spells (The Hammer of Light Problem)​

Some spells transform into a different spell temporarily but still require casting the ORIGINAL spell ID.

Classic Example: Divine Toll → Hammer of Light (Protection Paladin, Lightsmith)

What happens:

You cast Divine Toll (ID: 375576)

Divine Toll's button transforms into Hammer of Light for ~30 seconds

Hammer of Light has a different icon and different tooltip ID

But internally, Blizzard expects you to cast Divine Toll again to trigger it

Why normal casting fails:

```
-- This WON'T work:local hammer_of_light = izi.spell(HAMMER_OF_LIGHT_ID)hammer_of_light:cast_safe(target)  -- Fails! Wrong ID-- The helper checks Divine Toll's cooldown, sees it's on CD, blocks the cast-- But the SERVER would actually accept it!
```

Temporary Workaround:

```
-- Use raw cast (bypasses cooldown/usability checks)core.input.cast_spell(DIVINE_TOLL_ID, target)
```

Raw Casting Warning
Do NOT use raw casting everywhere! This bypass is a workaround for specific broken spells, not a standard rotation tool. Raw casts:

Don't check cooldowns

Don't check resources

Don't check range/LOS

Can cause issues if misused

Only use for confirmed double-cast spell issues.

When to Report: If you find a spell like this:

Confirm both spell IDs (original and transformed)

Confirm that casting the original ID triggers the transformed effect

Report to Silvi with full details so a proper exception can be added to the library

#### 5. Debugging Checklist​

When a spell won't cast, check these in order:

```
local spell_id = YOUR_SPELL_IDlocal player = core.object_manager.get_local_player()local target = core.object_manager.get_target()-- 1. Is it learned?core.log("Learned: " .. tostring(core.spell_book.is_learned(spell_id)))-- 2. Do we have it?core.log("Has spell: " .. tostring(core.spell_book.has_spell(spell_id)))-- 3. Is it on cooldown?local cd_info = core.spell_book.get_spell_cooldown(spell_id)core.log("On CD: " .. tostring(cd_info and cd_info.remaining > 0))-- 4. Can we afford it?local cost = spell_helper:get_spell_cost(spell_id)core.log("Can afford: " .. tostring(spell_helper:can_afford_spell(player, spell_id, cost)))-- 5. Is target in range?core.log("In range: " .. tostring(spell_helper:is_spell_in_range(    spell_id, target, player:get_position(), target:get_position())))-- 6. Do we have LOS?core.log("Has LOS: " .. tostring(spell_helper:is_spell_in_line_of_sight(    spell_id, player, target)))-- 7. Are we facing?core.log("Facing: " .. tostring(spell_helper:is_spell_within_angle(    spell_id, player, target, player:get_position(), target:get_position())))
```

#### What to Send When Reporting Issues​

When you DM Silvi about spell issues, include:

Spell name and Spell ID you're trying to cast

What the framework reports (not learned, not owned, cooldown blocked, etc.)

Screenshot of spellbook proving the spell is learned

Your code snippet showing how you're trying to cast

Video clip if the issue is complex (like double-cast spells)

What you've already tried (skip_learned, raw cast test, etc.)

#### Basic Castability Check​

```
local spell_helper = require("common/utility/spell_helper")local FIREBALL = 133local player = core.object_manager.get_local_player()local target = core.object_manager.get_target()if spell_helper:is_spell_castable(FIREBALL, player, target, false, false) then    core.input.cast_spell(FIREBALL, target)end
```

#### With Skip Options​

```
-- Skip facing (for instant spells while moving)if spell_helper:is_spell_castable(SPELL_ID, player, target, true, false) then    -- Cast...end-- Skip learned check (for problematic spells)if spell_helper:is_spell_castable(SPELL_ID, player, target, false, false, false, false, true) then    -- Cast...end
```

#### Position-Based Spell​

```
local BLIZZARD = 190356local cast_position = target:get_position()if spell_helper:is_spell_castable_position(BLIZZARD, player, target, cast_position, false, false) then    core.input.cast_spell_position(BLIZZARD, cast_position)end
```

Previous
Unit Helper
Next
Plugin Helper

Overview
Importing The Module
Functionsspell_helper:has_spell_equipped
spell_helper:is_spell_on_cooldown
spell_helper:is_spell_in_range
spell_helper:is_spell_within_angle
spell_helper:is_spell_in_line_of_sight
spell_helper:is_spell_in_line_of_sight_position
spell_helper:get_spell_cost
spell_helper:can_afford_spell
spell_helper:is_spell_castable
spell_helper:is_spell_castable_position
spell_helper:is_spell_queueable
spell_helper:get_spell_damage
spell_helper:get_spell_healing
spell_helper:get_remaining_charge_cooldown

Troubleshooting: "My Spell Won't Cast!"1. Framework Says "Spell Not Learned" (Common)
2. Framework Says "Spell Not Owned" (Rare)
3. Wrong Spell ID (Very Common)
4. Double-Cast Spells (The Hammer of Light Problem)
5. Debugging Checklist
What to Send When Reporting Issues

Example UsageBasic Castability Check
With Skip Options
Position-Based Spell
