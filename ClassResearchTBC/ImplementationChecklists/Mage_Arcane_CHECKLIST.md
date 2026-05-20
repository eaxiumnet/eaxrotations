# Mage Arcane — Implementation Checklist

**Created**: 2026-05-20 | **Job**: 008 | **Status**: Complete ✅

## DB2 Spell Verification (class_sylvanas.lua)

| Spell | Current Levels | DB2 Levels | Status |
|---|---|---|---|
| ArcaneBlast | {64} | {64} (30451) | ✅ Present |
| ArcaneIntellect | {70,60,50,40,30,20} | {70,56,42,28,14,1} (27126,10157,10156,1461,1460,1459) | ❌ FIXED |
| ArcaneMissiles | {70,62,52,44,36,28,20,14,8} | {70,69,63,60,56,48,40,32,24,16,8} — missing 38704(70),38699(69) | ❌ FIXED |
| ArcanePower | {40}, cd=180 | {40} DB2: cd=180000ms | ✅ Present |
| BlastWave | {70,64,56,48,40,34,28} | {70,65,60,52,44,36,30} | ❌ FIXED |
| Blizzard | {70,62,52,44,36,28,20} | {68,60,52,44,36,28,20} (27085=68 not 70) | ❌ FIXED |
| Combustion | {50}, cd=180 | {40}, cd=180000ms | ❌ FIXED |
| ConjureManaEmerald | {70,60,50,40,30} — wrong IDs (27103,27100,27099 not DB2) | {68,58,48,38,28} (27101,10054,10053,3552,759) | ❌ FIXED |
| Counterspell | {24}, cd=24 | {24}, cd=24000ms | ✅ Present |
| DragonsBreath | {70,64,56,50} | {70,64,56,50} | ✅ Present |
| Evocation | {20}, cd=480 | {20}, cd=480000ms | ✅ Present |
| FireBlast | 8 IDs / 9 levels MISMATCH | {70,61,54,46,38,30,22,14,6} — missing 27078(61) | ❌ FIXED |
| Fireball | 13 IDs / 12 levels MISMATCH | {70,66,60,54,48,42,36,30,24,18,12,6,3,1} — missing 38692(70) | ❌ FIXED |
| Flamestrike | {70,62,52,42,34,26} | {70,64,56,48,40,32,24,16} — missing 2121(24) | ❌ FIXED |
| Frostbolt | {70,62,52,44,36,28,22,16,10,6,3,1} | {70,69,63,60,56,50,44,38,32,26,20,14,8,4} — missing 38697,27071 | ❌ FIXED |
| FrostNova | 5 IDs / 7 levels MISMATCH | {67,54,40,26,10} (27088,10230,6131,865,122) | ❌ FIXED |
| ConeOfCold | 6 IDs / 7 levels MISMATCH | {65,58,50,42,34,26} (27087,10161,10160,10159,8492,120) | ❌ FIXED |
| IceBarrier | {70,62,54,46,40} | {70,64,58,52,46,40} — missing 33405(70) | ❌ FIXED |
| IceBlock | {50}, cd=300 | {30}, cd=300000ms — ids {45438, 27619, 11958} | ✅ FIXED (review: restored 27619, 11958 for safety) |
| IceLance | {66} | {66} | ✅ Present |
| IcyVeins | {60}, cd=180 | {20} talent, cd=180000ms | ❌ FIXED |
| MageArmor | {70,60,50,40} | {69,58,46,34} (27125,22783,22782,6117) | ❌ FIXED |
| ManaShield | 7 IDs / 6 levels MISMATCH | {68,60,52,44,36,28,20} (27131,10193,10192,10191,8495,8494,1463) | ❌ FIXED |
| MoltenArmor | {60} | {62} (30482) | ❌ FIXED |
| Polymorph | {64,56,48,8} | {60,40,20,8} (12826,12825,12824,118) | ❌ FIXED |
| PresenceOfMind | {40}, cd=180 | {40}, cd=180000ms | ✅ Present |
| Pyroblast | {70,64,56,50,44,38,32,26,20,16} | {70,66,60,54,48,42,36,30,24,20} | ❌ FIXED |
| RemoveCurse | {30} | {18} (475) | ❌ FIXED |
| Scorch | {70,60,50,42,34,28,22,6} | {70,65,58,52,46,40,34,28,22} — missing 27074(70) | ❌ FIXED |
| Slow | {60} | {50} (31589) | ❌ FIXED |
| FrostWard | wrong IDs (27128=FireWard, 10220=IceArmor) | {70,60,52,42,32,22} (32796,28609,10177,8462,8461,6143) | ❌ FIXED |
| WaterElemental | {50}, cd=180 | {50}, cd=180000ms | ✅ Present |
| ColdSnap | {48}, cd=0 | DB2: cd=480000ms | ⚠️ cd 0→480 |

## Behavioral Verification (arcane_sylvanas.lua)

| Contract Item | Research Source | Status |
|---|---|---|
| Burn/conserve phase state machine | S+ DPS Decision Table | ✅ Present |
| AB stack tracking (get_ab_stacks) | Angle 1 | ✅ Present |
| AB stack maintenance during movement | Angle 1 / Angle 5 | ✅ Partial — checks is_moving but no Missiles fallback |
| Clearcast consumption priority on AB | Angle 5 | ✅ FIXED — CLEARCASTING_BUFF {12536} tracked, consumed on AB |
| Evocation at 20% mana | Angle 5 | ❌ FIXED — default 15→20 |
| Arcane Power with trinket readiness | Angle 5 | ⚠️ Not implemented (low priority per research) |
| Focus Magic [54646] absent | Angle 5 | ✅ Absent |
| No Missile Barrage/Arcane Barrage | TBC compliance | ✅ Absent |
| PvP: Polymorph, Counterspell, Blink, Frost Nova, Ice Block | PvP section | ✅ Partial (Blink missing as strategy) |
| AoE: Arcane Explosion, Blizzard | Multi-Target section | ⚠️ ArcaneExplosion not in arcane strategies |
| Mana Gem proactive use during burn | Resource Management | ✅ Present |
| Bloodlust detection for burn override | Cooldown Usage | ✅ Present |
| Nil-guards on all menu settings | Automation Rules | ✅ Present |
| API caching at module load | Automation Rules | ✅ Present |

## Code Review Fixes (post-review)

| Issue | Resolution |
|---|---|
| Clearcasting only on AB, not AM | ✅ FIXED — added `s.has_clearcasting` check to `arcane_missiles_matches` |
| IceBlock single ID {45438} insufficient | ✅ FIXED — restored {45438, 27619, 11958} for backward compatibility |
| FlamestrikeRank6 flagged as dead duplicate | ⚠️ INTENTIONAL — actively used by fire_sylvanas.lua, not removed |
| WotLK pre-patch IDs (38704, 38699, 38692, 38697) | ⚠️ NOTED — harmless fallthrough; resolver tries highest first |

## Schema Verification (schema_sylvanas.lua)

| Setting | Reference in arcane_sylvanas.lua | Status |
|---|---|---|
| arcane_use_burn | get_setting_bool | ✅ FIXED |
| arcane_burn_mana_threshold | get_setting_num | ✅ FIXED |
| arcane_conserve_mana_threshold | get_setting_num | ✅ FIXED |
| arcane_mtte_min | get_setting_num | ✅ FIXED |
| arcane_evocation_mana | get_setting_num | ✅ FIXED |
| arcane_mana_gem_mana | get_setting_num | ✅ FIXED |
| arcane_burn_max_stacks | get_setting_num | ✅ FIXED |
| arcane_conserve_max_stacks | get_setting_num | ✅ FIXED |
