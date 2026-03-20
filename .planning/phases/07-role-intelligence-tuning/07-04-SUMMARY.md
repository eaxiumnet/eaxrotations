---
phase: 07-role-intelligence-tuning
plan: 04
subsystem: api
tags: [lua, dps, threat, interrupts, reactive-runtime]
requires:
  - phase: 07-role-intelligence-tuning
    provides: shared role policy and normalized combat context
provides:
  - shared DPS burst-hold, threat-drop, and cast-abort rules
  - non-healer DPS wiring for common danger-window discipline
  - deterministic DPS role tests covering danger windows and commit aborts
affects: [phase-07-validation, phase-08-benchmark-matrix, dps-specs]
tech-stack:
  added: []
  patterns: [shared dps_risk thresholds, combat_context-backed dps snapshot wiring]
key-files:
  created: [tests/dps_role_behavior_spec.lua, eax_shared/dps_risk.lua, eax_shared/dps_runtime.lua]
  modified: [EAXMageFire/main.lua, EAXWarriorFury/main.lua, EAXWarlockAffliction/main.lua, EAXRogueCombat/main.lua, EAXHunterMarksmanship/main.lua, EAXDruidBalance/main.lua, EAXHunterBeastMastery/main.lua, EAXHunterSurvival/main.lua, EAXMageArcane/main.lua, EAXMageFrost/main.lua, EAXPaladinRetribution/main.lua, EAXPriestShadow/main.lua, EAXRogueAssassination/main.lua, EAXRogueSubtlety/main.lua, EAXShamanElemental/main.lua, EAXShamanEnhancement/main.lua, EAXWarlockDemonology/main.lua, EAXWarlockDestruction/main.lua, EAXWarriorArms/main.lua]
key-decisions:
  - "Use one shared dps_risk module for hold, drop, and abort thresholds so all DPS specs react consistently."
  - "Build live DPS snapshots from combat_context via dps_runtime instead of duplicating threat and danger reads in each spec."
  - "Keep interrupts aggressive by only gating burst, threat drops, and risky cast commits, not interrupt winners."
patterns-established:
  - "Shared DPS risk wiring: main.lua files call dps_risk with dps_runtime.build_snapshot(me, target, encounter_manager, ttd_tracker)."
  - "Caster abort pattern: stop casts only when dps_risk.should_abort_commit(...) confirms rising danger with marginal value."
requirements-completed: [ROLE-01, ROLE-04]
duration: 16 min
completed: 2026-03-20
---

# Phase 7 Plan 4: DPS Risk Rollout Summary

**Shared DPS danger-window burst holds, threat drops, and cast aborts rolled across the non-healer roster with combat-context-backed risk snapshots.**

## Performance

- **Duration:** 16 min
- **Started:** 2026-03-20T21:40:04Z
- **Completed:** 2026-03-20T21:56:48Z
- **Tasks:** 2
- **Files modified:** 22

## Accomplishments
- Added a shared `eax_shared/dps_risk.lua` policy for burst holds, threat drops, and risky cast aborts.
- Added `eax_shared/dps_runtime.lua` so DPS specs reuse normalized combat-context snapshots instead of inventing per-spec danger reads.
- Wired all non-healer DPS specs to respect shared hold logic, with caster aborts and threat-drop surfaces updated where the spec already has them.
- Added deterministic DPS behavior coverage in `tests/dps_role_behavior_spec.lua` and kept reactive wiring parity green.

## Task Commits

Each task was committed atomically:

1. **Task 1 RED: Create failing DPS risk behavior tests** - `57b6666` (test)
2. **Task 1 GREEN: Implement shared DPS risk helper** - `c8a0a7d` (feat)
3. **Task 2: Roll the shared DPS risk helper across all non-healer DPS specs** - `ab2b1b0` (feat)

_Note: Task 1 followed TDD and produced separate RED and GREEN commits._

## Files Created/Modified
- `tests/dps_role_behavior_spec.lua` - Failing-then-passing DPS danger-window behavior proof.
- `eax_shared/dps_risk.lua` - Shared hold, drop-threat, and abort-commit policy.
- `eax_shared/dps_runtime.lua` - Shared combat-context snapshot builder for DPS risk checks.
- `EAXMageFire/main.lua` - Representative caster hold, fade, and stop-cast integration.
- `EAXWarriorFury/main.lua` - Representative melee burst-hold integration.
- `EAXWarlockAffliction/main.lua` - Threat-drop and cast-abort rollout for caster DPS.
- `EAXRogueCombat/main.lua` - Shared burst hold plus Feint-based anti-aggro gating.
- `EAXHunterMarksmanship/main.lua` - Shared burst hold plus Feign Death gating.

## Decisions Made
- Used `combat_context.build(...)` inside `eax_shared/dps_runtime.lua` so per-spec integrations consume the same normalized threat and danger signals as the shared reactive runtime.
- Left interrupt handling untouched while gating only burst and threat-sensitive surfaces, preserving the Phase 7 rule that wipe-risk control stays aggressive.
- Reused existing class-native threat tools such as Fade, Feign Death, Feint, and Vanish instead of inventing new DPS-only escape behavior.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

- Bulk rollout needed a follow-up fix after Hunter burst gating referenced `hold_offense` before it was defined; the ordering was corrected before verification and commit.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- DPS role tuning is in place and verified, with shared behavior ready for Phase 07 plan 05 validation/reporting work.
- Healer and tank summaries already exist, so the remaining role-intelligence work can focus on parity gates and benchmark-visible telemetry.

---
*Phase: 07-role-intelligence-tuning*
*Completed: 2026-03-20*

## Self-Check: PASSED
