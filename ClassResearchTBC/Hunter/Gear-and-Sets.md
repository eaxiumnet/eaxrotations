# Hunter Gear and Set Pieces

This file is DB2-assisted. It lists class-relevant item sets, item IDs, item names when present in `ItemSparse`, set-bonus spell IDs, and the rotation checks each set implies.

## Rotation-Impact Rules

- Treat 2p/4p bonuses as active state flags in rotation code only when they change a decision.
- Do not hard-code a set bonus unless it is detectable or configured; use menu toggles if runtime item-set detection is unavailable.
- Separate throughput sets from tank survivability sets and PvP resilience/control sets.
- Re-check weapon speed, proc, and resource thresholds after set changes.

## Gladiator's Pursuit (`ItemSetID=586`)

### Pieces

| Item ID | Item name |
|---:|---|
| 28334 | Gladiator's Chain Armor |
| 28335 | Gladiator's Chain Gauntlets |
| 28331 | Gladiator's Chain Helm |
| 28332 | Gladiator's Chain Leggings |
| 28333 | Gladiator's Chain Spaulders |

### Bonuses

| Pieces | Bonus spell ID | Bonus name | DB2 description | Rotation impact |
|---:|---:|---|---|---|
| 2 | 32145 | Increased Resilience 35 | +value1 Resilience Rating. | Check as active set-bonus state; adjust priority, resource, cooldown, or defensive threshold if this text affects the spec. |
| 4 | 44292 | Improved Multi-Shot | Reduces the cooldown of your Multi-Shot ability by misc1/-1000 sec. | Check as active set-bonus state; adjust priority, resource, cooldown, or defensive threshold if this text affects the spec. |

## Demon Stalker Armor (`ItemSetID=651`)

### Pieces

| Item ID | Item name |
|---:|---|
| 29085 | Demon Stalker Gauntlets |
| 29081 | Demon Stalker Greathelm |
| 29083 | Demon Stalker Greaves |
| 29082 | Demon Stalker Harness |
| 29084 | Demon Stalker Shoulderguards |

### Bonuses

| Pieces | Bonus spell ID | Bonus name | DB2 description | Rotation impact |
|---:|---:|---|---|---|
| 2 | 37484 | Improved Feign Death | Reduces the chance your Feign Death ability will be resisted by value1%. | Check as active set-bonus state; adjust priority, resource, cooldown, or defensive threshold if this text affects the spec. |
| 4 | 37485 | Improved Multi-Shot | Reduces the mana cost of your Multi-Shot ability by value1%. | Check as active set-bonus state; adjust priority, resource, cooldown, or defensive threshold if this text affects the spec. |

## Rift Stalker Armor (`ItemSetID=652`)

### Pieces

| Item ID | Item name |
|---:|---|
| 30139 | Rift Stalker Hauberk |
| 30140 | Rift Stalker Gauntlets |
| 30141 | Rift Stalker Helm |
| 30142 | Rift Stalker Leggings |
| 30143 | Rift Stalker Mantle |

### Bonuses

| Pieces | Bonus spell ID | Bonus name | DB2 description | Rotation impact |
|---:|---:|---|---|---|
| 2 | 37381 | Pet Healing | Causes your pet to be healed for value1% of the damage you deal. | Check as active set-bonus state; adjust priority, resource, cooldown, or defensive threshold if this text affects the spec. |
| 4 | 37505 | Improved Steady Shot | Your Steady Shot ability has value1% increased critical strike chance. | Check as active set-bonus state; adjust priority, resource, cooldown, or defensive threshold if this text affects the spec. |

## Gronnstalker's Armor (`ItemSetID=669`)

### Pieces

| Item ID | Item name |
|---:|---|
| 31004 | Gronnstalker's Chestguard |
| 31001 | Gronnstalker's Gloves |
| 31003 | Gronnstalker's Helmet |
| 31005 | Gronnstalker's Leggings |
| 31006 | Gronnstalker's Spaulders |
| 34549 | Gronnstalker's Belt |
| 34443 | Gronnstalker's Bracers |
| 34570 | Gronnstalker's Boots |

### Bonuses

| Pieces | Bonus spell ID | Bonus name | DB2 description | Rotation impact |
|---:|---:|---|---|---|
| 2 | 38390 | Improved Aspect of the Viper | Increases the mana you gain from your Aspect of the Viper by an additional value1% of your Intellect. | Check as active set-bonus state; adjust priority, resource, cooldown, or defensive threshold if this text affects the spec. |
| 4 | 38392 | Improved Steady Shot | Increases the damage dealt by your Steady Shot ability by value1%. | Check as active set-bonus state; adjust priority, resource, cooldown, or defensive threshold if this text affects the spec. |

## Merciless Gladiator's Pursuit (`ItemSetID=706`)

### Bonuses

| Pieces | Bonus spell ID | Bonus name | DB2 description | Rotation impact |
|---:|---:|---|---|---|
| 2 | 41464 | Increased Resilience 35 | +value1 Resilience Rating. | Check as active set-bonus state; adjust priority, resource, cooldown, or defensive threshold if this text affects the spec. |
| 4 | 44292 | Improved Multi-Shot | Reduces the cooldown of your Multi-Shot ability by misc1/-1000 sec. | Check as active set-bonus state; adjust priority, resource, cooldown, or defensive threshold if this text affects the spec. |

## Vengeful Gladiator's Pursuit (`ItemSetID=723`)

### Bonuses

| Pieces | Bonus spell ID | Bonus name | DB2 description | Rotation impact |
|---:|---:|---|---|---|
| 2 | 43479 | Increased Resilience 35 | +value1 Resilience Rating. | Check as active set-bonus state; adjust priority, resource, cooldown, or defensive threshold if this text affects the spec. |
| 4 | 44292 | Improved Multi-Shot | Reduces the cooldown of your Multi-Shot ability by misc1/-1000 sec. | Check as active set-bonus state; adjust priority, resource, cooldown, or defensive threshold if this text affects the spec. |
