# Research Summary

## What This Is

Research into the TBC Classic WoW rotation bot ecosystem to inform EAX development strategy for reaching #1 status.

## Key Findings

### Competition
**Tempest** (wowtempest.gg) is the current #1 — SimC-accurate rotations natively, custom APL editor, zero bans. **Project Wholesome** (WRobot) is popular with 13 solo + 18 party rotations. **HeroRotation/HeroLib** provides simc-based rotation logic. EAX's advantages: Sylvanas-specific APIs, ESP/HUD overlay, encounter awareness, complete control.

### Stack
Pure Lua on Sylvanas core APIs. No changes needed — the platform is right. Key additions needed: set bonus scanner, swing timer library, DPS meter, shared module extraction.

### Table Stakes
EAX already has all table-stakes features: 27 specs, interrupts, defensives, encounter awareness, OOC automation. **Gaps**: swing timer optimization, set bonus detection, DoT clip prevention, threat management, DPS meter.

### Watch Out For
1. **DoT clipping** — never refresh before final tick; costs real DPS
2. **Slam/auto clip** — swing timer must be checked before Slam/weaving
3. **Interrupt waste** — don't interrupt spells with <200ms remaining
4. **Hardcoded sets** — only 3 sets tracked; all T4/T5/T6 ignored
5. **OOM mid-fight** — mana management for casters
6. **Shaman totems** — require physical items in bag, not just spell casting
7. **GCD overlap** — fast-cast path bypasses queue safety

## Feature Categories

### Table Stakes (EAX has most)
- 27 full specs
- Priority-based casting
- Interrupt system
- Defensive cooldowns
- Encounter awareness
- OOC automation

### Improve (rotation depth)
- Swing timer awareness (Warrior/Rogue/Hunter)
- DoT clip prevention (Lock/Druid/Priest)
- Haste breakpoint detection
- Threat management

### Missing (competitive gap)
- **Set bonus scanner** — dynamic gear scanning for all T4/T5/T6
- **DPS/HPS meter** — integrated damage tracking
- **Arcane Mage burn phase** — 3-stack AB, all CDs, Evocation
- **Subtlety Rogue** — Backstab, Hemorrhage priority
- **Demo Lock** — Metamorphosis, Felguard rotation

### Differentiators (reach #1)
- SimC-accurate APL-based priority tables
- Integrated DPS benchmark
- Consumables automation
- Swing timer library

## Architecture Direction

Extract shared modules to `common/eax_shared/`: interrupt_manager, defensive_manager, encounter_manager, ooc_manager, set_bonus, dps_meter.

Move rotation priority lists from main.lua to data tables (rotation.lua). This enables:
- Simpler main loop
- Easier tuning
- Future simc parsing

Build order: shared extraction → set bonus → rotation tables → swing timer → DoT clip prevention → DPS meter → consumables.
