---
phase: 02-core-combat
plan: 03
subsystem: eax_shared
tags: [interrupt, encounter-awareness, burn-phase, movement-phase, aoe-detection]
requires:
  - INTER-01
  - INTER-02
  - INTER-03
  - ENCOUNT-01
  - ENCOUNT-02
  - ENCOUNT-03
  - ENCOUNT-04
provides:
  - MIN_CAST_TIME_MS=200 check on interrupt timing
  - Healing priority interrupt targeting
  - AoE safe detection (>3 nearby enemies)
  - Movement phase awareness for mobile bosses
  - Burn phase cooldown hold (threshold HP)
affects: [eax_shared/interrupt_manager.lua, eax_shared/encounter_manager.lua, all 27 spec main.lua]
tech-stack:
  added: [lua]
  patterns: [pcall-wrappers, priority-scoring, phase-detection]
key-files:
  created: []
  modified: [eax_shared/interrupt_manager.lua, eax_shared/encounter_manager.lua]
key-decisions:
  - "Min-cast-time threshold of 200ms chosen to account for server latency — casts finishing in <200ms are skipped"
  - "Healer interrupt bonus (+50 priority) applied when HEALER_CLASSES members cast on players"
  - "AoE safe triggers at >3 nearby enemies (not >2) to avoid false positives in crowded raid scenarios"
  - "Sunwell bosses already present in BOSS_DB from previous work — only burn/movement phase tables needed"
requirements-completed: [INTER-01, INTER-02, INTER-03, ENCOUNT-01, ENCOUNT-02, ENCOUNT-03, ENCOUNT-04]
duration: 167 sec
start: 2026-03-20T01:15:09Z
completed: 2026-03-20T01:17:56Z
tasks: 2
files: 2
---

# Phase 02 Plan 03: Core Combat Systems — Shared Module Improvements Summary

## Objective

Improve `eax_shared/interrupt_manager.lua` (min-cast-time, target priority, spell weights) and expand `eax_shared/encounter_manager.lua` (AoE safe, movement phase, burn phase) for all 27 TBC Classic specs.

## What Was Built

### Task 1: interrupt_manager.lua Improvements

- **MIN_CAST_TIME_MS = 200** constant added — `should_interrupt()` now returns `false` when cast/channel has <200ms remaining, preventing wasted interrupts on casts too fast to react to
- **9 new spell IDs** added to `DANGEROUS_SPELLS` covering TBC boss casts (Magtheridon Shadow Nova 30511, M'uru Void Blast 36092, Kil'jaeden Flame Spike 45742, Shadow Spike 45770, Vampiric Touch 34917, Void Reaver Pounding 26555) and healer spells (Nourish 5040, Healing Touch 26980, Regrowth 20787, Rejuvenation 26981, Chain Heal 25423)
- **HEALER_CLASSES table** added (Priest=5, Druid=6, Paladin=2, Shaman=7)
- **should_interrupt_target(target)** — returns `(should_interrupt, priority_score)`, applies healer bonus (+50) when healer casts on players
- **get_best_interrupt_target(me)** — scans nearby enemies within 10 yards, returns highest-priority interruptable target
- All API calls wrapped in `pcall` for safety

### Task 2: encounter_manager.lua Improvements

- **is_aoe_safe(me)** — counts nearby enemies via `core.object_manager.get_units_in_range(me, 10)`, returns `false` if >3 hostile targets detected, preventing face-pull in dungeons
- **MOVEMENT_PHASE_BOSSES table** — 11 bosses with movement mechanics (brutallus, felmyst, lady vashj, illidan stormrage, teron gorefiend, prince malchezaar, gruul, magtheridon, al'ar, void reaver, high astromancer solarian)
- **is_movement_phase(me)** — returns `true` if player is moving (`core.navigation.is_moving()`) or within minimum range of a movement boss
- **get_min_range(me)** — returns encounter-specific minimum range from policy
- **BURN_PHASE_BOSSES table** — 9 bosses with burn phase mechanics (gruul 30%, magtheridon 35%, selin fireheart 30%, the curator 15%, brutallus 30%, m'uru 20%, kil'jaeden 30%, teron gorefiend 30%, gurtogg bloodboil 25%)
- **should_hold_cooldowns(me)** — returns `(hold_cds, burn_until_pct)`, checks target HP percentage vs burn threshold, respects `hold_cooldowns` policy flag
- **get_burn_threshold(encounter_id)** — returns burn threshold percentage for a given encounter
- Sunwell bosses (brutallus, felmyst, eredar twins, m'uru, kil'jaeden) already present in BOSS_DB

## Commits

| Task | Hash | Message |
|------|------|---------|
| 1 | 5bcad8d | feat(02-03): improve interrupt_manager with min-cast-time, healing priority, best-target |
| 2 | 023be11 | feat(02-03): expand encounter_manager with AoE safe, movement/burn phase detection |

## Verification

- ✅ `luac -p` passes on both files
- ✅ `MIN_CAST_TIME_MS = 200` in interrupt_manager.lua
- ✅ `get_best_interrupt_target` exported in interrupt_manager.lua
- ✅ `HEALER_CLASSES` table present in interrupt_manager.lua
- ✅ `should_interrupt_target` exported in interrupt_manager.lua
- ✅ `is_aoe_safe`, `is_movement_phase`, `should_hold_cooldowns`, `get_min_range` in encounter_manager.lua
- ✅ Sunwell bosses in BOSS_DB (brutallus x3, felmyst x2, eredar twins, m'uru x2, kil'jaeden x2)

## Deviation: None

Plan executed exactly as written. No bugs encountered, no missing functionality discovered, no blockers.

## Next

Ready for Phase 02 Plan 04: Spell Resolver & Target Finder Refinements — finalize `spell_resolver.lua` and `target_finder.lua` shared modules.
