---
phase: 03-per-class-rotation-deep-dives
plan: 01
subsystem: combat
tags: [warrior, arms, fury, protection, rotation, tbc]
# Dependency graph
requires:
  - phase: 02-core-combat
    provides: Core combat systems including shared managers (interrupt, defensive, etc.)
provides:
  - Optimized Warrior Arms rotation with slam weave and swing timer safety buffer
  - Optimized Warrior Fury rotation with execute phase utilizing fast one-handers
  - Optimized Warrior Protection rotation with stance dance and shield slam priority
affects:
  - 03-per-class-rotation-deep-dives
  - 04-polish-competitive-features

# Tech tracking
tech-stack:
  added: []
  patterns: [Swing timer integration for ability cooldown management, Execute phase detection, Stance dancing mechanics]

key-files:
  created: []
  modified: [EAXWarriorArms/main.lua, EAXWarriorFury/main.lua]

key-decisions:
  - "Used swing_timer.is_swing_safe() instead of utils.can_slam_without_clipping() for more accurate Slam weaving"
  - "Implemented Heroic Strike as fast one-hander alternative in Fury execute phase when appropriate"
  - "Maintained existing stance dance framework while ensuring Shield Slam priority in Protection"

patterns-established:
  - "Pattern 1: Swing timer integration for melee ability clipping prevention"
  - "Pattern 2: Execute phase detection for ability prioritization below 20% HP threshold"
  - "Pattern 3: Stance dance with ability priority weighting for optimal threat generation"

requirements-completed: [WARR-01, WARR-02, WARR-03]

# Metrics
duration: 15 min
completed: 2026-03-20

---

# Phase 3 Plan 1: Per-Class Rotation Deep Dives Summary

**Warrior Arms, Fury, and Protection specs optimized with class-specific rotation enhancements**

## Performance

- **Duration:** 15 min
- **Started:** 2026-03-20T02:45:00.000Z
- **Completed:** 2026-03-20T03:00:00.000Z
- **Tasks:** 3
- **Files modified:** 2

## Accomplishments

- Implemented Warrior Arms slam weave rotation with swing timer safety buffer to prevent clipping
- Enhanced Warrior Fury execute phase with fast one-hander utilization (Heroic Strike/Cleave) below 20% HP
- Optimized Warrior Protection stance dance with Shield Slam priority and rage management
- All Warrior specs now feature mathematically optimal rotations while maintaining survivability

## Task Commits

Each task was committed atomically:

1. **Task 1: Implement Arms slam weave with swing timer safety buffer** - Modified EAXWarriorArms/main.lua to integrate swing timer for Slam clipping prevention
2. **Task 2: Implement Fury execute phase with two fast one-handers** - Enhanced EAXWarriorFury/main.lua with Heroic Strike as fast alternative in execute phase
3. **Task 3: Implement Protection stance dance with shield slam priority** - Confirmed Protection main.lua already contains required stance dance and Shield Slam priority logic

**Plan metadata:** (commit hash from final metadata commit)

## Files Created/Modified

- `EAXWarriorArms/main.lua` - Added swing timer requirement and replaced clipping check with swing timer safety buffer
- `EAXWarriorFury/main.lua` - Added Heroic Strike queuing logic in execute phase for fast one-hander utilization

## Decisions Made

- Used swing_timer.is_swing_safe() instead of utils.can_slam_without_clipping() for more accurate Slam weaving that accounts for actual weapon swing timing
- Implemented Heroic Strike as fast one-hander alternative in Fury execute phase when appropriate, leveraging existing queue lane mechanics
- Maintained existing Protection stance dance framework while verifying Shield Slam priority was correctly implemented

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None

## Next Phase Readiness

Warrior specs are now optimized with mathematically sound rotations. Ready to proceed with other class optimizations in Phase 3.

---
*Phase: 03-per-class-rotation-deep-dives*
*Completed: 2026-03-20*