# Vanilla Anniversary APL Audit + Post-Audit Improvements — COMPLETE

**Started:** 2026-06-26
**Completed:** 2026-06-26
**Plan:** `plans/vanilla-apl-audit-2026-06.md`

## Baseline
- HEAD: eaf80ff6 (in sync with origin/master)
- 171 rotation + 11 leveling suites PASS
- Vanilla spell audit: 31 specs clean, 0 tainted
- All 40/40 vanilla files have Pattern 15 headers

## Vanilla APL Audit — COMPLETED
- [x] Pattern 15 headers added to all 35 vanilla files
- [x] TBC-only dead code removed from ALL 22 vanilla specs (8 by me + 14 by agent)
- [x] Classic Era DBC extracted (1.15.8.67156, 31,248 spells)
- [x] DBC verified: Water Elemental, Ice Lance, Icy Veins NOT in Classic Era

## Post-Audit Improvements — ALL COMPLETE

### Wave 1 — COMPLETE
- [x] **Task 1.1**: Add Readiness 23989 to Hunter (BM/MM/Survival)
- [x] **Task 1.2**: Fix Balance hot-path require() — ALREADY CLEAN
- [x] **Task 1.3**: Delete 10 dead shared modules — ALREADY DONE

### Wave 2 — COMPLETE
- [x] **Task 2.1**: AuraCache snapshot module — ALREADY IMPLEMENTED
- [x] **Task 2.2**: HealPredict shield absorb data — ALREADY IMPLEMENTED

### Wave 3 — COMPLETE
- [x] **Task 3.1**: Friendly Target Step 0 (5 healers) — DONE
  - FriendlyTarget strategy at index 1 in all 5 TBC healer specs
  - State-driven: build_state resolves friendly target once per tick
  - Emergency override: auto-scanned lowest in critical range still wins
  - 5 test files rewritten for Step 0 semantics
- [x] **Task 3.2**: Per-spec predictive thresholds — ALREADY IMPLEMENTED (4/5 specs)

### Wave 4 — COMPLETE
- [x] **Task 4.1**: Fix PvP Burst Window hot-path garbage — ALREADY IMPLEMENTED

## Upstream Sync — DONE
- [x] **wowsims/tbc-new** pulled to `ee9e011bd` (2026-06-26)
  - Hunter APL: `MeleeAuto` → `MainHandAuto` naming; added `RangedAuto` timing check in melee-weave logic
  - Mage: Arcane Blast end-of-fight spam APL change
  - Warrior: Item additions, protection test updates
  - Sync script updated to remove stale untracked files before pull

## Additional Cleanup
- [x] Remove stale binary blobs (common, core_lua, core_universal_kicks)
- [x] Remove dead ui_sylvanas.lua (zero references)
- [x] Update validate.cmd format
- [x] Add fallback friendly-target helpers to core_sylvanas.lua

## Scorecard + Docs
- [x] Rotation Scorecard — 66 specs × 6 content types, 4.3/5.0 avg
- [x] README badges + per-class rotation guides
- [x] WoWSims upstream tracking infrastructure

## Gate Status
- `validate.cmd`: **ALL CHECKS PASSED** (171 + 11 suites + spell audit)

## Commits This Session (26 total)
1-22. (see prior plan versions)
23. `ea303790` — Mark ALL waves COMPLETE
24. `99febb3e` — Fallback friendly-target helpers + restore validate.cmd
25. `cd656554` — FriendlyTarget Step 0 for 5 healers
26. `eaf80ff6` — Update tbc-new sync script

## Notes
- EaxAutoQuester has uncommitted changes from another agent — not touched
- Fury spec uses table-driven `add_strategy` — APL analyzer has known limitation
