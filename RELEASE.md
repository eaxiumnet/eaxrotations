# EAX Rotations v2.5.0

**Released:** 2026-07-08
**Game:** The Burning Crusade Classic (2.5.5) + Classic Era (1.15)
**Download:** [EaxRotations-v2.5.0.zip](https://github.com/eaxiumnet/eaxrotations/releases/tag/v2.5.0)

---

## What's New: Spec Standardization & Polish

**All 29 class specializations have been rebuilt on a shared foundation that makes the rotation engine more reliable, safer, and easier to maintain.**

This is a massive internal refactoring — you won't see a single button change, but every spec is now more robust against edge cases. The result: fewer "the bot just stopped" moments and faster bug fixes in the future.

Full customer-facing changelog: [CHANGELOG_CUSTOMER.md](CHANGELOG_CUSTOMER.md)

### Headline changes since v2.4.0

| Category | Change |
|----------|--------|
| **Bear Druid** | Complete rebuild — pure bear-form tank, no accidental form-shifting |
| **Protection Paladin** | Wowsims-aligned priority: Holy Shield > Judgement > Consecration |
| **Holy Paladin** | Triage-scored healing, downranked Holy Light, Divine Favor + Holy Shock burst combo |
| **Hunter (all 3)** | Auto-shot timer prevents clipping, melee weaving on all specs, Viper/Hawk auto-swap |
| **All specs** | Healthstone automation (<28% HP), Engineering bomb support, Cooldown Planner power-window alignment |
| **Healers** | Stop-Cast Engine cancels overhealing casts, Triage scoring picks best heal target |
| **EaxFishing** | v2.5.1 — Stealth suspicion decays over time, debug logging throttled, suspicion resets on toggle |

### Bug fixes

- Out-of-range spells no longer stall the rotation — they fall through to next priority
- Party buffs and dispels correctly skip range checks
- Bear Druid no longer attempts cat/caster spells in combat
- Pets no longer pull neutral mobs unintentionally
- Switching targets correctly resets Time-To-Death tracking

---

## Quality Gates

| Gate | Result |
|------|--------|
| Rotation test suites | **242/242 pass** |
| Leveling test suites | **13/13 pass** |
| Spell database audit | **61 TBC + 31 Vanilla clean** (verified against DBC 2.5.5.68101) |
| spec_kit compliance | **29/29 specs converted** |

---

## How to Install

1. Download `EaxRotations-v2.5.0.zip` from the link above
2. Delete your current `EaxRotations` folder
3. Extract the new one in its place
4. Your settings carry over automatically — no reset needed

---

## Previous Releases

- **v2.4.0** (July 5) — Wowsims APL alignment for all 15 DPS specs
- **v2.3.15** (July 5) — Cooldown Planner power-window alignment
- **v2.3.12** (July 4) — Healthstone automation + pet handling overhaul

Full history: [CHANGELOG.md](CHANGELOG.md) | Customer-friendly: [CHANGELOG_CUSTOMER.md](CHANGELOG_CUSTOMER.md)
