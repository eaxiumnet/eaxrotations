# Vanilla Anniversary APL Audit — Active Effort

**Started:** 2026-06-26
**Goal:** Guide-review all 31 vanilla spec files (`*_vanilla.lua`) against Classic Anniversary (1.15.x) sources
**Method:** Same as TBC round — research → compare → fix → gate → commit
**Plan:** `plans/vanilla-apl-audit-2026-06.md`

## Baseline
- HEAD: f5743bd4 (in sync with origin/master)
- 171 rotation + 11 leveling suites PASS
- Vanilla spell audit: 31 specs clean, 0 tainted
- Only 5/40 vanilla files have Pattern 15 headers

## In Progress
- (none yet — starting Phase 1 research)

## Completed
- (none yet)

## Deferred
- EaxAutoQuester verification (separate product, ungated)
- B6.2 predictive threshold sliders (design-first, smaller scope)
- Opportunistic spec_kit migrations (only when already editing a file)

## Rules
- One concern per commit
- `luac -p` + full gate after every spec
- Update this file after each spec batch
- Reference: `plans/vanilla-apl-audit-2026-06.md` (full matrix)
