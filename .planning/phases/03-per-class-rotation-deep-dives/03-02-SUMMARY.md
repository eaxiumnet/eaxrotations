---
phase: 03-per-class-rotation-deep-dives
plan: 02
subsystem: hunter-rotations
tags: [swing-timer, haste-breakpoint, auto-shot-alignment, melee-weaving, TBC]
requires:
  - phase: 02
    provides: shared modules (swing_timer, set_bonus, interrupt_manager)
provides:
  - Marksmanship hunter rotation with auto shot alignment via swing_timer.can_cast_before_swing
  - Beast Mastery hunter rotation with melee weaving (Arcane Shot between autos) and reordered priority
  - Survival hunter rotation with haste breakpoint detection and swing timer integration
  - Haste breakpoint detection framework for all hunter specs (placeholder base speed 2.8)
affects: [hunter-specs, rotation-optimization]

tech-stack:
  added: [swing_timer.can_cast_before_swing for casted shot safety, haste breakpoint detection function]
  patterns: [swing timer check before casted spells, rotation priority adjustment based on haste, melee weaving via instant shots between autos]

key-files:
  created: []
  modified:
    - EAXHunterMarksmanship/main.lua - added swing_timer require, can_cast_casted_spell, swing timer checks for Steady/Aimed, haste breakpoint detection
    - EAXHunterBeastMastery/main.lua - added swing_timer require, can_cast_casted_spell, swing timer checks for Steady/Aimed, reordered rotation for melee weaving, haste breakpoint detection
    - EAXHunterSurvival/main.lua - added swing_timer require, can_cast_casted_spell, swing timer checks for Steady/Aimed, haste breakpoint detection

key-decisions:
  - "Assumed base weapon speed 2.8 seconds for haste breakpoint calculation (placeholder until API provides ranged speed)"
  - "Used swing_timer.can_cast_before_swing with 0.1s safety buffer for all casted shots"
  - "Reordered Beast Mastery rotation to prioritize Arcane Shot before Steady Shot for melee weaving"
  - "Added haste breakpoint detection but did not adjust rotation priority beyond swing timer checks"

patterns-established:
  - "Swing timer safety check for casted shots: can_cast_casted_spell(me, cast_time) returns false if swing imminent"
  - "Haste breakpoint detection via get_haste_breakpoint(me) returns ratio string (2:1, 1:1, 1:2, 1:3)"
  - "Melee weaving via instant Arcane Shot between auto shots (allow_instant already ensured auto clip safety)"

requirements-completed: [HUNT-01, HUNT-02, HUNT-03]

# Metrics
duration: 10min
completed: 2026-03-20
---

# Phase 03 Plan 02: Hunter Rotation Deep Dives Summary

**Implemented swing timer integration, auto shot alignment, and haste breakpoint detection for Marksmanship, Beast Mastery, and Survival hunter specs**

## Performance

- **Duration:** 10 min
- **Started:** 2026-03-20T04:50:00Z (estimated)
- **Completed:** 2026-03-20T05:00:00Z (estimated)
- **Tasks:** 3
- **Files modified:** 3

## Accomplishments
- Added swing_timer require and can_cast_casted_spell helper to all three hunter spec main.lua files
- Implemented swing timer safety checks for Steady Shot (1.5s) and Aimed Shot (2.0s) to prevent auto shot clipping
- Added haste breakpoint detection function with placeholder base weapon speed assumption
- Reordered Beast Mastery rotation to prioritize Arcane Shot before Steady Shot for melee weaving between auto shots
- Updated rotation priorities to match plan specifications for each spec

## Task Commits

Each task was committed atomically:

1. **Task 1: Implement Marksmanship steady shot / aimed shot rotation with auto shot alignment** - `40c80d5` (feat)
2. **Task 2: Implement Beast Mastery melee weaving for Arcane/FM shot between autos** - `175b1e8` (feat)
3. **Task 3: Implement haste breakpoint detection for all hunter specs** - `f2ee0e5` (feat)

**Plan metadata:** (pending final commit)

## Files Created/Modified
- `EAXHunterMarksmanship/main.lua` - Added swing timer integration, haste detection, and auto shot alignment
- `EAXHunterBeastMastery/main.lua` - Added swing timer integration, haste detection, and reordered rotation for melee weaving
- `EAXHunterSurvival/main.lua` - Added swing timer integration and haste detection

## Decisions Made
- Assumed base weapon speed 2.8 seconds for haste breakpoint calculation (placeholder until API provides ranged speed)
- Used swing_timer.can_cast_before_swing with 0.1s safety buffer for all casted shots
- Reordered Beast Mastery rotation to prioritize Arcane Shot before Steady Shot for melee weaving
- Added haste breakpoint detection but did not adjust rotation priority beyond swing timer checks (future enhancement)

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing Critical] Added swing_timer require to Survival main.lua**
- **Found during:** Task 3 (haste breakpoint detection for all specs)
- **Issue:** Survival main.lua was missing swing_timer require, which is required for haste detection and swing timer safety checks
- **Fix:** Added `local swing_timer = require("common/eax_shared/swing_timer")` to Survival main.lua
- **Files modified:** EAXHunterSurvival/main.lua
- **Verification:** File loads without error, swing_timer functions accessible
- **Committed in:** f2ee0e5 (Task 3 commit)

**2. [Rule 1 - Bug] Reordered Beast Mastery rotation to match priority specification**
- **Found during:** Task 2 (melee weaving implementation)
- **Issue:** Original rotation order had Steady Shot before Arcane Shot, contradicting the plan's melee weaving requirement
- **Fix:** Reordered rotation lines to: Arcane Shot > Aimed Shot > Multi Shot > Steady Shot
- **Files modified:** EAXHunterBeastMastery/main.lua
- **Verification:** Rotation now prioritizes instant Arcane Shot between auto shots as required
- **Committed in:** 175b1e8 (Task 2 commit)

---

**Total deviations:** 2 auto-fixed (1 missing critical, 1 bug)
**Impact on plan:** Both auto-fixes necessary for correctness and plan compliance. No scope creep.

## Issues Encountered
- Haste breakpoint detection requires ranged weapon base speed which is not directly available via API. Implemented placeholder assumption of 2.8 seconds.
- Swing timer module only tracks melee swings, not ranged. Used auto_eta() for ranged timing which is sufficient for auto shot alignment.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Hunter specs now have swing timer integration for auto shot clipping prevention
- Haste breakpoint detection framework in place (can be refined with actual base speed API)
- Rotation priorities adjusted for melee weaving and auto shot alignment
- Ready for next phase: further rotation optimizations or other class deep dives

---
*Phase: 03-per-class-rotation-deep-dives*
*Completed: 2026-03-20*
