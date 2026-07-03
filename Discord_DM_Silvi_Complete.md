# Profession Spell IDs — Cross-Expansion Reference

> **Date**: 2026-06-28
> **Purpose**: Locale-safe profession window opening via spell ID for Project Sylvanas
> **Method**: Extracted from Blizzard DBC files (SkillLineAbility + SpellName tables)
> **Clients Used**: Classic Era 1.15.8, TBC 2.5.5, MoP Classic 5.5.4, Retail 12.0.7

---

## How Profession Spells Work

Each profession has a **supercede chain** of ranks. When you learn a higher rank, the lower rank is removed from your spellbook. All ranks share the **same localized name**.

`GetSpellInfo(spellID)` queries the game database (not your spellbook) and returns the localized name. `CastSpellByName` then casts whatever rank you actually know.

| Rank | Skill Range | Expansion Added |
|------|-------------|-----------------|
| Apprentice | 1–75 | Vanilla |
| Journeyman | 75–150 | Vanilla |
| Expert | 150–225 | Vanilla |
| Artisan | 225–300 | Vanilla |
| Master | 300–375 | The Burning Crusade |
| Grand Master | 350–450 | Wrath of the Lich King |
| Illustrious | 425–525 | Cataclysm |
| Zen Master | 500–600 | Mists of Pandaria |
| Draenor | 1–700 | Warlords of Draenor |
| Legion | 1–800 | Legion |
| Kul Tiran / Zandalari | 1–175 | Battle for Azeroth |
| Shadowlands | 1–150 | Shadowlands |
| Dragon Isles | 1–100 | Dragonflight |
| Khaz Algar | 1–100 | The War Within |

**Apprentice IDs are stable across all expansions.** `GetSpellInfo(2259)` returns "Alchemy" (localized) in every WoW client from 2004 to present.

---

## Alchemy (SkillLine 171)

| Expansion | Apprentice | Journeyman | Expert | Artisan | Master | Grand Master | Illustrious | Zen Master | Draenor | Legion | Khaz Algar |
|-----------|-----------|-----------|--------|---------|--------|-------------|-------------|------------|---------|--------|------------|
| Vanilla | 2259 | 3101 | 3464 | 11611 | — | — | — | — | — | — | — |
| TBC | 2259 | 3101 | 3464 | 11611 | 28596 | — | — | — | — | — | — |
| WotLK | 2259 | 3101 | 3464 | 11611 | 28596 | 51304 | — | — | — | — | — |
| Cata | 2259 | 3101 | 3464 | 11611 | 28596 | 51304 | 80731 | — | — | — | — |
| MoP | 2259 | 3101 | 3464 | 11611 | 28596 | 51304 | 80731 | 105206 | — | — | — |
| WoD | 2259 | 3101 | 3464 | 11611 | 28596 | 51304 | 80731 | 105206 | 156606 | — | — |
| Legion | 2259 | 3101 | 3464 | 11611 | 28596 | 51304 | 80731 | 105206 | 156606 | 195095 | — |
| BfA | 2259 | 3101 | 3464 | 11611 | 28596 | 51304 | 80731 | 105206 | 156606 | 195095 | — |
| Shadowlands | 2259 | 3101 | 3464 | 11611 | 28596 | 51304 | 80731 | 105206 | 156606 | 195095 | — |
| Dragonflight | 2259 | 3101 | 3464 | 11611 | 28596 | 51304 | 80731 | 105206 | 156606 | 195095 | — |
| TWW | 2259 | 3101 | 3464 | 11611 | 28596 | 51304 | 80731 | 105206 | 156606 | 195095 | 264211 |

**Stable Apprentice Anchor**: 2259

---

## Blacksmithing (SkillLine 164)

| Expansion | Apprentice | Journeyman | Expert | Artisan | Master | Grand Master | Illustrious | Zen Master | Draenor | Legion | Khaz Algar |
|-----------|-----------|-----------|--------|---------|--------|-------------|-------------|------------|---------|--------|------------|
| Vanilla | 2018 | 3100 | 3538 | 9785 | — | — | — | — | — | — | — |
| TBC | 2018 | 3100 | 3538 | 9785 | 29844 | — | — | — | — | — | — |
| WotLK | 2018 | 3100 | 3538 | 9785 | 29844 | 51300 | — | — | — | — | — |
| Cata | 2018 | 3100 | 3538 | 9785 | 29844 | 51300 | 76666 | — | — | — | — |
| MoP | 2018 | 3100 | 3538 | 9785 | 29844 | 51300 | 76666 | 110396 | — | — | — |
| WoD | 2018 | 3100 | 3538 | 9785 | 29844 | 51300 | 76666 | 110396 | 158737 | — | — |
| Legion | 2018 | 3100 | 3538 | 9785 | 29844 | 51300 | 76666 | 110396 | 158737 | 195097 | — |
| BfA | 2018 | 3100 | 3538 | 9785 | 29844 | 51300 | 76666 | 110396 | 158737 | 195097 | — |
| Shadowlands | 2018 | 3100 | 3538 | 9785 | 29844 | 51300 | 76666 | 110396 | 158737 | 195097 | — |
| Dragonflight | 2018 | 3100 | 3538 | 9785 | 29844 | 51300 | 76666 | 110396 | 158737 | 195097 | — |
| TWW | 2018 | 3100 | 3538 | 9785 | 29844 | 51300 | 76666 | 110396 | 158737 | 195097 | 264434 |

**Stable Apprentice Anchor**: 2018

---

## Cooking (SkillLine 185)

| Expansion | Apprentice | Journeyman | Expert | Artisan | Master | Grand Master | Illustrious | Zen Master | Draenor | Legion |
|-----------|-----------|-----------|--------|---------|--------|-------------|-------------|------------|---------|--------|
| Vanilla | 2550 | 3102 | 3413 | 18260 | — | — | — | — | — | — |
| TBC | 2550 | 3102 | 3413 | 18260 | 33359 | — | — | — | — | — |
| WotLK | 2550 | 3102 | 3413 | 18260 | 33359 | 51296 | — | — | — | — |
| Cata | 2550 | 3102 | 3413 | 18260 | 33359 | 51296 | 88053 | — | — | — |
| MoP | 2550 | 3102 | 3413 | 18260 | 33359 | 51296 | 88053 | 104381 | — | — |
| WoD | 2550 | 3102 | 3413 | 18260 | 33359 | 51296 | 88053 | 104381 | 158765 | — |
| Legion | 2550 | 3102 | 3413 | 18260 | 33359 | 51296 | 88053 | 104381 | 158765 | 195128 |
| BfA | 2550 | 3102 | 3413 | 18260 | 33359 | 51296 | 88053 | 104381 | 158765 | 195128 |
| Shadowlands | 2550 | 3102 | 3413 | 18260 | 33359 | 51296 | 88053 | 104381 | 158765 | 195128 |
| Dragonflight | 2550 | 3102 | 3413 | 18260 | 33359 | 51296 | 88053 | 104381 | 158765 | 195128 |
| TWW | 2550 | 3102 | 3413 | 18260 | 33359 | 51296 | 88053 | 104381 | 158765 | 195128 |

**Stable Apprentice Anchor**: 2550

---

## Enchanting (SkillLine 333)

| Expansion | Apprentice | Journeyman | Expert | Artisan | Master | Grand Master | Illustrious | Zen Master | Draenor | Legion | Khaz Algar |
|-----------|-----------|-----------|--------|---------|--------|-------------|-------------|------------|---------|--------|------------|
| Vanilla | 7411 | 7412 | 7413 | 13920 | — | — | — | — | — | — | — |
| TBC | 7411 | 7412 | 7413 | 13920 | 28029 | — | — | — | — | — | — |
| WotLK | 7411 | 7412 | 7413 | 13920 | 28029 | 51313 | — | — | — | — | — |
| Cata | 7411 | 7412 | 7413 | 13920 | 28029 | 51313 | 74258 | — | — | — | — |
| MoP | 7411 | 7412 | 7413 | 13920 | 28029 | 51313 | 74258 | 110400 | — | — | — |
| WoD | 7411 | 7412 | 7413 | 13920 | 28029 | 51313 | 74258 | 110400 | 158716 | — | — |
| Legion | 7411 | 7412 | 7413 | 13920 | 28029 | 51313 | 74258 | 110400 | 158716 | 195096 | — |
| BfA | 7411 | 7412 | 7413 | 13920 | 28029 | 51313 | 74258 | 110400 | 158716 | 195096 | — |
| Shadowlands | 7411 | 7412 | 7413 | 13920 | 28029 | 51313 | 74258 | 110400 | 158716 | 195096 | — |
| Dragonflight | 7411 | 7412 | 7413 | 13920 | 28029 | 51313 | 74258 | 110400 | 158716 | 195096 | — |
| TWW | 7411 | 7412 | 7413 | 13920 | 28029 | 51313 | 74258 | 110400 | 158716 | 195096 | 264455 |

**Stable Apprentice Anchor**: 7411

**Note**: Enchanting fires `CRAFT_SHOW` (not `TRADE_SKILL_SHOW`).

---

## Engineering (SkillLine 202)

| Expansion | Apprentice | Journeyman | Expert | Artisan | Master | Grand Master | Illustrious | Zen Master | Draenor | Legion | Khaz Algar |
|-----------|-----------|-----------|--------|---------|--------|-------------|-------------|------------|---------|--------|------------|
| Vanilla | 4036 | 4037 | 4038 | 12656 | — | — | — | — | — | — | — |
| TBC | 4036 | 4037 | 4038 | 12656 | 30350 | — | — | — | — | — | — |
| WotLK | 4036 | 4037 | 4038 | 12656 | 30350 | 51306 | — | — | — | — | — |
| Cata | 4036 | 4037 | 4038 | 12656 | 30350 | 51306 | 82774 | — | — | — | — |
| MoP | 4036 | 4037 | 4038 | 12656 | 30350 | 51306 | 82774 | 110403 | — | — | — |
| WoD | 4036 | 4037 | 4038 | 12656 | 30350 | 51306 | 82774 | 110403 | 158739 | — | — |
| Legion | 4036 | 4037 | 4038 | 12656 | 30350 | 51306 | 82774 | 110403 | 158739 | 195112 | — |
| BfA | 4036 | 4037 | 4038 | 12656 | 30350 | 51306 | 82774 | 110403 | 158739 | 195112 | — |
| Shadowlands | 4036 | 4037 | 4038 | 12656 | 30350 | 51306 | 82774 | 110403 | 158739 | 195112 | — |
| Dragonflight | 4036 | 4037 | 4038 | 12656 | 30350 | 51306 | 82774 | 110403 | 158739 | 195112 | — |
| TWW | 4036 | 4037 | 4038 | 12656 | 30350 | 51306 | 82774 | 110403 | 158739 | 195112 | 264475 |

**Stable Apprentice Anchor**: 4036

---

## First Aid (SkillLine 129)

| Expansion | Apprentice | Journeyman | Expert | Artisan | Master | Grand Master | Illustrious | Zen Master |
|-----------|-----------|-----------|--------|---------|--------|-------------|-------------|------------|
| Vanilla | 3273 | 3274 | 7924 | 10846 | — | — | — | — |
| TBC | 3273 | 3274 | 7924 | 10846 | 27028 | — | — | — |
| WotLK | 3273 | 3274 | 7924 | 10846 | 27028 | 45542 | — | — |
| Cata | 3273 | 3274 | 7924 | 10846 | 27028 | 45542 | 74559 | — |
| MoP | 3273 | 3274 | 7924 | 10846 | 27028 | 45542 | 74559 | 110406 |
| WoD | — | — | — | — | — | — | — | — |
| Legion | — | — | — | — | — | — | — | — |
| BfA | — | — | — | — | — | — | — | — |
| Shadowlands | — | — | — | — | — | — | — | — |
| Dragonflight | — | — | — | — | — | — | — | — |
| TWW | — | — | — | — | — | — | — | — |

**Stable Apprentice Anchor**: 3273

**Removed in patch 8.0.1 (Battle for Azeroth).** Does not exist in Retail or later expansions.

---

## Fishing (SkillLine 356)

| Expansion | Apprentice | Journeyman | Expert | Artisan | Master | Grand Master | Illustrious | Zen Master | Draenor | Legion |
|-----------|-----------|-----------|--------|---------|--------|-------------|-------------|------------|---------|--------|
| Vanilla | 7620 | 7731 | 7732 | 18248 | — | — | — | — | — | — |
| TBC | 7620 | 7731 | 7732 | 18248 | 33095 | — | — | — | — | — |
| WotLK | 7620 | 7731 | 7732 | 18248 | 33095 | 51294 | — | — | — | — |
| Cata | 7620 | 7731 | 7732 | 18248 | 33095 | 51294 | 88868 | — | — | — |
| MoP | 7620 | 7731 | 7732 | 18248 | 33095 | 51294 | 88868 | 110410 | — | — |
| WoD | 7620 | 7731 | 7732 | 18248 | 33095 | 51294 | 88868 | 110410 | 158743 | — |
| Legion | 7620 | 7731 | 7732 | 18248 | 33095 | 51294 | 88868 | 110410 | 158743 | 271616 |
| BfA | 7620 | 7731 | 7732 | 18248 | 33095 | 51294 | 88868 | 110410 | 158743 | 272011 |
| Shadowlands | 7620 | 7731 | 7732 | 18248 | 33095 | 51294 | 88868 | 110410 | 158743 | 272011 |
| Dragonflight | 7620 | 7731 | 7732 | 18248 | 33095 | 51294 | 88868 | 110410 | 158743 | 272011 |
| TWW | 7620 | 7731 | 7732 | 18248 | 33095 | 51294 | 88868 | 110410 | 158743 | 272011 |

**Stable Apprentice Anchor**: 7620

**Retail Branches**: In Legion+, Fishing has non-chain branch spells:
- 271616 = Legion Fishing
- 272011 = Kul Tiran / Zandalari Fishing

These are expansion-specific variants, not part of the supercede chain.

---

## Inscription (SkillLine 773)

| Expansion | Apprentice | Journeyman | Expert | Artisan | Master | Grand Master | Illustrious | Zen Master | Draenor | Legion | Khaz Algar |
|-----------|-----------|-----------|--------|---------|--------|-------------|-------------|------------|---------|--------|------------|
| Vanilla | — | — | — | — | — | — | — | — | — | — | — |
| TBC | — | — | — | — | — | — | — | — | — | — | — |
| WotLK | 45357 | 45358 | 45359 | 45360 | 45361 | 45363 | — | — | — | — | — |
| Cata | 45357 | 45358 | 45359 | 45360 | 45361 | 45363 | 86008 | — | — | — | — |
| MoP | 45357 | 45358 | 45359 | 45360 | 45361 | 45363 | 86008 | 110417 | — | — | — |
| WoD | 45357 | 45358 | 45359 | 45360 | 45361 | 45363 | 86008 | 110417 | 158748 | — | — |
| Legion | 45357 | 45358 | 45359 | 45360 | 45361 | 45363 | 86008 | 110417 | 158748 | 195115 | — |
| BfA | 45357 | 45358 | 45359 | 45360 | 45361 | 45363 | 86008 | 110417 | 158748 | 195115 | — |
| Shadowlands | 45357 | 45358 | 45359 | 45360 | 45361 | 45363 | 86008 | 110417 | 158748 | 195115 | — |
| Dragonflight | 45357 | 45358 | 45359 | 45360 | 45361 | 45363 | 86008 | 110417 | 158748 | 195115 | — |
| TWW | 45357 | 45358 | 45359 | 45360 | 45361 | 45363 | 86008 | 110417 | 158748 | 195115 | 264494 |

**Stable Apprentice Anchor**: 45357

**Added in Wrath of the Lich King.** Does not exist in Vanilla or TBC.

---

## Jewelcrafting (SkillLine 755)

| Expansion | Apprentice | Journeyman | Expert | Artisan | Master | Grand Master | Illustrious | Zen Master | Draenor | Legion | Khaz Algar |
|-----------|-----------|-----------|--------|---------|--------|-------------|-------------|------------|---------|--------|------------|
| Vanilla | — | — | — | — | — | — | — | — | — | — | — |
| TBC | 25229 | 25230 | 28894 | 28895 | 28897 | — | — | — | — | — | — |
| WotLK | 25229 | 25230 | 28894 | 28895 | 28897 | 51311 | — | — | — | — | — |
| Cata | 25229 | 25230 | 28894 | 28895 | 28897 | 51311 | 73318 | — | — | — | — |
| MoP | 25229 | 25230 | 28894 | 28895 | 28897 | 51311 | 73318 | 110420 | — | — | — |
| WoD | 25229 | 25230 | 28894 | 28895 | 28897 | 51311 | 73318 | 110420 | 158750 | — | — |
| Legion | 25229 | 25230 | 28894 | 28895 | 28897 | 51311 | 73318 | 110420 | 158750 | 195116 | — |
| BfA | 25229 | 25230 | 28894 | 28895 | 28897 | 51311 | 73318 | 110420 | 158750 | 195116 | — |
| Shadowlands | 25229 | 25230 | 28894 | 28895 | 28897 | 51311 | 73318 | 110420 | 158750 | 195116 | — |
| Dragonflight | 25229 | 25230 | 28894 | 28895 | 28897 | 51311 | 73318 | 110420 | 158750 | 195116 | — |
| TWW | 25229 | 25230 | 28894 | 28895 | 28897 | 51311 | 73318 | 110420 | 158750 | 195116 | 264532 |

**Stable Apprentice Anchor**: 25229

**Added in The Burning Crusade.** Does not exist in Vanilla.

---

## Leatherworking (SkillLine 165)

| Expansion | Apprentice | Journeyman | Expert | Artisan | Master | Grand Master | Illustrious | Zen Master | Draenor | Legion | Khaz Algar |
|-----------|-----------|-----------|--------|---------|--------|-------------|-------------|------------|---------|--------|------------|
| Vanilla | 2108 | 3104 | 3811 | 10662 | — | — | — | — | — | — | — |
| TBC | 2108 | 3104 | 3811 | 10662 | 32549 | — | — | — | — | — | — |
| WotLK | 2108 | 3104 | 3811 | 10662 | 32549 | 51302 | — | — | — | — | — |
| Cata | 2108 | 3104 | 3811 | 10662 | 32549 | 51302 | 81199 | — | — | — | — |
| MoP | 2108 | 3104 | 3811 | 10662 | 32549 | 51302 | 81199 | 110423 | — | — | — |
| WoD | 2108 | 3104 | 3811 | 10662 | 32549 | 51302 | 81199 | 110423 | 158752 | — | — |
| Legion | 2108 | 3104 | 3811 | 10662 | 32549 | 51302 | 81199 | 110423 | 158752 | 195119 | — |
| BfA | 2108 | 3104 | 3811 | 10662 | 32549 | 51302 | 81199 | 110423 | 158752 | 195119 | — |
| Shadowlands | 2108 | 3104 | 3811 | 10662 | 32549 | 51302 | 81199 | 110423 | 158752 | 195119 | — |
| Dragonflight | 2108 | 3104 | 3811 | 10662 | 32549 | 51302 | 81199 | 110423 | 158752 | 195119 | — |
| TWW | 2108 | 3104 | 3811 | 10662 | 32549 | 51302 | 81199 | 110423 | 158752 | 195119 | 264577 |

**Stable Apprentice Anchor**: 2108

---

## Mining (SkillLine 186)

| Expansion | Apprentice | Journeyman | Expert | Artisan | Master | Grand Master | Illustrious | Zen Master | Draenor | Legion |
|-----------|-----------|-----------|--------|---------|--------|-------------|-------------|------------|---------|--------|
| Vanilla | 2575 | 2576 | 3564 | 10248 | — | — | — | — | — | — |
| TBC | 2575 | 2576 | 3564 | 10248 | 29354 | — | — | — | — | — |
| WotLK | 2575 | 2576 | 3564 | 10248 | 29354 | 50310 | — | — | — | — |
| Cata | 2575 | 2576 | 3564 | 10248 | 29354 | 50310 | 74517 | — | — | — |
| MoP | 2575 | 2576 | 3564 | 10248 | 29354 | 50310 | 74517 | 102161 | — | — |
| WoD | 2575 | 2576 | 3564 | 10248 | 29354 | 50310 | 74517 | 102161 | 158754 | — |
| Legion | 2575 | 2576 | 3564 | 10248 | 29354 | 50310 | 74517 | 102161 | 158754 | 195122 |
| BfA | 2575 | 2576 | 3564 | 10248 | 29354 | 50310 | 74517 | 102161 | 158754 | 195122 |
| Shadowlands | 2575 | 2576 | 3564 | 10248 | 29354 | 50310 | 74517 | 102161 | 158754 | 195122 |
| Dragonflight | 2575 | 2576 | 3564 | 10248 | 29354 | 50310 | 74517 | 102161 | 158754 | 195122 |
| TWW | 2575 | 2576 | 3564 | 10248 | 29354 | 50310 | 74517 | 102161 | 158754 | 195122 |

**Stable Apprentice Anchor**: 2575

**Important**: Mining is a gathering profession. It does **NOT** open a crafting window. Use **Smelting** (2656) to open the crafting window.

**Retail Specialization Variants**: Mining has additional non-chain spell IDs in Retail (265837, 265839, 265841, etc.) for profession specializations. These are not needed for window opening.

---

## Skinning (SkillLine 393)

| Expansion | Apprentice | Journeyman | Expert | Artisan | Master | Grand Master | Illustrious | Zen Master | Draenor | Legion |
|-----------|-----------|-----------|--------|---------|--------|-------------|-------------|------------|---------|--------|
| Vanilla | 8613 | 8617 | 8618 | 10768 | — | — | — | — | — | — |
| TBC | 8613 | 8617 | 8618 | 10768 | 32678 | — | — | — | — | — |
| WotLK | 8613 | 8617 | 8618 | 10768 | 32678 | 50305 | — | — | — | — |
| Cata | 8613 | 8617 | 8618 | 10768 | 32678 | 50305 | 74522 | — | — | — |
| MoP | 8613 | 8617 | 8618 | 10768 | 32678 | 50305 | 74522 | 102216 | — | — |
| WoD | 8613 | 8617 | 8618 | 10768 | 32678 | 50305 | 74522 | 102216 | 158756 | — |
| Legion | 8613 | 8617 | 8618 | 10768 | 32678 | 50305 | 74522 | 102216 | 158756 | 195125 |
| BfA | 8613 | 8617 | 8618 | 10768 | 32678 | 50305 | 74522 | 102216 | 158756 | 195125 |
| Shadowlands | 8613 | 8617 | 8618 | 10768 | 32678 | 50305 | 74522 | 102216 | 158756 | 195125 |
| Dragonflight | 8613 | 8617 | 8618 | 10768 | 32678 | 50305 | 74522 | 102216 | 158756 | 195125 |
| TWW | 8613 | 8617 | 8618 | 10768 | 32678 | 50305 | 74522 | 102216 | 158756 | 195125 |

**Stable Apprentice Anchor**: 8613

**Important**: Skinning is a gathering profession. It does **NOT** open a crafting window.

---

## Tailoring (SkillLine 197)

| Expansion | Apprentice | Journeyman | Expert | Artisan | Master | Grand Master | Illustrious | Zen Master | Draenor | Legion | Khaz Algar |
|-----------|-----------|-----------|--------|---------|--------|-------------|-------------|------------|---------|--------|------------|
| Vanilla | 3908 | 3909 | 3910 | 12180 | — | — | — | — | — | — | — |
| TBC | 3908 | 3909 | 3910 | 12180 | 26790 | — | — | — | — | — | — |
| WotLK | 3908 | 3909 | 3910 | 12180 | 26790 | 51309 | — | — | — | — | — |
| Cata | 3908 | 3909 | 3910 | 12180 | 26790 | 51309 | 75156 | — | — | — | — |
| MoP | 3908 | 3909 | 3910 | 12180 | 26790 | 51309 | 75156 | 110426 | — | — | — |
| WoD | 3908 | 3909 | 3910 | 12180 | 26790 | 51309 | 75156 | 110426 | 158758 | — | — |
| Legion | 3908 | 3909 | 3910 | 12180 | 26790 | 51309 | 75156 | 110426 | 158758 | 195126 | — |
| BfA | 3908 | 3909 | 3910 | 12180 | 26790 | 51309 | 75156 | 110426 | 158758 | 195126 | — |
| Shadowlands | 3908 | 3909 | 3910 | 12180 | 26790 | 51309 | 75156 | 110426 | 158758 | 195126 | — |
| Dragonflight | 3908 | 3909 | 3910 | 12180 | 26790 | 51309 | 75156 | 110426 | 158758 | 195126 | — |
| TWW | 3908 | 3909 | 3910 | 12180 | 26790 | 51309 | 75156 | 110426 | 158758 | 195126 | 264616 |

**Stable Apprentice Anchor**: 3908

---

## Smelting (Mining's Crafting Skill, SkillLine 186)

| Expansion | Apprentice | Journeyman | Expert | Artisan | Master |
|-----------|-----------|-----------|--------|---------|--------|
| Vanilla | 2656 | 2657 | 3308 | 3307 | 16153 |
| TBC | 2656 | 2657 | 3308 | 3307 | 16153 |
| WotLK | 2656 | 2657 | 3308 | 3307 | 16153 |
| Cata | 2656 | 2657 | 3308 | 3307 | 16153 |
| MoP | 2656 | 2657 | 3308 | 3307 | 16153 |
| WoD | 2656 | 2657 | 3308 | 3307 | 16153 |
| Legion | 2656 | 2657 | 3308 | 3307 | 16153 |
| BfA | 2656 | 2657 | 3308 | 3307 | 16153 |
| Shadowlands | 2656 | 2657 | 3308 | 3307 | 16153 |
| Dragonflight | 2656 | 2657 | 3308 | 3307 | 16153 |
| TWW | 2656 | 2657 | 3308 | 3307 | 16153 |

**Stable Apprentice Anchor**: 2656

**Note**: In Retail TWW, spell 2656 is named "Mining Journal" instead of "Smelting", but functions identically.

---

## Locale Edge Cases

The following locales have name mismatches between `GetSpellInfo` and the actual spellbook name:

| Locale | `GetSpellInfo` Returns | Spellbook Name | Profession |
|--------|----------------------|----------------|------------|
| frFR | Ingénieur | Ingénierie | Engineering |
| frFR | Premiers soins | Secourisme | First Aid |
| esES | Peletería | Marroquinería | Leatherworking |
| esES | Sastrería | Costura | Tailoring |
| koKR | 가죽세공 | 가죽 세공 | Leatherworking |

---

## Data Sources

| Expansion | Client Version | Product | DB File | Verified |
|-----------|---------------|---------|---------|----------|
| Vanilla / Classic Era | 1.15.8.67156 | `wow_classic_era` | `wowsims_classic_era.db` | Yes |
| TBC Classic | 2.5.5.68101 | `wow_anniversary` | `wowsims.db` | Yes |
| MoP Classic | 5.5.4.68317 | `wow_classic` | `wowsims_mop_classic.db` | Yes |
| Retail (TWW) | 12.0.7.68275 | `wow` | `wowsims_retail.db` | Yes |

**Cross-verification method**: Higher-expansion clients include all previous expansion data. TBC IDs were verified against both `wowsims.db` (TBC client) and `wowsims_mop_classic.db` (MoP client). MoP IDs were verified against both MoP and Retail clients.

**Missing standalone extractions**: WotLK Classic, Cata Classic, WoD, Legion, BfA, Shadowlands, Dragonflight standalone clients were not installed at time of extraction. Their IDs are present in the chain because higher-expansion clients (MoP, Retail) include all previous ranks. For authoritative standalone verification, install the client and run the extraction pipeline.

---

## Extraction Pipeline

To regenerate this data from any WoW client:

```
1. Install WoW client via Battle.net
2. Create DB2ToSqlite config: appsettings.<expansion>.json
 - Set BaseDir to WoW install directory
 - Set Product to Battle.net product code
3. Run: dotnet run --project DB2ToSqliteTool.csproj -c appsettings.<expansion>.json
4. Run: python extract_from_dbc.py --db wowsims_<expansion>.db --expansion <name> --out-dir .
```

The `extract_from_dbc.py` script lives at `build_tools/profession_spell_ids/`.

---

*End of reference. All spell IDs verified from Blizzard DBC files.*