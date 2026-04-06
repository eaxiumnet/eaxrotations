# Addons | Project Sylvanas

Source: https://docs.project-sylvanas.net/dev/api/addons

## Overview

Integration API for popular WoW addons including Zygor, BigWigs, Conroc, Questie, and TSM.

## General Addon Functions

### core.addons.is_addon_loaded

Syntax

```
core.addons.is_addon_loaded(addon_name: string): boolean
```

Parameters

addon_name: string - The name of the addon to check.

Returns

boolean - True if the addon is loaded.

Description
Checks if a specific addon is currently loaded.

### core.addons.get_addon_version

Syntax

```
core.addons.get_addon_version(addon_name: string): string
```

Parameters

addon_name: string - The name of the addon.

Returns

string - The addon version string.

Description
Gets the version of a loaded addon.

## Zygor Guides Integration

### core.addons.zygor.is_available

Syntax

```
core.addons.zygor.is_available(): boolean
```

Returns

boolean - True if Zygor is loaded.

Description
Checks if Zygor Guides addon is available.

### core.addons.zygor.get_current_step

Syntax

```
core.addons.zygor.get_current_step(): table
```

Returns

table - Current guide step information.

Description
Gets the current step from Zygor Guides.

### core.addons.zygor.get_next_waypoint

Syntax

```
core.addons.zygor.get_next_waypoint(): table
```

Returns

table - Next waypoint coordinates.

Description
Gets the next waypoint from Zygor Guides.

## BigWigs Integration

### core.addons.bigwigs.is_available

Syntax

```
core.addons.bigwigs.is_available(): boolean
```

Returns

boolean - True if BigWigs is loaded.

Description
Checks if BigWigs addon is available.

### core.addons.bigwigs.get_timer

Syntax

```
core.addons.bigwigs.get_timer(spell_id: number): number
```

Parameters

spell_id: number - The boss ability spell ID.

Returns

number - Time remaining in seconds.

Description
Gets the remaining time on a BigWigs timer.

### core.addons.bigwigs.get_all_timers

Syntax

```
core.addons.bigwigs.get_all_timers(): table
```

Returns

table - Array of all active timers.

Description
Gets all active BigWigs timers.

## ConROC Integration

### core.addons.conroc.is_available

Syntax

```
core.addons.conroc.is_available(): boolean
```

Returns

boolean - True if ConROC is loaded.

Description
Checks if ConROC addon is available.

### core.addons.conroc.get_recommended_spell

Syntax

```
core.addons.conroc.get_recommended_spell(): number
```

Returns

number - Spell ID of recommended spell.

Description
Gets the next recommended spell from ConROC.

## Questie Integration

### core.addons.questie.is_available

Syntax

```
core.addons.questie.is_available(): boolean
```

Returns

boolean - True if Questie is loaded.

Description
Checks if Questie addon is available.

### core.addons.questie.get_quest_objectives

Syntax

```
core.addons.questie.get_quest_objectives(quest_id: number): table
```

Parameters

quest_id: number - The quest ID.

Returns

table - Array of quest objectives with positions.

Description
Gets quest objective positions from Questie.

### core.addons.questie.get_quest_locations

Syntax

```
core.addons.questie.get_quest_locations(quest_id: number): table
```

Parameters

quest_id: number - The quest ID.

Returns

table - Array of quest-related NPC/object locations.

Description
Gets quest-related locations from Questie.

## TradeSkillMaster (TSM) Integration

### core.addons.tsm.is_available

Syntax

```
core.addons.tsm.is_available(): boolean
```

Returns

boolean - True if TSM is loaded.

Description
Checks if TradeSkillMaster addon is available.

### core.addons.tsm.get_item_price

Syntax

```
core.addons.tsm.get_item_price(item_id: number): number
```

Parameters

item_id: number - The item ID.

Returns

number - TSM market price in copper.

Description
Gets the TSM market price for an item.

### core.addons.tsm.get_crafting_cost

Syntax

```
core.addons.tsm.get_crafting_cost(item_id: number): number
```

Parameters

item_id: number - The crafted item ID.

Returns

number - Crafting cost in copper.

Description
Gets the crafting cost for an item from TSM.

### core.addons.tsm.is_profitable_to_craft

Syntax

```
core.addons.tsm.is_profitable_to_craft(item_id: number): boolean
```

Parameters

item_id: number - The crafted item ID.

Returns

boolean - True if crafting is profitable.

Description
Checks if crafting an item is profitable according to TSM.
