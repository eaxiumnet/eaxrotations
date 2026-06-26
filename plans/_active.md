# Vanilla Anniversary APL Audit — Active Effort

**Started:** 2026-06-26
**Goal:** Guide-review all 31 vanilla spec files (`*_vanilla.lua`) against Classic Anniversary (1.15.x) sources
**Method:** Same as TBC round — research → compare → fix → gate → commit
**Plan:** `plans/vanilla-apl-audit-2026-06.md`

## Baseline
- HEAD: f0e0ec4a (in sync with origin/master)
- 171 rotation + 11 leveling suites PASS
- Vanilla spell audit: 31 specs clean, 0 tainted
- All 40/40 vanilla files now have Pattern 15 headers

## In Progress
- Background agent cleaning remaining 14 vanilla files with UnavailableClassic references
- Phase 1 research complete (4 agents, 30 specs) + Batch 2 web research (6 specs)
- Classic Era DBC extracted (1.15.8.67156, 31,248 spells)
- Research saved to `research_classic_1.15_rotations.md`

## Completed
- [x] Pattern 15 headers added to all 35 vanilla files that lacked them
- [x] Fixed false-positive forbidden-token matches in test_classic_remaining_specs
- [x] Classic Era DBC extracted to `wowheadScrape/dbc_extract/wowsims_classic_era.db`
- [x] DBC verified: Water Elemental (31687), Ice Lance (30455), Icy Veins (12472) — **NOT in Classic Era**
- [x] **TBC-only dead code removed from 8 vanilla specs:**
  - Hunter BM: Steady Shot, Kill Command, Misdirection
  - Hunter Survival: Steady Shot, Kill Command, Misdirection, Aspect of Viper, pre_steady_leveling
  - Hunter MM: BestialWrath
  - Mage Arcane: Frostbolt primary nuke (was FireBlast spam), FireBlast now moving-only
  - Mage Fire: Dragon's Breath, Blast Wave
  - Mage Frost: Water Elemental, Ice Lance
  - Paladin Retribution: Avenging Wrath, Crusader Strike
  - Rogue Assassination: Cloak of Shadows, Shiv, Envenom, Mutilate, Deadly Throw
  - Warlock Destruction: Incinerate, Soulshatter, dead AoE placeholder
- [x] **Rotation Scorecard** — 66 specs × 6 content types, auto-computed from codebase
- [x] **README badges + per-class rotation guides** — shipped in repo
- [x] **WoWSims upstream tracking infrastructure** (wowsims_classic clone + APL analyzer + sync script)

## Deferred
- EaxAutoQuester verification (separate product, ungated)
- B6.2 predictive threshold sliders (design-first, smaller scope)
- Opportunistic spec_kit migrations (only when already editing a file)

## Rules
- One concern per commit
- `luac -p` + full gate after every spec
- Update this file after each spec batch
- Reference: `plans/vanilla-apl-audit-2026-06.md` (full matrix)
