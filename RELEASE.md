# EAX Rotations v2.3.3

**Released:** 2026-07-03
**Game:** The Burning Crusade Classic (2.5.5)
**Download:** `dist/EaxRotations-v2.3.3.zip`

---

## What's Fixed

### Settings Nil-Guard Sweep

**Specs:** Priest Holy (TBC + Classic), Priest Smite (TBC + Classic), Priest Discipline (Classic), Druid Restoration (Classic), Paladin Holy (Classic), Druid/Warlock/Priest Middleware (TBC)

Fixed a class of crashes where the rotation tried to read a setting (like "Use Power Word: Shield" or "Use Circle of Healing") before confirming the settings table was ready. This could happen during API hiccups, loading screens, or when switching specs rapidly.

Every settings read across all affected specs is now guarded — no more `attempt to index a nil value (field 'settings')` errors.

---

## Quality Gates

| Gate | Result |
|------|--------|
| Rotation test suites | **219/219 pass** |
| Leveling test suites | **13/13 pass** |
| Spell database audit | **61/61 clean** |

---

## How to Install

1. Download `EaxRotations-v2.3.3.zip`
2. Delete your current `EaxRotations` folder
3. Extract the new one in its place
4. Your settings carry over automatically — no reset needed

---

## Previous Release

See [CHANGELOG.md](CHANGELOG.md) for v2.3.2 fixes (Holy Priest crash + dispel spam) and v2.3.0 features (CLEU swing timer, snap threat, Light's Grace chaining, BoK party buff, configurable DoT windows).
