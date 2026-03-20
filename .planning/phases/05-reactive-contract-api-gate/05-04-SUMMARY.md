---
phase: 05-reactive-contract-api-gate
plan: 04
subsystem: api
tags: [lua, api-gate, validation, allowlist, runtime-contract]
requires:
  - phase: 05-reactive-contract-api-gate
    provides: generated allowlist enforcement and blocking validation entrypoint
provides:
  - strict runtime API enforcement for documented root namespaces and object methods
  - authoritative API surface updates for currently used runtime calls
  - unified validation proof that temp gate violations block while clean repo validation passes
affects: [phase-05, validation, release-gates, api-surface]
tech-stack:
  added: []
  patterns: [documented-namespace API enforcement, receiver-scoped method validation, generated allowlist from authoritative stubs]
key-files:
  created: [.planning/phases/05-reactive-contract-api-gate/05-04-SUMMARY.md]
  modified: [tools/api_hard_gate.lua, tools/api_allowlist.lua, .api/core.lua, .api/game_object.lua, tests/api_hard_gate_spec.lua, tests/rotation_validation_spec.lua]
key-decisions:
  - "Strict hard-gate enforcement applies to documented API namespaces and runtime object receivers, not arbitrary Lua builtins or repo-local helper DSLs."
  - "The authoritative `.api` surface now includes missing runtime aliases and helper entrypoints so clean validation can pass honestly under the generated allowlist."
patterns-established:
  - "Runtime gate regressions must prove both a failing temp-fixture path and a clean-repo success path."
  - "When runtime code relies on legitimate engine calls absent from `.api`, update the authoritative stubs and regenerate `tools/api_allowlist.lua` before tightening enforcement."
requirements-completed: [APIG-01, APIG-02]
duration: 19 min
completed: 2026-03-20
---

# Phase 05 Plan 04: API Gate Gap-Closure Summary

**Allowlist-backed runtime enforcement now blocks real undocumented API calls while the current repo passes cleanly under a regenerated authoritative `.api` surface.**

## Performance

- **Duration:** 19 min
- **Started:** 2026-03-20T15:53:53Z
- **Completed:** 2026-03-20T16:12:45.584Z
- **Tasks:** 2
- **Files modified:** 6

## Accomplishments

- Tightened `tools/api_hard_gate.lua` so rooted runtime calls and selected object methods fail closed against the generated allowlist.
- Added regression coverage for banned patterns, disallowed rooted calls, disallowed object methods, and clean handling of Lua builtins outside gate scope.
- Expanded `.api` stubs and regenerated `tools/api_allowlist.lua` so the current runtime codebase passes strict validation honestly.
- Proved `tools/rotation_validation.lua` blocks on temporary API-gate violations and returns `0` again after the fixture is removed.

## Task Commits

Each task was committed atomically:

1. **Task 1: Enforce the generated allowlist against rooted calls and colon methods** - `eae69ba` (test), `fa1576d` (feat)
2. **Task 2: Prove unified validation still blocks on allowlist violations** - `932df16` (test), `b5997ce` (fix)

_Note: This plan used TDD red-green commits for both tasks._

## Files Created/Modified

- `tools/api_hard_gate.lua` - Enforces documented root namespaces and scoped object-method checks against the generated allowlist.
- `tools/api_allowlist.lua` - Regenerated allowlist including newly documented runtime API entries.
- `.api/core.lua` - Documents missing inventory, input, navigation, object-manager, and spell-book runtime entrypoints.
- `.api/game_object.lua` - Documents missing game object method aliases used by current runtime code.
- `tests/api_hard_gate_spec.lua` - Covers rooted/method violations plus builtin calls that should remain out of scope.
- `tests/rotation_validation_spec.lua` - Proves temporary API violations block validation and clean repo validation returns success afterward.

## Decisions Made

- Scoped strict rooted-call enforcement to documented API namespaces so local project modules and Lua standard libraries are not misclassified as engine API violations.
- Scoped colon-method enforcement to likely runtime object receivers and filled in missing `.api` method aliases so repo validation reflects actual engine-surface compliance instead of parser false positives.

## Deviations from Plan

### Approved Architectural Change

**1. [Rule 4 - Architectural] Scope strict enforcement to documented API namespaces and runtime object receivers**
- **Found during:** Task 2 (unified validation proof)
- **Issue:** Enforcing every rooted namespace and every colon call made the clean repo fail on Lua builtins and repo-local helper DSLs, which are not the intended runtime engine surface.
- **Decision:** User selected Option 1 to keep strict enforcement honest by expanding the authoritative `.api` surface and refining scanner scope.
- **Fix:** Added namespace/receiver scoping in `tools/api_hard_gate.lua`, documented missing legitimate runtime calls in `.api`, and regenerated `tools/api_allowlist.lua`.
- **Files modified:** `tools/api_hard_gate.lua`, `.api/core.lua`, `.api/game_object.lua`, `tools/api_allowlist.lua`
- **Verification:** `rtk lua tests/api_hard_gate_spec.lua`, `rtk lua tests/rotation_validation_spec.lua`, `rtk lua tools/api_hard_gate.lua`, `rtk lua tools/rotation_validation.lua`
- **Committed in:** `b5997ce`

---

**Total deviations:** 0 auto-fixed, 1 user-approved architectural change
**Impact on plan:** The approved scope refinement was necessary to keep strict `@.api` enforcement accurate for the real runtime surface. No hidden failures remain in the clean repo path.

## Issues Encountered

- Initial full-call enforcement surfaced dozens of existing false positives from Lua builtins, local helper DSLs, and legitimate engine aliases missing from `.api`; resolving that required a user-approved scope decision plus authoritative surface updates.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Phase 05 now has honest fail-closed API enforcement backed by the generated allowlist and a passing clean-repo validation path.
- Ready for `05-reactive-contract-api-gate-05-PLAN.md` or broader Phase 05 completion work.

## Self-Check: PASSED

- Verified `.planning/phases/05-reactive-contract-api-gate/05-04-SUMMARY.md` exists on disk.
- Verified task commits `eae69ba`, `fa1576d`, `932df16`, and `b5997ce` exist in git history.
