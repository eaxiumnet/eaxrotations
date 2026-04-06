# Pet Battle | Project Sylvanas

Source: https://docs.project-sylvanas.net/dev/api/pet_battle

## Overview

Full Pet Battle API for managing battle state, pet stats, abilities, and the pet journal.

## Battle State Functions

### core.pet_battle.is_in_battle

Syntax

```
core.pet_battle.is_in_battle(): boolean
```

Returns

boolean - True if currently in a pet battle.

Description
Checks if the player is currently in a pet battle.

### core.pet_battle.get_active_pet

Syntax

```
core.pet_battle.get_active_pet(): number
```

Returns

number - Index of the currently active pet (1-3).

Description
Gets the index of the currently active pet in battle.

### core.pet_battle.get_pet_info

Syntax

```
core.pet_battle.get_pet_info(pet_index: number): table
```

Parameters

pet_index: number - The pet slot index (1-3).

Returns

table - Pet information including health, max health, level, and species.

Description
Gets information about a pet in the current battle.

### core.pet_battle.get_enemy_pet_info

Syntax

```
core.pet_battle.get_enemy_pet_info(pet_index: number): table
```

Parameters

pet_index: number - The enemy pet slot index (1-3).

Returns

table - Enemy pet information.

Description
Gets information about an enemy pet in battle.

### core.pet_battle.get_abilities

Syntax

```
core.pet_battle.get_abilities(pet_index: number): table
```

Parameters

pet_index: number - The pet slot index.

Returns

table - Array of available abilities with cooldowns.

Description
Gets the abilities available to a pet in battle.

### core.pet_battle.use_ability

Syntax

```
core.pet_battle.use_ability(ability_index: number): boolean
```

Parameters

ability_index: number - The ability slot index.

Returns

boolean - True if ability was used.

Description
Uses a pet ability in battle.

### core.pet_battle.switch_pet

Syntax

```
core.pet_battle.switch_pet(pet_index: number): boolean
```

Parameters

pet_index: number - The pet index to switch to.

Returns

boolean - True if pet was switched.

Description
Switches to a different pet in battle.

### core.pet_battle.forfeit

Syntax

```
core.pet_battle.forfeit(): void
```

Description
Forfeits the current pet battle.

## Pet Journal Functions

### core.pet_battle.get_journal

Syntax

```
core.pet_battle.get_journal(): table
```

Returns

table - Array of all pets in the journal.

Description
Gets all pets in the pet journal.

### core.pet_battle.get_journal_pet_info

Syntax

```
core.pet_battle.get_journal_pet_info(pet_id: number): table
```

Parameters

pet_id: number - The pet ID in the journal.

Returns

table - Detailed pet information including stats and abilities.

Description
Gets detailed information about a pet in the journal.

### core.pet_battle.summon_pet

Syntax

```
core.pet_battle.summon_pet(pet_id: number): boolean
```

Parameters

pet_id: number - The pet ID to summon.

Returns

boolean - True if pet was summoned.

Description
Summons a pet companion.

### core.pet_battle.dismiss_pet

Syntax

```
core.pet_battle.dismiss_pet(): void
```

Description
Dismisses the current pet companion.

## Pet Stats and Abilities

### core.pet_battle.get_pet_stats

Syntax

```
core.pet_battle.get_pet_stats(pet_id: number): table
```

Parameters

pet_id: number - The pet ID.

Returns

table - Pet stats (health, power, speed, etc).

Description
Gets the stats for a specific pet.

### core.pet_battle.get_pet_abilities

Syntax

```
core.pet_battle.get_pet_abilities(pet_id: number): table
```

Parameters

pet_id: number - The pet ID.

Returns

table - Array of pet abilities with their stats.

Description
Gets all abilities for a specific pet.

### core.pet_battle.is_ability_strong_against

Syntax

```
core.pet_battle.is_ability_strong_against(ability_id: number, target_type: number): boolean
```

Parameters

ability_id: number - The ability ID.
target_type: number - The target pet type.

Returns

boolean - True if ability is strong against target.

Description
Checks if an ability type is strong against a pet type.

## Pet Battle Toys

### core.pet_battle.get_toys

Syntax

```
core.pet_battle.get_toys(): table
```

Returns

table - Array of available pet battle toys.

Description
Gets all available pet battle toys.

### core.pet_battle.use_toy

Syntax

```
core.pet_battle.use_toy(toy_id: number): boolean
```

Parameters

toy_id: number - The toy item ID.

Returns

boolean - True if toy was used.

Description
Uses a pet battle toy.
