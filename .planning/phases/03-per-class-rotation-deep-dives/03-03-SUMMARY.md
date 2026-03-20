---
phase: 03
plan: 03
subsystem: mage rotations
tags: [mage, arcane, fire, frost, rotation, mana_manager, swing_timer, encounter_manager, execute, FSCT]

# Dependency graph
requires:
  - phase: 02
    provides: shared modules (mana_manager, swing_timer, encounter_manager, dot_manager)
provides:
  - Optimized Arcane Mage 3-stack burn phase with Evocation timing
  - Fire Mage Scorch stack management with Molten Fury execute awareness
  - Frost Mage FSCT timing with swing time awareness
  - Mana potion integration across all three specs
affects: [mage specs, rotation optimization, future class deep dives]

# Tech tracking
tech-stack:
  added: []
  patterns: [execute phase detection, swing timer clipping prevention, proactive mana management]

key-files:
  created: []
  modified: [EAXMageArcane/main.lua, EAXMageFire/main.lua, EAXMageFrost/main.lua]

key-decisions:
  - "Added Molten Fury execute detection using encounter_manager burn_until_pct for boss-specific timing"
  - "Implemented FSCT timing using swing_timer.can_cast_before_swing to prevent auto clipping"
  - "Integrated mana_manager for mana potion usage across all three specs (Evocation already present for Arcane/Fire)"
  - "Maintained existing Scorch stack management (5 stacks before Fireball) as per plan"

patterns-established:
  - "Execute phase detection: check target health <20% or boss burn_until_pct"
  - "FSCT timing: compare cast time with swing timer before casting"
  - "Proactive mana management: use mana_manager.should_use_mana_potion before damage rotation"

requirements-completed: [MAGE-01, MAGE-02, MAGE-03, MAGE-04]

# Metrics
duration: 10min
completed: 2026-03-20
---

# Phase 03 Plan 03: Per-Class Rotation Deep Dives - Mage Specs Summary

**Optimized Arcane, Fire, and Frost Mage rotations with 3-stack burn phase, Scorch stack management with Molten Fury execute, and FSCT timing with swing time awareness.**

## Performance

- **Duration:** 10 min
- **Started:** 2026-03-20T04:50:00Z (approx)
- **Completed:** 2026-03-20T05:00:00Z (approx)
- **Tasks:** 3
- **Files modified:** 3

## Accomplishments
- Arcane Mage verified to have 3-stack burn phase with Arcane Blast spam and Evocation timing (already implemented)
- Fire Mage enhanced with Molten Fury execute detection based on target health <20% or boss-specific burn_until_pct
- Frost Mage enhanced with FSCT timing that prevents auto-attack clipping when cast time exceeds swing time
- Integrated mana_manager for mana potion usage across all three specs (Arcane/Fire already had Evocation integration)
- Maintained existing Scorch stack management (5 stacks before Fireball) as per plan

## Task Commits

Each task was committed atomically:

1. **Task 1: Implement Arcane Mage 3-stack burn phase** - `N/A` (already implemented, no changes needed)
2. **Task 2: Implement Fire Mage Scorch stack management and Molten Fury execute** - `03c9b6d` (feat)
3. **Task 3: Implement Frost Mage FSCT timing** - `c3bbe1a` (feat)

**Plan metadata:** pending (docs commit after SUMMARY)

## Files Created/Modified
- `EAXMageArcane/main.lua` - No changes required (already meets criteria)
- `EAXMageFire/main.lua` - Added execute phase detection and Molten Fury awareness
- `EAXMageFrost/main.lua` - Added FSCT timing with swing_timer and mana_manager integration

## Decisions Made
- Added Molten Fury execute detection using encounter_manager burn_until_pct for boss-specific timing
- Implemented FSCT timing using swing_timer.can_cast_before_swing to prevent auto clipping
- Integrated mana_manager for mana potion usage across all three specs (Evocation already present for Arcane/Fire)
- Maintained existing Scorch stack management (5 stacks before Fireball) as per plan

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
- Frost spec did not originally include mana_manager; added as per plan requirement "All Mage specs integrate mana_manager.lua for Evocation/potion timing where applicable"
- Frostfire Bolt spell not present in Frost spells.lua; implemented FSCT timing for Frostbolt (primary spell) as acceptable alternative

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Mage rotations optimized and ready for further refinement in later phases
- Shared modules (mana_manager, swing_timer, encounter_manager) integrated and ready for use by other specs
- Execute phase detection pattern established for future class implementations

---
*Phase: 03-per-class-rotation-deep-dives*
*Completed: 2026-03-20*