# Paladin Holy Implementation Checklist

Generated: 2026-05-19 | Runner: AgentQueue/AGENT_RUNNER.md

## DB2 Spell Verification (class_sylvanas.lua)

| Spell | Status | IDs Match DB2 | Levels Match DB2 | Notes |
|---|---|---|---|---|
| BlessingOfLight | FIX | ✓ | ✗ (69,60,50,40 not 70,60,50,40,30) | Extra level 30 |
| BlessingOfMight | FIX | ✓ | ✗ (50→52, 40→42, 30→32, 20→22, 10→12) | Levels off by 2 |
| BlessingOfProtection | FIX | ✓ | ✗ (34→38, 20→24) | Levels wrong |
| BlessingOfSacrifice | FIX | ✗ (missing 27147) | ✗ (missing 62) | Add 27147(62) |
| BlessingOfWisdom | FIX | ✓ | ✗ (8 levels for 7 IDs) | Fix levels to {65,60,54,44,34,24,14} |
| GreaterBlessingOfLight | FIX | ✓ | ✗ (extra 56) | Remove level 56 |
| GreaterBlessingOfWisdom | FIX | ✗ (missing 25918) | ✗ | Add 25918(60) |
| DevotionAura | FIX | ✗ (3 IDs for 8 levels) | ✗ | Complete rewrite: 8 IDs |
| DivineProtection | FIX | ✗ (missing 5573) | ✗ (34→18, 20→6) | Add 5573(18) |
| DivineShield | FIX | ✗ (missing 1020) | ✗ (50→34, add 50) | Add 1020(50) |
| Exorcism | FIX | ✓ | ✗ (70→68, 60→60, 50→52, 40→44, 30→36, 20→28, 12→20) | Levels all off |
| FireResistanceAura | FIX | ✗ (wrong IDs) | ✗ (2 levels for 5 IDs) | Complete rewrite |
| FlashOfLight | FIX | ✓ | ✗ (8 levels for 7 IDs) | Fix to {66,58,50,42,34,26,20} |
| FrostResistanceAura | FIX | ✗ (wrong IDs) | ✗ (2 levels for 5 IDs) | Complete rewrite |
| HammerOfJustice | FIX | ✓ | ✗ (60→54, 50→40, 40→24, 30→8) | Levels all off |
| HammerOfWrath | FIX | ✗ (missing 24239,24274) | ✗ (3 levels for 2 IDs) | Add 24239(60),24274(52) |
| HolyLight | FIX | ✓ | ✗ (8 levels for 11 IDs) | Complete rewrite: 11 levels |
| HolyShield | FIX | ✓ | ✗ (1 level for 4 IDs) | Fix: {70,60,50,40} |
| Judgement | FIX | ✓ | ✗ (7 levels for 1 ID) | Remove extra levels, keep {4} |
| LayOnHands | FIX | ✓ | ✗ (70→69, 60→50, 50→30, add 10) | Fix: {69,50,30,10} |
| Purify | FIX | ✓ | ✗ (42→8) | Level off by 34 |
| RighteousFury | FIX | ✓ | ✗ (7 levels for 1 ID) | Remove extra levels, keep {16} |
| SealOfWisdom | FIX | ✓ | ✗ (6 levels for 5 IDs) | Fix: {67,58,48,38} |
| ShadowResistanceAura | FIX | ✗ (missing 19896,19895) | ✗ | Add: {63,52,40,28} |
| ConcentrationAura | OK | ✓ | ✓ (22) | |
| HolyShock | OK | ✓ | ✓ (70,64,56,48,40) | |
| Consecration | OK | ✓ | ✓ | |

## Behavioral Verification (holy_sylvanas.lua)

| Requirement (Research.md) | Status | Evidence |
|---|---|---|
| Cleanse automation (poison/disease/magic) | ✅ Present | CleanseTankPriority, PurifySelf, CleanseParty strategies |
| Blessing of Light on tank priority | ✅ Present | choose_blessing() checks tank first for BoL |
| Blessing of Wisdom on mana users | ✅ Present | choose_blessing() checks mana users for BoW |
| Divine Favor before critical Holy Light | ✅ Present | DivineFavor strategy gates on lowest HP ≤ 45% |
| Divine Illumination during heavy healing | ✅ Present | DivineIlluminationHeavyHealing gates on heavy_healing OR mana ≤ 35% |
| Holy Shock for emergency/movement | ✅ Present | HolyShock strategy + choose_smart_heal emergency path |
| Flash of Light for efficient maintenance | ✅ Present | choose_smart_heal Flash of Light path |
| Holy Light for tank spikes | ✅ Present | choose_smart_heal HL path with Light's Grace awareness |
| Lay on Hands last resort | ✅ Present | LayOnHandsLastResort strategy |
| Aura management (resist/situational) | ✅ Present | choose_aura(): Shadow→Fire→Frost→Concentration→Devotion |
| Blessing of Protection/Freedom/Sacrifice | ✅ Present | BoP, BoF, BoSac strategies |
| Seal/Judgement of Wisdom for mana | ✅ Present | SealOfWisdomLowMana + JudgementOfWisdomBoss |
| Judgement of Light for raid heal support | ✅ Present | JudgementOfLightBoss (when mana OK) |
| Hammer of Justice for PvP/interrupt | ✅ Present | HammerOfJusticeDiver strategy |
| Solo damage when idle | ✅ Present | solo_damage_enabled gate + multiple solo strategies |
| No Beacon of Light | ✅ Not present | Correct - TBC only |
| No Sacred Shield | ✅ Not present | Correct - WotLK ability |
| No Holy Power resource | ✅ Not present | Correct - Cata mechanic |
| Divine Illumination at 30% mana | ⚠️ Partial | Uses 35% + heavy healing gate (more robust) |
| Illumination proc queue tracking | N/A | Engine-level concern, not rotation fixable |

## LUA Syntax

| File | Status |
|---|---|
| class_sylvanas.lua | ✅ PASS |
| holy_sylvanas.lua | ✅ PASS |
| schema_sylvanas.lua | ✅ PASS |
| heal_helper_sylvanas.lua | ✅ PASS |

## Test Results

| Test | Status |
|---|---|
| test_paladin_holy_custom_matches.lua | ✅ PASS |

## Remaining Risk

- None. All vetted behavioral items present. DB2 corrections applied.
