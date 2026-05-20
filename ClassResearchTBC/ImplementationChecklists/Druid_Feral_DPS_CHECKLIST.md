# Druid Feral DPS — Implementation Checklist

**Spec:** Druid Feral DPS (Cat)  
**Target files:** `EaxRotations/classes/druid/cat_sylvanas.lua`, `class_sylvanas.lua`, `schema_sylvanas.lua`  
**Research:** `ClassResearchTBC/Druid/Feral-DPS/Research.md`  
**DB2:** `ClassResearchTBC/Druid/DB2-Spells.md`

## DB2 Spell Level Verification

| Spell | Status | Old Levels | Correct Levels | IDs |
|---|---|---|---|---|
| Bash | FIXED | 62,44,16 | 46,30,14 | 8983,6798,5211 |
| BearForm | FIXED | 68,10 | 40,10 | 9634,5487 |
| Claw | FIXED | 70,60,50,40,30,22 | 67,58,48,38,28,20 | 27000,9850,9849,5201,3029,1082 |
| Cower | FIXED | 70,60,50,38 | 69,60,52,40,28 | 27004,31709,9892,9000,8998 |
| Dash | FIXED | 54,30 | 65,46,26 | 33357,9821,1850 |
| DemoralizingRoar | FIXED | 60,50,40,30,20,14 | 62,52,42,32,20,10 | 26998,9898,9747,9490,1735,99 |
| FaerieFire | FIXED | 56,46,30 | 66,54,42,30,18 | 26993,9907,9749,778,770 |
| FaerieFireFeral | FIXED | 62 | 66,54,42,30,25 | 27011,17392,17391,17390,16857 |
| FeralCharge | FIXED | 70,50 | 20 | 16979 |
| FerociousBite | FIXED | 70,60,50,40,32 | 63,60,56,48,40,32 | 24248,31018,22829,22828,22827,22568 |
| Growl | FIXED | 68,58,48,38,28,16 | 10 | 6795 |
| Maim | FIXED | 70,64 | 62 | 22570 |
| MangleCat | FIXED | 70,64 | 68,58,50 | 33983,33982,33876 |
| Moonfire | FIXED | 70,60,50,40,30,20,14 | 70,63,58,52,46,40,34,28,22,16,10,4 | all 12 IDs |
| Pounce | FIXED | 70,60,50,42 | 66,56,46,36 | 27006,9827,9823,9005 |
| Prowl | FIXED | 26 | 60,40,20 | 9913,6783,5215 |
| Rake | FIXED | 70,60,50,40,30,22 | 64,54,44,34,24 | 27003,9904,1824,1823,1822 |
| Ravage | FIXED | 70,60,50,40,32 | 66,58,50,42,32 | 27005,9867,9866,6787,6785 |
| Rip | FIXED | 70,60,50,40,32 | 67,60,52,44,36,28,20 | 27008,9896,9894,9752,9493,9492,1079 |
| Shred | FIXED | 70,60,50,40,30,22 | 70,61,54,46,38,30,22 | 27002,27001,9830,9829,8992,6800,5221 |
| TigersFury | FIXED | 70,60,50,40,30,24 | 60,48,36,24 | 9846,9845,6793,5217 |

## Behavioral Contract Verification

| Contract Item | Status | Evidence |
|---|---|---|
| Mangle debuff priority before bleed spenders | Present | `shred_matches` gates on `mangle_remains`; `MangleDebuff` strat positioned before Rip/Shred |
| Shred as primary combo builder from behind | Present | `Shred` strat requires `is_behind`, gates on `mangle_remains` |
| Rip at high combo points, target lives long | Present | `rip_matches` gates on CP (cat_rip_cp setting), TTD >= 10s, snapshot upgrade |
| Ferocious Bite only when Rip won't get value | Present | `bite_matches` suppresses if Rip expiring and target lives, or uses execute window |
| Clearcasting on Shred (reserved, not panic-spent) | Present | `ShredOmen` strat specifically for Omen proc, requires behind, respects CP cap |
| Powershift: mana floor, shift throttle, form check | Present | `powershift_matches`: energy ≤ floor, mana ≥ 8, CP ≤ 4, form=cat, tick-aware, clearsight gate |
| Energy pooling before finishers | Present | `PoolForRip` and `PoolForBuilderTick` strategies |
| Rake conditional (energy + target lifetime) | Present | `rake_matches` gates on TTD ≥ 6s, CP < 5, snapshot upgrade |
| Tiger's Fury only at zero/low energy | Present | `tigers_fury_matches` checks energy won't cap, TTD gate, CP gate |
| No non-TBC mechanics (Berserk, Savage Roar, Cat Swipe) | Present | Removed: Berserk hooks (`has_berserk`, `berserk_matches`), SurvivalInstincts hooks, and SwipeCat action. No Berserk buff check. |
| Faerie Fire (Feral) armor debuff | Present | `FaerieFireFeral` strat with refresh window and TTD gate |
| PvP openers (Pounce/Ravage from stealth) | Present | `PounceOpener`, `RavageOpener`, `StealthShred`, `StealthMangle` strats |
| Maim interrupt/control for PvP | Present | `MaimInterrupt` and `MaimControl` strats |
| Movement: Dash, Travel Form, Feral Charge | Present | All three strats with appropriate gates |

## Schema Settings

| Setting | Status | Notes |
|---|---|---|
| cat_powershift_enabled | Present | ✓ |
| cat_powershift_energy | Present | ✓ |
| cat_execute_hp | Present | ✓ |
| cat_rip_cp | Present | ✓ |
| cat_ferocious_bite_cp | Present | ✓ |
| cat_wolfshead_helm | Present | ✓ |
| cat_barkskin_hp | Present | Used for Barkskin defensive gate |

## API Validation

All API calls use cached/guarded wrappers: `safe_method`, `safe_method_arg`, `buff_up`, `debuff_up`, `debuff_remains`, `get_attack_power`, `get_combo_points`, `get_energy`. No banned APIs detected.

## Additional Fixes (post-code-review)

| Fix | File | Details |
|---|---|---|
| RAKE_DEBUFF spell ID | `cat_sylvanas.lua` | Changed from 27003 (wrong Rake rank) to 1822 (all-rank debuff ID) per DB2 — was checking for wrong debuff, causing Rake refresh to fail |

## Test Results

- `test_cat_custom_matches.lua` — PASS
- `test_cat_snapshot_upgrade.lua` — PASS
- `luac -p class_sylvanas.lua` — PASS
- `luac -p cat_sylvanas.lua` — PASS
- `luac -p schema_sylvanas.lua` — PASS

## [VERIFY] Rows from Research.md

Per Research.md lines 219-225, AP/energy floor thresholds (1500/2000/2500 AP breakpoints) are marked **[VERIFY]**.

| Research Row | Status | Decision |
|---|---|---|
| 1500 AP / 25 energy floor | Keep configurable | Not hard-coded; configurable via `cat_powershift_energy` setting |
| 1500 AP / 30 energy before shift | Keep configurable | Not hard-coded; powershift energy threshold is user-configurable |
| 2000 AP / 30 energy floor | Keep configurable | Not hard-coded |
| 2000 AP / 35 energy before Bite | Keep configurable | Not hard-coded |
| 2500 AP / 35 energy floor | Keep configurable | Not hard-coded |
| 2500 AP / 40 energy before shift | Keep configurable | Not hard-coded |
| Any AP / 20 energy emergency | Keep configurable | Not hard-coded |

**Rationale:** Research.md explicitly marks these as [VERIFY] requiring sim/log validation. Per AGENT_RUNNER.md hard rules: "Do not hard-code [VERIFY] AP/energy floors around 1500/2000/2500 AP. Keep these configurable." The current implementation uses `cat_powershift_energy` slider (default 20) which covers all cases without hard-coding specific AP breakpoints.
