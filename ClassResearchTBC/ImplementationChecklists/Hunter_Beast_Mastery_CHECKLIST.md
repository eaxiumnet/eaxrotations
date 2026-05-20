# Hunter Beast Mastery — Implementation Checklist

Created: 2026-05-19

## DB2-Verified Spell Levels

| Spell | DB2 IDs | DB2 Levels | Code Levels (before) | Code Levels (after) | Status |
|---|---|---|---|---|---|
| ArcaneShot | 3044(6)→27019(69) | 6,12,20,28,36,44,52,60,69 | 70,60,50,42,34,28,22,16,6 | 69,60,52,44,36,28,20,12,6 | ✅ Fixed |
| AspectOfTheHawk | 13165(10)→27044(68) | 10,18,28,38,48,58,60,68 | 70,64,58,52,44,36,28,20 | 68,60,58,48,38,28,18,10 | ✅ Fixed |
| AspectOfTheViper | 34074(64) | 64 | 62 | 64 | ✅ Fixed |
| BestialWrath | 19574(40) | 40 | 50 | 40 | ✅ Fixed |
| HuntersMark | 1130(6)→14325(58) | 6,22,40,58 | 62,54,44,4 | 58,40,22,6 | ✅ Fixed |
| KillCommand | 34026(66) | 66 | 62 | 66 | ✅ Fixed |
| MendPet | 136(12)→27046(68) | 12,20,28,36,44,52,60,68 | 70,64,58,52,44,36,28,20 | 68,60,52,44,36,28,20,12 | ✅ Fixed |
| SerpentSting | 1978(4)→27016(67) | 4,10,18,26,34,42,50,58,60,67 | 70,64,56,48,40,32,24,16,8,4 | 67,60,58,50,42,34,26,18,10,4 | ✅ Fixed |
| MultiShot | 2643(18)→27021(67) | 18,30,42,54,60,67 | (bare, no levels) | 67,60,54,42,30,18 | ✅ Fixed (added explicit constructor) |

## Behavioral Fixes

| Mechanic | Research Contract | Implementation | Status |
|---|---|---|---|
| Arcane Shot mana gate | Angle 4: <20% mana = Steady only, no Arcane | `mana_pct < 20` gate added, constant `ARCANE_SHOT_MANA_FLOOR = 20` | ✅ Fixed |
| Multi-Shot CC gate | Research: "only when it will not break CC" | `context.has_breakable_cc_nearby` gate added | ✅ Fixed |
| Multi-Shot mana gate | Angle 4: suppress expensive AoE at very low mana | `mana_pct < 15` gate added, constant `MULTI_SHOT_MANA_FLOOR = 15` | ✅ Fixed |
| Aspect switching threshold | Angle 4: Viper at 20% mana | Schema `mana_viper_start` default 10→20 | ✅ Fixed |

## Validation

| Test | Result |
|---|---|
| `luac -p beast_mastery_sylvanas.lua` | ✅ Pass |
| `luac -p class_sylvanas.lua` | ✅ Pass |
| `luac -p schema_sylvanas.lua` | ✅ Pass |
| Code review (code-reviewer-deepseek) | ✅ Reviewed — 2 suggestions applied |

## Files Changed

1. `EaxRotations/classes/hunter/class_sylvanas.lua` — 9 DB2 level corrections + MultiShot explicit constructor
2. `EaxRotations/classes/hunter/beast_mastery_sylvanas.lua` — Arcane mana gate, Multi-Shot CC+mana gates, named constants
3. `EaxRotations/classes/hunter/schema_sylvanas.lua` — mana_viper_start default 10→20
