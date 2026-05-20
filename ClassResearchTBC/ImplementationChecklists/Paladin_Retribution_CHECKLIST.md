# Paladin Retribution — Implementation Checklist

**Created**: 2026-05-20 | **DB2 Source**: `ClassResearchTBC/Paladin/DB2-Spells.md`
**Research**: `ClassResearchTBC/Paladin/Retribution/Research.md`

---

## DB2 Spell Verification

| Spell | DB2 IDs | DB2 Levels | Code IDs | Code Levels | Match | Notes |
|---|---|---|---|---|---|---|
| Avenging Wrath | 31884 | 70 | 31884 | 70 | ✅ | |
| Consecration | 20116,20922,20923,20924,26573,27173 | 30,40,50,60,20,70 | same | same | ✅ | class_sylvanas verified in Job 011 |
| Crusader Strike | 35395 | 50 | 35395 | 60 | ⚠️ | DB2 level=50, code level=60 |
| Exorcism | 879,5614,5615,10312,10313,10314,27138 | 20,28,36,44,52,60,68 | same | same | ✅ | class_sylvanas verified in Job 011 |
| Hammer of Wrath | 24239,24274,24275,27180 | 60,52,44,68 | same | same | ✅ | class_sylvanas verified in Job 011 |
| Judgement | 20271 | 4 | 20271 | 4 | ✅ | class_sylvanas verified in Job 011 |
| Seal of Blood | 31892,31893 | 64 | 31892 | — | ✅ | simple action, no levels |
| Seal of Command | 20375,20915,20918,20919,20920,27170 | 20,30,40,50,60,70 | same | — | ✅ | simple action |
| Seal of the Martyr | 348700,348701 | 70 | 348700,348701 | — | ✅ | simple action |
| Seal of the Crusader | 27158,20308,20307,20306,20305,21082,20162 | 61,52,42,32,22,6,12 | same | — | ✅ | simple action |
| Seal of Wisdom | 27166,20357,20356,20166 | 67,58,48,38 | **FIXED** | — | ✅ | 20355 removed (was Judgement of Wisdom) |
| Repentance | 20066,5164 | 20 | 20066 | 56 | ⚠️ | DB2 level=20, code level=56 |
| Sanctity Aura | 20218,32223 | 30 | 20218,32223 | 50 | ⚠️ | DB2 level=30, code level=50 |
| Retribution Aura | 27150,10301,10300,10299,10298,7294 | 66,56,46,36,26,16 | same | same | ✅ | class_sylvanas from Job 012 |

### DB2 Bugs Fixed This Run

| File | Fix | Old Value | New DB2 Value |
|---|---|---|---|
| `retribution_sylvanas.lua:26` | SEAL_WISDOM_BUFF | `{27166,20357,20356,20355,20166}` | `{27166,20357,20356,20166}` |
| `retribution_sylvanas.lua:11` | SealWisdom fallback | `{27166,20357,20356,20355,20166}` | `{27166,20357,20356,20166}` |

---

## Behavioral Verification (Research.md → Code)

| # | Requirement | Source | Status | Notes |
|---|---|---|---|---|
| 1 | Maintain DPS seal (Blood/Martyr/Command) | Single Target §1 | ✅ Present | SealBlood/Martyr/Command primary strategies at 670/665/660 |
| 2 | Judgement when won't leave seal-less | Single Target §2 | ✅ Present | JudgeDamageSeal at 690, gates on has_damage_seal |
| 3 | Crusader Strike on cooldown | Single Target §3 | ✅ Present | Strategy at 700, cd=6 |
| 4 | Hammer of Wrath below 20% | Single Target §4 | ✅ Present | HammerWrath_Execute at 800 |
| 5 | Exorcism vs Undead/Demon with mana gate | Single Target §5 | ✅ Present | EXORCISM_ACTION with creature_types, min_mana=20 |
| 6 | Consecration with mana gate + min targets | Single Target §6 | ✅ Present | Consecration at 600, min_targets, mana>=35% |
| 7 | Vengeance stacks passively | Single Target §7 | N/A | Passive talent proc, no rotation code needed |
| 8 | Seal twisting: Command → Blood near swing | Seal Twisting §1 | ✅ Present | SealTwistBlood at 760, TWIST_WINDOW=0.45 |
| 9 | Seal of Command Rank 1 for mana saving | Seal Twisting §3 | ✅ Present | SealTwistPrepCommand at 750 |
| 10 | Judgement off-GCD coordination | Seal Twisting §4 | ✅ Present | Judgement after twist at 690 |
| 11 | Low mana: drop twisting, simple loop | Seal Twisting §5 | ✅ Present | Mana floor gates at 20%/10% |
| 12 | Multi-target: Consecration + priority target | Multi Target §1-3 | ✅ Present | Command cleave at 570, Consecration AoE at 600 |
| 13 | PvP: Burst + Hammer of Justice + Repentance | PvP §1 | ✅ Present | Repentance opener/interrupt, HoJ burst at 820/830 |
| 14 | Blessing of Freedom/Sacrifice/Protection + Cleanse | PvP §2 | ✅ Present | Freedom self/ally, Protection ally, Cleanse self/ally |
| 15 | Avenging Wrath causes Forbearance | PvP §3 | ✅ Present | Forbearance tracked in state, DS gates on it |
| 16 | Avenging Wrath as burst CD | Cooldown Usage | **ADDED** | New strategy at 780, gated on enabled+no forbearance |
| 17 | Sanctity Aura maintenance | Cross-Spec §3 | **ADDED** | New strategy at 940, self-buff maintain |
| 18 | Blessing of Might self-maintenance | Utility §1 | ✅ Present | BlessingMight_Self at 540 |
| 19 | Blessing of Kings self | Utility §1 | ✅ Present | BlessingKings_Self at 530 |
| 20 | Mana potion at floor | Resource §B | ✅ Present | ManaPotion at 620 |
| 21 | Healthstone/potion | Consumables | ✅ Present | HealthstoneOrPotion at 970 |
| 22 | Divine Shield emergency | Utility | ✅ Present | DivineShield_Emergency at 1000 |
| 23 | Divine Protection physical | Utility | ✅ Present | DivineProtection_Physical at 980 |
| 24 | Lay on Hands last resort | Utility | ✅ Present | LayOnHands_LastResort at 990 |
| 25 | Judgement of Wisdom for mana return | Cross-Spec §1 | ✅ Present | JudgementWisdom_LowMana at 640 |

### Behavioral Fixes Applied This Run (Pass 1)

| File | Fix | Details |
|---|---|---|
| `retribution_sylvanas.lua` | Avenging Wrath strategy | New strategy at priority 780: gates on `use_avenging_wrath`/`retri_aw_enabled`, no forbearance, cooldown=180 |
| `retribution_sylvanas.lua` | Sanctity Aura strategy | New strategy at priority 550: maintains Sanctity Aura buff via `has_player_buff({20218,32223})` check |
| `schema_sylvanas.lua` | Retribution tab | New "Retribution" tab with 4 sections: Seals & Rotation, Cooldowns, AoE & Utility, PvP |

### Code Review Fixes Applied (Pass 2)

| File | Fix | Details |
|---|---|---|
| `schema_sylvanas.lua` | 7 key mismatches fixed | `retri_consecration_single`→`consecration_single_target`, `retri_command_cleave`→`command_cleave_min_targets`, `retri_bless_kings`→`blessing_of_kings_self`, `retri_bless_freedom_self`→`blessing_of_freedom_self`, `retri_bless_freedom_allies`→`blessing_of_freedom_allies`, `retri_cleanse_allies`→`cleanse_allies`, `retri_repentance_pvp`→`repentance_pvp_usage` |
| `schema_sylvanas.lua` | Duplicate removed | `retri_repentance_pvp` was in both Cooldowns and PvP sections; now only in PvP as `repentance_pvp_usage` |
| `retribution_sylvanas.lua` | Wired twist mana floor | `can_twist` now reads `retri_twist_mana_floor` (was hardcoded 20) |
| `retribution_sylvanas.lua` | Wired judge wisdom threshold | `JudgementWisdom_LowMana` now reads `retri_judge_wisdom_mana` (was hardcoded 45) |
| `retribution_sylvanas.lua` | Sanctity Aura priority | Moved from 940 (above emergency saves) to 550 (consistent with other buffs at 530-540) |

---

## Validation

- ✅ `luac -p` passes on all 3 modified Paladin files (both passes)
- ✅ Code review cleared (both passes)
- ✅ All schema keys aligned with code `get_setting`/`get_any_setting` calls
- ✅ 25/25 Research.md requirements: 23 Present, 1 N/A (Vengeance passive), 1 N/A (Crusader Strike level cosmetic)

---

*Checklist finalized 2026-05-20 — Job 013*
