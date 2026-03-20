---
phase: 04-polish-competitive-features
plan: 05
subsystem: testing
tags: [lua, validation, benchmark, quality-gate]
requires:
  - phase: 04-polish-competitive-features
    provides: Shared visual and automation wiring from plans 02 and 04
provides:
  - Rotation validation script with shared wiring and syntax checks across all 27 specs
  - DPS benchmark script with dry-run output schema for comparable snapshots
  - Regression checklist matrix tracking Visual HUD, Automation, Validation Script, and Benchmark status for 27 specs
affects: [qual-gates, phase-04-signoff, release-readiness]
tech-stack:
  added: []
  patterns:
    - Lua tools expose callable module functions and CLI entrypoints
    - Deterministic PASS/FAIL line output for grep-friendly automation
key-files:
  created:
    - tools/rotation_validation.lua
    - tools/dps_benchmark.lua
    - .planning/phases/04-polish-competitive-features/04-REGRESSION-CHECKLIST.md
    - tests/rotation_validation_spec.lua
    - tests/dps_benchmark_spec.lua
    - tests/regression_checklist_spec.lua
  modified:
    - tools/rotation_validation.lua
    - tests/rotation_validation_spec.lua
key-decisions:
  - "Validation scope is pinned to the 27 canonical combat specs to avoid false failures from non-rotation plugins."
  - "Benchmark dry-run emits deterministic mock snapshots so output remains comparable across runs."
patterns-established:
  - "Quality tools print stable PASS:/FAIL: lines and exit non-zero on failed gates."
  - "Phase checklists track spec-level gate progress in a single markdown matrix artifact."
requirements-completed: [QUAL-01, QUAL-02, QUAL-03]
duration: 11 min
completed: 2026-03-20
---

# Phase 04 Plan 05: Validation, benchmark, and checklist summary

**Phase 04 now has a runnable validation gate, deterministic benchmark output, and a full 27-spec regression checklist for repeatable quality verification.**

## Performance

- **Duration:** 11 min
- **Started:** 2026-03-20T13:07:31Z
- **Completed:** 2026-03-20T13:18:55Z
- **Tasks:** 2
- **Files modified:** 6

## Accomplishments
- Added `tools/rotation_validation.lua` with `validate_spec` and `main` to enforce import + syntax requirements per spec.
- Added `tools/dps_benchmark.lua` with `run_benchmark(args)` and `--dry-run` schema output containing `spec`, `damage_total`, `healing_total`, `dps`, `hps`, and `duration_s`.
- Added `.planning/phases/04-polish-competitive-features/04-REGRESSION-CHECKLIST.md` with all 27 specs and required verification columns.

## Task Commits

Each task was committed atomically:

1. **Task 1: Create rotation validation framework script (RED)** - `138b0ee` (test)
2. **Task 1: Create rotation validation framework script (GREEN)** - `97f3fc8` (feat)
3. **Task 2: Create DPS benchmark tool and regression checklist artifact (RED)** - `3d5ffc2` (test)
4. **Task 2: Create DPS benchmark tool and regression checklist artifact (GREEN)** - `f1d7dba` (feat)

**Plan metadata:** pending

## Files Created/Modified
- `tools/rotation_validation.lua` - 27-spec validator with deterministic per-spec PASS/FAIL output and non-zero failure exit.
- `tools/dps_benchmark.lua` - benchmark runner with `run_benchmark(args)` and dry-run schema output.
- `.planning/phases/04-polish-competitive-features/04-REGRESSION-CHECKLIST.md` - 27-spec matrix for Visual HUD, Automation, Validation Script, Benchmark, and notes.
- `tests/rotation_validation_spec.lua` - TDD assertion for module shape and required entrypoints.
- `tests/dps_benchmark_spec.lua` - TDD assertion for benchmark module and `run_benchmark`.
- `tests/regression_checklist_spec.lua` - checklist contract test (columns + exact 27 rows).

## Decisions Made
- Kept quality-gate validation focused on the 27 combat spec directories so unrelated plugin folders do not break Phase 04 signoff.
- Standardized benchmark dry-run with deterministic synthetic snapshots to make baseline output comparable between runs and environments.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed CLI entrypoint detection for scripts invoked with arguments**
- **Found during:** Task 2 verification
- **Issue:** `tools/dps_benchmark.lua --dry-run` did not execute because the script treated any non-nil top-level `...` as module-load mode.
- **Fix:** Switched both tools to explicit module-name checks (`tools.dps_benchmark` / `tools.rotation_validation`) so CLI invocation always runs, including with arguments.
- **Files modified:** tools/dps_benchmark.lua, tools/rotation_validation.lua
- **Verification:** `lua tools/rotation_validation.lua` and `lua tools/dps_benchmark.lua --dry-run` both execute and print expected output.
- **Committed in:** f1d7dba

---

**Total deviations:** 1 auto-fixed (1 bug)
**Impact on plan:** Bug fix was necessary to make the planned CLI verification commands runnable; no scope creep.

## Issues Encountered
None.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- QUAL-01 through QUAL-03 artifacts are present and executable.
- Phase 04 has complete plan coverage and is ready for phase close-out flow.

---
*Phase: 04-polish-competitive-features*
*Completed: 2026-03-20*

## Self-Check: PASSED
- Found summary file at `.planning/phases/04-polish-competitive-features/04-05-SUMMARY.md`.
- Verified task commits exist: `138b0ee`, `97f3fc8`, `3d5ffc2`, `f1d7dba`.
