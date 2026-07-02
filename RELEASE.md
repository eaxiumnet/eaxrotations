# EAX Rotations v2.3.2

**Released:** 2026-07-03
**Game:** The Burning Crusade Classic (2.5.5)
**Download:** `dist/EaxRotations-v2.3.2.zip`

---

## What's Fixed

### Holy Priest Crash

**Specs:** Holy Priest (TBC + Classic), Smite Priest (TBC + Classic), Kebab Warrior (TBC + Classic)

Fixed a combat crash that flooded the error log with red text every tick. The rotation now runs silently as intended.

### Dispel Spam

**Specs:** Holy Priest (TBC + Classic), Shadow Priest (Classic)

- Dispel Magic and Cure Disease were firing on party members even when they had no debuffs, wasting mana and GCDs.
- Now only casts when someone actually needs cleansing.
- Shadow Priest self-dispel now only fires when YOU have a magic debuff (Polymorph, Silence, Mind Control, etc.).

---

## Quality Gates

| Gate | Result |
|------|--------|
| Rotation test suites | **219/219 pass** |
| Leveling test suites | **13/13 pass** |
| Spell database audit | **61/61 clean** |

---

## How to Install

1. Download `EaxRotations-v2.3.2.zip`
2. Delete your current `EaxRotations` folder
3. Extract the new one in its place
4. Your settings carry over automatically — no reset needed

---

## Previous Release

See [CHANGELOG.md](CHANGELOG.md) for v2.3.0 features (CLEU swing timer, snap threat, Light's Grace chaining, BoK party buff, configurable DoT windows).
