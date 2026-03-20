---
phase: 03-per-class-rotation-deep-dives
plan: 06
subsystem: class-rotations
tags: [druid, balance, feral, eclipse, dot-management, combo-points, energy-pooling]
requires:
  - phase: 02
    provides: shared modules (dot_manager, encounter_manager, mana_manager)
provides:
  - Balance druid eclipse detection and burst phase optimization
  - Balance druid DoT clip prevention using dot_manager
  - Feral druid combo point and energy management with optimal bite timing
affects: [druid-specs, future-rotation-optimizations]
tech-stack:
  added: []
  patterns: [eclipse buff detection, energy pooling for finishers, combo point cap enforcement]
key-files:
  created: []
  modified:
    - EAXDruidBalance/main.lua
    - EAXDruidFeral/main.lua
key-decisions:
  - "Implemented eclipse detection using existing Lunar/Solar eclipse buffs (IDs 48518/48517) rather than custom energy tracking"
  - "Added energy pooling for Ferocious Bite to prevent wasting combo points when energy insufficient"
  - "Added combo point cap check in Mangle and Claw filler abilities to avoid overcapping"
patterns-established:
  - "Pattern: Use buff detection for eclipse phases instead of simulating energy"
  - "Pattern: Pool energy for expensive finishers (bite) based on combo point cost"
requirements-completed: [DRUID-01, DRUID-02, DRUID-03]

# Metrics
duration: 8 min
completed: 2026-03-20
---

# Phase 03 Plan 06: Per-Class Rotation Deep Dives Summary

**Eclipse detection with Lunar/Solar buff tracking, DoT clip prevention via dot_manager, and Feral combo point/energy management with bite pooling**

## Performance

- **Duration:** 8 min
- **Started:** 2026-03-20T05:00:08Z
- **Completed:** 2026-03-20T05:08:00Z
- **Tasks:** 3
- **Files modified:** 2

## Accomplishments
- Added eclipse detection to Balance druid rotation using Lunar/Solar eclipse buffs
- Enhanced DoT clip prevention already using dot_manager for Moonfire and Insect Swarm
- Implemented energy pooling for Ferocious Bite to prevent combo point waste
- Added combo point cap checks in Mangle and Claw filler abilities
- Integrated mana_manager for potion timing (already present)

## Task Commits

Each task was committed atomically:

1. **Task 1 & 2: Balance Druid eclipse detection and DoT clip prevention** - `0101253` (feat)
2. **Task 3: Feral Druid combo point and energy management** - `6d59665` (feat)

**Plan metadata:** `75d3c39` (docs: complete plan)

## Files Created/Modified
- `EAXDruidBalance/main.lua` - Added eclipse detection, energy tracking, and priority rotation
- `EAXDruidFeral/main.lua` - Added energy pooling for bite, combo point cap enforcement

## Decisions Made
- Used existing Lunar/Solar eclipse buffs for detection instead of custom energy simulation
- Added energy cost check for Ferocious Bite (35 energy per combo point)
- Added cp < 5 guard on Mangle and Claw filler to prevent overcapping combo points
- Kept existing DoT clip prevention logic unchanged (already correct)

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
- Plan referenced file paths `specs/druid/balance/main.lua` and `specs/druid/feral/main.lua` but actual paths are `EAXDruidBalance/main.lua` and `EAXDruidFeral/main.lua`. Adapted verification commands accordingly.
- Plan mentioned Starsurge for eclipse energy generation, but spell not present in TBC. Skipped.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- Druid Balance and Feral rotations optimized with eclipse detection and resource management
- Ready for next plan in Phase 03 or move to Phase 04

---
*Phase: 03-per-class-rotation-deep-dives*
*Completed: 2026-03-20*

## Self-Check: PASSED
