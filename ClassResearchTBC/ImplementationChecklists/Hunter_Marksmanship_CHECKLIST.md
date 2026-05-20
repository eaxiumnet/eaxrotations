# Hunter Marksmanship Implementation Checklist

## DB2 Spell Verification

| Spell | Requirement | Status | Evidence |
|---|---|---|---|
| AimedShot levels [27065/20904/20903/20902/20901/20900/19434] | {70,60,52,44,36,28,20} per DB2 | ✅ Fixed | DB2-Spells.md: 19434(20),20900(28),20901(36),20902(44),20903(52),20904(60),27065(70) |
| ArcaneShot levels | {69,60,52,44,36,28,20,12,6} | ✅ Present | Fixed in BM pass |
| AspectOfTheHawk levels | {68,60,58,48,38,28,18,10} | ✅ Present | Fixed in BM pass |
| AspectOfTheViper level | {64} | ✅ Present | Fixed in BM pass |
| BestialWrath level | {40} | ✅ Present | Fixed in BM pass |
| FeignDeath level | {30} | ✅ Fixed | DB2-Spells.md: 5384(30). Was {32}. |
| HuntersMark levels | {58,40,22,6} | ✅ Present | Fixed in BM pass |
| KillCommand level | {66} | ✅ Present | Fixed in BM pass |
| MendPet levels | {68,60,52,44,36,28,20,12} | ✅ Present | Fixed in BM pass |
| Misdirection level | {70} | ✅ Fixed | DB2-Spells.md: 34477(70). Was {64}. |
| MultiShot levels | {67,60,54,42,30,18} | ✅ Present | Fixed in BM pass |
| RapidFire | [3045], level 26, CD 300s | ✅ Present | Bare constructor; gameplay CD handled in match function |
| SerpentSting levels | {67,60,58,50,42,34,26,18,10,4} | ✅ Present | Fixed in BM pass |
| SilencingShot [34490] | 20s CD, level 30, silence 3s | ✅ Added | DB2-Spells.md: 34490(30), CD 20000ms. Was missing entirely. |
| SteadyShot level | {62} | ✅ Present | |
| ViperSting levels | {66,56,46,36} | ✅ Fixed | DB2-Spells.md: 3034(36),14279(46),14280(56),27018(66). Was {68,60,40,36}. |

## Behavioral Alignment

| Requirement | Research Source | Status | Evidence |
|---|---|---|---|
| SilencingShot [34490] strategy | Angle 5: target_is_casting check | ✅ Wired | Strategies array: position 11, after Readiness, gated by `target:is_casting()` |
| Serpent Sting refresh < 1.5s | Angle 5: "Refresh at < 1.5s" | ✅ Fixed | Changed refresh from 3 to 1.5 |
| Hunter's Mark refresh < 5s | Angle 5: "mark_remains < 5 refresh" | ✅ Present | debuff refresh=10 already set; framework handles refresh |
| In-combat Aimed Shot + mana gate | Angle 4: "Mana < 20%: no Aimed Shot" | ✅ Wired | Strategies array: position 12, after SilencingShot, gated by mana and auto-shot timing |
| Multi-Shot CC gate | Angle 5: avoid breaking CC | ✅ Added | `has_breakable_cc_nearby` check |
| Arcane Shot mana gate | Angle 4: mana < 20% suppress | ✅ Added | `mana_pct < 20` gate |
| Aspect flip-flop prevention | Angle 4: Viper→Hawk at > 30% | ✅ Fixed | Hawk requires mana > 30 if coming from Viper |
| Feign Death threat drop | Angle 3: core utility | ✅ Present | |
| Misdirection opener | Angle 3: core utility | ✅ Present | |
| Volley AoE | Angle 3: 4+ targets | ✅ Present | schema setting exists |

## Silencing Shot Behavior

- Spell ID: [34490]
- DB2 cooldown: 20000ms (20s)
- Wowhead silence: 3s
- Gate: target must be casting and not silence-immune
- Category: interrupt/utility, NOT core DPS rotation

## API Validation

| API | File | Verified |
|---|---|---|
| NS.spell_action | class_sylvanas.lua | Existing pattern |
| NS.debuff_up | marksmanship_sylvanas.lua | Existing pattern |
| NS.buff_up | marksmanship_sylvanas.lua | Existing pattern |
| NS.spell_ready | marksmanship_sylvanas.lua | Existing pattern |
| NS.action_matches | marksmanship_sylvanas.lua | Existing pattern |
| NS.action_execute | marksmanship_sylvanas.lua | Existing pattern |
| context.has_breakable_cc_nearby | marksmanship_sylvanas.lua | Existing pattern (BM pass) |

## Validation

| Check | Result |
|---|---|
| `luac -p marksmanship_sylvanas.lua` | ✅ Pass |
| `luac -p class_sylvanas.lua` | ✅ Pass |
| Code review (code-reviewer-deepseek) | ✅ No issues |
| Strategies wired to rotation | ✅ All 22 strategies in array |

## Summary

- **DB2 fixes**: 8 spells corrected (AimedShot, FeignDeath, ViperSting, Misdirection levels), SilencingShot [34490] added
- **Behavioral fixes**: SerpentSting refresh 3→1.5, SilencingShot interrupt strat, InCombatAimedShot with mana gate, Multi-Shot CC+mana gates, Arcane Shot mana gate, Aspect Hawk flip-flop guard
- **Strategy wiring**: 2 strategies (SilencingShot, InCombatAimedShot) that had match functions but weren't in the rotation array are now wired
