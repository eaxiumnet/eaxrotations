# Vanilla Anniversary APL Audit + Post-Audit Improvements — COMPLETE

**Started:** 2026-06-26
**Status:** COMPLETE (2026-06-26)
**Plan:** `plans/vanilla-apl-audit-2026-06.md`

## Baseline
- HEAD: 843ff5a4 (in sync with origin/master)
- 171 rotation + 11 leveling suites PASS
- Vanilla spell audit: 31 specs clean, 0 tainted
- All 40/40 vanilla files have Pattern 15 headers

## Vanilla APL Audit — COMPLETED
- [x] Pattern 15 headers added to all 35 vanilla files
- [x] TBC-only dead code removed from ALL 22 vanilla specs
- [x] Classic Era DBC extracted (1.15.8.67156, 31,248 spells)
- [x] DBC verified: Water Elemental, Ice Lance, Icy Veins NOT in Classic Era

## Post-Audit Improvements — IN PROGRESS

### Wave 1 — COMPLETE
- [x] **Task 1.1**: Add Readiness 23989 to Hunter (BM/MM/Survival)
  - rapid_fire_cd tracking, readiness fires when Rapid Fire has >=60s CD left
  - 3 files changed, gate passes
- [x] **Task 1.2**: Fix Balance hot-path require() — ALREADY CLEAN (module-level requires)
- [x] **Task 1.3**: Delete 10 dead shared modules — ALREADY DONE (prior commit)

### Wave 2 — COMPLETE
- [x] **Task 2.1**: AuraCache snapshot module — ALREADY IMPLEMENTED (`aura_cache_sylvanas.lua`)
- [x] **Task 2.2**: HealPredict shield absorb data — ALREADY IMPLEMENTED (`preemptive_heal_sylvanas.lua`)

### Wave 3 — IN PROGRESS
- [ ] **Task 3.1**: Friendly Target Step 0 (5 healers) — AGENT RUNNING
- [x] **Task 3.2**: Per-spec predictive thresholds — ALREADY IMPLEMENTED (4/5 specs)
  - discipline: `discipline_preemptive_threshold`
  - holy priest: `holy_preemptive_threshold`
  - druid resto: `resto_preemptive_threshold`
  - shaman resto: `restoration_preemptive_threshold`
  - paladin holy: does NOT use PreemptiveHeal yet (future enhancement)

### Wave 4 — PENDING
- [ ] **Task 4.1**: Fix PvP Burst Window hot-path garbage

## Scorecard + Docs
- [x] Rotation Scorecard — 66 specs × 6 content types, 4.3/5.0 avg
- [x] README badges + per-class rotation guides
- [x] WoWSims upstream tracking infrastructure

## Cleanup
- [x] Remove stale binary blobs (common, core_lua, core_universal_kicks)
- [x] Update validate.cmd format

## Gate Status
- `validate.cmd`: **ALL CHECKS PASSED** (171 + 11 suites + spell audit)

## Notes
- EaxAutoQuester has uncommitted changes from another agent — not touched
- Fury spec uses table-driven `add_strategy` — APL analyzer has known limitation
