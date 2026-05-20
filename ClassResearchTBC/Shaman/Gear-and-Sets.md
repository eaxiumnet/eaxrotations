# Shaman Gear and Set Pieces

This file is DB2-assisted. It lists class-relevant item sets, item IDs, item names when present in `ItemSparse`, set-bonus spell IDs, and the rotation checks each set implies.

## Rotation-Impact Rules

- Treat 2p/4p bonuses as active state flags in rotation code only when they change a decision.
- Do not hard-code a set bonus unless it is detectable or configured; use menu toggles if runtime item-set detection is unavailable.
- Separate throughput sets from tank survivability sets and PvP resilience/control sets.
- Re-check weapon speed, proc, and resource thresholds after set changes.

## Gladiator's Earthshaker (`ItemSetID=578`)

### Pieces

| Item ID | Item name |
|---:|---|
| 25997 | Gladiator's Linked Armor |
| 26000 | Gladiator's Linked Gauntlets |
| 25998 | Gladiator's Linked Helm |
| 26001 | Gladiator's Linked Leggings |
| 25999 | Gladiator's Linked Spaulders |

### Bonuses

| Pieces | Bonus spell ID | Bonus name | DB2 description | Rotation impact |
|---:|---:|---|---|---|
| 2 | 32145 | Increased Resilience 35 | +value1 Resilience Rating. | Check as active set-bonus state; adjust priority, resource, cooldown, or defensive threshold if this text affects the spec. |
| 4 | 33018 | Shaman Stormstrike Cooldown Reduction | Reduces the cooldown of your Stormstrike ability by $/1000;s1 sec. | Check as active set-bonus state; adjust priority, resource, cooldown, or defensive threshold if this text affects the spec. |

## Gladiator's Thunderfist (`ItemSetID=580`)

### Pieces

| Item ID | Item name |
|---:|---|
| 27469 | Gladiator's Mail Armor |
| 27470 | Gladiator's Mail Gauntlets |
| 27471 | Gladiator's Mail Helm |
| 27472 | Gladiator's Mail Leggings |
| 27473 | Gladiator's Mail Spaulders |

### Bonuses

| Pieces | Bonus spell ID | Bonus name | DB2 description | Rotation impact |
|---:|---:|---|---|---|
| 2 | 40042 | Increased Resilience 35 | +value1 Resilience Rating. | Check as active set-bonus state; adjust priority, resource, cooldown, or defensive threshold if this text affects the spec. |
| 4 | 44296 | Improved Lightning Bolt | Gives you a value1% chance to avoid interruption caused by damage while casting Lightning Bolt. | Check as active set-bonus state; adjust priority, resource, cooldown, or defensive threshold if this text affects the spec. |

## Cyclone Raiment (`ItemSetID=631`)

### Pieces

| Item ID | Item name |
|---:|---|
| 29032 | Cyclone Gloves |
| 29029 | Cyclone Hauberk |
| 29028 | Cyclone Headdress |
| 29030 | Cyclone Kilt |
| 29031 | Cyclone Shoulderpads |

### Bonuses

| Pieces | Bonus spell ID | Bonus name | DB2 description | Rotation impact |
|---:|---:|---|---|---|
| 2 | 37210 | Improved Mana Spring Totem | Your Mana Spring Totem ability grants an additional value1 mana every 2 sec. | Check as active set-bonus state; adjust priority, resource, cooldown, or defensive threshold if this text affects the spec. |
| 4 | 37211 | Improved Nature's Swiftness | Reduces the cooldown on your Nature's Swiftness ability by misc1/-1000 sec. | Check as active set-bonus state; adjust priority, resource, cooldown, or defensive threshold if this text affects the spec. |

## Cyclone Regalia (`ItemSetID=632`)

### Pieces

| Item ID | Item name |
|---:|---|
| 29033 | Cyclone Chestguard |
| 29035 | Cyclone Faceguard |
| 29034 | Cyclone Handguards |
| 29036 | Cyclone Legguards |
| 29037 | Cyclone Shoulderguards |

### Bonuses

| Pieces | Bonus spell ID | Bonus name | DB2 description | Rotation impact |
|---:|---:|---|---|---|
| 2 | 37212 | Improved Wrath of Air Totem | Your Wrath of Air Totem ability grants an additional value1 spell damage. | Check as active set-bonus state; adjust priority, resource, cooldown, or defensive threshold if this text affects the spec. |
| 4 | 37213 | Mana Cost Reduction | Your offensive spell critical strikes have a chance to reduce the base mana cost of your next spell by $37214s1. | Check as active set-bonus state; adjust priority, resource, cooldown, or defensive threshold if this text affects the spec. |

## Cyclone Harness (`ItemSetID=633`)

### Pieces

| Item ID | Item name |
|---:|---|
| 29038 | Cyclone Breastplate |
| 29039 | Cyclone Gauntlets |
| 29040 | Cyclone Helm |
| 29043 | Cyclone Shoulderplates |
| 29042 | Cyclone War-Kilt |

### Bonuses

| Pieces | Bonus spell ID | Bonus name | DB2 description | Rotation impact |
|---:|---:|---|---|---|
| 2 | 37223 | Improved Strength of Earth | Your Strength of Earth Totem ability grants an additional value1 strength. | Check as active set-bonus state; adjust priority, resource, cooldown, or defensive threshold if this text affects the spec. |
| 4 | 37224 | Improved Storm Strike | Your Stormstrike ability does an additional value1 damage per weapon. | Check as active set-bonus state; adjust priority, resource, cooldown, or defensive threshold if this text affects the spec. |

## Cataclysm Raiment (`ItemSetID=634`)

### Pieces

| Item ID | Item name |
|---:|---|
| 30164 | Cataclysm Chestguard |
| 30165 | Cataclysm Gloves |
| 30166 | Cataclysm Headguard |
| 30167 | Cataclysm Legguards |
| 30168 | Cataclysm Shoulderguards |

### Bonuses

| Pieces | Bonus spell ID | Bonus name | DB2 description | Rotation impact |
|---:|---:|---|---|---|
| 2 | 37225 | Improved Lesser Healing Wave | Reduces the cost of your Lesser Healing Wave spell by value1%. | Check as active set-bonus state; adjust priority, resource, cooldown, or defensive threshold if this text affects the spec. |
| 4 | 37227 | Improved Healing Wave | Your critical heals from Healing Wave, Lesser Healing Wave, and Chain Heal reduce the cast time of your next Healing Wave spell by $39950m1/-1000.2 sec for $39950d. This effect cannot occur more than once per minute. | Check as active set-bonus state; adjust priority, resource, cooldown, or defensive threshold if this text affects the spec. |

## Cataclysm Regalia (`ItemSetID=635`)

### Pieces

| Item ID | Item name |
|---:|---|
| 30169 | Cataclysm Chestpiece |
| 30170 | Cataclysm Handgrips |
| 30171 | Cataclysm Headpiece |
| 30172 | Cataclysm Leggings |
| 30173 | Cataclysm Shoulderpads |

### Bonuses

| Pieces | Bonus spell ID | Bonus name | DB2 description | Rotation impact |
|---:|---:|---|---|---|
| 2 | 37228 | Lesser Healing Wave Discount | Each time you cast an offensive spell, there is a chance your next Lesser Healing Wave will cost $37234s1 less mana. | Check as active set-bonus state; adjust priority, resource, cooldown, or defensive threshold if this text affects the spec. |
| 4 | 37237 | Lightning Bolt Discount | Your Lightning Bolt critical strikes have a chance to grant you $37238s1 mana. | Check as active set-bonus state; adjust priority, resource, cooldown, or defensive threshold if this text affects the spec. |

## Cataclysm Harness (`ItemSetID=636`)

### Pieces

| Item ID | Item name |
|---:|---|
| 30185 | Cataclysm Chestplate |
| 30189 | Cataclysm Gauntlets |
| 30190 | Cataclysm Helm |
| 30192 | Cataclysm Legplates |
| 30194 | Cataclysm Shoulderplates |

### Bonuses

| Pieces | Bonus spell ID | Bonus name | DB2 description | Rotation impact |
|---:|---:|---|---|---|
| 2 | 37239 | Fast Lesser Healing Wave | Your melee attacks have a chance to reduce the cast time of your next Lesser Healing Wave by $37240m1/-1000.1 sec. | Check as active set-bonus state; adjust priority, resource, cooldown, or defensive threshold if this text affects the spec. |
| 4 | 37241 | Improved Flurry | You gain value1% additional haste from your Flurry ability. | Check as active set-bonus state; adjust priority, resource, cooldown, or defensive threshold if this text affects the spec. |

## Skyshatter Harness (`ItemSetID=682`)

### Pieces

| Item ID | Item name |
|---:|---|
| 31018 | Skyshatter Tunic |
| 31011 | Skyshatter Grips |
| 31015 | Skyshatter Cover |
| 31021 | Skyshatter Pants |
| 31024 | Skyshatter Pauldrons |
| 34567 | Skyshatter Greaves |
| 34439 | Skyshatter Wristguards |
| 34545 | Skyshatter Girdle |

### Bonuses

| Pieces | Bonus spell ID | Bonus name | DB2 description | Rotation impact |
|---:|---:|---|---|---|
| 2 | 38429 | Shock Discount | Your Earth Shock, Flame Shock, and Frost Shock abilities cost value1% less mana. | Check as active set-bonus state; adjust priority, resource, cooldown, or defensive threshold if this text affects the spec. |
| 4 | 38432 | Stormstrike AP Buff | Whenever you use Stormstrike, you gain $38430s1 attack power for $38430d. | Check as active set-bonus state; adjust priority, resource, cooldown, or defensive threshold if this text affects the spec. |

## Skyshatter Raiment (`ItemSetID=683`)

### Pieces

| Item ID | Item name |
|---:|---|
| 31016 | Skyshatter Chestguard |
| 31007 | Skyshatter Gloves |
| 31012 | Skyshatter Helmet |
| 31019 | Skyshatter Leggings |
| 31022 | Skyshatter Shoulderpads |
| 34543 | Skyshatter Belt |
| 34438 | Skyshatter Bracers |
| 34565 | Skyshatter Boots |

### Bonuses

| Pieces | Bonus spell ID | Bonus name | DB2 description | Rotation impact |
|---:|---:|---|---|---|
| 2 | 38434 | Chain Heal Discount | Your Chain Heal ability costs value1% less mana. | Check as active set-bonus state; adjust priority, resource, cooldown, or defensive threshold if this text affects the spec. |
| 4 | 38435 | Improved Chain Heal | Increases the amount healed by your Chain Heal ability by value1%. | Check as active set-bonus state; adjust priority, resource, cooldown, or defensive threshold if this text affects the spec. |

## Skyshatter Regalia (`ItemSetID=684`)

### Pieces

| Item ID | Item name |
|---:|---|
| 31017 | Skyshatter Breastplate |
| 31008 | Skyshatter Gauntlets |
| 31014 | Skyshatter Headguard |
| 31020 | Skyshatter Legguards |
| 31023 | Skyshatter Mantle |
| 34542 | Skyshatter Cord |
| 34437 | Skyshatter Bands |
| 34566 | Skyshatter Treads |

### Bonuses

| Pieces | Bonus spell ID | Bonus name | DB2 description | Rotation impact |
|---:|---:|---|---|---|
| 2 | 38443 | Totemic Mastery | Whenever you have an air totem, an earth totem, a fire totem, and a water totem active at the same time, you gain $38437s1 mana per 5 sec, $38437s2 spell critical strike rating, and up to $38437s3 spell damage. | Check as active set-bonus state; adjust priority, resource, cooldown, or defensive threshold if this text affects the spec. |
| 4 | 38436 | Improved Lightning Bolt | Increases the damage dealt by your Lightning Bolt ability by value1%. | Check as active set-bonus state; adjust priority, resource, cooldown, or defensive threshold if this text affects the spec. |

## Gladiator's Wartide (`ItemSetID=686`)

### Pieces

| Item ID | Item name |
|---:|---|
| 31396 | Gladiator's Ringmail Armor |
| 31397 | Gladiator's Ringmail Gauntlets |
| 31400 | Gladiator's Ringmail Helm |
| 31406 | Gladiator's Ringmail Leggings |
| 31407 | Gladiator's Ringmail Spaulders |

### Bonuses

| Pieces | Bonus spell ID | Bonus name | DB2 description | Rotation impact |
|---:|---:|---|---|---|
| 2 | 40043 | Increased Resilience 35 | +value1 Resilience Rating. | Check as active set-bonus state; adjust priority, resource, cooldown, or defensive threshold if this text affects the spec. |
| 4 | 44299 | Improved Grounding Totem | Reduces the cooldown of your Grounding Totem ability by misc1/-1000.1 sec. | Check as active set-bonus state; adjust priority, resource, cooldown, or defensive threshold if this text affects the spec. |

## Merciless Gladiator's Earthshaker (`ItemSetID=703`)

### Bonuses

| Pieces | Bonus spell ID | Bonus name | DB2 description | Rotation impact |
|---:|---:|---|---|---|
| 2 | 41464 | Increased Resilience 35 | +value1 Resilience Rating. | Check as active set-bonus state; adjust priority, resource, cooldown, or defensive threshold if this text affects the spec. |
| 4 | 33018 | Shaman Stormstrike Cooldown Reduction | Reduces the cooldown of your Stormstrike ability by $/1000;s1 sec. | Check as active set-bonus state; adjust priority, resource, cooldown, or defensive threshold if this text affects the spec. |

## Merciless Gladiator's Thunderfist (`ItemSetID=712`)

### Bonuses

| Pieces | Bonus spell ID | Bonus name | DB2 description | Rotation impact |
|---:|---:|---|---|---|
| 2 | 41462 | Increased Resilience 35 | +value1 Resilience Rating. | Check as active set-bonus state; adjust priority, resource, cooldown, or defensive threshold if this text affects the spec. |
| 4 | 44296 | Improved Lightning Bolt | Gives you a value1% chance to avoid interruption caused by damage while casting Lightning Bolt. | Check as active set-bonus state; adjust priority, resource, cooldown, or defensive threshold if this text affects the spec. |

## Merciless Gladiator's Wartide (`ItemSetID=715`)

### Bonuses

| Pieces | Bonus spell ID | Bonus name | DB2 description | Rotation impact |
|---:|---:|---|---|---|
| 2 | 41463 | Increased Resilience 35 | +value1 Resilience Rating. | Check as active set-bonus state; adjust priority, resource, cooldown, or defensive threshold if this text affects the spec. |
| 4 | 44299 | Improved Grounding Totem | Reduces the cooldown of your Grounding Totem ability by misc1/-1000.1 sec. | Check as active set-bonus state; adjust priority, resource, cooldown, or defensive threshold if this text affects the spec. |

## Vengeful Gladiator's Wartide (`ItemSetID=731`)

### Bonuses

| Pieces | Bonus spell ID | Bonus name | DB2 description | Rotation impact |
|---:|---:|---|---|---|
| 2 | 43478 | Increased Resilience 35 | +value1 Resilience Rating. | Check as active set-bonus state; adjust priority, resource, cooldown, or defensive threshold if this text affects the spec. |
| 4 | 44299 | Improved Grounding Totem | Reduces the cooldown of your Grounding Totem ability by misc1/-1000.1 sec. | Check as active set-bonus state; adjust priority, resource, cooldown, or defensive threshold if this text affects the spec. |

## Vengeful Gladiator's Earthshaker (`ItemSetID=732`)

### Bonuses

| Pieces | Bonus spell ID | Bonus name | DB2 description | Rotation impact |
|---:|---:|---|---|---|
| 2 | 43479 | Increased Resilience 35 | +value1 Resilience Rating. | Check as active set-bonus state; adjust priority, resource, cooldown, or defensive threshold if this text affects the spec. |
| 4 | 33018 | Shaman Stormstrike Cooldown Reduction | Reduces the cooldown of your Stormstrike ability by $/1000;s1 sec. | Check as active set-bonus state; adjust priority, resource, cooldown, or defensive threshold if this text affects the spec. |

## Vengeful Gladiator's Thunderfist (`ItemSetID=733`)

### Bonuses

| Pieces | Bonus spell ID | Bonus name | DB2 description | Rotation impact |
|---:|---:|---|---|---|
| 2 | 43480 | Increased Resilience 35 | +value1 Resilience Rating. | Check as active set-bonus state; adjust priority, resource, cooldown, or defensive threshold if this text affects the spec. |
| 4 | 44296 | Improved Lightning Bolt | Gives you a value1% chance to avoid interruption caused by damage while casting Lightning Bolt. | Check as active set-bonus state; adjust priority, resource, cooldown, or defensive threshold if this text affects the spec. |
