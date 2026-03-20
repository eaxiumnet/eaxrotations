---
phase: 03-per-class-rotation-deep-dives
plan: 11
subsystem: warlock-rotations
tags: [warlock, destruction, conflagrate, immolate, lock-02]
requires:
  - phase: 03-per-class-rotation-deep-dives
    provides: gap findings in 03-VERIFICATION.md for LOCK-02
provides:
  - Explicit Immolate-proc readiness predicate for Destruction Conflagrate
  - Immediate Conflagrate consumption ordering in Destruction core rotation
affects: [03-VERIFICATION.md, phase-03-gap-closure, warlock-destruction]
tech-stack:
  added: []
  patterns: [named readiness predicate gating, proc-window-first cast ordering]
key-files:
  created: [.planning/phases/03-per-class-rotation-deep-dives/03-11-SUMMARY.md]
  modified: [EAXWarlockDestruction/main.lua]
key-decisions:
  - "Use a dedicated is_conflagrate_proc_ready predicate to centralize spell-ready, target validity, lockout, and Immolate checks."
  - "Prioritize try_conflagrate before try_shadowfury to enforce immediate proc-window consumption."
patterns-established:
  - "Proc-sensitive finishers should use named predicate helpers instead of inline cooldown-only branches."
requirements-completed: [LOCK-02]
duration: 2 min
completed: 2026-03-20
---

# Phase 03 Plan 11: Destruction Conflagrate Gap Closure Summary

**Destruction now gates Conflagrate through an explicit Immolate-proc readiness predicate and consumes the proc window immediately in rotation order.**

## Performance

- **Duration:** 2 min
- **Started:** 2026-03-20T11:56:38Z
- **Completed:** 2026-03-20T11:59:08Z
- **Tasks:** 2
- **Files modified:** 1

## Accomplishments
- Added `is_conflagrate_proc_ready` in `EAXWarlockDestruction/main.lua` to require spell readiness, valid target, no cast lockout, and active Immolate state before Conflagrate.
- Refactored `try_conflagrate` to rely on the explicit predicate and removed the previous TODO/cooldown-fallback behavior.
- Reordered the core rotation branch to attempt `try_conflagrate` before `try_shadowfury`, enforcing immediate proc-window consumption.

## Task Commits

Each task was committed atomically:

1. **Task 1: Add explicit Immolate-proc Conflagrate readiness predicate** - `f786ecd` (fix)
2. **Task 2: Remove cooldown fallback path and enforce immediate proc consumption** - `4b29b52` (fix)

**Plan metadata:** `(pending)`

## Files Created/Modified
- `EAXWarlockDestruction/main.lua` - Added explicit proc-aware Conflagrate readiness gating and immediate consumption ordering.
- `.planning/phases/03-per-class-rotation-deep-dives/03-11-SUMMARY.md` - Plan execution record for LOCK-02 closure.

## Decisions Made
- Introduced a named readiness predicate instead of inline checks so proc gating stays deterministic and easy to verify.
- Enforced Conflagrate before Shadowfury in the damage sequence to avoid delaying Immolate-proc consumption.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- LOCK-02 implementation gap is closed in code and ready for re-verification.
- Remaining phase blocker is WARR-02 from plan 03-10.

## Self-Check: PASSED
- FOUND: `.planning/phases/03-per-class-rotation-deep-dives/03-11-SUMMARY.md`
- FOUND: `f786ecd`
- FOUND: `4b29b52`

---
*Phase: 03-per-class-rotation-deep-dives*
*Completed: 2026-03-20*
