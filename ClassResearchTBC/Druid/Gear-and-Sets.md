# Druid Gear and Set Pieces

This file is DB2-assisted. It lists class-relevant item sets, item IDs, item names when present in `ItemSparse`, set-bonus spell IDs, and the rotation checks each set implies.

## Rotation-Impact Rules

- Treat 2p/4p bonuses as active state flags in rotation code only when they change a decision.
- Do not hard-code a set bonus unless it is detectable or configured; use menu toggles if runtime item-set detection is unavailable.
- Separate throughput sets from tank survivability sets and PvP resilience/control sets.
- Re-check weapon speed, proc, and resource thresholds after set changes.

## Gladiator's Sanctuary (`ItemSetID=584`)

### Pieces

| Item ID | Item name |
|---:|---|
| 28126 | Gladiator's Dragonhide Gloves |
| 28127 | Gladiator's Dragonhide Helm |
| 28128 | Gladiator's Dragonhide Legguards |
| 28129 | Gladiator's Dragonhide Spaulders |
| 28130 | Gladiator's Dragonhide Tunic |

### Bonuses

| Pieces | Bonus spell ID | Bonus name | DB2 description | Rotation impact |
|---:|---:|---|---|---|
| 2 | 32145 | Increased Resilience 35 | +value1 Resilience Rating. | Check as active set-bonus state; adjust priority, resource, cooldown, or defensive threshold if this text affects the spec. |
| 4 | 23218 | Feral Move Speed Increase | Increases your movement speed by value1% while in Bear Form, Cat Form, or Travel Form. Only active outdoors. | Check as active set-bonus state; adjust priority, resource, cooldown, or defensive threshold if this text affects the spec. |

## Gladiator's Wildhide (`ItemSetID=585`)

### Pieces

| Item ID | Item name |
|---:|---|
| 28136 | Gladiator's Wyrmhide Gloves |
| 28137 | Gladiator's Wyrmhide Helm |
| 28138 | Gladiator's Wyrmhide Legguards |
| 28139 | Gladiator's Wyrmhide Spaulders |
| 28140 | Gladiator's Wyrmhide Tunic |

### Bonuses

| Pieces | Bonus spell ID | Bonus name | DB2 description | Rotation impact |
|---:|---:|---|---|---|
| 2 | 40042 | Increased Resilience 35 | +value1 Resilience Rating. | Check as active set-bonus state; adjust priority, resource, cooldown, or defensive threshold if this text affects the spec. |
| 4 | 46832 | Moonkin Starfire Bonus | Your Wrath casts have a chance to reduce the cast time on your next Starfire by 1.5 sec. | Check as active set-bonus state; adjust priority, resource, cooldown, or defensive threshold if this text affects the spec. |

## Malorne Raiment (`ItemSetID=638`)

### Pieces

| Item ID | Item name |
|---:|---|
| 29087 | Chestguard of Malorne |
| 29086 | Crown of Malorne |
| 29090 | Handguards of Malorne |
| 29088 | Legguards of Malorne |
| 29089 | Shoulderguards of Malorne |

### Bonuses

| Pieces | Bonus spell ID | Bonus name | DB2 description | Rotation impact |
|---:|---:|---|---|---|
| 2 | 37288 | Mana Restore | Your helpful spells have a chance to restore up to 120 mana. | Check as active set-bonus state; adjust priority, resource, cooldown, or defensive threshold if this text affects the spec. |
| 4 | 37292 | Improved Nature's Swiftness | Reduces the cooldown on your Nature's Swiftness ability by misc1/-1000 sec. | Check as active set-bonus state; adjust priority, resource, cooldown, or defensive threshold if this text affects the spec. |

## Malorne Regalia (`ItemSetID=639`)

### Pieces

| Item ID | Item name |
|---:|---|
| 29093 | Antlers of Malorne |
| 29094 | Britches of Malorne |
| 29091 | Chestpiece of Malorne |
| 29092 | Gloves of Malorne |
| 29095 | Pauldrons of Malorne |

### Bonuses

| Pieces | Bonus spell ID | Bonus name | DB2 description | Rotation impact |
|---:|---:|---|---|---|
| 2 | 37295 | Mana Restore | Your harmful spells have a chance to restore up to 120 mana. | Check as active set-bonus state; adjust priority, resource, cooldown, or defensive threshold if this text affects the spec. |
| 4 | 37297 | Improved Innervate | Reduces the cooldown on your Innervate ability by misc1/-1000 sec. | Check as active set-bonus state; adjust priority, resource, cooldown, or defensive threshold if this text affects the spec. |

## Malorne Harness (`ItemSetID=640`)

### Pieces

| Item ID | Item name |
|---:|---|
| 29096 | Breastplate of Malorne |
| 29097 | Gauntlets of Malorne |
| 29099 | Greaves of Malorne |
| 29100 | Mantle of Malorne |
| 29098 | Stag-Helm of Malorne |

### Bonuses

| Pieces | Bonus spell ID | Bonus name | DB2 description | Rotation impact |
|---:|---:|---|---|---|
| 2 | 37306 | Bear Rage | Your melee attacks in Bear Form and Dire Bear Form have a chance to generate $37309m1/10 additional rage. | Check as active set-bonus state; adjust priority, resource, cooldown, or defensive threshold if this text affects the spec. |
| 2 | 37311 | Cat Energy | Your melee attacks in Cat Form have a chance to generate $37310s1 additional energy. | Check as active set-bonus state; adjust priority, resource, cooldown, or defensive threshold if this text affects the spec. |
| 4 | 37298 | Bear Armor | Increases your armor by value1 in Bear Form and Dire Bear Form. | Check as active set-bonus state; adjust priority, resource, cooldown, or defensive threshold if this text affects the spec. |
| 4 | 37299 | Cat Strength | Increases your strength by value1 in Cat Form. | Check as active set-bonus state; adjust priority, resource, cooldown, or defensive threshold if this text affects the spec. |

## Nordrassil Harness (`ItemSetID=641`)

### Pieces

| Item ID | Item name |
|---:|---|
| 30222 | Nordrassil Chestplate |
| 30223 | Nordrassil Handgrips |
| 30228 | Nordrassil Headdress |
| 30229 | Nordrassil Feral-Kilt |
| 30230 | Nordrassil Feral-Mantle |

### Bonuses

| Pieces | Bonus spell ID | Bonus name | DB2 description | Rotation impact |
|---:|---:|---|---|---|
| 2 | 37315 | Feral Regrowth Bonus | When you shift out of Bear Form, Dire Bear Form, or Cat Form, your next Regrowth spell takes $37316m1/-1000.1 fewer sec. to cast. | Check as active set-bonus state; adjust priority, resource, cooldown, or defensive threshold if this text affects the spec. |
| 4 | 37333 | Increased Shred and Lacerate | Your Shred ability deals an additional 75 damage, and your Lacerate ability does an additional 15 per application. | Check as active set-bonus state; adjust priority, resource, cooldown, or defensive threshold if this text affects the spec. |

## Nordrassil Raiment (`ItemSetID=642`)

### Pieces

| Item ID | Item name |
|---:|---|
| 30216 | Nordrassil Chestguard |
| 30217 | Nordrassil Gloves |
| 30219 | Nordrassil Headguard |
| 30220 | Nordrassil Life-Kilt |
| 30221 | Nordrassil Life-Mantle |

### Bonuses

| Pieces | Bonus spell ID | Bonus name | DB2 description | Rotation impact |
|---:|---:|---|---|---|
| 2 | 37313 | Regrowth Bonus | Increases the duration of your Regrowth spell by misc1/1000 sec. | Check as active set-bonus state; adjust priority, resource, cooldown, or defensive threshold if this text affects the spec. |
| 4 | 37314 | Lifebloom Bonus | Increases the final amount healed by your Lifebloom spell by value1. | Check as active set-bonus state; adjust priority, resource, cooldown, or defensive threshold if this text affects the spec. |

## Nordrassil Regalia (`ItemSetID=643`)

### Pieces

| Item ID | Item name |
|---:|---|
| 30231 | Nordrassil Chestpiece |
| 30232 | Nordrassil Gauntlets |
| 30233 | Nordrassil Headpiece |
| 30234 | Nordrassil Wrath-Kilt |
| 30235 | Nordrassil Wrath-Mantle |

### Bonuses

| Pieces | Bonus spell ID | Bonus name | DB2 description | Rotation impact |
|---:|---:|---|---|---|
| 2 | 37324 | Moonkin Regrowth Bonus | When you shift out of Moonkin Form, your next Regrowth spell costs $37325s1 less mana. | Check as active set-bonus state; adjust priority, resource, cooldown, or defensive threshold if this text affects the spec. |
| 4 | 37327 | Starfire Bonus | Increases your Starfire damage against targets afflicted with Moonfire or Insect Swarm by value1%. | Check as active set-bonus state; adjust priority, resource, cooldown, or defensive threshold if this text affects the spec. |

## Thunderheart Harness (`ItemSetID=676`)

### Pieces

| Item ID | Item name |
|---:|---|
| 31042 | Thunderheart Chestguard |
| 31034 | Thunderheart Gauntlets |
| 31039 | Thunderheart Cover |
| 31044 | Thunderheart Leggings |
| 31048 | Thunderheart Pauldrons |
| 34556 | Thunderheart Waistguard |
| 34444 | Thunderheart Wristguards |
| 34573 | Thunderheart Treads |

### Bonuses

| Pieces | Bonus spell ID | Bonus name | DB2 description | Rotation impact |
|---:|---:|---|---|---|
| 2 | 38447 | Improved Mangle | Reduces the energy cost of your Mangle ability in Cat Form by value1 and increases the threat generated by your Mangle ability in Bear Form by $s2%. | Check as active set-bonus state; adjust priority, resource, cooldown, or defensive threshold if this text affects the spec. |
| 4 | 38416 | Improved Rip and Ferocious Bite | Increases the damage dealt by your Rip, Swipe, and Ferocious Bite abilities by value1%. | Check as active set-bonus state; adjust priority, resource, cooldown, or defensive threshold if this text affects the spec. |

## Thunderheart Regalia (`ItemSetID=677`)

### Pieces

| Item ID | Item name |
|---:|---|
| 31043 | Thunderheart Vest |
| 31035 | Thunderheart Handguards |
| 31040 | Thunderheart Headguard |
| 31046 | Thunderheart Pants |
| 31049 | Thunderheart Shoulderpads |
| 34572 | Thunderheart Footwraps |
| 34446 | Thunderheart Bands |
| 34555 | Thunderheart Cord |

### Bonuses

| Pieces | Bonus spell ID | Bonus name | DB2 description | Rotation impact |
|---:|---:|---|---|---|
| 2 | 38414 | Increased Moonfire Duration | Increases the duration of your Moonfire ability by misc1/1000 sec. | Check as active set-bonus state; adjust priority, resource, cooldown, or defensive threshold if this text affects the spec. |
| 4 | 38415 | Starfire Crit | Increases the critical strike chance of your Starfire ability by value1%. | Check as active set-bonus state; adjust priority, resource, cooldown, or defensive threshold if this text affects the spec. |

## Thunderheart Raiment (`ItemSetID=678`)

### Pieces

| Item ID | Item name |
|---:|---|
| 31041 | Thunderheart Tunic |
| 31032 | Thunderheart Gloves |
| 31037 | Thunderheart Helmet |
| 31045 | Thunderheart Legguards |
| 31047 | Thunderheart Spaulders |
| 34571 | Thunderheart Boots |
| 34445 | Thunderheart Bracers |
| 34554 | Thunderheart Belt |

### Bonuses

| Pieces | Bonus spell ID | Bonus name | DB2 description | Rotation impact |
|---:|---:|---|---|---|
| 2 | 38417 | Reduced Swiftmend Cooldown | Reduces the cooldown of your Swiftmend ability by misc1/-1000 sec. | Check as active set-bonus state; adjust priority, resource, cooldown, or defensive threshold if this text affects the spec. |
| 4 | 38420 | Improved Healing Touch | Increases the healing from your Healing Touch ability by value1%. | Check as active set-bonus state; adjust priority, resource, cooldown, or defensive threshold if this text affects the spec. |

## Gladiator's Refuge (`ItemSetID=685`)

### Pieces

| Item ID | Item name |
|---:|---|
| 31375 | Gladiator's Kodohide Gloves |
| 31376 | Gladiator's Kodohide Helm |
| 31377 | Gladiator's Kodohide Legguards |
| 31378 | Gladiator's Kodohide Spaulders |
| 31379 | Gladiator's Kodohide Tunic |

### Bonuses

| Pieces | Bonus spell ID | Bonus name | DB2 description | Rotation impact |
|---:|---:|---|---|---|
| 2 | 40043 | Increased Resilience 35 | +value1 Resilience Rating. | Check as active set-bonus state; adjust priority, resource, cooldown, or defensive threshold if this text affects the spec. |
| 4 | 46834 | Restoration Regrowth Bonus | The casting time on your Regrowth spell is reduced by misc1/-1000.2 sec. The casting time on your Regrowth spell is reduced by misc1/-1000.2 sec. | Check as active set-bonus state; adjust priority, resource, cooldown, or defensive threshold if this text affects the spec. |

## Merciless Gladiator's Refuge (`ItemSetID=709`)

### Bonuses

| Pieces | Bonus spell ID | Bonus name | DB2 description | Rotation impact |
|---:|---:|---|---|---|
| 2 | 41463 | Increased Resilience 35 | +value1 Resilience Rating. | Check as active set-bonus state; adjust priority, resource, cooldown, or defensive threshold if this text affects the spec. |
| 4 | 23218 | Feral Move Speed Increase | Increases your movement speed by value1% while in Bear Form, Cat Form, or Travel Form. Only active outdoors. | Check as active set-bonus state; adjust priority, resource, cooldown, or defensive threshold if this text affects the spec. |

## Merciless Gladiator's Sanctuary (`ItemSetID=711`)

### Bonuses

| Pieces | Bonus spell ID | Bonus name | DB2 description | Rotation impact |
|---:|---:|---|---|---|
| 2 | 41464 | Increased Resilience 35 | +value1 Resilience Rating. | Check as active set-bonus state; adjust priority, resource, cooldown, or defensive threshold if this text affects the spec. |
| 4 | 23218 | Feral Move Speed Increase | Increases your movement speed by value1% while in Bear Form, Cat Form, or Travel Form. Only active outdoors. | Check as active set-bonus state; adjust priority, resource, cooldown, or defensive threshold if this text affects the spec. |

## Merciless Gladiator's Wildhide (`ItemSetID=716`)

### Bonuses

| Pieces | Bonus spell ID | Bonus name | DB2 description | Rotation impact |
|---:|---:|---|---|---|
| 2 | 41462 | Increased Resilience 35 | +value1 Resilience Rating. | Check as active set-bonus state; adjust priority, resource, cooldown, or defensive threshold if this text affects the spec. |
| 4 | 44293 | Improved Entangling Roots | Reduces the casting time of your Entangling Roots ability by misc1/-1000.2 sec. | Check as active set-bonus state; adjust priority, resource, cooldown, or defensive threshold if this text affects the spec. |

## Vengeful Gladiator's Refuge (`ItemSetID=720`)

### Bonuses

| Pieces | Bonus spell ID | Bonus name | DB2 description | Rotation impact |
|---:|---:|---|---|---|
| 2 | 43478 | Increased Resilience 35 | +value1 Resilience Rating. | Check as active set-bonus state; adjust priority, resource, cooldown, or defensive threshold if this text affects the spec. |
| 4 | 23218 | Feral Move Speed Increase | Increases your movement speed by value1% while in Bear Form, Cat Form, or Travel Form. Only active outdoors. | Check as active set-bonus state; adjust priority, resource, cooldown, or defensive threshold if this text affects the spec. |

## Vengeful Gladiator's Sanctuary (`ItemSetID=721`)

### Bonuses

| Pieces | Bonus spell ID | Bonus name | DB2 description | Rotation impact |
|---:|---:|---|---|---|
| 2 | 43479 | Increased Resilience 35 | +value1 Resilience Rating. | Check as active set-bonus state; adjust priority, resource, cooldown, or defensive threshold if this text affects the spec. |
| 4 | 23218 | Feral Move Speed Increase | Increases your movement speed by value1% while in Bear Form, Cat Form, or Travel Form. Only active outdoors. | Check as active set-bonus state; adjust priority, resource, cooldown, or defensive threshold if this text affects the spec. |

## Vengeful Gladiator's Wildhide (`ItemSetID=722`)

### Bonuses

| Pieces | Bonus spell ID | Bonus name | DB2 description | Rotation impact |
|---:|---:|---|---|---|
| 2 | 43480 | Increased Resilience 35 | +value1 Resilience Rating. | Check as active set-bonus state; adjust priority, resource, cooldown, or defensive threshold if this text affects the spec. |
| 4 | 44293 | Improved Entangling Roots | Reduces the casting time of your Entangling Roots ability by misc1/-1000.2 sec. | Check as active set-bonus state; adjust priority, resource, cooldown, or defensive threshold if this text affects the spec. |
