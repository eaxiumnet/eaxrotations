# Paladin Gear and Set Pieces

This file is DB2-assisted. It lists class-relevant item sets, item IDs, item names when present in `ItemSparse`, set-bonus spell IDs, and the rotation checks each set implies.

## Rotation-Impact Rules

- Treat 2p/4p bonuses as active state flags in rotation code only when they change a decision.
- Do not hard-code a set bonus unless it is detectable or configured; use menu toggles if runtime item-set detection is unavailable.
- Separate throughput sets from tank survivability sets and PvP resilience/control sets.
- Re-check weapon speed, proc, and resource thresholds after set changes.

## Gladiator's Aegis (`ItemSetID=582`)

### Pieces

| Item ID | Item name |
|---:|---|
| 27702 | Gladiator's Lamellar Chestpiece |
| 27703 | Gladiator's Lamellar Gauntlets |
| 27704 | Gladiator's Lamellar Helm |
| 27705 | Gladiator's Lamellar Legguards |
| 27706 | Gladiator's Lamellar Shoulders |

### Bonuses

| Pieces | Bonus spell ID | Bonus name | DB2 description | Rotation impact |
|---:|---:|---|---|---|
| 2 | 40044 | Increased Resilience 35 | +value1 Resilience Rating. | Check as active set-bonus state; adjust priority, resource, cooldown, or defensive threshold if this text affects the spec. |
| 4 | 23302 | Hammer of Justice Cooldown Reduction | Reduces the cooldown of your Hammer of Justice by $/1000;s1 sec. | Check as active set-bonus state; adjust priority, resource, cooldown, or defensive threshold if this text affects the spec. |

## Gladiator's Vindication (`ItemSetID=583`)

### Pieces

| Item ID | Item name |
|---:|---|
| 27879 | Gladiator's Scaled Chestpiece |
| 27880 | Gladiator's Scaled Gauntlets |
| 27881 | Gladiator's Scaled Helm |
| 27882 | Gladiator's Scaled Legguards |
| 27883 | Gladiator's Scaled Shoulders |

### Bonuses

| Pieces | Bonus spell ID | Bonus name | DB2 description | Rotation impact |
|---:|---:|---|---|---|
| 2 | 32145 | Increased Resilience 35 | +value1 Resilience Rating. | Check as active set-bonus state; adjust priority, resource, cooldown, or defensive threshold if this text affects the spec. |
| 4 | 23302 | Hammer of Justice Cooldown Reduction | Reduces the cooldown of your Hammer of Justice by $/1000;s1 sec. | Check as active set-bonus state; adjust priority, resource, cooldown, or defensive threshold if this text affects the spec. |

## Justicar Raiment (`ItemSetID=624`)

### Pieces

| Item ID | Item name |
|---:|---|
| 29062 | Justicar Chestpiece |
| 29061 | Justicar Diadem |
| 29065 | Justicar Gloves |
| 29063 | Justicar Leggings |
| 29064 | Justicar Pauldrons |

### Bonuses

| Pieces | Bonus spell ID | Bonus name | DB2 description | Rotation impact |
|---:|---:|---|---|---|
| 2 | 37182 | Increased Judgement of Light | Increases the amount healed by your Judgement of Light by value1. | Check as active set-bonus state; adjust priority, resource, cooldown, or defensive threshold if this text affects the spec. |
| 4 | 37183 | Divine Favor Cooldown | Reduces the cooldown on your Divine Favor ability by misc1/-1000 sec. | Check as active set-bonus state; adjust priority, resource, cooldown, or defensive threshold if this text affects the spec. |

## Justicar Armor (`ItemSetID=625`)

### Pieces

| Item ID | Item name |
|---:|---|
| 29066 | Justicar Chestguard |
| 29068 | Justicar Faceguard |
| 29067 | Justicar Handguards |
| 29069 | Justicar Legguards |
| 29070 | Justicar Shoulderguards |

### Bonuses

| Pieces | Bonus spell ID | Bonus name | DB2 description | Rotation impact |
|---:|---:|---|---|---|
| 2 | 37184 | Increased Right./Venge./Blood | Increases the damage dealt by your Seal of Righteousness, Seal of Vengeance, or Seal of $?fac[Blood][the Martyr] by value1%. | Check as active set-bonus state; adjust priority, resource, cooldown, or defensive threshold if this text affects the spec. |
| 4 | 37185 | Increased Holy Shield | Increases the damage dealt by your Holy Shield by value1. | Check as active set-bonus state; adjust priority, resource, cooldown, or defensive threshold if this text affects the spec. |

## Justicar Battlegear (`ItemSetID=626`)

### Pieces

| Item ID | Item name |
|---:|---|
| 29071 | Justicar Breastplate |
| 29073 | Justicar Crown |
| 29072 | Justicar Gauntlets |
| 29074 | Justicar Greaves |
| 29075 | Justicar Shoulderplates |

### Bonuses

| Pieces | Bonus spell ID | Bonus name | DB2 description | Rotation impact |
|---:|---:|---|---|---|
| 2 | 37186 | Increased Judgement of Crusader | Increases the damage bonus of your Judgement of the Crusader by value1%. | Check as active set-bonus state; adjust priority, resource, cooldown, or defensive threshold if this text affects the spec. |
| 4 | 37187 | Increased Judgement of Command | Increases the damage dealt by your Judgement of Command by value1%. | Check as active set-bonus state; adjust priority, resource, cooldown, or defensive threshold if this text affects the spec. |

## Crystalforge Raiment (`ItemSetID=627`)

### Pieces

| Item ID | Item name |
|---:|---|
| 30134 | Crystalforge Chestpiece |
| 30135 | Crystalforge Gloves |
| 30136 | Crystalforge Greathelm |
| 30137 | Crystalforge Leggings |
| 30138 | Crystalforge Pauldrons |

### Bonuses

| Pieces | Bonus spell ID | Bonus name | DB2 description | Rotation impact |
|---:|---:|---|---|---|
| 2 | 37188 | Improved Judgement | Each time you cast a Judgement, your party members gain $43838s1 mana. | Check as active set-bonus state; adjust priority, resource, cooldown, or defensive threshold if this text affects the spec. |
| 4 | 37189 | Recuced Holy Light Cast Time | Your critical heals from Flash of Light and Holy Light reduce the cast time of your next Holy Light spell by $43837m1/-1000.2 sec for $43837d. This effect cannot occur more than once per minute. | Check as active set-bonus state; adjust priority, resource, cooldown, or defensive threshold if this text affects the spec. |

## Crystalforge Armor (`ItemSetID=628`)

### Pieces

| Item ID | Item name |
|---:|---|
| 30123 | Crystalforge Chestguard |
| 30125 | Crystalforge Faceguard |
| 30124 | Crystalforge Handguards |
| 30126 | Crystalforge Legguards |
| 30127 | Crystalforge Shoulderguards |

### Bonuses

| Pieces | Bonus spell ID | Bonus name | DB2 description | Rotation impact |
|---:|---:|---|---|---|
| 2 | 37190 | Increased Retribution Aura | Increases the damage from your Retribution Aura by value1. | Check as active set-bonus state; adjust priority, resource, cooldown, or defensive threshold if this text affects the spec. |
| 4 | 37191 | Holy Shield Block Value | Each time you use your Holy Shield ability, you gain $37193s1 block value against a single attack in the next $37193d. | Check as active set-bonus state; adjust priority, resource, cooldown, or defensive threshold if this text affects the spec. |

## Crystalforge Battlegear (`ItemSetID=629`)

### Pieces

| Item ID | Item name |
|---:|---|
| 30129 | Crystalforge Breastplate |
| 30130 | Crystalforge Gauntlets |
| 30132 | Crystalforge Greaves |
| 30133 | Crystalforge Shoulderbraces |
| 30131 | Crystalforge War-Helm |

### Bonuses

| Pieces | Bonus spell ID | Bonus name | DB2 description | Rotation impact |
|---:|---:|---|---|---|
| 2 | 37194 | Reduced Judgement Cost | Reduces the cost of your Judgements by value1. | Check as active set-bonus state; adjust priority, resource, cooldown, or defensive threshold if this text affects the spec. |
| 4 | 37195 | Judgement Group Heal | Each time you cast a Judgement, there is a chance it will heal all nearby party members for $37196s1. | Check as active set-bonus state; adjust priority, resource, cooldown, or defensive threshold if this text affects the spec. |

## Lightbringer Armor (`ItemSetID=679`)

### Pieces

| Item ID | Item name |
|---:|---|
| 30991 | Lightbringer Chestguard |
| 30987 | Lightbringer Faceguard |
| 30985 | Lightbringer Handguards |
| 30995 | Lightbringer Legguards |
| 30998 | Lightbringer Shoulderguards |
| 34488 | Lightbringer Waistguard |
| 34433 | Lightbringer Wristguards |
| 34560 | Lightbringer Stompers |

### Bonuses

| Pieces | Bonus spell ID | Bonus name | DB2 description | Rotation impact |
|---:|---:|---|---|---|
| 2 | 38421 | Improved Spiritual Attunement | Increases the mana gained from your Spiritual Attunement ability by value1%. | Check as active set-bonus state; adjust priority, resource, cooldown, or defensive threshold if this text affects the spec. |
| 4 | 38422 | Improved Consecration | Increases the damage dealt by your Consecration ability by value1%. | Check as active set-bonus state; adjust priority, resource, cooldown, or defensive threshold if this text affects the spec. |

## Lightbringer Battlegear (`ItemSetID=680`)

### Pieces

| Item ID | Item name |
|---:|---|
| 30990 | Lightbringer Breastplate |
| 30982 | Lightbringer Gauntlets |
| 30993 | Lightbringer Greaves |
| 30997 | Lightbringer Shoulderbraces |
| 30989 | Lightbringer War-Helm |
| 34561 | Lightbringer Boots |
| 34431 | Lightbringer Bands |
| 34485 | Lightbringer Girdle |

### Bonuses

| Pieces | Bonus spell ID | Bonus name | DB2 description | Rotation impact |
|---:|---:|---|---|---|
| 2 | 38427 | Mana Regen Proc | Your melee attacks have a chance to grant you $38428s1 mana. | Check as active set-bonus state; adjust priority, resource, cooldown, or defensive threshold if this text affects the spec. |
| 4 | 38424 | Improved Hammer of Wrath | Increases the damage dealt by your Hammer of Wrath ability by value1%. | Check as active set-bonus state; adjust priority, resource, cooldown, or defensive threshold if this text affects the spec. |

## Lightbringer Raiment (`ItemSetID=681`)

### Pieces

| Item ID | Item name |
|---:|---|
| 30992 | Lightbringer Chestpiece |
| 30983 | Lightbringer Gloves |
| 30988 | Lightbringer Greathelm |
| 30994 | Lightbringer Leggings |
| 30996 | Lightbringer Pauldrons |
| 34432 | Lightbringer Bracers |
| 34487 | Lightbringer Belt |
| 34559 | Lightbringer Treads |

### Bonuses

| Pieces | Bonus spell ID | Bonus name | DB2 description | Rotation impact |
|---:|---:|---|---|---|
| 2 | 38426 | Holy Light Crit | Increases the critical strike chance of your Holy Light ability by value1%. | Check as active set-bonus state; adjust priority, resource, cooldown, or defensive threshold if this text affects the spec. |
| 4 | 38425 | Improved Flash of Light | Increases the healing from your Flash of Light ability by value1%. | Check as active set-bonus state; adjust priority, resource, cooldown, or defensive threshold if this text affects the spec. |

## Gladiator's Redemption (`ItemSetID=690`)

### Pieces

| Item ID | Item name |
|---:|---|
| 31613 | Gladiator's Ornamented Chestguard |
| 31614 | Gladiator's Ornamented Gloves |
| 31616 | Gladiator's Ornamented Headcover |
| 31618 | Gladiator's Ornamented Legplates |
| 31619 | Gladiator's Ornamented Spaulders |

### Bonuses

| Pieces | Bonus spell ID | Bonus name | DB2 description | Rotation impact |
|---:|---:|---|---|---|
| 2 | 40043 | Increased Resilience 35 | +value1 Resilience Rating. | Check as active set-bonus state; adjust priority, resource, cooldown, or defensive threshold if this text affects the spec. |
| 4 | 46851 | Holy Shock Bonus | Increases the healing from your Holy Shock spell by $m%. | Check as active set-bonus state; adjust priority, resource, cooldown, or defensive threshold if this text affects the spec. |

## Merciless Gladiator's Aegis (`ItemSetID=700`)

### Bonuses

| Pieces | Bonus spell ID | Bonus name | DB2 description | Rotation impact |
|---:|---:|---|---|---|
| 2 | 41462 | Increased Resilience 35 | +value1 Resilience Rating. | Check as active set-bonus state; adjust priority, resource, cooldown, or defensive threshold if this text affects the spec. |
| 4 | 23302 | Hammer of Justice Cooldown Reduction | Reduces the cooldown of your Hammer of Justice by $/1000;s1 sec. | Check as active set-bonus state; adjust priority, resource, cooldown, or defensive threshold if this text affects the spec. |

## Merciless Gladiator's Redemption (`ItemSetID=708`)

### Bonuses

| Pieces | Bonus spell ID | Bonus name | DB2 description | Rotation impact |
|---:|---:|---|---|---|
| 2 | 41463 | Increased Resilience 35 | +value1 Resilience Rating. | Check as active set-bonus state; adjust priority, resource, cooldown, or defensive threshold if this text affects the spec. |
| 4 | 46851 | Holy Shock Bonus | Increases the healing from your Holy Shock spell by $m%. | Check as active set-bonus state; adjust priority, resource, cooldown, or defensive threshold if this text affects the spec. |

## Merciless Gladiator's Vindication (`ItemSetID=714`)

### Bonuses

| Pieces | Bonus spell ID | Bonus name | DB2 description | Rotation impact |
|---:|---:|---|---|---|
| 2 | 41464 | Increased Resilience 35 | +value1 Resilience Rating. | Check as active set-bonus state; adjust priority, resource, cooldown, or defensive threshold if this text affects the spec. |
| 4 | 23302 | Hammer of Justice Cooldown Reduction | Reduces the cooldown of your Hammer of Justice by $/1000;s1 sec. | Check as active set-bonus state; adjust priority, resource, cooldown, or defensive threshold if this text affects the spec. |

## Vengeful Gladiator's Redemption (`ItemSetID=725`)

### Bonuses

| Pieces | Bonus spell ID | Bonus name | DB2 description | Rotation impact |
|---:|---:|---|---|---|
| 2 | 43478 | Increased Resilience 35 | +value1 Resilience Rating. | Check as active set-bonus state; adjust priority, resource, cooldown, or defensive threshold if this text affects the spec. |
| 4 | 23302 | Hammer of Justice Cooldown Reduction | Reduces the cooldown of your Hammer of Justice by $/1000;s1 sec. | Check as active set-bonus state; adjust priority, resource, cooldown, or defensive threshold if this text affects the spec. |

## Vengeful Gladiator's Vindication (`ItemSetID=726`)

### Bonuses

| Pieces | Bonus spell ID | Bonus name | DB2 description | Rotation impact |
|---:|---:|---|---|---|
| 2 | 43479 | Increased Resilience 35 | +value1 Resilience Rating. | Check as active set-bonus state; adjust priority, resource, cooldown, or defensive threshold if this text affects the spec. |
| 4 | 23302 | Hammer of Justice Cooldown Reduction | Reduces the cooldown of your Hammer of Justice by $/1000;s1 sec. | Check as active set-bonus state; adjust priority, resource, cooldown, or defensive threshold if this text affects the spec. |

## Vengeful Gladiator's Aegis (`ItemSetID=727`)

### Bonuses

| Pieces | Bonus spell ID | Bonus name | DB2 description | Rotation impact |
|---:|---:|---|---|---|
| 2 | 43480 | Increased Resilience 35 | +value1 Resilience Rating. | Check as active set-bonus state; adjust priority, resource, cooldown, or defensive threshold if this text affects the spec. |
| 4 | 23302 | Hammer of Justice Cooldown Reduction | Reduces the cooldown of your Hammer of Justice by $/1000;s1 sec. | Check as active set-bonus state; adjust priority, resource, cooldown, or defensive threshold if this text affects the spec. |
