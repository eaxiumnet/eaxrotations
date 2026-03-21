---
phase: 08-benchmark-matrix-hardening
plan: 01
subsystem: testing
tags: [lua, benchmark, matrix, telemetry, validation]
requires:
  - phase: 07-role-intelligence-tuning
    provides: shared reactive runtime telemetry and role-aware benchmark fields
provides:
  - strict benchmark threshold constants and canonical 27-spec role mapping
  - shared matrix row and verdict helpers for benchmark and validation tools
  - threat throughput and behavior KPI counters in shared runtime snapshots
affects: [tools/dps_benchmark.lua, tools/rotation_validation.lua, phase-08-plan-02, phase-08-plan-03]
tech-stack:
  added: []
  patterns: [shared Lua benchmark policy modules, runtime-fed KPI counters, deterministic assert-style matrix specs]
key-files:
  created: [tools/benchmark_thresholds.lua, tools/benchmark_matrix.lua, tests/benchmark_matrix_spec.lua]
  modified: [eax_shared/dps_meter.lua, eax_shared/reactive_runtime.lua, tests/dps_meter_spec.lua, tests/reactive_runtime_spec.lua]
key-decisions:
  - "Keep matrix verdict math in shared helper modules so benchmark and validation entrypoints cannot drift."
  - "Treat mock evidence as schema_only and never release-passing, while exposing near_fail only as informational pass metadata."
  - "Derive tank TPS and behavior KPI counters from shared runtime ticks instead of reopening all 27 spec files."
patterns-established:
  - "Benchmark verdicts come from shared row -> spec summary -> matrix summary helpers."
  - "Shared runtime ticks own matrix KPI accumulation through dps_meter helpers and counters."
requirements-completed: [MATX-01, MATX-02]
duration: 7 min
completed: 2026-03-21
---

# Phase 08 Plan 01: Benchmark Matrix Hardening Summary

**Shared benchmark verdict helpers plus expanded snapshot telemetry for DPS, HPS, TPS, and behavior KPI scoring.**

## Performance

- **Duration:** 7 min
- **Started:** 2026-03-20T23:56:57Z
- **Completed:** 2026-03-21T00:03:53Z
- **Tasks:** 2
- **Files modified:** 7

## Accomplishments
- Added `tools/benchmark_thresholds.lua` with strict matrix constants and the canonical 27-spec role/metric catalog.
- Added `tools/benchmark_matrix.lua` with reusable row building, per-spec verdicts, matrix aggregation, and blocker formatting.
- Expanded shared snapshots to carry `threat_total`, `tps`, `sample_count`, and behavior KPI counters from the shared runtime tick lane.

## Task Commits

Each task was committed atomically:

1. **Task 1: Define the strict matrix threshold and verdict helpers** - `bdc4334` (test), `7d3eb8e` (feat)
2. **Task 2: Persist threat throughput and behavior KPI counters in the shared meter** - `b69f9a5` (test), `a0c8ed3` (feat)

**Plan metadata:** pending

## Files Created/Modified
- `tools/benchmark_thresholds.lua` - strict matrix constants plus canonical spec role and primary metric mapping
- `tools/benchmark_matrix.lua` - shared row construction, per-spec summaries, full-matrix aggregation, and blocker formatting
- `tests/benchmark_matrix_spec.lua` - deterministic mock/live/variance/near_fail/full-matrix coverage for the shared verdict engine
- `eax_shared/dps_meter.lua` - threat throughput accumulation, sample counting, and behavior KPI snapshot fields
- `eax_shared/reactive_runtime.lua` - per-tick KPI feeding for threat, noop unsupported, unsafe skip, fail-safe, and reactive events
- `tests/dps_meter_spec.lua` - meter assertions for new throughput fields and reset behavior
- `tests/reactive_runtime_spec.lua` - runtime assertions for per-tick KPI accumulation and fail-safe handling

## Decisions Made
- Kept verdict math in shared helper modules so later benchmark and validation plans can reuse one deterministic contract.
- Left `near_fail` as operator-facing metadata only; it never upgrades a failing row, and mock evidence always remains `schema_only`.
- Computed TPS from shared `threat_pct` deltas inside `dps_meter` so all 27 specs inherit the same metric path without spec-local edits.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Preserve combat start time while recording threat samples**
- **Found during:** Task 2 (Persist threat throughput and behavior KPI counters in the shared meter)
- **Issue:** `record_threat_sample()` rewrote `started_at` when combat began at timestamp `0`, collapsing `duration_s` and forcing `tps` to zero.
- **Fix:** Removed the `started_at` rewrite so threat sampling only updates threat totals and sample counters.
- **Files modified:** `eax_shared/dps_meter.lua`
- **Verification:** `rtk lua tests/dps_meter_spec.lua && rtk lua tests/reactive_runtime_spec.lua`
- **Committed in:** `a0c8ed3` (part of task commit)

---

**Total deviations:** 1 auto-fixed (1 bug)
**Impact on plan:** The auto-fix was required for correct TPS calculation and stayed inside the planned snapshot telemetry scope.

## Issues Encountered
- Adjusted the new runtime counter tests to start combat before asserting meter accumulation; the counter contract belongs to the combat window.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- Plan 02 can now consume shared matrix helpers instead of re-implementing verdict math in the benchmark CLI.
- Plan 03 can enforce the release gate against the same shared row and matrix summaries.

## Self-Check

PASSED - `08-01-SUMMARY.md` exists and task commits `bdc4334`, `7d3eb8e`, `b69f9a5`, and `a0c8ed3` are present in git history.

---
*Phase: 08-benchmark-matrix-hardening*
*Completed: 2026-03-21*
