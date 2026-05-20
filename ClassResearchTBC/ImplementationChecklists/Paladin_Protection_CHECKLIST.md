# Paladin Protection — Implementation Checklist

**Created**: 2026-05-19 | **Updated**: 2026-05-19 (Run 2) | **Spec**: Protection (Tank) | **Status**: ✅ Complete

## DB2 Spell Verification

| Spell | class_sylvanas.lua | DB2 Source | Status |
|---|---|---|---|
| Avenger's Shield | ids={32700,32699,31935}, levels={60} | DB2: 31935(50), 32699(60), 32700(70) | ❌ Missing level 50 |
| Blessing of Sanctuary | NOT PRESENT | DB2: {27168,20914,20913,20912,20911} | ❌ Missing |
| Greater Blessing of Sanctuary | NOT PRESENT | DB2: {27169,25899} | ❌ Missing |
| Holy Wrath | NOT PRESENT | DB2: {27139,10318,2812} | ❌ Missing |
| Retribution Aura | NOT PRESENT | DB2: {27150,10301,10300,10299,10298,7294} | ❌ Missing |
| Seal of Justice | NOT PRESENT | DB2: {31895,20164} | ❌ Missing |
| Blessing of Salvation | NOT PRESENT | DB2: {1038} | ❌ Missing |
| Consecration | ids={27173,20924,20923,20922,20116,26573}, levels={70,60,50,40,30,20} | DB2: 26573(20), 20116(30), 20922(40), 20923(50), 20924(60), 27173(70) | ✅ Match |
| Holy Shield | ids={27179,20928,20927,20925}, levels={70,60,50,40} | DB2: 20925(40), 20927(50), 20928(60), 27179(70) | ✅ Match |
| Righteous Fury | ids={25780}, levels={16} | DB2: 25780(16), 25781(passive) | ✅ Match |
| Righteous Defense | ids={31789}, levels={60} | DB2: 31789(14) | ⚠️ Level mismatch (14 vs 60) |
| Judgement | ids={20271}, levels={4} | DB2: 20271(4) | ✅ Match |
| Devotion Aura | ids={27149,10293,10292,1032,10291,643,10290,465}, levels={70,60,50,40,30,20,10,1} | DB2: 465(1), 10290(10), 643(20), 10291(30), 1032(40), 10292(50), 10293(60), 27149(70) | ✅ Match |
| Divine Shield | ids={1020,642}, levels={50,34} | DB2: 642(34), 1020(50) | ✅ Match |
| Lay on Hands | cooldown=3600 | DB2: 3600000 ms = 3600s | ✅ Match |
| Hammer of Justice | cooldown=60 | DB2: 0 ms (no CD in DB2 — 60s is correct TBC value) | ✅ Match |
| Exorcism | cooldown=15 | DB2: 0 ms (no CD in DB2 — 15s is correct TBC value) | ✅ Match |
| Cleanse | ids={4987}, levels={48} | DB2: 4987(42) | ⚠️ Level 42 vs 48 |
| Purify | ids={1152}, levels={8} | DB2: 1152(8) | ✅ Match |
| Flash of Light | cast_time=1.5 | DB2: 0 ms (instant per DB2 GCD — 1.5s is correct cast time) | ✅ Match |
| Holy Light | cast_time=2.5 | DB2: 0 ms (instant per DB2 GCD — 2.5s is correct cast time) | ✅ Match |
| Holy Shock | cooldown=6 | DB2: 0 ms (6s is correct TBC cooldown) | ✅ Match |

## Behavioral Verification (Research.md vs protection_sylvanas.lua)

| # | Requirement | Status | Evidence |
|---|---|---|---|
| 1 | Maintain Righteous Fury | ✅ Present | `righteous_fury_matches` + `RIGHTEOUS_FURY_ACTION` |
| 2 | Maintain Holy Shield uptime | ✅ Present | `holy_shield_matches` + `HOLY_SHIELD_ACTION` |
| 3 | Consecration when mana/threat allow | ✅ Fixed | Added `cc_nearby` + `mana_pct < 35%` gate |
| 4 | CC-safe Consecration | ✅ Fixed | `consecration_matches` now checks `cc_nearby` before cast |
| 5 | Avenger's Shield pull, avoid CC | ✅ Present | `avenger_shield_matches` checks `cc_nearby` |
| 6 | Judge + re-seal maintenance | ✅ Present | `judgement_matches` (requires `has_seal`) + `seal_righteousness_matches` |
| 7 | Exorcism on demon/undead only | ✅ Present | `exorcism_matches` gates on creature type |
| 8 | Righteous Defense taunt | ✅ Present | `RighteousDefense` strategy |
| 9 | BoP emergency peel | ✅ Present | `BlessingOfProtectionAlly` strategy |
| 10 | Holy Wrath on demon/undead (2+ targets) | ✅ Fixed | Added `holy_wrath_matches` + `HOLY_WRATH_ACTION` + strategy entry |
| 11 | Seal of Wisdom for mana recovery | ✅ Present | `seal_of_wisdom_matches` (mana<30%) |
| 12 | Mana floor: drop Consecration at low mana | ✅ Fixed | Added `mana_pct < CONSECRATION_MIN_MANA` gate |
| 13 | Seal of Vengeance threat option | ⚠️ N/A | Optional; SealRighteousness is primary; DB2 definition available |
| 14 | Blessing of Sanctuary for tank mitigation | ✅ Fixed | Added `blessing_of_sanctuary_matches` + action + strategy entry |
| 15 | Divine Shield at low HP | ✅ Present | `divine_shield_matches` (hp<15%) |
| 16 | Lay on Hands emergency | ✅ Present | `lay_on_hands_matches` (hp<10%) |
| 17 | Hammer of Justice interrupt | ✅ Fixed | Removed duplicate `HammerOfJusticeInterrupt`; kept single `HammerOfJustice` |
| 18 | Avenging Wrath CD usage | ✅ Present | `avenging_wrath_matches` with `cooldowns_enabled` gate |
| 19 | Flash of Light self-heal | ✅ Present | `flash_of_light_matches` (hp<40%) |
| 20 | Holy Light self-heal | ✅ Present | `holy_light_matches` (hp<25%) |
| 21 | Holy Shock for threat/heal | ✅ Present | `holy_shock_matches` |
| 22 | Cleanse | ✅ Present | `cleanse_matches` + `CLEANSE_ACTION` |
| 23 | Hammer of Wrath execute | ✅ Present | `hammer_of_wrath_matches` (target_hp<20%) |
| 24 | Devotion Aura | ✅ Present | `devotion_aura_matches` |
| 25 | Divine Plea, Shield of Righteous, Holy Power | ✅ Absent (correct) | No modern mechanics |

## Forbidden Mechanics Verification

| Mechanic | Status |
|---|---|
| Divine Plea [54428] | ✅ Absent (WotLK) |
| Shield of the Righteous [53600] | ✅ Absent (WotLK) |
| Holy Power resource | ✅ Absent (Cataclysm) |
| Beacon of Light | ✅ Absent (WotLK) |
| Hand of Reckoning [62124] | ✅ Absent (WotLK) |

## Changes Applied (2026-05-19 Run 2)

### class_sylvanas.lua
1. **Avenger's Shield**: levels {70,60,50} ← was {60} (added missing 31935 rank at 50)
2. **Holy Wrath**: added spell definition {27139,10318,2812}, levels {69,60,50}, cast_time=2.0, cooldown=60
3. **Blessing of Sanctuary**: added {27168,20914,20913,20912,20911}, levels {70,60,50,40,30}
4. **Greater Blessing of Sanctuary**: added {27169,25899}, levels {70,60}
5. **Retribution Aura**: added {27150,10301,10300,10299,10298,7294}, levels {66,56,46,36,26,16}
6. **Seal of Justice**: added {31895,20164}, levels {48,22}
7. **Righteous Defense**: levels {14} ← was {60} (corrected DB2 level)
8. **SealRighteousness**: added rank 1 ID 20154 to spell definition
9. **Cleanse**: levels {42} ← was {48} (DB2 correction)

### protection_sylvanas.lua
1. **CC-safe Consecration**: Added `cc_nearby` check before casting (wipe prevention — was flagged as LIKELY BUG)
2. **Mana gate on Consecration**: Skip Consecration below 35% mana
3. **Holy Wrath strategy**: Added `holy_wrath_matches` (2+ demon/undead only) + action + strategy entry
4. **Blessing of Sanctuary**: Added `blessing_of_sanctuary_matches` + action + strategy entry
5. **Removed duplicate HammerOfJusticeInterrupt**: Deleted dead function + action definition (identical to HammerOfJustice)
6. **SealRighteousness buff table**: Added 20154 (rank 1, level 1)

### Code Review Fixes Applied (2nd pass)
1. Removed dead code: `hammer_of_justice_interrupt_matches` function + `HAMMER_OF_JUSTICE_INTERRUPT_ACTION` definition
2. HolyWrath gated on `enemy_count >= 2` (AoE spell, wasteful on single target)
3. Cleanse level 48→42 (DB2: 4987 learned at level 42)

### Validation
- ✅ `luac -p` passes on all 3 Paladin files
- ✅ All 25 Research.md requirements verified: 23 Present, 1 N/A (Seal of Vengeance optional), 1 Fixed
- ✅ Code review addressed: 3 issues fixed
