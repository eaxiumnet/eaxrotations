---
phase: 03-per-class-rotation-deep-dives
plan: 09
subsystem: api
tags: [rogue, rotation, combat, subtlety, assassination]
requires:
  - phase: 03-per-class-rotation-deep-dives
    provides: Existing Rogue spec frameworks and shared encounter policy module
provides:
  - Subtlety rear-arc Backstab/Hemorrhage decision flow with Shadowstep reposition support
  - Slice and Dice refresh timing controls across all Rogue specs
  - Combat Blade Flurry multi-target on/off control and synced finisher windows
affects: [rogue, encounter_manager, finisher_logic]
tech-stack:
  added: []
  patterns:
    - Shared encounter_manager helpers for positional and nearby-enemy checks
    - SnD timing window policy: refresh <=2s, avoid clipping >10s
key-files:
  created: []
  modified:
    - EAXRogueSubtlety/main.lua
    - EAXRogueCombat/main.lua
    - EAXRogueAssassination/main.lua
    - eax_shared/encounter_manager.lua
key-decisions:
  - "Use encounter_manager as the authoritative source for behind-target and enemy-count checks."
  - "Standardize Slice and Dice refresh windows across Rogue specs to reduce clipping waste."
  - "Tie Combat Killing Spree usage to active Blade Flurry for multi-target burst alignment."
patterns-established:
  - "Rogue finishers consume 3-5 combo points based on SnD urgency and encounter pressure."
  - "Blade Flurry should be toggled both on (2+ enemies) and off (<2 enemies) for energy control."
requirements-completed: [ROGUE-01, ROGUE-02, ROGUE-03]
duration: 6 min
completed: 2026-03-20
---

# Phase 03 Plan 09: Rogue rotation deep-dive summary

**Subtlety now enforces rear-arc Backstab/Hemorrhage logic, all Rogue specs use stricter Slice and Dice refresh windows, and Combat toggles Blade Flurry by target count for efficient AoE pressure.**

## Performance

- **Duration:** 6 min
- **Started:** 2026-03-20T06:44:16Z
- **Completed:** 2026-03-20T06:50:16Z
- **Tasks:** 3
- **Files modified:** 4

## Accomplishments
- Added shared encounter helpers (`is_target_behind`, `enemy_count_in_range`) and wired Subtlety to use them for Backstab vs Hemorrhage choice.
- Implemented SnD timing in all Rogue specs to refresh only at expiration or <=2s remaining while blocking >10s clips and enforcing 3-5 CP spending.
- Updated Combat to enable Blade Flurry at 2+ targets, disable it below 2 targets, force 5-CP Eviscerate during BF windows, and gate Killing Spree to BF uptime.

## Task Commits

Each task was committed atomically:

1. **Task 1: Implement Subtlety Rogue Backstab / Hemorrhage rotation** - `bbb24cb` (feat)
2. **Task 2: Implement Rogue Slice and Dice refresh timing** - `fe0674d` (feat)
3. **Task 3: Implement Combat Rogue Blade Flurry on multi-target** - `e8119b2` (feat)

**Plan metadata:** pending

## Files Created/Modified
- `EAXRogueSubtlety/main.lua` - Added behind-target routing, Shadowstep positioning gate, and Subtlety finisher combo cap normalization.
- `EAXRogueCombat/main.lua` - Added Blade Flurry on/off target-count toggles and BF-aware finisher/burst gating.
- `EAXRogueAssassination/main.lua` - Added standardized SnD refresh-window and combo-point gating.
- `eax_shared/encounter_manager.lua` - Added shared rear-arc and enemy-count helper APIs.

## Decisions Made
- Encounter-position and nearby-enemy logic is centralized in `encounter_manager` to keep spec files consistent and simpler.
- SnD refresh policy is fixed around outcome thresholds (<=2s urgent, >10s clip guard) instead of per-spec arbitrary refresh windows.
- Combat burst sequencing prioritizes synchronized AoE windows by requiring active Blade Flurry for Killing Spree.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Plan file paths did not match repository layout**
- **Found during:** Task 1 (initial file load)
- **Issue:** Plan referenced `specs/rogue/*` and `common/eax_shared/*`, but repository uses `EAXRogue*` and `eax_shared/*` paths.
- **Fix:** Applied plan intent to actual repository paths and kept module usage semantics aligned with plan goals.
- **Files modified:** EAXRogueSubtlety/main.lua, EAXRogueCombat/main.lua, EAXRogueAssassination/main.lua, eax_shared/encounter_manager.lua
- **Verification:** Grep checks confirmed required rotation and encounter_manager patterns in actual source paths.
- **Committed in:** bbb24cb, fe0674d, e8119b2

**2. [Rule 1 - Bug] Fixed malformed interrupt condition blocks in Rogue mains**
- **Found during:** Task 1 and Task 2 edits
- **Issue:** Subtlety and Assassination had broken multi-line `interrupt_manager.should_interrupt` expressions that caused parse errors.
- **Fix:** Replaced malformed expressions with valid interrupt checks that preserve encounter policy gating.
- **Files modified:** EAXRogueSubtlety/main.lua, EAXRogueAssassination/main.lua
- **Verification:** LSP parse errors cleared after rewriting condition blocks.
- **Committed in:** bbb24cb, fe0674d

---

**Total deviations:** 2 auto-fixed (1 blocking, 1 bug)
**Impact on plan:** Deviations were required to execute plan intent in the real repository and maintain runnable rotation files.

## Issues Encountered
None.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Rogue rotation requirements for this plan are implemented and committed per task.
- Ready for subsequent Phase 03 plans or final phase close-out flow.

---
*Phase: 03-per-class-rotation-deep-dives*
*Completed: 2026-03-20*

## Self-Check: PASSED
- Found summary file at `.planning/phases/03-per-class-rotation-deep-dives/03-09-SUMMARY.md`.
- Verified task commits exist: `bbb24cb`, `fe0674d`, `e8119b2`.
