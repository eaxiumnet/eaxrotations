---
phase: 07-role-intelligence-tuning
plan: 03
subsystem: combat
tags: [lua, tanks, reactive-runtime, threat-control, interrupts]
requires:
  - phase: 06-27-spec-reactive-wiring
    provides: shared reactive adapter contract and retarget runtime
provides:
  - shared tank recovery scoring for peel vs self-save posture
  - tank anti_aggro handlers for warrior, feral, and protection paladin
  - urgency-aware interrupt retargeting toward recovery mobs
affects: [07-role-intelligence-tuning-04, 07-role-intelligence-tuning-05, 08-benchmark-matrix-hardening]
tech-stack:
  added: []
  patterns: [shared tank recovery helper, reactive anti_aggro peel handlers, urgency-aware interrupt retargeting]
key-files:
  created: [eax_shared/tank_recovery.lua, tests/tank_role_behavior_spec.lua]
  modified: [EAXWarriorProtection/main.lua, EAXDruidFeral/main.lua, EAXPaladinProtection/main.lua]
key-decisions:
  - "Keep tank recovery scoring shared while leaving spec files responsible for legal spell execution."
  - "Let tank anti_aggro handlers choose peel or personals from one shared pressure snapshot instead of static target order."
  - "Reuse recovery target selection for interrupt retargeting so dangerous peel mobs outrank the current target when needed."
patterns-established:
  - "Tank posture pattern: shared snapshot scoring picks recovery targets, spec adapters cast class-specific peel/control tools."
  - "Tank control pattern: interrupt branches may retarget to the same recovery mob selected for threat stabilization."
requirements-completed: [ROLE-03, ROLE-04]
duration: 6 min
completed: 2026-03-20
---

# Phase 7 Plan 3: Tank Recovery Summary

**Shared tank recovery scoring now drives peel-vs-defensive posture for Protection Warrior, Feral Druid, and Protection Paladin with deterministic tank behavior coverage.**

## Performance

- **Duration:** 6 min
- **Started:** 2026-03-20T22:40:59+01:00
- **Completed:** 2026-03-20T22:47:58+01:00
- **Tasks:** 2
- **Files modified:** 5

## Accomplishments
- Added `eax_shared/tank_recovery.lua` to score healer/damager peel targets, classify stable windows, and mark self-death pressure.
- Added `tests/tank_role_behavior_spec.lua` to lock threat instability, self-save priority, and stable-window silence.
- Wired Warrior Protection, Feral Druid, and Protection Paladin `anti_aggro` handlers through shared recovery scoring instead of unsupported noops.
- Retargeted tank interrupt/control branches toward urgent recovery mobs when the current target is not the most dangerous caster.

## Task Commits

Each task was committed atomically:

1. **Task 1: Create a shared tank recovery helper for peel-vs-defensive posture** - `ac8972a` (test), `e893604` (feat)
2. **Task 2: Wire tank recovery and urgency-aware control into all tank specs** - `405fc0c` (feat)

## Files Created/Modified
- `eax_shared/tank_recovery.lua` - Shared target scoring and defensive posture helper for tanks.
- `tests/tank_role_behavior_spec.lua` - Deterministic tank recovery coverage for peel priority and stable windows.
- `EAXWarriorProtection/main.lua` - Shared recovery scoring now feeds warrior peel and reactive retargeting.
- `EAXDruidFeral/main.lua` - Guardian recovery branches now choose peel or self-save through the shared helper.
- `EAXPaladinProtection/main.lua` - Protection paladin recovery and control retargeting now use shared tank posture scoring.

## Decisions Made
- Kept threat scoring centralized in `eax_shared/tank_recovery.lua` while letting each spec keep its own spell legality and execution helpers.
- Used the shared pressure snapshot inside `anti_aggro` handlers so tanks can proactively self-save when recovery windows become unsafe.
- Reused recovery target selection for interrupt retargeting to satisfy the urgency-aware control requirement without changing the shared runtime contract.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Tank families now expose shared peel and defensive posture behavior needed by validation and telemetry work.
- Ready for `07-role-intelligence-tuning-04-PLAN.md`.

## Self-Check: PASSED

- Verified `.planning/phases/07-role-intelligence-tuning/07-03-SUMMARY.md` exists on disk.
- Verified task commits `ac8972a`, `e893604`, and `405fc0c` resolve in git history.
