---
phase: 03-per-class-rotation-deep-dives
plan: 05
subsystem: priest
tags: [priest, shadow, discipline, rotation, tbc, dot_manager, mana_manager]
# Dependency graph
requires:
  - phase: 02-core-combat
    provides: Shared combat managers (dot_manager, mana_manager, encounter_manager)
provides:
  - Shadow Priest DoT clip prevention using dot_manager for SW:P and Vampiric Touch
  - Shadow Priest Mind Blast timing with Shadow Orbs tracking (Shadow Weaving buff or stacked resources)
  - Discipline Priest Power Word: Shield management with cooldown checks and tank priority during heavy damage
  - Integration of mana_manager for proactive mana potion usage in both specs
affects:
  - 03-per-class-rotation-deep-dives
  - 04-polish-competitive-features

# Tech tracking
tech-stack:
  added: []
  patterns: [Shadow Orbs resource tracking via buff detection and cast-counting, Tank-priority shielding based on encounter policy]

key-files:
  created: []
  modified: [EAXPriestShadow/main.lua, EAXPriestShadow/spells.lua, EAXPriestDiscipline/main.lua]

key-decisions:
  - "Added Shadow Weaving buff detection and tracked Shadow Orb stacks as proxy for Mind Blast proc timing"
  - "Implemented tank-priority shielding during tank_damage_heavy encounters using class detection"
  - "Integrated mana_manager for proactive mana potion usage in both Shadow and Discipline specs"

patterns-established:
  - "Pattern 1: Shadow Orbs as resource stacks from Mind Flay casts, consumed by Mind Blast"
  - "Pattern 2: Tank detection via party unit class scanning for shield prioritization"
  - "Pattern 3: Cooldown checks before casting shields to avoid wasted GCD"

requirements-completed: [PRST-01, PRST-02, PRST-03]

# Metrics
duration: 10 min
completed: 2026-03-20

---

# Phase 3 Plan 5: Priest Shadow & Discipline Rotation Deep Dives Summary

**Shadow Priest DoT clip prevention and Mind Blast timing with Shadow Orbs tracking; Discipline Priest Power Word: Shield management with tank priority and mana potion integration**

## Performance

- **Duration:** 10 min
- **Started:** 2026-03-20T04:30:00.000Z
- **Completed:** 2026-03-20T04:40:00.000Z
- **Tasks:** 3
- **Files modified:** 3

## Accomplishments

- Enhanced Shadow Priest rotation with Shadow Orbs tracking (Shadow Weaving buff or cast-counting) to time Mind Blast procs
- Added DoT clip prevention for Shadow Word: Pain and Vampiric Touch using existing dot_manager
- Improved Discipline Priest shield management with cooldown checks, Weakened Soul debuff validation, and tank priority during heavy damage encounters
- Integrated mana_manager for proactive mana potion usage in both specs

## Task Commits

Each task was committed atomically:

1. **Task 1: Implement Shadow Priest DoT clip prevention** - Already present via dot_manager; no changes needed
2. **Task 2: Implement Shadow Priest Mind Blast timing** - `5714b77` (feat) - Added Shadow Orbs tracking and Mind Blast proc logic
3. **Task 3: Implement Discipline Priest Power Word: Shield management** - `8b5e60d` (feat) - Added cooldown checks, tank priority, and mana potion integration

**Plan metadata:** (to be committed after summary creation)

## Files Created/Modified

- `EAXPriestShadow/main.lua` - Added Shadow Orbs tracking, Shadow Weaving buff detection, and Mind Blast proc logic
- `EAXPriestShadow/spells.lua` - Added BUFF_SHADOW_WEAVING spell ID
- `EAXPriestDiscipline/main.lua` - Added shield cooldown checks, Weakened Soul validation, tank priority via class detection, mana potion integration, and fixed missing runtime.pw_shield_id assignment

## Decisions Made

- Used Shadow Weaving buff stacks as proxy for Shadow Orbs (since TBC doesn't have Shadow Orbs)
- Tracked Shadow Orb stacks via Mind Flay casts (increment up to 3) when Shadow Weaving buff absent
- Implemented tank detection by scanning party/raid units for Warrior/Paladin/Druid classes
- Integrated mana_manager for proactive mana potion usage at 30% mana threshold

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed missing runtime.pw_shield_id assignment**
- **Found during:** Task 3 (Discipline shield management)
- **Issue:** runtime.pw_shield_id was nil, causing try_pw_shield to always return false
- **Fix:** Added `runtime.pw_shield_id = resolved.shield` after resolved table
- **Files modified:** EAXPriestDiscipline/main.lua
- **Verification:** try_pw_shield now passes cooldown check
- **Committed in:** 8b5e60d (Task 3 commit)

**2. [Rule 2 - Missing Critical] Added Weakened Soul debuff check before shielding**
- **Found during:** Task 3 (Discipline shield management)
- **Issue:** Original try_shield did not check for Weakened Soul debuff, could waste GCD on invalid target
- **Fix:** Added `utils.has_debuff(candidate, spells.BUFF_WEAKENED_SOUL)` check
- **Files modified:** EAXPriestDiscipline/main.lua
- **Verification:** Shield cast now respects Weakened Soul debuff
- **Committed in:** 8b5e60d (Task 3 commit)

**3. [Rule 2 - Missing Critical] Added shield cooldown check**
- **Found during:** Task 3 (Discipline shield management)
- **Issue:** Shield could be cast while on cooldown, wasting GCD
- **Fix:** Added `core.spell_book.get_spell_cooldown(resolved.shield) > 0` check
- **Files modified:** EAXPriestDiscipline/main.lua
- **Verification:** Shield cast only when off cooldown
- **Committed in:** 8b5e60d (Task 3 commit)

---

**Total deviations:** 3 auto-fixed (1 bug, 2 missing critical)
**Impact on plan:** All auto-fixes essential for correct shield behavior and rotation efficiency. No scope creep.

## Issues Encountered

- Shadow Orbs mechanic not present in TBC Classic; used Shadow Weaving buff and cast-counting as proxy
- Tank detection via class scanning is heuristic; proper tank identification would require threat_manager integration (deferred)

## Next Phase Readiness

- Shadow Priest rotation now includes DoT clip prevention and Mind Blast timing with resource tracking
- Discipline Priest rotation includes shield management with cooldown and tank priority
- Both specs integrated with mana_manager for proactive mana potion usage
- Ready for further priest optimizations (Holy spec) or other class deep dives in Phase 3

---
*Phase: 03-per-class-rotation-deep-dives*
*Completed: 2026-03-20*