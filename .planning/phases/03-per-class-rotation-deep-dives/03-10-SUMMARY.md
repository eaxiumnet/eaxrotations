---
phase: 03-per-class-rotation-deep-dives
plan: 10
subsystem: combat
tags: [warrior, fury, execute, swing-timer, dual-wield]

# Dependency graph
requires:
  - phase: 03-per-class-rotation-deep-dives
    provides: Fury baseline execute threshold and rotation scaffolding from 03-01
provides:
  - Fury execute branch with explicit fast-1H detection below 20% target HP
  - Swing-safe execute and queue gating via shared swing_timer helpers
affects: [03-VERIFICATION, WARR-02, warrior-fury]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - Explicit dual-wield mainhand/offhand speed classification for execute lanes
    - Shared swing_timer safety guard for execute cast and queue windows

key-files:
  created: []
  modified:
    - EAXWarriorFury/main.lua

key-decisions:
  - "Treat fast-1H execute as true only when both mainhand and offhand speeds resolve and are <= 2.0s"
  - "Gate execute-phase cast/queue decisions through swing_timer safety checks to avoid clipping white swings"

patterns-established:
  - "Warrior execute branches can split by dual-wield speed profile while preserving non-fast fallback behavior"
  - "Use swing_timer.is_swing_safe/can_cast_before_swing for melee weave safety decisions in execute windows"

requirements-completed: [WARR-02]

# Metrics
duration: 3 min
completed: 2026-03-20
---

# Phase 03 Plan 10: Fury Execute Gap Closure Summary

**Fury execute now uses explicit dual-wield fast-1H detection below 20% HP and routes execute timing through shared swing-timer safety checks.**

## Performance

- **Duration:** 3 min
- **Started:** 2026-03-20T11:57:09Z
- **Completed:** 2026-03-20T12:00:53Z
- **Tasks:** 2
- **Files modified:** 1

## Accomplishments
- Added deterministic mainhand/offhand speed reads and fast-1H predicate (`<= 2.0` both hands) in Fury.
- Wired Fury execute timing to `swing_timer.is_swing_safe` / `swing_timer.can_cast_before_swing`.
- Implemented explicit fast-1H execute lane with non-fast fallback behavior in the below-20% branch.

## Task Commits

Each task was committed atomically:

1. **Task 1: Add Fury execute prerequisites (swing timer + weapon speed checks)** - `729eb54` (feat)
2. **Task 2: Enforce swing-safe fast-1H execute lane below 20%** - `51b2ffb` (feat)

## Files Created/Modified
- `EAXWarriorFury/main.lua` - Added fast-1H execute setup detection and swing-safe execute lane gating.

## Decisions Made
- Used direct weapon-speed reads from existing unit APIs (`get_attack_time`, `get_offhand_attack_time`) so unresolved speeds cleanly fall back to non-fast behavior.
- Applied swing safety checks only in execute-phase decision points so non-execute rotation flow remains unchanged.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Read-first path mismatch for shared swing_timer module**
- **Found during:** Task 1 (Add Fury execute prerequisites)
- **Issue:** Plan listed `common/eax_shared/swing_timer.lua`, but repository contains `eax_shared/swing_timer.lua`.
- **Fix:** Read and used the existing `eax_shared/swing_timer.lua` implementation while wiring Fury to the required module path string in code.
- **Files modified:** None (execution-context adaptation only)
- **Verification:** Confirmed `EAXWarriorFury/main.lua` now requires `common/eax_shared/swing_timer` and references shared APIs.
- **Committed in:** `729eb54` (part of task commit)

---

**Total deviations:** 1 auto-fixed (1 blocking)
**Impact on plan:** No scope expansion; adaptation was required to complete planned wiring against current repo layout.

## Issues Encountered
None

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- WARR-02 code gap is closed in Fury and ready for verifier re-check.
- Remaining phase blocker is independent (LOCK-02 verification state in `03-VERIFICATION.md`).

---
*Phase: 03-per-class-rotation-deep-dives*
*Completed: 2026-03-20*

## Self-Check: PASSED

- FOUND: `.planning/phases/03-per-class-rotation-deep-dives/03-10-SUMMARY.md`
- FOUND: `729eb54`
- FOUND: `51b2ffb`
