# Warlock Affliction Implementation Checklist

## DB2 Level Corrections (class_sylvanas.lua)

| Spell | Old Levels | New Levels (DB2) | DB2 Verified |
|---|---|---|---|
| Corruption | {70,62,54,46,38,30,22,14,8,4} | {65,60,54,44,34,24,14,4} | ✅ |
| CurseOfAgony | {70,62,54,46,38,30,22,14,8,4} | {67,58,48,38,28,18,8} | ✅ |
| CurseOfDoom | {70,64,56} | {70,60} | ✅ |
| CurseOfTongues | {28} | {50,26} | ✅ |
| DarkPact | {56} | {70,60,50,40} | ✅ |
| DeathCoil | {70,62,54,48} | {68,58,50,42} | ✅ |
| DrainLife | {70,62,52,44,36,28,20,14,8} | {69,62,54,46,38,30,22,14} | ✅ |
| DrainSoul | {70,62,52,44,36,28,20,10} | {67,52,38,24,10} | ✅ |
| Fear | {60,50,40,30} | {56,32,8} | ✅ |
| HealthFunnel | missing 3698(20), wrong order | {67,60,52,44,36,28,20,12} | ✅ |
| Immolate | {70,62,52,44,36,28,20,12,6} | {69,60,60,50,40,30,20,10,1} | ✅ |
| LifeTap | {70,62,52,44,36,28,20,12,6} | {68,56,46,36,26,16,6} | ✅ |
| SeedOfCorruption | {68} | {70} | ✅ |
| ShadowBolt | {70,62,52,44,36,28,20,14,8,4,1} | {69,60,60,52,44,36,28,20,12,6,1} | ✅ |
| Shadowburn | {70,62,54,48} | {70,63,56,48,40,32,24,20} | ✅ |
| SiphonLife | {70,62,54,46,38,30,20} | {70,63,58,48,38,30} | ✅ |
| Soulshatter | {50} | {66} | ✅ |
| UnstableAffliction | {70,64,56} | {70,60,50} | ✅ |

## Behavioral Fixes (affliction_sylvanas.lua)

| Fix | Before | After | Research Source |
|---|---|---|---|
| DoT refresh window | 3.0s | 1.5s | Research Angle 1: "Refresh only when < 1.5s remains" |

## Schema Additions (schema_sylvanas.lua)

| Setting Key | Type | Default | Min/Max |
|---|---|---|---|
| aff_life_tap_mana | slider | 30 | 0-65 |
| aff_dark_pact_mana | slider | 20 | 0-100 |
| aff_mana_potion | slider | 15 | 0-100 |
| aff_wand_mana | slider | 15 | 0-100 |
| aff_seed_targets | slider | 3 | 3-10 |
| aff_use_amplify_curse | checkbox | true | — |

## Schema Constraint Alignments

| Fix | Before | After |
|---|---|---|
| aff_seed_targets min | 2 (contradicts Research Angle 1: "3+ targets") | 3 |
| aff_life_tap_mana max | 100 (code caps at 65 via max_mana field) | 65 (matches code cap) |

## Validation

| Check | Result |
|---|---|
| luac -p affliction_sylvanas.lua | ✅ PASS |
| luac -p class_sylvanas.lua | ✅ PASS |
| luac -p schema_sylvanas.lua | ✅ PASS |
| Code review (deepseek) | ✅ Cleared (2 minor issues fixed) |
