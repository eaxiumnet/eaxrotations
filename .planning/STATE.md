---
gsd_state_version: 1.0
milestone: v1.0
milestone_name: milestone
current_plan: 5
status: unknown
stopped_at: Completed 04-05-PLAN.md
last_updated: "2026-03-20T13:20:27.640Z"
progress:
  total_phases: 4
  completed_phases: 3
  total_plans: 22
  completed_plans: 21
---

# State

## Project Reference

See: `.planning/PROJECT.md` (updated 2026-03-20)

**Core value:** Every spec executes the mathematically optimal rotation while maintaining survival and encounter-specific awareness.

**Current focus:** Phase 04 — polish-competitive-features

## Current Status

- [x] Project initialized
- [x] Codebase mapped
- [x] Research complete
- [x] Requirements defined
- [x] Roadmap created
- [x] Phase 03 planned (9 plans)
- **Current Plan:** 5
- **Total Plans in Phase:** 5

## Roadmap

4 phases | 53 requirements

| # | Phase | Status |
|---|-------|--------|
| 1 | Foundation | Complete |
| 2 | Core Combat Systems | Complete |
| 3 | Per-Class Rotation Deep Dives | Complete |
| 4 | Polish & Competitive Features | Pending |

## Decisions Made

- **Min-cast-time 200ms threshold** for interrupt_manager — prevents wasted interrupts on casts finishing before server can react
- **Healer bonus (+50 priority)** applied in interrupt target selection when healer classes cast on players
- **AoE safe triggers at >3 nearby enemies** — conservative threshold to avoid false positives in crowded raid scenarios
- **Sunwell bosses already in BOSS_DB** — brutallus, felmyst, eredar twins, m'uru, kil'jaeden present from previous work
- [Phase 03]: Used swing_timer.is_swing_safe() instead of utils.can_slam_without_clipping() for more accurate Slam weaving that accounts for actual weapon swing timing
- [Phase 03]: Implemented Heroic Strike as fast one-hander alternative in Fury execute phase when appropriate, leveraging existing queue lane mechanics
- [Phase 03]: Added Molten Fury execute detection using encounter_manager burn_until_pct for boss-specific timing
- [Phase 03]: Implemented FSCT timing using swing_timer.can_cast_before_swing to prevent auto clipping
- [Phase 03]: Integrated mana_manager for mana potion usage across all three specs
- [Phase 03]: Assumed base weapon speed 2.8 seconds for haste breakpoint calculation (placeholder until API provides ranged speed) — Ranged weapon base speed not directly available via API, used typical value for detection.
- [Phase 03]: Used swing_timer.can_cast_before_swing with 0.1s safety buffer for all casted shots — Prevents auto shot clipping while allowing maximum shot density.
- [Phase 03]: Reordered Beast Mastery rotation to prioritize Arcane Shot before Steady Shot for melee weaving — Plan required melee weaving of Arcane Shot between auto shots, original order had Steady Shot first.
- [Phase 03]: Implemented eclipse detection using existing Lunar/Solar eclipse buffs (IDs 48518/48517) rather than custom energy tracking — Simpler and matches server implementation
- [Phase 03]: Added energy pooling for Ferocious Bite to prevent wasting combo points when energy insufficient — Ensures optimal bite timing and prevents CP waste
- [Phase 03]: Added combo point cap check in Mangle and Claw filler abilities to avoid overcapping — Prevents CP waste and ensures finishers at 5 CP
- [Phase 03]: Added Shadow Weaving buff detection and tracked Shadow Orb stacks as proxy for Mind Blast proc timing — TBC does not have Shadow Orbs; using existing Shadow Weaving buff stacks or cast-counting provides similar proc-based Mind Blast timing
- [Phase 03]: Implemented tank-priority shielding during tank_damage_heavy encounters using class detection — Healer AI should prioritize tank survival during heavy tank damage phases; class detection is a heuristic until threat_manager tank identification is integrated
- [Phase 03]: Integrated mana_manager for proactive mana potion usage in both Shadow and Discipline specs — Proactive mana management prevents OOM situations; existing mana_manager module provides threshold-based potion usage
- [Phase 03]: Use encounter_manager helpers for behind-target and enemy-count checks in Rogue rotations.
- [Phase 03]: Standardize Slice and Dice refresh policy to <=2s urgency with >10s clip guard across Rogue specs.
- [Phase 03]: Gate Combat Killing Spree to active Blade Flurry windows for synchronized multi-target burst.
- [Phase 03]: Applied shared totem cast gating across all shaman specs for consistent missing-item handling.
- [Phase 03]: Used encounter_manager burn windows plus bloodlust checks to bias Elemental burst priorities.
- [Phase 03]: Retribution Divine Storm now spends 3 Holy Power only in 3+ target AoE windows
- [Phase 03]: Holy focus-target healing normalizes API health percent values to 0-1 before threshold logic
- [Phase 03]: Protection checks Avenger's Shield before Shield of the Righteous when Holy Power/proc conditions are met
- [Phase 03]: Use is_conflagrate_proc_ready to centralize deterministic Conflagrate gating with spell-ready, target-valid, lockout, and Immolate checks.
- [Phase 03]: Prioritize try_conflagrate before try_shadowfury in Destruction to consume Immolate proc windows immediately.
- [Phase 03]: Fury fast-1H execute only activates when both mainhand and offhand speeds resolve and are <= 2.0s
- [Phase 03]: Fury execute cast/queue decisions are gated by shared swing_timer safety checks to prevent white-swing clipping
- [Phase 04]: Use core.input.use_container_item with bag scans to sell only quality-0 items.
- [Phase 04]: Mount manager dismounts on combat and mounts only when out-of-combat and stationary.
- [Phase 04]: Normalized unknown TTD to '--' for HUD-safe visual snapshot contract
- [Phase 04]: Guarded DPS/HPS division with duration >= 0.1s threshold in shared meter
- [Phase 04]: Wrapped esp_renderer.on_cast in each main.lua to capture recommended spell cooldown telemetry without touching spell-priority logic.
- [Phase 04]: Used a resilient visual_get_ttd_seconds fallback to '--' whenever a spec lacks usable ttd_tracker output.
- [Phase 04]: Use per-spec menu key prefixes for automation toggle storage to avoid cross-spec collisions.
- [Phase 04]: Keep shared automation execution gated by menu state checks in the runtime loop.
- [Phase 04]: Validation scope pinned to 27 canonical combat specs to avoid non-rotation plugin false failures.
- [Phase 04]: Benchmark dry-run emits deterministic snapshot rows for comparable DPS/HPS baselines.

## Recent Commits

- `012a3b4` feat(02-02): threat estimation + fade protection for all 27 specs
- `29329c2` feat(02-01): wire mana_manager into 6 caster specs for proactive mana optimization
- `4bed73d` feat(02-01): wire dot_manager into 7 caster specs for clip-safe DoT refresh
- `ea69d3d` feat(02-01): create eax_shared dot_manager, mana_manager, threat_manager modules
- `023be11` feat(02-03): expand encounter_manager with AoE safe, movement/burn phase detection
- `c63cfba` feat: add set_bonus.lua and swing_timer.lua shared modules
- `2baeb46` docs(phase-01): add foundation phase plans

## Config

Mode: YOLO | Granularity: Coarse | Parallelization: true | Commit: true
Research: Yes | Plan Check: Yes | Verifier: Yes

## Performance Metrics

| Phase | Plan | Duration | Tasks | Files |
|-------|------|----------|-------|-------|
| 03 | 01 | 15 min | 3 | 2 |

---
*Last updated: 2026-03-20 — Phase 2 complete: 3/3 plans done**
| Phase 03 P03 | 10 | 3 tasks | 2 files |
| Phase 03 P02 | 10 min | 3 tasks | 3 files |
| Phase 03 P06 | 8 min | 3 tasks | 2 files |
| Phase 03 P05 | 10 min | 3 tasks | 3 files |
| Phase 03 P09 | 6 min | 3 tasks | 4 files |
| Phase 03 P08 | 2 min | 3 tasks | 4 files |
| Phase 03 P07 | 22 min | 3 tasks | 3 files |
| Phase 03 P11 | 2 min | 2 tasks | 1 files |
| Phase 03 P10 | 3 min | 2 tasks | 1 files |
| Phase 04 P03 | 6 min | 2 tasks | 3 files |
| Phase 04 P01 | 13 min | 2 tasks | 5 files |
| Phase 04 P02 | 6 min | 2 tasks | 54 files |
| Phase 04 P04 | 51 min | 2 tasks | 54 files |
| Phase 04 P05 | 11 min | 2 tasks | 6 files |

## Session Continuity

Last session: 2026-03-20T13:20:27.637Z
Stopped at: Completed 04-05-PLAN.md
Resume file: None
