# EAX TBC Classic Rotations

## What This Is

EAX TBC Classic Rotations are 27 WoW TBC Classic (patch 2.4.3) combat automation plugins for the Project Sylvanas bot. Each plugin handles a specific class/spec combination — executing priority-based rotations, interrupts, defensives, boss encounter awareness, and out-of-combat automation — so players can bot through dungeons and raids with performance matching or exceeding a skilled manual player. Goal: become the #1 rotation suite in the TBC Classic botting space.

## Core Value

Every spec executes the mathematically optimal rotation for its class while maintaining survival and encounter-specific awareness — making assisted gameplay indistinguishable from expert manual play.

## Requirements

### Validated

Shipped and working:

- ✓ **27 full specs** across 9 classes — all 27 class/spec combinations implemented
- ✓ **Interrupt management** — priority-based system with weighted spell lists covering all classes
- ✓ **Defensive cooldowns** — HP-threshold layered defensive system (Last Stand, Shield Wall, Evasion, etc.)
- ✓ **Encounter awareness** — boss database covering all TBC dungeons and raids (Hellfire Citadel through Sunwell Plateau)
- ✓ **OOC automation** — drink/eat, group buffs, party resurrection
- ✓ **Leveling support** — 1-70 leveling with wand/melee fallback and combat form management
- ✓ **ESP/HUD overlay** — cast visualization, target display, icons with caching
- ✓ **Racial abilities** — Blood Fury, Berserking, War Stomp, Stoneform, etc.
- ✓ **Pet management** — Mend Pet, Revive Pet, Call/Dismiss (Hunter specs)
- ✓ **Set bonus multipliers** — Warbringer, WarbringerBattlegear, Ymirjar sets (hardcoded item IDs)
- ✓ **Talent detection** — spell resolution returns nil for unlearned talents
- ✓ **Spell rank resolution** — returns highest learned rank (fixed from backwards iteration bug)
- ✓ **Combo points** — `me:get_power(COMBOPOINTS_TBC)` on player (fixed from target error)
- ✓ **Target range cap** — 30 yard limit on non-attacking hostiles
- ✓ **Spec conflict detection** — runtime warning when multiple specs of same class enabled

### Active

What needs to be built or fixed to reach #1:

- [ ] **Set bonus detection** — replace hardcoded TBC_SETS table with dynamic gear scanning using `ItemSetXxx.CharacterHasSetBonus()` pattern; covers all T4/T5/T6 sets
- [ ] **Shaman totem handling** — TBC requires totem items in bag (Air Totem 5178 etc.); wire `core.input.use_item()` for totem placement
- [ ] **DPS/HPS optimization per spec** — review each spec's priority list against reference implementations (BRLite, ni-main, simc) for mathematically correct APM and cooldown alignment
- [ ] **Interrupt accuracy** — refine spell priority weights, add missing dangerous spell IDs, reduce false interrupts
- [ ] **Encounter behaviors** — expand boss-specific policies (hold cooldowns, burn phases, AoE gating)
- [ ] **Shared module extraction** — extract duplicate `interrupt_manager.lua`, `defensive_manager.lua`, `encounter_manager.lua`, `ooc_manager.lua` into `common/eax_shared/`
- [ ] **OOC automation expansion** — auto-sell grey items, auto-repair, auto-consumables management
- [ ] **ESP/HUD improvements** — DPS/HPS meter, TTD display, buff/debuff tracking, cooldown timers
- [ ] **DPS benchmarking** — integrated damage/healing meter to measure rotation effectiveness

### Out of Scope

- Wrath of the Lich King or Retail expansions
- Hardcore or solo-only variants
- Fresh 1-70 leveling speedrun optimization
- Battleground PvP modes

## Context

The codebase (v2.1.0) is a mature, working plugin suite. Each spec follows a consistent architecture: `main.lua` (rotation logic), `spells.lua` (spell ID rank tables), `utils.lua` (casting/targeting helpers), and shared manager modules. The main bottleneck to reaching #1 is not missing features — it's **rotation optimization depth** and **set bonus accuracy**. The codebase was last updated 2026-03-17 with combo point and ESP/HUD fixes.

Phase 4 (Polish & Competitive Features) is complete: shared telemetry, shared automation modules, spec-wide HUD/automation wiring, and validation/benchmark tooling are now in place.

Reference implementations for spell priority and set bonuses:
- `/c/618497f1/scripts/tbc/sim/*/` — complete spell lists and set bonus patterns
- `/c/618497f1/scripts/PublicGithubs/BRLite-main/` — rotation examples
- `/c/618497f1/scripts/PublicGithubs/ni-main/` — rotation examples
- `/c/618497f1/scripts/sylvanas-dev-docs-llm/` — Sylvanas API docs

Repository: https://github.com/eaxiumnet/eax-tbc-classic-rotations

## Constraints

- **Tech stack**: Pure Lua 5.x — no external dependencies, only Sylvanas core APIs
- **Platform**: Project Sylvanas bot, TBC Classic patch 2.4.3 only
- **No automated testing**: All validation manual; no test framework exists
- **No build step**: Plugins are direct Lua file copies to Sylvanas scripts folder
- **27 duplicate modules**: Shared managers exist as 27 copies rather than centralized modules

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Per-spec plugin structure | Sylvanas loads each spec folder independently; class-level isolation prevents conflicts | ✓ Working |
| Hardcoded set bonus table | Fast lookup without API calls; only 3 sets covered | ⚠️ Needs dynamic detection |
| Interrupt manager per spec | Class-specific interrupt spells require class-specific data | ⚠️ Duplicated across 27 specs |
| OOC manager per spec | OOC behaviors vary by class (rez spells, buff types) | ⚠️ Duplicated across 27 specs |
| No shared modules extracted | Faster initial development, simpler deployment | ⚠️ Maintenance burden at 27 specs |
| Manual-only testing | No TBC server API available for automated validation | ⚠️ Regression risk |

---
*Last updated: 2026-03-20 after Phase 04 completion*
