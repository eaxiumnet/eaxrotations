---
phase: 06-27-spec-reactive-wiring
plan: 01
subsystem: api
tags: [lua, reactive-runtime, adapters, telemetry, targeting]
requires:
  - phase: 05-reactive-contract-api-gate
    provides: shared reactive runtime bridge, one-winner telemetry, and 27-spec runtime wiring
provides:
  - shared adapter execution with handled/noop/unsafe reactive telemetry
  - urgent retarget and restore orchestration for representative live specs
  - representative DPS, healer, and tank adapter wiring for Phase 06 rollout
affects: [phase-06-plan-02, shared-runtime, validation, representative-specs]
tech-stack:
  added: []
  patterns: [explicit reactive adapter contract, reactive_status telemetry, urgent retarget restore]
key-files:
  created: []
  modified: [eax_shared/reactive_runtime.lua, eax_shared/dps_meter.lua, tools/dps_benchmark.lua, tests/reactive_runtime_spec.lua, EAXWarriorFury/main.lua, EAXPriestHoly/main.lua, EAXWarriorProtection/main.lua]
key-decisions:
  - "Keep reactive winner selection in the shared runtime, but require per-spec adapters to declare explicit handlers or noop=unsupported for all six branches."
  - "Expose reactive_status as handled/noop_unsupported/skipped_unsafe/none so unsupported or unsafe winners stay visible in telemetry and benchmarks."
  - "Let the shared runtime own urgent retarget and snap-back behavior while representative specs only resolve targets and invoke existing cast lanes."
patterns-established:
  - "Reactive adapter pattern: declare one local reactive_adapter, pass it into reactive_runtime.update_tick, and wire unsupported categories with exact noop markers."
  - "Representative integration pattern: DPS and tank specs reuse defensive/interrupt lanes, healer specs resolve ally-save targets through existing heal helpers."
requirements-completed: [WIRE-01, WIRE-02]
duration: 6 min
completed: 2026-03-20
---

# Phase 06 Plan 01: Reactive Adapter Runtime Summary

**Shared reactive ticks now execute explicit spec adapters, publish handled/noop/unsafe status telemetry, and prove urgent snap-back wiring in Fury, Holy, and Protection specs.**

## Performance

- **Duration:** 6 min
- **Started:** 2026-03-20T18:31:09Z
- **Completed:** 2026-03-20T18:37:03Z
- **Tasks:** 2
- **Files modified:** 7

## Accomplishments
- Extended `eax_shared/reactive_runtime.lua` from telemetry-only winner reporting into a live adapter executor with retarget/restore state.
- Added `reactive_status` to shared meter and benchmark output so handled, unsupported, unsafe, and absent winners are distinguishable.
- Wired representative DPS, healer, and tank specs to the shared adapter contract without replacing their existing cast lanes.

## Task Commits

Each task was committed atomically:

1. **Task 1: Extend the shared runtime contract with explicit adapter execution and noop telemetry** - `5b7e977` (test), `8d916ab` (feat)
2. **Task 2: Prove the adapter pattern in representative DPS, healer, and tank specs** - `b536e2b` (feat)

**Plan metadata:** Pending final docs commit

## Files Created/Modified
- `eax_shared/reactive_runtime.lua` - validates adapter contracts, executes winning handlers, and restores prior targets after urgent retargets.
- `eax_shared/dps_meter.lua` - persists `reactive_status` alongside the existing reactive telemetry fields.
- `tools/dps_benchmark.lua` - includes `reactive_status` in schema and live/mock benchmark rows.
- `tests/reactive_runtime_spec.lua` - covers handled, explicit noop, and skipped-unsafe runtime outcomes with stub adapters.
- `EAXWarriorFury/main.lua` - adds a conservative DPS reactive adapter for self-defensives and interrupts.
- `EAXPriestHoly/main.lua` - adds healer save-target and stop-cast adapter wiring.
- `EAXWarriorProtection/main.lua` - adds tank interrupt/recovery target wiring with urgent hostile retarget support.

## Decisions Made
- Kept the shared runtime responsible for action execution boundaries so the 27 spec files can stay adapter-style instead of reimplementing retarget logic independently.
- Limited representative adapters to existing spell lanes and explicit unsupported noops so Phase 06 proves contract parity before wider role tuning.
- Used direct target resolution callbacks per spec so healers can save allies and tanks can peel dangerous casters while still snapping back to the prior main target.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Passed live handler context into adapter callbacks**
- **Found during:** Task 2 (Prove the adapter pattern in representative DPS, healer, and tank specs)
- **Issue:** The new spec adapters needed the active player/state context to call existing cast lanes without duplicating closure-specific wiring inside each runtime caller.
- **Fix:** Extended `reactive_runtime` handler payloads with `me` and `state` so representative spec adapters can invoke existing managers and restore logic safely.
- **Files modified:** `eax_shared/reactive_runtime.lua`
- **Verification:** `rtk lua tests/reactive_runtime_spec.lua && rtk lua tests/reactive_runtime_wiring_spec.lua`
- **Committed in:** `b536e2b`

---

**Total deviations:** 1 auto-fixed (1 blocking)
**Impact on plan:** The fix stayed inside the shared runtime contract and enabled the planned representative wiring without adding scope.

## Issues Encountered

- The first RED-phase test revision failed because the helper wrapper discarded return values; fixing the test harness produced the intended runtime-contract failure before GREEN work started.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Shared runtime execution and representative adapters are in place, so Plan 02 can roll the same contract across the remaining canonical specs.
- Reactive parity validation can now expand from bridge-only wiring to full adapter coverage in the blocking validation flow.

## Self-Check: FAILED

- Verified `.planning/phases/06-27-spec-reactive-wiring/06-01-SUMMARY.md` exists on disk.
- MISSING: Verified task commit `5b7e977` exists in git history.
- MISSING: Verified task commit `8d916ab` exists in git history.
- MISSING: Verified task commit `b536e2b` exists in git history.
