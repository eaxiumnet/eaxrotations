# Priest Gear and Set Pieces

This file is DB2-assisted. It lists class-relevant item sets, item IDs, item names when present in `ItemSparse`, set-bonus spell IDs, and the rotation checks each set implies.

## Rotation-Impact Rules

- Treat 2p/4p bonuses as active state flags in rotation code only when they change a decision.
- Do not hard-code a set bonus unless it is detectable or configured; use menu toggles if runtime item-set detection is unavailable.
- Separate throughput sets from tank survivability sets and PvP resilience/control sets.
- Re-check weapon speed, proc, and resource thresholds after set changes.

## Gladiator's Raiment (`ItemSetID=581`)

### Pieces

| Item ID | Item name |
|---:|---|
| 27707 | Gladiator's Satin Gloves |
| 27708 | Gladiator's Satin Hood |
| 27709 | Gladiator's Satin Leggings |
| 27710 | Gladiator's Satin Mantle |
| 27711 | Gladiator's Satin Robe |

### Bonuses

| Pieces | Bonus spell ID | Bonus name | DB2 description | Rotation impact |
|---:|---:|---|---|---|
| 2 | 40042 | Increased Resilience 35 | +value1 Resilience Rating. | Check as active set-bonus state; adjust priority, resource, cooldown, or defensive threshold if this text affects the spec. |
| 4 | 33333 | Weakened Soul Reduction | Reduces the duration of the Weakened Soul effect caused by your Power Word: Shield by $/1000;s1 sec. | Check as active set-bonus state; adjust priority, resource, cooldown, or defensive threshold if this text affects the spec. |

## Incarnate Raiment (`ItemSetID=663`)

### Pieces

| Item ID | Item name |
|---:|---|
| 29055 | Handwraps of the Incarnate |
| 29049 | Light-Collar of the Incarnate |
| 29054 | Light-Mantle of the Incarnate |
| 29050 | Robes of the Incarnate |
| 29053 | Trousers of the Incarnate |

### Bonuses

| Pieces | Bonus spell ID | Bonus name | DB2 description | Rotation impact |
|---:|---:|---|---|---|
| 2 | 37564 | Improved Prayer of Healing | Your Prayer of Healing spell now also causes an additional $37563o healing over $37563d. | Check as active set-bonus state; adjust priority, resource, cooldown, or defensive threshold if this text affects the spec. |
| 4 | 37568 | Greater Heal Discount | Each time you cast Flash Heal, your next Greater Heal cast within $37565d has its casting time reduced by $37565m1/-1000.1, stacking up to 5 times. | Check as active set-bonus state; adjust priority, resource, cooldown, or defensive threshold if this text affects the spec. |

## Incarnate Regalia (`ItemSetID=664`)

### Pieces

| Item ID | Item name |
|---:|---|
| 29057 | Gloves of the Incarnate |
| 29059 | Leggings of the Incarnate |
| 29056 | Shroud of the Incarnate |
| 29058 | Soul-Collar of the Incarnate |
| 29060 | Soul-Mantle of the Incarnate |

### Bonuses

| Pieces | Bonus spell ID | Bonus name | DB2 description | Rotation impact |
|---:|---:|---|---|---|
| 2 | 37570 | Improved Shadowfiend | Your Shadowfiend now has value1 more stamina and lasts $m2/1000 sec. longer. | Check as active set-bonus state; adjust priority, resource, cooldown, or defensive threshold if this text affects the spec. |
| 4 | 37571 | Improved Mind Flay and Smite | Your Mind Flay and Smite spells deal value1% more damage. | Check as active set-bonus state; adjust priority, resource, cooldown, or defensive threshold if this text affects the spec. |

## Avatar Raiment (`ItemSetID=665`)

### Pieces

| Item ID | Item name |
|---:|---|
| 30153 | Breeches of the Avatar |
| 30152 | Cowl of the Avatar |
| 30151 | Gloves of the Avatar |
| 30154 | Mantle of the Avatar |
| 30150 | Vestments of the Avatar |

### Bonuses

| Pieces | Bonus spell ID | Bonus name | DB2 description | Rotation impact |
|---:|---:|---|---|---|
| 2 | 37594 | Greater Heal Refund | If your Greater Heal brings the target to full health, you gain $37595s1 mana. | Check as active set-bonus state; adjust priority, resource, cooldown, or defensive threshold if this text affects the spec. |
| 4 | 26171 | Increased Renew Duration | Increases the duration of your Renew spell by $/1000;s1 sec. | Check as active set-bonus state; adjust priority, resource, cooldown, or defensive threshold if this text affects the spec. |

## Avatar Regalia (`ItemSetID=666`)

### Pieces

| Item ID | Item name |
|---:|---|
| 30160 | Handguards of the Avatar |
| 30161 | Hood of the Avatar |
| 30162 | Leggings of the Avatar |
| 30159 | Shroud of the Avatar |
| 30163 | Wings of the Avatar |

### Bonuses

| Pieces | Bonus spell ID | Bonus name | DB2 description | Rotation impact |
|---:|---:|---|---|---|
| 2 | 37600 | Offensive Discount | Each time you cast an offensive spell, there is a chance your next spell will cost $37601s1 less mana. | Check as active set-bonus state; adjust priority, resource, cooldown, or defensive threshold if this text affects the spec. |
| 4 | 37603 | Shadow Word Pain Damage | Each time your Shadow Word: Pain deals damage, it has a chance to grant your next spell cast within $37604d up to $37604s1 damage and healing. | Check as active set-bonus state; adjust priority, resource, cooldown, or defensive threshold if this text affects the spec. |

## Absolution Regalia (`ItemSetID=674`)

### Pieces

| Item ID | Item name |
|---:|---|
| 31061 | Handguards of Absolution |
| 31064 | Hood of Absolution |
| 31067 | Leggings of Absolution |
| 31070 | Shoulderpads of Absolution |
| 31065 | Shroud of Absolution |
| 34434 | Bracers of Absolution |
| 34528 | Cord of Absolution |
| 34563 | Treads of Absolution |

### Bonuses

| Pieces | Bonus spell ID | Bonus name | DB2 description | Rotation impact |
|---:|---:|---|---|---|
| 2 | 38413 | Increased Shadow Word: Pain Duration | Increases the duration of your Shadow Word: Pain ability by misc1/1000 sec. | Check as active set-bonus state; adjust priority, resource, cooldown, or defensive threshold if this text affects the spec. |
| 4 | 38412 | Improved Mind Blast | Increases the damage from your Mind Blast ability by value1%. | Check as active set-bonus state; adjust priority, resource, cooldown, or defensive threshold if this text affects the spec. |

## Vestments of Absolution (`ItemSetID=675`)

### Pieces

| Item ID | Item name |
|---:|---|
| 31068 | Breeches of Absolution |
| 31063 | Cowl of Absolution |
| 31060 | Gloves of Absolution |
| 31069 | Mantle of Absolution |
| 31066 | Vestments of Absolution |
| 34562 | Boots of Absolution |
| 34527 | Belt of Absolution |
| 34435 | Cuffs of Absolution |

### Bonuses

| Pieces | Bonus spell ID | Bonus name | DB2 description | Rotation impact |
|---:|---:|---|---|---|
| 2 | 38410 | Reduced Prayer of Healing Cost | Reduces the mana cost of your Prayer of Healing ability by value1%. | Check as active set-bonus state; adjust priority, resource, cooldown, or defensive threshold if this text affects the spec. |
| 4 | 38411 | Improved Greater Heal | Increases the healing from your Greater Heal ability by value1%. | Check as active set-bonus state; adjust priority, resource, cooldown, or defensive threshold if this text affects the spec. |

## Gladiator's Investiture (`ItemSetID=687`)

### Pieces

| Item ID | Item name |
|---:|---|
| 31409 | Gladiator's Mooncloth Gloves |
| 31410 | Gladiator's Mooncloth Hood |
| 31411 | Gladiator's Mooncloth Leggings |
| 31412 | Gladiator's Mooncloth Mantle |
| 31413 | Gladiator's Mooncloth Robe |

### Bonuses

| Pieces | Bonus spell ID | Bonus name | DB2 description | Rotation impact |
|---:|---:|---|---|---|
| 2 | 40043 | Increased Resilience 35 | +value1 Resilience Rating. | Check as active set-bonus state; adjust priority, resource, cooldown, or defensive threshold if this text affects the spec. |
| 4 | 33333 | Weakened Soul Reduction | Reduces the duration of the Weakened Soul effect caused by your Power Word: Shield by $/1000;s1 sec. | Check as active set-bonus state; adjust priority, resource, cooldown, or defensive threshold if this text affects the spec. |

## Merciless Gladiator's Investiture (`ItemSetID=705`)

### Bonuses

| Pieces | Bonus spell ID | Bonus name | DB2 description | Rotation impact |
|---:|---:|---|---|---|
| 2 | 41463 | Increased Resilience 35 | +value1 Resilience Rating. | Check as active set-bonus state; adjust priority, resource, cooldown, or defensive threshold if this text affects the spec. |
| 4 | 33333 | Weakened Soul Reduction | Reduces the duration of the Weakened Soul effect caused by your Power Word: Shield by $/1000;s1 sec. | Check as active set-bonus state; adjust priority, resource, cooldown, or defensive threshold if this text affects the spec. |

## Merciless Gladiator's Raiment (`ItemSetID=707`)

### Bonuses

| Pieces | Bonus spell ID | Bonus name | DB2 description | Rotation impact |
|---:|---:|---|---|---|
| 2 | 41462 | Increased Resilience 35 | +value1 Resilience Rating. | Check as active set-bonus state; adjust priority, resource, cooldown, or defensive threshold if this text affects the spec. |
| 4 | 33333 | Weakened Soul Reduction | Reduces the duration of the Weakened Soul effect caused by your Power Word: Shield by $/1000;s1 sec. | Check as active set-bonus state; adjust priority, resource, cooldown, or defensive threshold if this text affects the spec. |

## Vengeful Gladiator's Investiture (`ItemSetID=728`)

### Bonuses

| Pieces | Bonus spell ID | Bonus name | DB2 description | Rotation impact |
|---:|---:|---|---|---|
| 2 | 43478 | Increased Resilience 35 | +value1 Resilience Rating. | Check as active set-bonus state; adjust priority, resource, cooldown, or defensive threshold if this text affects the spec. |
| 4 | 33333 | Weakened Soul Reduction | Reduces the duration of the Weakened Soul effect caused by your Power Word: Shield by $/1000;s1 sec. | Check as active set-bonus state; adjust priority, resource, cooldown, or defensive threshold if this text affects the spec. |

## Vengeful Gladiator's Raiment (`ItemSetID=729`)

### Bonuses

| Pieces | Bonus spell ID | Bonus name | DB2 description | Rotation impact |
|---:|---:|---|---|---|
| 2 | 43480 | Increased Resilience 35 | +value1 Resilience Rating. | Check as active set-bonus state; adjust priority, resource, cooldown, or defensive threshold if this text affects the spec. |
| 4 | 33333 | Weakened Soul Reduction | Reduces the duration of the Weakened Soul effect caused by your Power Word: Shield by $/1000;s1 sec. | Check as active set-bonus state; adjust priority, resource, cooldown, or defensive threshold if this text affects the spec. |
