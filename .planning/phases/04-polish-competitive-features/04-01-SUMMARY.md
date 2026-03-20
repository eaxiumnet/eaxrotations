---
phase: 04-polish-competitive-features
plan: 01
subsystem: ui
tags: [lua, hud, telemetry, dps, cooldown, ttd]
requires:
  - phase: 03-per-class-rotation-deep-dives
    provides: Existing per-spec `ttd_tracker.lua` and ESP cast telemetry hooks
provides:
  - Shared combat DPS/HPS meter contract for visual features
  - Shared cooldown tracker for next-action availability timing
  - Shared visual snapshot builder for HUD consumption
affects: [04-polish-competitive-features-02, vis-contract, esp-renderers]
tech-stack:
  added: []
  patterns: [Shared Lua telemetry modules, deterministic snapshot contracts]
key-files:
  created: [eax_shared/dps_meter.lua, eax_shared/cooldown_tracker.lua, eax_shared/visual_state.lua, tests/dps_meter_spec.lua, tests/visual_state_spec.lua]
  modified: []
key-decisions:
  - "Treat TTD >= 999 as unknown and normalize to '--' in shared visual snapshots"
  - "Guard DPS/HPS divide-by-zero when duration is below 0.1 seconds"
patterns-established:
  - "Expose shared visual data through stable field names instead of per-spec HUD logic"
  - "Keep telemetry modules side-effect free except explicit combat/cooldown state updates"
requirements-completed: [VIS-01, VIS-02, VIS-03, VIS-04]
duration: 13 min
completed: 2026-03-20
---

# Phase 04 Plan 01: Shared Visual Telemetry Summary

**Shared Lua telemetry modules now provide DPS/HPS, cooldown, TTD, and aura snapshot data through one stable HUD contract for all specs.**

## Performance

- **Duration:** 13 min
- **Started:** 2026-03-20T12:37:23Z
- **Completed:** 2026-03-20T12:50:50Z
- **Tasks:** 2
- **Files modified:** 5

## Accomplishments
- Added `eax_shared/dps_meter.lua` with combat window accumulation, final snapshot persistence, and safe rate calculations
- Added `eax_shared/cooldown_tracker.lua` for deterministic next-spell cooldown state and remaining-seconds reads
- Added `eax_shared/visual_state.lua` to compose unified HUD payload (`dps`, `hps`, `cooldown_s`, `ttd_s`, `tracked_auras`)
- Added Lua specs validating RED/GREEN behavior for both telemetry and visual snapshot contracts

## Task Commits

Each task was committed atomically:

1. **Task 1: Implement shared DPS/HPS fight meter module** - `6f6f504` (test), `938ebf5` (feat)
2. **Task 2: Implement cooldown + visual snapshot composition modules** - `1d3b35d` (test), `c002634` (feat)

## Files Created/Modified
- `eax_shared/dps_meter.lua` - shared combat-window damage/healing accumulation and snapshot API
- `eax_shared/cooldown_tracker.lua` - shared cooldown tracking and remaining-time API
- `eax_shared/visual_state.lua` - shared HUD snapshot composition from trackers and input fields
- `tests/dps_meter_spec.lua` - Lua behavioral spec for DPS/HPS meter contract
- `tests/visual_state_spec.lua` - Lua behavioral spec for cooldown + visual snapshot contract

## Decisions Made
- Normalized unknown TTD (`nil` or `>=999`) to `"--"` in shared snapshots to keep renderer output display-safe.
- Preserved latest completed combat snapshot after combat end while resetting active combat counters for the next fight window.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- Shared visual telemetry contracts are complete and ready for Phase 04 Plan 02 renderer/main wiring.
- No blockers identified for next plan execution.

---
*Phase: 04-polish-competitive-features*
*Completed: 2026-03-20*

## Self-Check: PASSED
