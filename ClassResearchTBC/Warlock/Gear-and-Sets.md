# Warlock Gear and Set Pieces

This file is DB2-assisted. It lists class-relevant item sets, item IDs, item names when present in `ItemSparse`, set-bonus spell IDs, and the rotation checks each set implies.

## Rotation-Impact Rules

- Treat 2p/4p bonuses as active state flags in rotation code only when they change a decision.
- Do not hard-code a set bonus unless it is detectable or configured; use menu toggles if runtime item-set detection is unavailable.
- Separate throughput sets from tank survivability sets and PvP resilience/control sets.
- Re-check weapon speed, proc, and resource thresholds after set changes.

## Gladiator's Dreadgear (`ItemSetID=568`)

### Pieces

| Item ID | Item name |
|---:|---|
| 24556 | Gladiator's Dreadweave Gloves |
| 24553 | Gladiator's Dreadweave Hood |
| 24555 | Gladiator's Dreadweave Leggings |
| 24554 | Gladiator's Dreadweave Mantle |
| 24552 | Gladiator's Dreadweave Robe |

### Bonuses

| Pieces | Bonus spell ID | Bonus name | DB2 description | Rotation impact |
|---:|---:|---|---|---|
| 2 | 40042 | Increased Resilience 35 | +value1 Resilience Rating. | Check as active set-bonus state; adjust priority, resource, cooldown, or defensive threshold if this text affects the spec. |
| 4 | 23047 | Fear Cast Time Reduction | Reduces the casting time of your Fear spell by misc1/-1000.1 sec. | Check as active set-bonus state; adjust priority, resource, cooldown, or defensive threshold if this text affects the spec. |

## Gladiator's Felshroud (`ItemSetID=615`)

### Pieces

| Item ID | Item name |
|---:|---|
| 30186 | Gladiator's Felweave Amice |
| 30187 | Gladiator's Felweave Cowl |
| 30188 | Gladiator's Felweave Handguards |
| 30200 | Gladiator's Felweave Raiment |
| 30201 | Gladiator's Felweave Trousers |

### Bonuses

| Pieces | Bonus spell ID | Bonus name | DB2 description | Rotation impact |
|---:|---:|---|---|---|
| 2 | 40053 | Increased Resilience 35 | +value1 Resilience Rating. | Check as active set-bonus state; adjust priority, resource, cooldown, or defensive threshold if this text affects the spec. |
| 4 | 23047 | Fear Cast Time Reduction | Reduces the casting time of your Fear spell by misc1/-1000.1 sec. | Check as active set-bonus state; adjust priority, resource, cooldown, or defensive threshold if this text affects the spec. |

## Voidheart Raiment (`ItemSetID=645`)

### Pieces

| Item ID | Item name |
|---:|---|
| 28963 | Voidheart Crown |
| 28968 | Voidheart Gloves |
| 28966 | Voidheart Leggings |
| 28967 | Voidheart Mantle |
| 28964 | Voidheart Robe |

### Bonuses

| Pieces | Bonus spell ID | Bonus name | DB2 description | Rotation impact |
|---:|---:|---|---|---|
| 2 | 37377 | Shadowflame | Your shadow damage spells have a chance to grant you $37378s1 bonus shadow damage for $37378d. Your shadow damage spells have a chance to grant you $37378s1 bonus shadow damage for $37378d. | Check as active set-bonus state; adjust priority, resource, cooldown, or defensive threshold if this text affects the spec. |
| 2 | 39437 | Shadowflame Hellfire and RoF | Your fire damage spells have a chance to grant you $37378s1 bonus fire damage for $37378d. Your fire damage spells have a chance to grant you $37378s1 bonus fire damage for $37378d. | Check as active set-bonus state; adjust priority, resource, cooldown, or defensive threshold if this text affects the spec. |
| 4 | 37380 | Improved Corruption and Immolate | Increases the duration of your Corruption and Immolate abilities by misc1/1000 sec. | Check as active set-bonus state; adjust priority, resource, cooldown, or defensive threshold if this text affects the spec. |

## Corruptor Raiment (`ItemSetID=646`)

### Pieces

| Item ID | Item name |
|---:|---|
| 30211 | Gloves of the Corruptor |
| 30212 | Hood of the Corruptor |
| 30213 | Leggings of the Corruptor |
| 30215 | Mantle of the Corruptor |
| 30214 | Robe of the Corruptor |

### Bonuses

| Pieces | Bonus spell ID | Bonus name | DB2 description | Rotation impact |
|---:|---:|---|---|---|
| 2 | 37381 | Pet Healing | Causes your pet to be healed for value1% of the damage you deal. | Check as active set-bonus state; adjust priority, resource, cooldown, or defensive threshold if this text affects the spec. |
| 4 | 37384 | Improved Corruption and Immolate | Your Shadowbolt spell hits increase the damage of Corruption by value1% and your Incinerate spell hits increase the damage of Immolate by value1%. | Check as active set-bonus state; adjust priority, resource, cooldown, or defensive threshold if this text affects the spec. |

## Malefic Raiment (`ItemSetID=670`)

### Pieces

| Item ID | Item name |
|---:|---|
| 31050 | Gloves of the Malefic |
| 31051 | Hood of the Malefic |
| 31053 | Leggings of the Malefic |
| 31054 | Mantle of the Malefic |
| 31052 | Robe of the Malefic |
| 34564 | Boots of the Malefic |
| 34436 | Bracers of the Malefic |
| 34541 | Belt of the Malefic |

### Bonuses

| Pieces | Bonus spell ID | Bonus name | DB2 description | Rotation impact |
|---:|---:|---|---|---|
| 2 | 38394 | Dot Heals | Each time one of your Corruption or Immolate spells deals periodic damage, you heal $38395s1 health. | Check as active set-bonus state; adjust priority, resource, cooldown, or defensive threshold if this text affects the spec. |
| 4 | 38393 | Improved Shadow Bolt and Incinerate | Increases the damage dealt by your Shadow Bolt and Incinerate abilities by value1%. | Check as active set-bonus state; adjust priority, resource, cooldown, or defensive threshold if this text affects the spec. |

## Merciless Gladiator's Dreadgear (`ItemSetID=702`)

### Bonuses

| Pieces | Bonus spell ID | Bonus name | DB2 description | Rotation impact |
|---:|---:|---|---|---|
| 2 | 41474 | Increased Resilience 35 | +value1 Resilience Rating. | Check as active set-bonus state; adjust priority, resource, cooldown, or defensive threshold if this text affects the spec. |
| 4 | 23047 | Fear Cast Time Reduction | Reduces the casting time of your Fear spell by misc1/-1000.1 sec. | Check as active set-bonus state; adjust priority, resource, cooldown, or defensive threshold if this text affects the spec. |

## Merciless Gladiator's Felshroud (`ItemSetID=704`)

### Bonuses

| Pieces | Bonus spell ID | Bonus name | DB2 description | Rotation impact |
|---:|---:|---|---|---|
| 2 | 41462 | Increased Resilience 35 | +value1 Resilience Rating. | Check as active set-bonus state; adjust priority, resource, cooldown, or defensive threshold if this text affects the spec. |
| 4 | 23047 | Fear Cast Time Reduction | Reduces the casting time of your Fear spell by misc1/-1000.1 sec. | Check as active set-bonus state; adjust priority, resource, cooldown, or defensive threshold if this text affects the spec. |

## Vengeful Gladiator's Dreadgear (`ItemSetID=734`)

### Bonuses

| Pieces | Bonus spell ID | Bonus name | DB2 description | Rotation impact |
|---:|---:|---|---|---|
| 2 | 43481 | Increased Resilience 35 | +value1 Resilience Rating. | Check as active set-bonus state; adjust priority, resource, cooldown, or defensive threshold if this text affects the spec. |
| 4 | 23047 | Fear Cast Time Reduction | Reduces the casting time of your Fear spell by misc1/-1000.1 sec. | Check as active set-bonus state; adjust priority, resource, cooldown, or defensive threshold if this text affects the spec. |

## Vengeful Gladiator's Felshroud (`ItemSetID=735`)

### Bonuses

| Pieces | Bonus spell ID | Bonus name | DB2 description | Rotation impact |
|---:|---:|---|---|---|
| 2 | 43480 | Increased Resilience 35 | +value1 Resilience Rating. | Check as active set-bonus state; adjust priority, resource, cooldown, or defensive threshold if this text affects the spec. |
| 4 | 23047 | Fear Cast Time Reduction | Reduces the casting time of your Fear spell by misc1/-1000.1 sec. | Check as active set-bonus state; adjust priority, resource, cooldown, or defensive threshold if this text affects the spec. |
