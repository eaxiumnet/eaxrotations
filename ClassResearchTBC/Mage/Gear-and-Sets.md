# Mage Gear and Set Pieces

This file is DB2-assisted. It lists class-relevant item sets, item IDs, item names when present in `ItemSparse`, set-bonus spell IDs, and the rotation checks each set implies.

## Rotation-Impact Rules

- Treat 2p/4p bonuses as active state flags in rotation code only when they change a decision.
- Do not hard-code a set bonus unless it is detectable or configured; use menu toggles if runtime item-set detection is unavailable.
- Separate throughput sets from tank survivability sets and PvP resilience/control sets.
- Re-check weapon speed, proc, and resource thresholds after set changes.

## Gladiator's Regalia (`ItemSetID=579`)

### Pieces

| Item ID | Item name |
|---:|---|
| 25854 | Gladiator's Silk Amice |
| 25855 | Gladiator's Silk Cowl |
| 25857 | Gladiator's Silk Handguards |
| 25856 | Gladiator's Silk Raiment |
| 25858 | Gladiator's Silk Trousers |

### Bonuses

| Pieces | Bonus spell ID | Bonus name | DB2 description | Rotation impact |
|---:|---:|---|---|---|
| 2 | 40042 | Increased Resilience 35 | +value1 Resilience Rating. | Check as active set-bonus state; adjust priority, resource, cooldown, or defensive threshold if this text affects the spec. |
| 4 | 44302 | Improved Polymorph | Reduces the casting time of your Polymorph spell by misc1/-1000.2 sec. | Check as active set-bonus state; adjust priority, resource, cooldown, or defensive threshold if this text affects the spec. |

## Aldor Regalia (`ItemSetID=648`)

### Pieces

| Item ID | Item name |
|---:|---|
| 29076 | Collar of the Aldor |
| 29080 | Gloves of the Aldor |
| 29078 | Legwraps of the Aldor |
| 29079 | Pauldrons of the Aldor |
| 29077 | Vestments of the Aldor |

### Bonuses

| Pieces | Bonus spell ID | Bonus name | DB2 description | Rotation impact |
|---:|---:|---|---|---|
| 2 | 37438 | Pushback Resistance | Gives you a value1% chance to avoid interruption caused by damage while casting Fireball or Frostbolt. | Check as active set-bonus state; adjust priority, resource, cooldown, or defensive threshold if this text affects the spec. |
| 4 | 37439 | Cooldown Reduction | Reduces the cooldown on Presence of Mind by misc1/-1000 sec, on Blast Wave by $m2/-1000 sec, and on Ice Block by $m3/-1000 sec. | Check as active set-bonus state; adjust priority, resource, cooldown, or defensive threshold if this text affects the spec. |

## Tirisfal Regalia (`ItemSetID=649`)

### Pieces

| Item ID | Item name |
|---:|---|
| 30206 | Cowl of Tirisfal |
| 30205 | Gloves of Tirisfal |
| 30207 | Leggings of Tirisfal |
| 30210 | Mantle of Tirisfal |
| 30196 | Robes of Tirisfal |

### Bonuses

| Pieces | Bonus spell ID | Bonus name | DB2 description | Rotation impact |
|---:|---:|---|---|---|
| 2 | 37441 | Improved Arcane Blast | Increases the damage and mana cost of Arcane Blast by value1%. | Check as active set-bonus state; adjust priority, resource, cooldown, or defensive threshold if this text affects the spec. |
| 4 | 37443 | Crit Bonus Damage | Your spell critical strikes grant you up to $37444s1 spell damage for $37444d. | Check as active set-bonus state; adjust priority, resource, cooldown, or defensive threshold if this text affects the spec. |

## Tempest Regalia (`ItemSetID=671`)

### Pieces

| Item ID | Item name |
|---:|---|
| 31056 | Cowl of the Tempest |
| 31055 | Gloves of the Tempest |
| 31058 | Leggings of the Tempest |
| 31059 | Mantle of the Tempest |
| 31057 | Robes of the Tempest |
| 34574 | Boots of the Tempest |
| 34447 | Bracers of the Tempest |
| 34557 | Belt of the Tempest |

### Bonuses

| Pieces | Bonus spell ID | Bonus name | DB2 description | Rotation impact |
|---:|---:|---|---|---|
| 2 | 38396 | Improved Evocation | Increases the duration of your Evocation ability by misc1/1000 sec. | Check as active set-bonus state; adjust priority, resource, cooldown, or defensive threshold if this text affects the spec. |
| 4 | 38397 | Improved Fireball, Frostbolt, and Arcane Missiles | Increases the damage of your Fireball, Frostbolt, and Arcane Missiles abilities by value1%. | Check as active set-bonus state; adjust priority, resource, cooldown, or defensive threshold if this text affects the spec. |

## Merciless Gladiator's Regalia (`ItemSetID=710`)

### Bonuses

| Pieces | Bonus spell ID | Bonus name | DB2 description | Rotation impact |
|---:|---:|---|---|---|
| 2 | 41462 | Increased Resilience 35 | +value1 Resilience Rating. | Check as active set-bonus state; adjust priority, resource, cooldown, or defensive threshold if this text affects the spec. |
| 4 | 44302 | Improved Polymorph | Reduces the casting time of your Polymorph spell by misc1/-1000.2 sec. | Check as active set-bonus state; adjust priority, resource, cooldown, or defensive threshold if this text affects the spec. |

## Vengeful Gladiator's Regalia (`ItemSetID=724`)

### Bonuses

| Pieces | Bonus spell ID | Bonus name | DB2 description | Rotation impact |
|---:|---:|---|---|---|
| 2 | 43480 | Increased Resilience 35 | +value1 Resilience Rating. | Check as active set-bonus state; adjust priority, resource, cooldown, or defensive threshold if this text affects the spec. |
| 4 | 44302 | Improved Polymorph | Reduces the casting time of your Polymorph spell by misc1/-1000.2 sec. | Check as active set-bonus state; adjust priority, resource, cooldown, or defensive threshold if this text affects the spec. |
