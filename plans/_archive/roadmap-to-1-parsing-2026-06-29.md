# Roadmap to #1 Parsing — EAX Rotation System

**Status**: Active
**Started**: 2026-06-29
**Branch**: master
**Baseline**: 208/208 rotation + 11/11 leveling suites PASS, 416 Lua 0 syntax errors, v2.2.0
**Goal**: Close the final APL-fidelity and feature gaps to make EAX the top #1 parsing
rotation automation system for TBC Classic Anniversary + Vanilla.

## Context

A full Five-Axis review (API correctness, nil safety, architecture, era validity,
performance) + APL-fidelity audit against the local `wowsims_classic/` simulator +
competitor cross-check found the codebase in strong shape. Most "gaps" flagged in the
2026-06-28 competitor analysis were already closed by the 2026-06-29 deep-review sprint
(totem twisting, Ret post-swing judge + twist diagnostics, Shadow IF→MB, multi-DoT,
DoT-TTD gating, cat snapshot, healthstone, dispel, stance/rage management — all backed
by passing tests).

The remaining work is a prioritized set of micro-optimization + parity + hardening items.

## Track A — Clean Baseline (low risk)

### A1. Residual nil-guards (Commit 1) ✅ DONE 2026-06-29
- [ ] Arms `state.ttd` comparison (L494) — not covered by spec_kit defaults
- [ ] Cat `target_lives()` (L339-340) — nil target_ttd → crash + logic bug
- [ ] Cat `prevent_cp_waste()` (L344) — nil combo_points → arithmetic crash
- [ ] Cat `build_state` pooling reads (L458-459, L465) — bare combo_points/energy
- Gate: luac -p + 208/208 + 11/11

### A2. Remove dead `context.spell_damage` snapshot gate (Commit 2)
- Consumers: affliction, shadow, elemental, balance, destruction, demonology (×sylvanas+vanilla)
- build_context() never populates spell_damage → snapshot-upgrade gate always sees 0/0 → no-op
- Decision: REMOVE the dead gate (only API is imprecise tooltip parsing; wiring it risks missed DoT refreshes)
- Keep `should_snapshot_upgrade` helper (cat uses it for AP snapshots via context.attack_power which IS wired)
- Gate: full suite green

### A3. Per-frame NS.GetPlayer() cache (Commit 3)
- Cache _get_player() pcall result once per tick in main_sylvanas.lua
- Gate: full suite green + test_dispatcher_tick.lua

## Track B — Feature Parity (low-medium)

### B1. Druid healthstone + auto-dispel (Commit 4)
- healthstone (copy consumable_manager pattern) + Remove Curse (all) + Abolish Poison (resto)
- Test: test_druid_middleware_healthstone_dispel.lua
### B2. Paladin healthstone + auto-dispel (Commit 5)
- Test: test_paladin_middleware_healthstone_dispel.lua
### B3. Combat mode for Rogue/Mage/Druid (Commit 6)
- 9 spec files; read combat_mode in build_state, adjust enemy_count thresholds
- Test: test_combat_mode_rogue_mage_druid.lua
### B4. JoC maintenance (Commit 7)
- Optional Judgement of the Crusader across paladin specs (gated checkbox, default off)
- Test: test_paladin_joc_maintenance.lua

## Track C — Parsing Power (the #1 differentiators)

### C1. Feral rip trick + shred trick (Commit 8)
- Source: wowsims_classic/sim/druid/feral/rotation.go (canRip isTrick, UseRipTrick, UseShredTrick)
- cat_sylvanas.lua: rip_trick_matches + shred_trick_matches (short fight, full powershift only)
- schema: cat_use_rip_trick + cat_use_shred_trick checkboxes (default off)
- Extend test_cat_custom_matches.lua + test_cat_snapshot_upgrade.lua

### C2. Hunter cliptracker precision (Commit 9) — HIGHEST RISK
- Source: wowsims_classic/sim/hunter/hunter.go (OnGCDReady weave)
- Target: shared/hunter_core_sylvanas.lua (384→~600 lines) + cliptracker_sylvanas.lua
- Add: exact auto-shot timer, steady-shot weave math (cast only if completes before next auto),
  Multi-Shot/Arcane clip prevention, Kill Command window, latency-compensated swing prediction
- Leverage existing shot_timer_sylvanas.lua + swing_timer_sylvanas.lua
- Extend test_shot_timer.lua, test_hunter_shot_timer_integration.lua, test_hunter_steady_shot_weave.lua
- STOP condition: if loops >2 attempts, write plans/hunter-cliptracker-blocker.md

## Track D — Maintainability (no DPS impact, last)

### D1-D5. core_sylvanas.lua Phase 2 extraction (Commits 10-14)
- D1: core/auras.lua (-400 lines)
- D2: core/spell_safety.lua (-600)
- D3: core/pvp.lua + core/cc_immunity.lua (-420)
- D4: core/healing.lua + core/targeting.lua (-550)
- D5: core/registry.lua (-500) + build_context sub-builders + action_matches predicate table
- Each commit keeps core_sylvanas.lua re-exports for backward compat

## Verification Gate (after EACH commit)
```
luac -p <changed files>
lua EaxRotations/tests/run_rotation_tests.lua   # 208/208
lua EaxRotations/tests/run_leveling_tests.lua   # 11/11
```
One concern per commit. If any suite fails: git checkout, investigate. If loops >2
attempts → STOP + write plans/<item>-blocker.md (AGENTS.md contract rule 5).
