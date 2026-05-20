# Warrior Gear and Set Pieces

This file is DB2-assisted. It lists class-relevant item sets, item IDs, item names when present in `ItemSparse`, set-bonus spell IDs, and the rotation checks each set implies.

## Rotation-Impact Rules

- Treat 2p/4p bonuses as active state flags in rotation code only when they change a decision.
- Do not hard-code a set bonus unless it is detectable or configured; use menu toggles if runtime item-set detection is unavailable.
- Separate throughput sets from tank survivability sets and PvP resilience/control sets.
- Re-check weapon speed, proc, and resource thresholds after set changes.

## Gladiator's Battlegear (`ItemSetID=567`)

### Pieces

| Item ID | Item name |
|---:|---|
| 24544 | Gladiator's Plate Chestpiece |
| 24549 | Gladiator's Plate Gauntlets |
| 24545 | Gladiator's Plate Helm |
| 24547 | Gladiator's Plate Legguards |
| 24546 | Gladiator's Plate Shoulders |

### Bonuses

| Pieces | Bonus spell ID | Bonus name | DB2 description | Rotation impact |
|---:|---:|---|---|---|
| 2 | 32145 | Increased Resilience 35 | +value1 Resilience Rating. | Check as active set-bonus state; adjust priority, resource, cooldown, or defensive threshold if this text affects the spec. |
| 4 | 22738 | Intercept Cooldown Reduction | Reduces the cooldown of your Intercept ability by $/1000;s1 sec. | Check as active set-bonus state; adjust priority, resource, cooldown, or defensive threshold if this text affects the spec. |

## Warbringer Armor (`ItemSetID=654`)

### Pieces

| Item ID | Item name |
|---:|---|
| 29012 | Warbringer Chestguard |
| 29011 | Warbringer Greathelm |
| 29017 | Warbringer Handguards |
| 29015 | Warbringer Legguards |
| 29016 | Warbringer Shoulderguards |

### Bonuses

| Pieces | Bonus spell ID | Bonus name | DB2 description | Rotation impact |
|---:|---:|---|---|---|
| 2 | 37514 | Blade Turning | You have a chance each time you parry to gain Blade Turning, absorbing $37515s1 damage for $37515d. | Check as active set-bonus state; adjust priority, resource, cooldown, or defensive threshold if this text affects the spec. |
| 4 | 37516 | Revenge Bonus | Your Revenge ability causes your next damaging ability to do $37517s1% more damage. | Check as active set-bonus state; adjust priority, resource, cooldown, or defensive threshold if this text affects the spec. |

## Warbringer Battlegear (`ItemSetID=655`)

### Pieces

| Item ID | Item name |
|---:|---|
| 29021 | Warbringer Battle-Helm |
| 29019 | Warbringer Breastplate |
| 29020 | Warbringer Gauntlets |
| 29022 | Warbringer Greaves |
| 29023 | Warbringer Shoulderplates |

### Bonuses

| Pieces | Bonus spell ID | Bonus name | DB2 description | Rotation impact |
|---:|---:|---|---|---|
| 2 | 37518 | Whirlwind Discount | Your Whirlwind ability costs misc1/-10 less rage. | Check as active set-bonus state; adjust priority, resource, cooldown, or defensive threshold if this text affects the spec. |
| 4 | 37519 | Rage Bonus | You gain an additional $37521m1/10 rage each time one of your attacks is parried or dodged. | Check as active set-bonus state; adjust priority, resource, cooldown, or defensive threshold if this text affects the spec. |

## Destroyer Armor (`ItemSetID=656`)

### Pieces

| Item ID | Item name |
|---:|---|
| 30113 | Destroyer Chestguard |
| 30115 | Destroyer Greathelm |
| 30114 | Destroyer Handguards |
| 30116 | Destroyer Legguards |
| 30117 | Destroyer Shoulderguards |

### Bonuses

| Pieces | Bonus spell ID | Bonus name | DB2 description | Rotation impact |
|---:|---:|---|---|---|
| 2 | 37522 | Shield Block Block Value | Each time you use your Shield Block ability, you gain $37523s1 block value against a single attack in the next $37523d. | Check as active set-bonus state; adjust priority, resource, cooldown, or defensive threshold if this text affects the spec. |
| 4 | 37525 | Battle Rush | You have a chance each time you are hit to gain $37526s1 haste rating for $37526d. | Check as active set-bonus state; adjust priority, resource, cooldown, or defensive threshold if this text affects the spec. |

## Destroyer Battlegear (`ItemSetID=657`)

### Pieces

| Item ID | Item name |
|---:|---|
| 30120 | Destroyer Battle-Helm |
| 30118 | Destroyer Breastplate |
| 30119 | Destroyer Gauntlets |
| 30121 | Destroyer Greaves |
| 30122 | Destroyer Shoulderblades |

### Bonuses

| Pieces | Bonus spell ID | Bonus name | DB2 description | Rotation impact |
|---:|---:|---|---|---|
| 2 | 37528 | Overpower Bonus | Your Overpower ability now grants you $37529s1 attack power for $37529d. | Check as active set-bonus state; adjust priority, resource, cooldown, or defensive threshold if this text affects the spec. |
| 4 | 37535 | Bloodthirst and Mortal Strike Discount | Your Bloodthirst and Mortal Strike abilities cost 5 less rage. | Check as active set-bonus state; adjust priority, resource, cooldown, or defensive threshold if this text affects the spec. |

## Onslaught Battlegear (`ItemSetID=672`)

### Pieces

| Item ID | Item name |
|---:|---|
| 30972 | Onslaught Battle-Helm |
| 30975 | Onslaught Breastplate |
| 30969 | Onslaught Gauntlets |
| 30977 | Onslaught Greaves |
| 30979 | Onslaught Shoulderblades |
| 34546 | Onslaught Belt |
| 34441 | Onslaught Bracers |
| 34569 | Onslaught Treads |

### Bonuses

| Pieces | Bonus spell ID | Bonus name | DB2 description | Rotation impact |
|---:|---:|---|---|---|
| 2 | 38398 | Reduced Cleave Cost | Reduces the rage cost of your Execute ability by misc1/-10. | Check as active set-bonus state; adjust priority, resource, cooldown, or defensive threshold if this text affects the spec. |
| 4 | 38399 | Improved Mortal Strike and Bloodthirst | Increases the damage of your Mortal Strike and Bloodthirst abilities by value1%. | Check as active set-bonus state; adjust priority, resource, cooldown, or defensive threshold if this text affects the spec. |

## Onslaught Armor (`ItemSetID=673`)

### Pieces

| Item ID | Item name |
|---:|---|
| 30976 | Onslaught Chestguard |
| 30974 | Onslaught Greathelm |
| 30970 | Onslaught Handguards |
| 30978 | Onslaught Legguards |
| 30980 | Onslaught Shoulderguards |
| 34568 | Onslaught Boots |
| 34442 | Onslaught Wristguards |
| 34547 | Onslaught Waistguard |

### Bonuses

| Pieces | Bonus spell ID | Bonus name | DB2 description | Rotation impact |
|---:|---:|---|---|---|
| 2 | 38408 | Improved Commanding Shout | Increases the health bonus from your Commanding Shout ability by value1. | Check as active set-bonus state; adjust priority, resource, cooldown, or defensive threshold if this text affects the spec. |
| 4 | 38407 | Improved Shield Slam | Increases the damage of your Shield Slam ability by value1%. | Check as active set-bonus state; adjust priority, resource, cooldown, or defensive threshold if this text affects the spec. |

## Merciless Gladiator's Battlegear (`ItemSetID=701`)

### Bonuses

| Pieces | Bonus spell ID | Bonus name | DB2 description | Rotation impact |
|---:|---:|---|---|---|
| 2 | 41464 | Increased Resilience 35 | +value1 Resilience Rating. | Check as active set-bonus state; adjust priority, resource, cooldown, or defensive threshold if this text affects the spec. |
| 4 | 22738 | Intercept Cooldown Reduction | Reduces the cooldown of your Intercept ability by $/1000;s1 sec. | Check as active set-bonus state; adjust priority, resource, cooldown, or defensive threshold if this text affects the spec. |

## Vengeful Gladiator's Battlegear (`ItemSetID=736`)

### Bonuses

| Pieces | Bonus spell ID | Bonus name | DB2 description | Rotation impact |
|---:|---:|---|---|---|
| 2 | 43479 | Increased Resilience 35 | +value1 Resilience Rating. | Check as active set-bonus state; adjust priority, resource, cooldown, or defensive threshold if this text affects the spec. |
| 4 | 22738 | Intercept Cooldown Reduction | Reduces the cooldown of your Intercept ability by $/1000;s1 sec. | Check as active set-bonus state; adjust priority, resource, cooldown, or defensive threshold if this text affects the spec. |
