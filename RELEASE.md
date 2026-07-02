# EAX Rotations v2.3.0

**Released:** 2026-07-02
**Game:** The Burning Crusade Classic (2.5.5)
**Download:** `dist/EaxRotations-v2.3.0.zip`

---

## What's New

### Server-Authoritative Swing Timer (CLEU)

**Specs:** Retribution Paladin, Enhancement Shaman, Arms Warrior, Fury Warrior, Kebab Warrior

Frame-polling swing prediction is replaced with direct Combat Log Event tracking. The rotation reads the exact server swing timestamp.

- Seal twisting judged against real server data
- Diagnostics report `PERFECT`, `LATE`, or `PHANTOM` with millisecond precision
- Falls back to native prediction if CLEU API is unavailable

### Instant Snap Threat on Pull

**Specs:** Protection Paladin, Protection Warrior

Hooks `PLAYER_REGEN_DISABLED` to fire the opener the exact frame combat begins. Gives Judgement / Shield Slam a ~50-100ms head start before DPS opens.

### Light's Grace Chaining

**Spec:** Holy Paladin

When Light's Grace has less than 2.5 seconds remaining, queues another Holy Light automatically to keep the 0.5-second cast-time reduction rolling.

### Blessing of Kings Party Buff

**Spec:** Protection Paladin

Out-of-combat strategy scans party members and applies Blessing of Kings to anyone missing the buff. Gated by setting (default enabled).

### Configurable DoT Refresh Windows

**Spec:** Shadow Priest

| Setting | Range | Default |
|---------|-------|---------|
| VT Refresh Window | 0.5s - 3.0s | 1.5s |
| SW:P Refresh Window | 0.5s - 3.0s | 1.5s |

Fully backward compatible. Existing installs keep the 1.5s default.

---

## Quality Gates

| Gate | Result |
|------|--------|
| Rotation test suites | **219/219 pass** |
| Leveling test suites | **13/13 pass** |
| luac -p syntax check | **438 files clean** |
| Vanilla spell audit | **31/31 clean** |
| Sylvanas DBC spell audit | **61/61 clean** |

---

## Files in Release

```
EaxRotations/
  classes/          (29 spec files + leveling + vanilla)
  core/
  docs/
  shared/           (new: swing_diagnostics_sylvanas.lua)
  tests/            (new: test_swing_diagnostics.lua, test_melee_cleu_wiring.lua,
                     test_holy_lg_chaining.lua, test_protection_bok_party.lua,
                     test_shadow_refresh_windows.lua)
  header.lua        (version 2.3.0)
  main_sylvanas.lua
  core_sylvanas.lua
  CHANGELOG.md
  README.md
  CONTRIBUTING.md
  LICENSE.md
```

---

## Upgrade Notes

- Download the new zip and replace your existing `EaxRotations` folder
- All existing settings carry over unchanged
- No breaking changes. All new features are additive with safe fallbacks.
