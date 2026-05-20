# Rogue Gear and Set Pieces

This file is DB2-assisted. It lists class-relevant item sets, item IDs, item names when present in `ItemSparse`, set-bonus spell IDs, and the rotation checks each set implies.

## Rotation-Impact Rules

- Treat 2p/4p bonuses as active state flags in rotation code only when they change a decision.
- Do not hard-code a set bonus unless it is detectable or configured; use menu toggles if runtime item-set detection is unavailable.
- Separate throughput sets from tank survivability sets and PvP resilience/control sets.
- Re-check weapon speed, proc, and resource thresholds after set changes.

## Nightslayer Armor (`ItemSetID=204`)

### Pieces

| Item ID | Item name |
|---:|---|
| 16827 | Nightslayer Belt |
| 16824 | Nightslayer Boots |
| 16825 | Nightslayer Bracelets |
| 16820 | Nightslayer Chestpiece |
| 16821 | Nightslayer Cover |
| 16826 | Nightslayer Gloves |
| 16822 | Nightslayer Pants |
| 16823 | Nightslayer Shoulder Pads |

### Bonuses

| Pieces | Bonus spell ID | Bonus name | DB2 description | Rotation impact |
|---:|---:|---|---|---|
| 3 | 21874 | Improved Vanish | Reduces the cooldown of your Vanish ability by $/1000;s1 sec. | Check as active set-bonus state; adjust priority, resource, cooldown, or defensive threshold if this text affects the spec. |
| 5 | 21975 | Vigor | Increases your maximum Energy by value1. | Check as active set-bonus state; adjust priority, resource, cooldown, or defensive threshold if this text affects the spec. |
| 8 | 23582 | Clean Escape | Heals the rogue for $23583s1 when Vanish is performed. | Check as active set-bonus state; adjust priority, resource, cooldown, or defensive threshold if this text affects the spec. |

## Undead Slayer's Armor (`ItemSetID=534`)

### Pieces

| Item ID | Item name |
|---:|---|
| 23081 | Handwraps of Undead Slaying |
| 23089 | Tunic of Undead Slaying |
| 23093 | Wristwraps of Undead Slaying |

### Bonuses

| Pieces | Bonus spell ID | Bonus name | DB2 description | Rotation impact |
|---:|---:|---|---|---|
| 3 | 29068 | Increased Damage 2 | Increases your damage against undead by value1%. | Check as active set-bonus state; adjust priority, resource, cooldown, or defensive threshold if this text affects the spec. |

## Garb of the Undead Slayer (`ItemSetID=535`)

### Pieces

| Item ID | Item name |
|---:|---|
| 23088 | Chestguard of Undead Slaying |
| 23082 | Handguards of Undead Slaying |
| 23092 | Wristguards of Undead Slaying |

### Bonuses

| Pieces | Bonus spell ID | Bonus name | DB2 description | Rotation impact |
|---:|---:|---|---|---|
| 3 | 29068 | Increased Damage 2 | Increases your damage against undead by value1%. | Check as active set-bonus state; adjust priority, resource, cooldown, or defensive threshold if this text affects the spec. |

## Gladiator's Vestments (`ItemSetID=577`)

### Pieces

| Item ID | Item name |
|---:|---|
| 25834 | Gladiator's Leather Gloves |
| 25833 | Gladiator's Leather Legguards |
| 25830 | Gladiator's Leather Helm |
| 25832 | Gladiator's Leather Spaulders |
| 25831 | Gladiator's Leather Tunic |

### Bonuses

| Pieces | Bonus spell ID | Bonus name | DB2 description | Rotation impact |
|---:|---:|---|---|---|
| 2 | 32145 | Increased Resilience 35 | +value1 Resilience Rating. | Check as active set-bonus state; adjust priority, resource, cooldown, or defensive threshold if this text affects the spec. |
| 4 | 21975 | Vigor | Increases your maximum Energy by value1. | Check as active set-bonus state; adjust priority, resource, cooldown, or defensive threshold if this text affects the spec. |

## Netherblade (`ItemSetID=621`)

### Pieces

| Item ID | Item name |
|---:|---|
| 29046 | Netherblade Breeches |
| 29045 | Netherblade Chestpiece |
| 29044 | Netherblade Facemask |
| 29048 | Netherblade Gloves |
| 29047 | Netherblade Shoulderpads |

### Bonuses

| Pieces | Bonus spell ID | Bonus name | DB2 description | Rotation impact |
|---:|---:|---|---|---|
| 2 | 37167 | Increased Slice and Dice Duration | Increases the duration of your Slice and Dice ability by misc1/1000 sec. | Check as active set-bonus state; adjust priority, resource, cooldown, or defensive threshold if this text affects the spec. |
| 4 | 37168 | Finisher Combo | Your finishing moves have a $h% chance to grant you a combo point. | Check as active set-bonus state; adjust priority, resource, cooldown, or defensive threshold if this text affects the spec. |

## Deathmantle (`ItemSetID=622`)

### Pieces

| Item ID | Item name |
|---:|---|
| 30144 | Deathmantle Chestguard |
| 30145 | Deathmantle Handguards |
| 30146 | Deathmantle Helm |
| 30148 | Deathmantle Legguards |
| 30149 | Deathmantle Shoulderpads |

### Bonuses

| Pieces | Bonus spell ID | Bonus name | DB2 description | Rotation impact |
|---:|---:|---|---|---|
| 2 | 37169 | Eviscerate and Envenom Bonus Damage | Your Eviscerate and Envenom abilities cause value1 extra damage per combo point. | Check as active set-bonus state; adjust priority, resource, cooldown, or defensive threshold if this text affects the spec. |
| 4 | 37170 | Free Finisher Chance | Your attacks have a chance to make your next finishing move cost no energy. | Check as active set-bonus state; adjust priority, resource, cooldown, or defensive threshold if this text affects the spec. |

## Slayer's Armor (`ItemSetID=668`)

### Pieces

| Item ID | Item name |
|---:|---|
| 31028 | Slayer's Chestguard |
| 31026 | Slayer's Handguards |
| 31027 | Slayer's Helm |
| 31029 | Slayer's Legguards |
| 31030 | Slayer's Shoulderpads |
| 34575 | Slayer's Boots |
| 34448 | Slayer's Bracers |
| 34558 | Slayer's Belt |

### Bonuses

| Pieces | Bonus spell ID | Bonus name | DB2 description | Rotation impact |
|---:|---:|---|---|---|
| 2 | 38388 | Increased Slice and Dice Haste | Increases the haste from your Slice and Dice ability by value1%. | Check as active set-bonus state; adjust priority, resource, cooldown, or defensive threshold if this text affects the spec. |
| 4 | 38389 | Improved Backstab and Sinister Strike | Increases the damage dealt by your Backstab, Sinister Strike, Mutilate, and Hemorrhage abilities by value1%. | Check as active set-bonus state; adjust priority, resource, cooldown, or defensive threshold if this text affects the spec. |

## Merciless Gladiator's Vestments (`ItemSetID=713`)

### Bonuses

| Pieces | Bonus spell ID | Bonus name | DB2 description | Rotation impact |
|---:|---:|---|---|---|
| 2 | 41464 | Increased Resilience 35 | +value1 Resilience Rating. | Check as active set-bonus state; adjust priority, resource, cooldown, or defensive threshold if this text affects the spec. |
| 4 | 21975 | Vigor | Increases your maximum Energy by value1. | Check as active set-bonus state; adjust priority, resource, cooldown, or defensive threshold if this text affects the spec. |

## Vengeful Gladiator's Vestments (`ItemSetID=730`)

### Bonuses

| Pieces | Bonus spell ID | Bonus name | DB2 description | Rotation impact |
|---:|---:|---|---|---|
| 2 | 43479 | Increased Resilience 35 | +value1 Resilience Rating. | Check as active set-bonus state; adjust priority, resource, cooldown, or defensive threshold if this text affects the spec. |
| 4 | 21975 | Vigor | Increases your maximum Energy by value1. | Check as active set-bonus state; adjust priority, resource, cooldown, or defensive threshold if this text affects the spec. |
