# Vanilla Anniversary APL Audit — Active Effort

**Started:** 2026-06-26
**Goal:** Guide-review all 31 vanilla spec files (`*_vanilla.lua`) against Classic Anniversary (1.15.x) sources
**Method:** Same as TBC round — research → compare → fix → gate → commit
**Plan:** `plans/vanilla-apl-audit-2026-06.md`

## Baseline
- HEAD: a12a91d6 (in sync with origin/master)
- 171 rotation + 11 leveling suites PASS
- Vanilla spell audit: 31 specs clean, 0 tainted
- All 40/40 vanilla files now have Pattern 15 headers

## In Progress
- Phase 1 research complete (4 agents, 30 specs) + Batch 2 web research (6 specs: Hunter BM/MM/Survival, Mage Arcane/Fire/Frost)
- Classic Era DBC extracted (1.15.8.67156, 31,248 spells)
- Research saved to `research_classic_1.15_rotations.md`

## Completed
- [x] Pattern 15 headers added to all 35 vanilla files that lacked them
- [x] Fixed false-positive forbidden-token matches in test_classic_remaining_specs (assassination_vanilla + destruction_vanilla headers)
- [x] Classic Era DBC extracted to `wowheadScrape/dbc_extract/wowsims_classic_era.db`
- [x] **Rotation Scorecard** — 66 specs × 6 content types, auto-computed from codebase
  - `build_tools/compute_scorecard.lua` — scoring engine
  - `SCORECARD.md` — human-readable report (23 S-tier, 38 A-tier, 5 B-tier)
  - `EaxRotations/scorecard_data.json` — machine-readable for CI/integration
  - 5 dimensions: APL, Tests, Features, Content, Spell Validity
  - Content types: Solo, Dungeon, Raid, Arena, Battleground, Leveling
- [x] **README badges + per-class rotation guides** — shipped in repo
  - README shows scorecard summary + links to SCORECARD.md + docs/rotations/
  - 9 auto-generated class guides (TBC + Vanilla priorities, features, content types)
  - `docs/rotations/` no longer gitignored — ships with every release
- [x] **WoWSims upstream tracking infrastructure**
  - `wowsims_classic/` — cloned from https://github.com/wowsims/classic (27 APL JSON files)
  - `build_tools/analyze_wowsims_apl.lua` — parses APL JSON, compares to our rotations
  - `build_tools/sync_tbc_new.sh` — upstream sync script for `tbc-new` (preserves `appsettings.classic_era.json`)

## Deferred
- EaxAutoQuester verification (separate product, ungated)
- B6.2 predictive threshold sliders (design-first, smaller scope)
- Opportunistic spec_kit migrations (only when already editing a file)

## Rules
- One concern per commit
- `luac -p` + full gate after every spec
- Update this file after each spec batch
- Reference: `plans/vanilla-apl-audit-2026-06.md` (full matrix)
