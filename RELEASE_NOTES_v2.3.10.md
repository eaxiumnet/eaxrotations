# EAX Rotations v2.3.10

**Released:** 2026-07-04
**Game:** The Burning Crusade Classic (2.5.5)
**Download:** `dist/EaxRotations-v2.3.10.zip`

---

## What's Fixed

### Hunter Aspect Manager Missing Middleware Strategies

**Spec:** Hunter (all specs — Beast Mastery, Marksmanship, Survival)

Fixed a critical load-time error that prevented the entire Hunter rotation module from initializing:

```
attempt to call field 'viper_middleware_strategy' (a nil value)
```

The `aspect_manager_sylvanas.lua` shared module had state-helper functions (`should_hawk`, `should_viper`) but was missing the `viper_middleware_strategy()` and `hawk_middleware_strategy()` strategy-builder functions that `hunter/middleware_sylvanas.lua` injected directly into the strategies array.

**What this means:**
- Hunter rotations now load and execute correctly
- Aspect of the Viper auto-switch when mana is low works again
- Aspect of the Hawk auto-switch when mana recovers works again
- Both strategies respect the `settings.auto_aspect` toggle and mana thresholds

---

## Quality Gates

| Gate | Result |
|------|--------|
| Rotation test suites | **219/219 pass** |
| Leveling test suites | **13/13 pass** |
| Spell database audit | **61/61 clean** |

---

## How to Install

1. Download `EaxRotations-v2.3.10.zip`
2. Delete your current `EaxRotations` folder
3. Extract the new one in its place
4. Your settings carry over automatically — no reset needed

---

## Previous Release

See [CHANGELOG.md](CHANGELOG.md) for v2.3.9 fixes (Shadow Priest Mind Flay opener) and earlier changes.
