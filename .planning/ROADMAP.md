# Roadmap: EAX TBC Classic Rotations

**Created:** 2026-03-20
**Granularity:** Coarse
**Total Phases:** 4
**Total Requirements:** 53

## Phase 1: Foundation

**Goal:** Extract shared infrastructure, fix critical missing feature.

### Success Criteria
1. All 5 shared managers (interrupt, defensive, encounter, ooc, racial) exist in `common/eax_shared/` and are required by all 27 specs
2. Set bonus scanner dynamically detects all T4/T5/T6 sets from equipped gear
3. Swing timer library provides safe queue check for all melee specs
4. All 27 specs continue to function after refactoring

### Requirements
FOUND-01, FOUND-02, FOUND-03, COMBAT-01

**Plans:** 3 plans

Plans:
- [x] 01-foundation-01-PLAN.md — Extract 5 shared managers to common/eax_shared/
- [x] 01-foundation-02-PLAN.md — Create set_bonus.lua and swing_timer.lua
- [x] 01-foundation-03-PLAN.md — Refactor all 27 specs to require shared modules

### Key Files
- `common/eax_shared/interrupt_manager.lua`
- `common/eax_shared/defensive_manager.lua`
- `common/eax_shared/encounter_manager.lua`
- `common/eax_shared/ooc_manager.lua`
- `common/eax_shared/racial_manager.lua`
- `common/eax_shared/set_bonus.lua`
- `common/eax_shared/swing_timer.lua`
- All 27 `main.lua`, `interrupt_manager.lua`, `defensive_manager.lua`, `encounter_manager.lua`, `ooc_manager.lua`, `racial_manager.lua`

---

## Phase 2: Core Combat Systems

**Goal:** Optimize core combat systems across all specs — DoT timing, interrupts, encounter awareness, mana management.

### Success Criteria
1. All DoT-casting specs (Affliction, Shadow, Balance, etc.) never clip final tick
2. Interrupt system skips casts with <200ms remaining
3. Boss database covers all TBC encounters with correct policies
4. Casters track mana and use Evocation/potions proactively
5. Threat estimation warns before pull

### Requirements
COMBAT-02, COMBAT-03, COMBAT-04, INTER-01, INTER-02, INTER-03, ENCOUNT-01, ENCOUNT-02, ENCOUNT-03, ENCOUNT-04

**Plans:** 3 plans

Plans:
- [x] 02-core-combat-01-PLAN.md — DoT clip prevention + mana management
- [x] 02-core-combat-02-PLAN.md — Threat estimation + fade protection
- [x] 02-core-combat-03-PLAN.md — Interrupt refinements + encounter expansion

### Key Files
- `eax_shared/dot_manager.lua` — DoT clip prevention with safe refresh thresholds
- `eax_shared/mana_manager.lua` — Proactive mana management for casters
- `eax_shared/threat_manager.lua` — Threat estimation with tank tracking
- All caster spec `main.lua` (DoT refresh + mana management wired)
- All 27 `main.lua` (rotation timing)
- All 27 `encounter_manager.lua`
- All 27 `spells.lua` (expanded spell databases)

---

## Phase 3: Per-Class Rotation Deep Dives

**Goal:** Optimize every spec to match or exceed top rotation implementations. Reference simc profiles, Tempest, and Icy Veins guides.

### Success Criteria
1. Warrior specs: Slam weave with swing timer, stance dance, execute phase
2. Hunter specs: Haste breakpoint rotation, auto shot alignment, melee weave
3. Mage specs: Arcane burn phase, Fire Scorch stacking, Frost FSCT
4. Warlock specs: DoT priority, Conflagrate on proc, Meta rotation
5. Priest specs: DoT clip prevention, Shadow burst, Disc shield management
6. Druid specs: DoT clip prevention, eclipse detection, Feral CP/energy
7. Paladin specs: Ret/Prot/Holy optimized priority
8. Shaman specs: Totem item handling, Enhancement/Legacy burst
9. Rogue specs: Subtlety rotation, SnD refresh timing, Blade Flurry

### Requirements
WARR-01, WARR-02, WARR-03, HUNT-01, HUNT-02, HUNT-03, MAGE-01, MAGE-02, MAGE-03, MAGE-04, LOCK-01, LOCK-02, LOCK-03, PRST-01, PRST-02, PRST-03, DRUID-01, DRUID-02, DRUID-03, PAL-01, PAL-02, PAL-03, SHAM-01, SHAM-02, SHAM-03, ROGUE-01, ROGUE-02, ROGUE-03

### Plans
11 plans

### Plans
- [x] 03-per-class-rotation-deep-dives-01-PLAN.md — Warrior specs: Slam weave, execute phase, stance dance
- [x] 03-per-class-rotation-deep-dives-02-PLAN.md — Hunter specs: Steady shot/Aimed Shot, melee weaving, haste breakpoints
- [x] 03-per-class-rotation-deep-dives-03-PLAN.md — Mage specs: Arcane burn phase, Fire Scorch management, Frost FSCT timing
- [x] 03-per-class-rotation-deep-dives-04-PLAN.md — Warlock specs: Affliction DoT prevention, Destruction Conflagrate on proc, Demo Metamorphosis/Felguard
- [x] 03-per-class-rotation-deep-dives-05-PLAN.md — Priest specs: Shadow DoT prevention, Mind Blast timing, Disc PW:S management
- [x] 03-per-class-rotation-deep-dives-06-PLAN.md — Druid specs: Balance DoT prevention/eclipse, Feral CP/energy management
- [x] 03-per-class-rotation-deep-dives-07-PLAN.md — Paladin specs: Ret CS/Divine Storm, Holy Shock/FoL priority, Prot Holy Wrath/Avengers Shield
- [x] 03-per-class-rotation-deep-dives-08-PLAN.md — Shaman specs: Totem scanning, Enh Stormstrike/Lava Lash, Ele Chain Lightning/Lava Burst
- [x] 03-per-class-rotation-deep-dives-09-PLAN.md — Rogue specs: Subtlety Backstab/Hemo, SnD refresh timing, Combat Blade Flurry
- [x] 03-10-PLAN.md — Gap closure: Fury execute fast-1H + swing-safe gating
- [x] 03-11-PLAN.md — Gap closure: Destro Conflagrate proc-aware immediate consumption
- [ ] 03-per-class-rotation-deep-dives-10-PLAN.md — Gap closure: Fury execute fast-1H + swing timer wiring (WARR-02)
- [ ] 03-per-class-rotation-deep-dives-11-PLAN.md — Gap closure: Destruction Conflagrate proc gating cleanup (LOCK-02)

### Key Files
- All 27 `main.lua` (rotation priority tuning)
- All 27 `spells.lua` (spell data validation)
- All 27 `utils.lua` (class-specific helpers)

---

## Phase 4: Polish & Competitive Features

**Goal:** Match and exceed competitors with integrated benchmarking, automation, and visual polish.

### Success Criteria
1. DPS/HPS meter displays damage/healing per fight in ESP
2. Cooldown timer display shows next ability available
3. TTD display shows time-to-death for current target
4. Auto-repair triggers at low durability
5. Auto-sell greys on vendor interaction
6. Consumables management tracks and uses potions/food
7. Auto-mount/dismount based on combat state
8. Rotation validation framework catches regressions
9. DPS benchmark tool measures rotation effectiveness

### Requirements
VIS-01, VIS-02, VIS-03, VIS-04, AUTO-01, AUTO-02, AUTO-03, AUTO-04, QUAL-01, QUAL-02, QUAL-03

### Key Files
- `common/eax_shared/dps_meter.lua`
- `common/eax_shared/consumables.lua`
- All 27 `esp_renderer.lua`
- All 27 `main.lua`

---

## Phase Summary

| # | Phase | Goal | Requirements | Success Criteria |
|---|-------|------|-------------|------------------|
| 1 | Foundation | Shared infrastructure + critical fixes | 4 | Shared modules extracted, set bonus dynamic, swing timer library, all 27 specs refactored |
| 2 | Core Combat | Cross-spec systems optimization | 10 | DoT clip prevention, interrupt refinement, encounter expansion, threat estimation, mana management |
| 3 | Per-Class | Every spec rotation optimized | 28 | All 27 specs match top rotation implementations |
| 4 | Polish | Competitive features + automation | 11 | DPS meter, consumables, auto-repair, visual polish |

---

## Dependency Notes

- Phase 1 must complete before Phases 2-4 (shared modules are the foundation)
- Phase 2 enables Phase 3 (core systems needed before per-class tuning)
- Phase 4 can run parallel to Phase 3 (independent scope)
- Phase 3 should follow simc reference data from `/c/618497f1/scripts/tbc/sim/*/`

---
*Roadmap created: 2026-03-20*
*Last updated: 2026-03-20 after research synthesis*
