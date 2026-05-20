# Shaman Restoration — Implementation Checklist

Created: 2026-05-20
Spec: Shaman Restoration (Healer)
Files: `EaxRotations/classes/shaman/class_sylvanas.lua`, `restoration_sylvanas.lua`

---

## DB2 Level Verification

| Spell | Code Level | DB2 Level | Status |
|---|---|---|---|
| EarthShield [32593] | 64 | 60 | **FIXED** → 60 |
| HealingWave [25391] | 64 | 63 | **FIXED** → 63 |
| HealingWave [25357] | 58 | 60 | **FIXED** → 60 |
| HealingWave [10396] | 50 | 56 | **FIXED** → 56 |
| HealingWave [10395] | 42 | 48 | **FIXED** → 48 |
| HealingWave [959] | 34 | 32 | **FIXED** → 32 |
| HealingWave [939] | 26 | 24 | **FIXED** → 24 |
| GroundingTotem [8177] | 32 | 30 | **FIXED** → 30 |
| CurePoison [526] | 14 | 16 | **FIXED** → 16 |
| PoisonCleansingTotem [8166] | 24 | 22 | **FIXED** → 22 |
| StoneclawTotem [25525] | 68 | 67 | **FIXED** → 67 |
| EarthShield [974] | 62 | 50 | **FIXED** → 50 |

---

## Behavioral Requirements

| # | Requirement | Source | Status |
|---|---|---|---|
| 1 | Maintain Water Shield on self | Research Contract | ✅ Present |
| 2 | Maintain Earth Shield on tank | Research Contract | ✅ Present |
| 3 | Earth Shield refresh at configurable charges (default ≤2) | Research Contract | ✅ Present |
| 4 | Nature's Swiftness + Healing Wave for lethal ally windows | Research Contract | ✅ Present |
| 5 | Chain Heal on clustered injured group targets | Research Contract | ✅ Present |
| 6 | Lesser Healing Wave for fast single-target triage | Research Contract | ✅ Present (SmartHeal) |
| 7 | Healing Wave for efficient single-target healing | Research Contract | ✅ Present (SmartHeal) |
| 8 | Cure Poison / Cure Disease dispels | Research Contract | ✅ Present |
| 9 | Poison Cleansing / Disease Cleansing totems | Research Contract | ✅ Present |
| 10 | Tremor Totem for fear breaks | Research Contract | ✅ Present |
| 11 | Grounding Totem vs caster mobs | Research Contract | ✅ Present |
| 12 | Mana Tide Totem at group mana threshold | Research Contract | ✅ Present |
| 13 | Bloodlust/Heroism in combat | Research Contract | ✅ Present |
| 14 | Healing Way stacking (maintain 3 stacks on tank) | Research Contract | ✅ Present |
| 15 | Strength of Earth / Mana Spring / Grace of Air / Windfury totems | Research Contract | ✅ Present |
| 16 | Earth Shock interrupt | Research Contract | ✅ Present |
| 17 | Flame Shock / Lightning Bolt / Chain Lightning DPS when idle | Research Contract | ✅ Present |
| 18 | Mana < 5%: Auto-attack only, all spells forbidden | Research Part B | **FIXED** → ManaEmergencyWand at pos 0 |
| 19 | Mana < 15%: No Chain Heal, HW downrank | Research Part B | ✅ Present (SmartHeal select_heal) |
| 20 | Mana < 30%: LHW only | Research Part B | ✅ Present (SmartHeal select_heal) |
| 21 | Chain Heal bounce pet filter | Research Angle 5 | ⚠️ Blocked (requires engine-level group-position API to detect pet in bounce range; not implementable within spec-only scope) |
| 22 | Totem range check at group center | Research Angle 5 | ⚠️ Blocked (requires engine-level totem range/position API — not implementable within spec-only scope) |
| 23 | Water Shield refresh when charges depleted | Research | ✅ Present |
| 24 | Purge dispel in PvP | Research Contract | ✅ Present |

---

## API Validation

| API | File Checked | Valid |
|---|---|---|
| NS.spell_ready | existing usage | ✅ |
| NS.action_matches | existing usage | ✅ |
| NS.action_execute | existing usage | ✅ |
| NS.try_cast | existing usage | ✅ |
| NS.buff_up / buff_remains / buff_stacks | existing usage | ✅ |
| NS.unit_mana_pct / unit_health_pct | existing usage | ✅ |
| core.time | existing usage | ✅ |

---

## Test Results

| Test | Result |
|---|---|
| `test_restoration_healing_way.lua` | ✅ Pass (before + after changes) |
| `luac -p class_sylvanas.lua` | ✅ Pass |
| `luac -p restoration_sylvanas.lua` | ✅ Pass |
| `luac -p schema_sylvanas.lua` | ✅ Pass |
| Code review (deepseek) | ✅ Pass |

---

## Result Summary

- **DB2 fixes:** 6 spells corrected (12 level entries)
- **Behavioral fixes:** ManaEmergencyWand strategy + mana_emergency gates on healing strategies
- **Remaining gaps:** Chain Heal pet filter (Blocked — engine-level change), totem range check (Blocked — requires engine-level totem range API)
- **Syntax:** All files pass `luac -p`
- **Tests:** Existing test passes
