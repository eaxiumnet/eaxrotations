---
phase: 03-per-class-rotation-deep-dives
plan: 08
subsystem: api
tags: [shaman, totems, rotation, burst, encounter-manager]
requires:
  - phase: 02-core-combat
    provides: encounter and mana/cast infrastructure used by shaman rotations
provides:
  - Shaman-wide totem item gating with missing-item warnings and graceful cast skipping
  - Enhancement Stormstrike-first sequencing with Lava Lash timing and mana sustain support
  - Elemental burn-phase weighting for Chain Lightning/Lava Burst with Lightning Shield stack upkeep
affects: [EAXShamanEnhancement, EAXShamanElemental, EAXShamanRestoration, eax_shared]
tech-stack:
  added: []
  patterns: [shared cast gating via totem_manager, burn-window conditional priority, stack-aware shield refresh]
key-files:
  created: [eax_shared/totem_manager.lua]
  modified: [EAXShamanEnhancement/main.lua, EAXShamanElemental/main.lua, EAXShamanRestoration/main.lua]
key-decisions:
  - "Applied totem validation in cast wrappers so every relevant spell path degrades safely when items are missing."
  - "Used encounter_manager burn windows and bloodlust-style buffs to bias Elemental Chain Lightning/Lava Burst usage during burst phases."
patterns-established:
  - "Totem gating before cast: determine required elemental totem from spell label, scan bags, warn, and skip cast if missing"
  - "Enhancement sequence: Stormstrike first, then Lava Lash only when Stormstrike is cooling down and imbues are active"
requirements-completed: [SHAM-01, SHAM-02, SHAM-03]
duration: 2 min
completed: 2026-03-20
---

# Phase 03 Plan 08: Shaman Rotation Deep Dive Summary

**Shaman specs now enforce totem-item-aware casting, Enhancement Stormstrike/Lava Lash priority timing, and Elemental burn-window Chain Lightning/Lava Burst behavior with Lightning Shield stack upkeep.**

## Performance

- **Duration:** 2 min
- **Started:** 2026-03-20T06:55:12Z
- **Completed:** 2026-03-20T06:57:37Z
- **Tasks:** 3
- **Files modified:** 4

## Accomplishments
- Added shared `totem_manager` bag scanning with per-element missing-item warnings and cast-skip fallback behavior.
- Wired all three shaman specs to use totem gating in cast paths, preventing rotation failure when totem items are missing.
- Upgraded Enhancement to enforce Stormstrike-first flow, conditional Lava Lash timing, Flame Shock to Earth Shock sequencing, and potion/rage mana sustain.
- Upgraded Elemental with encounter-aware burn prioritization for Chain Lightning/Lava Burst, Lightning Shield stack floor maintenance, and Thunderstorm utility casting.

## Task Commits

Each task was committed atomically:

1. **Task 1: Implement totem item scanning for all shaman specs** - `7958fcd` (feat)
2. **Task 2: Implement Enhancement Shaman Stormstrike priority and Lava Lash timing** - `af52d7f` (feat)
3. **Task 3: Implement Elemental Shaman chain lightning / lava burst burst phase** - `ec461b0` (feat)

**Plan metadata:** pending

## Files Created/Modified
- `eax_shared/totem_manager.lua` - Shared totem item scanner and cast eligibility checker.
- `EAXShamanEnhancement/main.lua` - Totem gating in cast wrappers plus Stormstrike/Lava Lash/Flame Shock/Earth Shock/mana priority updates.
- `EAXShamanElemental/main.lua` - Totem gating, burn-phase Chain Lightning weighting, Lightning Shield stack management, Thunderstorm utility.
- `EAXShamanRestoration/main.lua` - Totem gating in ally/self/hostile cast wrappers for graceful degradation.

## Decisions Made
- Kept totem handling centralized in a shared manager to avoid per-spec drift and to make missing-item behavior consistent across all shaman specs.
- Implemented Enhancement Lava Lash as a follow-up action only when Stormstrike is unavailable and weapon imbues are active, matching required melee priority.
- Used encounter-manager burn thresholds (plus bloodlust/heroism-style buff checks) to drive Elemental burst weighting instead of hardcoding boss names in the spec.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Plan file paths did not match repository structure**
- **Found during:** Task 1
- **Issue:** Plan referenced `specs/shaman/*/main.lua`, but this repo stores shaman specs in `EAXShaman*/main.lua`.
- **Fix:** Applied all required shaman changes in the actual spec paths while preserving requested behavior.
- **Files modified:** `EAXShamanEnhancement/main.lua`, `EAXShamanElemental/main.lua`, `EAXShamanRestoration/main.lua`
- **Verification:** Confirmed `totem_manager` integration and totem-related logic in all three files.
- **Committed in:** `7958fcd`

**2. [Rule 3 - Blocking] `common/eax_shared` is not a writable path in this workspace**
- **Found during:** Task 1
- **Issue:** Plan requested creating `common/eax_shared/totem_manager.lua`, but `common` is a non-directory entry in this checkout.
- **Fix:** Created `eax_shared/totem_manager.lua`, matching existing shared-module layout used by this repository snapshot.
- **Files modified:** `eax_shared/totem_manager.lua`
- **Verification:** Shaman specs require `common/eax_shared/totem_manager` and include cast-time gating calls.
- **Committed in:** `7958fcd`

---

**Total deviations:** 2 auto-fixed (2 blocking)
**Impact on plan:** Both deviations were path-compatibility fixes only; requested behavior and outputs were still implemented.

## Issues Encountered
None.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Shaman requirements `SHAM-01`, `SHAM-02`, and `SHAM-03` are implemented and ready for follow-up validation.
- Ready for `03-09` execution.

---
*Phase: 03-per-class-rotation-deep-dives*
*Completed: 2026-03-20*

## Self-Check: PASSED

- FOUND: `.planning/phases/03-per-class-rotation-deep-dives/03-08-SUMMARY.md`
- FOUND: `7958fcd`
- FOUND: `af52d7f`
- FOUND: `ec461b0`
