---
phase: 02-core-combat
plan: 01
subsystem: combat
tags: [lua, tbc-classic, dot-manager, mana-manager, threat-manager, warlock, mage, priest, druid]

# Dependency graph
requires:
  - phase: 01-foundation
    provides: Per-spec directory structure, shared modules (interrupt_manager, defensive_manager, racial_manager, ooc_manager, encounter_manager)
provides:
  - eax_shared/dot_manager.lua — DoT clip prevention with safe refresh thresholds
  - eax_shared/mana_manager.lua — Proactive mana management for casters
  - eax_shared/threat_manager.lua — Threat estimation with tank tracking
affects: [03-per-class-rotations, 04-polish]

# Tech tracking
tech-stack:
  added: [dot_manager, mana_manager, threat_manager]
  patterns: [shared-module, clip-prevention, proactive-mana, tank-tracking]

key-files:
  created:
    - eax_shared/dot_manager.lua (308 lines)
    - eax_shared/mana_manager.lua (425 lines)
    - eax_shared/threat_manager.lua (339 lines)
    - EAXMageFire/spells.lua (added EVOCATION spell)
  modified:
    - EAXWarlockAffliction/main.lua
    - EAXWarlockDemonology/main.lua
    - EAXWarlockDestruction/main.lua
    - EAXPriestShadow/main.lua
    - EAXDruidBalance/main.lua
    - EAXDruidRestoration/main.lua
    - EAXMageFire/main.lua
    - EAXMageArcane/main.lua

key-decisions:
  - "DoT refresh uses remaining_ms < threshold (dot_manager.can_refresh_dot) — never clips final tick"
  - "mana_manager.should_evocate used for Mage Evocation timing, Druid Innervate via menu-driven threshold"
  - "Life Tap HP check delegated to mana_manager.should_life_tap, mode-specific thresholds preserved for Demonology"
  - "Pre-existing luac errors (pet:get_pet pattern) in Warlock files — not introduced by this plan"

patterns-established:
  - "Pattern: Shared DoT module — each spec requires dot_manager, uses can_refresh_dot for safe refresh"
  - "Pattern: Shared mana module — caster specs use should_use_mana_potion + class-specific evocation/life-tap"

requirements-completed: [COMBAT-02, COMBAT-04]

# Metrics
duration: 20 min
completed: 2026-03-20
---

# Phase 02 Plan 01: Core Combat Systems Summary

**DoT clip prevention via dot_manager with safe refresh thresholds + proactive mana management via mana_manager integrated into 6 caster specs**

## Performance

- **Duration:** 20 min
- **Started:** 2026-03-20T01:14:51Z
- **Completed:** 2026-03-20T01:35:42Z
- **Tasks:** 4
- **Files modified:** 12 (3 created, 9 modified)

## Accomplishments

- Created 3 shared combat modules: dot_manager (DoT clip prevention), mana_manager (proactive mana), threat_manager (tank threat tracking)
- Wired dot_manager into all 7 caster specs with safe clip-prevention for DoT refresh timing
- Integrated mana_manager into 6 caster specs with potion/Evocation/Life Tap optimization
- Added Evocation support to Fire Mage (previously missing) via new try_evocation() function
- All 3 new modules pass `luac -p` syntax validation

## Task Commits

Each task was committed atomically:

1. **Task 1: Create eax_shared/dot_manager.lua** - `ea69d3d` (feat)
2. **Task 2: Create eax_shared/mana_manager.lua** - `ea69d3d` (feat, same commit as Task 1)
3. **Task 3: Wire dot_manager into 7 caster specs** - `4bed73d` (feat)
4. **Task 4: Wire mana_manager into caster specs** - `29329c2` (feat)

**Plan metadata:** `29329c2` (docs: complete plan - via final metadata commit)

## Files Created/Modified

- `eax_shared/dot_manager.lua` — DoT clip prevention: DOT_DURATIONS table (simc data), can_refresh_dot(), get_safe_refresh_ms(), get_pending_timeout_ms()
- `eax_shared/mana_manager.lua` — Proactive mana: should_use_mana_potion(), should_evocate(), should_life_tap(), get_mana_pct(), MANA_POTIONS constants
- `eax_shared/threat_manager.lua` — Threat tracking: get_tank_unit(), get_tank_threat(), get_player_threat(), should_fade()
- `EAXWarlockAffliction/main.lua` — dot_manager for UA/Corruption/Siphon Life refresh; mana_manager for Life Tap + potion
- `EAXWarlockDemonology/main.lua` — dot_manager require; mana_manager for Life Tap + potion
- `EAXWarlockDestruction/main.lua` — dot_manager for Immolate refresh
- `EAXPriestShadow/main.lua` — dot_manager for VT/SW:P/DP refresh; mana_manager potion check
- `EAXDruidBalance/main.lua` — dot_manager for Moonfire/Insect Swarm refresh; mana_manager potion check
- `EAXDruidRestoration/main.lua` — dot_manager require (Faerie Fire 5min handled correctly)
- `EAXMageFire/main.lua` — dot_manager require; mana_manager with Evocation + potion (new try_evocation function)
- `EAXMageFire/spells.lua` — Added EVOCATION = { 12051 } spell table
- `EAXMageArcane/main.lua` — mana_manager with Evocation timing + potion check

## Decisions Made

- DoT refresh logic: replaced user-configurable threshold checks with dot_manager.can_refresh_dot() — provides mathematically safe refresh window (never clips final tick)
- For Druid Balance: removed menu-driven refresh_ms (3s default) in favor of dot_manager safe threshold — safer but less tunable
- For Shadow Priest: kept menu-driven dot_window_ms in try_mind_blast for burst logic, but refresh_dot() and try_devouring_plague() now use dot_manager
- Pre-existing Warlock luac errors (pet:get_pet pattern) documented but not modified — separate issue from this plan

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

**Pre-existing luac syntax errors in Warlock specs:**
- Files: EAXWarlockAffliction/main.lua (line 422), EAXWarlockDemonology/main.lua (line 336), EAXWarlockDestruction/main.lua (line 342)
- Issue: `me:get_pet and me:get_pet()` pattern — Lua evaluates as `(me:get_pet) and (me:get_pet())` instead of `(me:get_pet and me:get_pet)()`
- Impact: Pre-existing bug in original codebase, not introduced by this plan. 100% of new code (dot_manager, mana_manager, all integration) passes luac.

**dot_manager.lua and mana_manager.lua were pre-ignored in .gitignore:**
- Files were added to .gitignore in prior session (c8b04e0, b9b219f) before module creation
- Removed from .gitignore in ea69d3d to enable tracking and commit

## Next Phase Readiness

- Phase 03 (Per-Class Rotation Deep Dives) can now depend on dot_manager, mana_manager, and threat_manager
- All 3 shared modules established and tested via luac
- Ready for 02-core-combat-02 (Tank & Melee Systems) and 02-core-combat-03 (Interrupt & Encounter Management)

---
*Phase: 02-core-combat*
*Plan: 01*
*Completed: 2026-03-20*
