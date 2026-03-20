---
phase: 04-polish-competitive-features
plan: 03
subsystem: automation
tags: [vendor, consumables, mount, lua, shared-modules]
requires:
  - phase: 04-polish-competitive-features
    provides: visual telemetry modules from plan 01 used by phase-wide wiring
provides:
  - shared vendor repair and grey-sell automation module
  - shared consumables policy module for combat and OOC usage
  - shared mount state manager with combat dismount and OOC mounting
affects: [04-polish-competitive-features-04, AUTO-01, AUTO-02, AUTO-03, AUTO-04]
tech-stack:
  added: []
  patterns: [shared-manager extraction, throttle-guarded automation actions]
key-files:
  created:
    - eax_shared/vendor_automation.lua
    - eax_shared/consumables_manager.lua
    - eax_shared/mount_manager.lua
  modified: []
key-decisions:
  - "Use core.input.use_container_item with bag scan to sell quality-0 items only."
  - "Use core.input.dismount immediately on combat and mount only when out of combat and stationary."
patterns-established:
  - "Automation helpers use per-action timestamp throttles to prevent repeated calls in one frame window."
  - "Shared managers accept (me, menu, utils) signatures for drop-in spec integration."
requirements-completed: [AUTO-01, AUTO-02, AUTO-03, AUTO-04]
duration: 6 min
completed: 2026-03-20
---

# Phase 4 Plan 03: Automation Core Summary

**Shared vendor, consumable, and mount automation managers now provide reusable AUTO-01..AUTO-04 behavior for all specs.**

## Performance

- **Duration:** 6 min
- **Started:** 2026-03-20T12:37:16Z
- **Completed:** 2026-03-20T12:43:46Z
- **Tasks:** 2
- **Files modified:** 3

## Accomplishments
- Added `vendor_automation.lua` with repair flow (`get_total_repair_cost` + `repair_all_items`) and grey-only bag selling.
- Added `consumables_manager.lua` with combat potion, out-of-combat food/drink, and flask upkeep entry points.
- Added `mount_manager.lua` with explicit combat dismount and out-of-combat stationary mount branches.

## Task Commits

Each task was committed atomically:

1. **Task 1: Create shared vendor automation module (repair + sell greys)** - `45d9c96` (feat)
2. **Task 2: Create shared consumables and mount managers** - `172e682` (feat)

**Plan metadata:** pending

## Files Created/Modified
- `eax_shared/vendor_automation.lua` - Shared repair and grey-item selling helpers with throttling.
- `eax_shared/consumables_manager.lua` - Shared combat/OOC consumable policy functions.
- `eax_shared/mount_manager.lua` - Shared mount and dismount state transition function.

## Decisions Made
- Used documented bag slot action (`core.input.use_container_item`) for vendor selling so only quality `0` items are targeted.
- Mounted through configured spell/item when available, then fallback to first usable collection mount index.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
Ready for `04-polish-competitive-features-04-PLAN.md` to wire these shared modules across all specs.

---
*Phase: 04-polish-competitive-features*
*Completed: 2026-03-20*

## Self-Check: PASSED

- Verified summary and all three module files exist on disk.
- Verified task commits `45d9c96` and `172e682` exist in git history.
