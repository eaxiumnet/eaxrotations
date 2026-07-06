# EAX Rotations v2.4.0

**Released:** 2026-07-05
**Game:** The Burning Crusade Classic (2.5.5)
**Download:** `dist/EaxRotations-v2.4.0.zip`

---

## What's New: Wowsims APL Alignment

**Every DPS rotation has been audited against the authoritative wowsims theorycrafting APLs and aligned to match optimal play.**

This is a major fidelity release. All 15 DPS specs were compared line-by-line against the `wowsims/tbc-new` and `wowsims/classic` APL JSON files, and either improved to match or verified as already correct.

Full release notes: [RELEASE_NOTES_v2.4.0.md](RELEASE_NOTES_v2.4.0.md)

### Headline improvements

| Spec | Change |
|------|--------|
| **Arcane Mage** | Full burn/conserve rotation: AB3→Frostbolt conserve, PoM at end of Arcane Power, wowsims mana-gem logic |
| **Affliction Warlock** | Drain Soul + Shadowburn execute at <5% HP; Immolate moved from priority #13 → #8 |
| **Hunter (all 3)** | Viper/Hawk thresholds (5%/25%, was 20%/30%); Aimed Shot opener at ≤0.5s |
| **Shadow Priest** | Shadowfiend fight-length-aware timing; **Starshards moved above Mind Flay (was dead code!)** |
| **Fury Warrior** | Opt-in Overpower weaving stance-dance (wowsims "Overpower Weaving" group) |
| **Balance Druid** | Starfire is now primary nuke (was Wrath); mana gem strategy added |
| **Feral Cat** | Powershift threshold 20→25 (closer to wowsims' 30) |
| **Combat Rogue** | Blade Flurry requires Slice and Dice; Adrenaline Rush at ≤40 energy |

Plus a new **Cooldown Planner** shared module that aligns personal offensive CDs (Death Wish, Avenging Wrath, Combustion, etc.) with Bloodlust/Heroism/Drums power windows across all specs.

---

## Quality Gates

| Gate | Result |
|------|--------|
| Rotation test suites | **220/220 pass** |
| Leveling test suites | **13/13 pass** |
| Spell database audit | **61/61 clean** (verified against DBC client 2.5.5.68101) |

---

## How to Install

1. Download `EaxRotations-v2.4.0.zip`
2. Delete your current `EaxRotations` folder
3. Extract the new one in its place
4. Your settings carry over automatically — no reset needed

---

## Previous Release

See [RELEASE_NOTES_v2.3.12.md](RELEASE_NOTES_v2.3.12.md) for the Healthstone automation + pet handling release.
Full history: [CHANGELOG.md](CHANGELOG.md)
