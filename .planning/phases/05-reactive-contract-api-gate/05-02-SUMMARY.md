---
phase: 05-reactive-contract-api-gate
plan: 02
subsystem: api
tags: [lua, validation, api-gate, allowlist]
requires:
  - phase: 04-polish-competitive-features
    provides: validation entrypoint and regression checklist patterns
provides:
  - generated API allowlist derived from local `.api` files
  - fail-closed runtime API hard gate for behavior code paths
  - unified validation output that blocks on API gate failures
affects: [phase-05, validation, release-gates]
tech-stack:
  added: []
  patterns: [generated allowlist artifact, fail-closed runtime scan, single-command validation gate]
key-files:
  created: [tools/api_surface_extract.lua, tools/api_allowlist.lua, tools/api_hard_gate.lua, .planning/phases/05-reactive-contract-api-gate/05-API-GATE-CHECKLIST.md, .planning/phases/05-reactive-contract-api-gate/05-02-SUMMARY.md]
  modified: [tests/api_surface_extract_spec.lua, tests/api_hard_gate_spec.lua, tests/rotation_validation_spec.lua, tools/rotation_validation.lua]
key-decisions:
  - "Generate and commit `tools/api_allowlist.lua` from repo `.api` files so validation stays deterministic and local-first."
  - "Keep `tools/rotation_validation.lua` as the single blocking command and append API gate status after spec validation."
patterns-established:
  - "Validation tools emit deterministic PASS/FAIL lines for grep-friendly release checks."
  - "Runtime API enforcement scans only behavior paths: `EAX*/main.lua`, `EAX*/utils.lua`, `EAX*/eax_utils.lua`, and `eax_shared/*.lua`."
requirements-completed: [APIG-01, APIG-02, APIG-03]
duration: 9 min
completed: 2026-03-20
---

# Phase 05 Plan 02: API Gate Summary

**Generated API allowlist tooling plus a fail-closed runtime gate wired into the standard rotation validation command.**

## Performance

- **Duration:** 9 min
- **Started:** 2026-03-20T15:24:57Z
- **Completed:** 2026-03-20T15:34:00Z
- **Tasks:** 2
- **Files modified:** 8

## Accomplishments
- Added `tools/api_surface_extract.lua` and generated `tools/api_allowlist.lua` from repo `.api` sources.
- Added `tools/api_hard_gate.lua` with runtime-path scanning, allowlist loading, and banned-pattern failure reporting.
- Extended `tools/rotation_validation.lua` so standard validation now reports and blocks on API hard gate failures.
- Added Phase 05 checklist and regression specs covering allowlist generation, hard-gate behavior, and validation integration.

## Task Commits

Each task was committed atomically:

1. **Task 1: Generate the API allowlist and fail-closed hard gate** - `5b1eb9e` (test), `80fceeb` (feat)
2. **Task 2: Wire the API gate into release-blocking validation flow** - `a022c9d` (test), `2700e10` (feat)

_Note: This plan used TDD red-green commits for both tasks._

## Files Created/Modified
- `tools/api_surface_extract.lua` - Extracts callable API surface entries from `.api` files and writes the generated allowlist.
- `tools/api_allowlist.lua` - Generated allowlist artifact consumed by the runtime API gate.
- `tools/api_hard_gate.lua` - Scans runtime behavior files and fails on banned runtime patterns or missing allowlist state.
- `tools/rotation_validation.lua` - Runs spec validation and API hard-gate enforcement in one command.
- `tests/api_surface_extract_spec.lua` - Verifies allowlist extraction and generated artifact contents.
- `tests/api_hard_gate_spec.lua` - Verifies fail-closed API gate output and runtime-only scan scope.
- `tests/rotation_validation_spec.lua` - Verifies validation entrypoint integration and checklist presence.
- `.planning/phases/05-reactive-contract-api-gate/05-API-GATE-CHECKLIST.md` - Blocking sign-off checklist for allowlist, scan, and unified validation.

## Decisions Made
- Generated allowlist data stays repo-local and deterministic instead of hand-maintained so API validation tracks `.api` changes automatically.
- API enforcement stays inside `tools/rotation_validation.lua` so release readiness still hinges on one canonical validation command.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Plan 02 is complete and Phase 05 now has its API gate in place.
- Phase 05 still needs `05-reactive-contract-api-gate-01-PLAN.md` to finish the shared reactive contract work.

## Self-Check: PASSED

- Verified `.planning/phases/05-reactive-contract-api-gate/05-02-SUMMARY.md` exists on disk.
- Verified task commits `5b1eb9e`, `80fceeb`, `a022c9d`, and `2700e10` exist in git history.
