# Active Plans Index

**Rule:** One active plan per effort. Update status here. When complete or
abandoned, move the plan file to `plans/_archive/` and remove its row.

**Canonical active plan:** `plans/finish-what-i-started.md` — reconciles all prior
scattered plans against the verified working tree. Read it first.

| Plan | Status | Next step |
|------|--------|-----------|
| `finish-what-i-started.md` | **ACTIVE** | Track A ✅ COMPLETE + Track B ✅ B1-B5 complete. A1 validate.cmd Lua 5.1 pin; A2 hysteresis `configure()` timer-reset bug fixed (drop-hold now works under per-frame configure); A3 dead-ref cleanup (missile_tracker, swing_timer, reagent_guard 5-file, spell_flag_checker dead reg); B5 pvp_burst dangling `reasons` ref fixed; B1 ret seal-twist test gap filled (9 contracts, was 6-line stub); B2/B3/B4 verified already-implemented (native `auto_attack_helper`/`get_total_shield`/`get_incoming_heals` wired + tested). Gate green (161 rot + 11 lvl + audit on Lua 5.1). **Remaining:** A4 (pvp_burst DR stubs — low prio PvP), B6 (friendly-target healing — larger, design first), Track C (core_sylvanas split: ttd/talents/diagnostics extraction), Track D (data cleanup: 35 DEBUG entries, spell 28176). Changes NOT yet committed — grouped by concern for atomic commits. |
| `refactor-developer-experience-2026-06.md` | reconciled into `finish-what-i-started.md` (Track C) | Phase 1 ✅, Phase 2 🔶 (4/8 core modules extracted; core_sylvanas still 5,984 lines), Phase 4 ✅ (spec_kit + arms conversion done). Remaining = Track C. |
| `glm-5.2-optimization-session.md` | superseded by `finish-what-i-started.md` | Most waves ⛔ out-of-scope (native API supersedes reference ports). Surviving tasks folded into Tracks A/B/D. |
| `eax-external-improvements.md` | reconciled into `finish-what-i-started.md` | Phase 1.1/1.2 ✅ (hysteresis module+test); Phase 1.3 ❌ → A2; Phase 2 (seal twist) resurrected via native `auto_attack_helper` → B1. |
| `post-audit-improvements.md` | reconciled into `finish-what-i-started.md` | Tasks 1.1/1.2/2.1 ✅; 1.3 🔶 (deleted but dead refs remain → A3); 2.2/3.x/4.1 → B3/B6/B5. |
| `warlock-remaining-tests-and-polish.md` | pending | Close-out: orphan RED test (imp_firebolt_pacing), affliction summon test (✅ now passing), final validation. Production code fixed — tests/cleanup only. |
| `wowsims-apl-cross-reference.md` | reference doc | APL cross-reference; consult when tuning spec priorities. Not an active code effort. |

## Verified baseline (2026-06-25, Lua 5.1.5)
- Rotation tests: **161 suites PASS / 0 fail**
- Leveling tests: **11 suites PASS / 0 fail**
- Runtime interpreter: `C:\Program Files (x86)\Lua\5.1\lua.exe` (PATH `lua` is 5.4 — do not use for tests)
- Gate: `EaxRotations\validate.cmd` now pins Lua 5.1 (A1 fix applied)

## Archived (moved to `plans/_archive/` on 2026-06-23)
- `api-compliance-fixes.md` (2026-06-22 — 100% Sylvanas API compliance; 176/176 green)
- `autoquester-scope-exclusion.md` (2026-06-22 — out-of-scope decision for EaxAutoQuester)
- `warlock-imp-sac-backdraft-fix.md` (2026-06-23 — committed 3a5bf13)
- `omnibus-audit-v3.md` (2026-06-23 — 10/10 fixed; 167/167 + 11/11 green)

## Archived (moved to `plans/_archive/` on 2026-06-19)
All 11 plans verified against git log and archived:
- `01-performance-optimization.md`, `02-shaman-tbc-rotation.md`,
  `apl_lua_diff_2026_06_13.md`, `apl_to_lua_mapping_2026_06_13.md`,
  `eaxrotations-bugfix-2026-06-13.md`, `flux-import-hunter-adaptive.md`,
  `flux-import-warrior-rage-pooling.md`, `hardcoded-to-api-migration.md`,
  `rake-claw-pve-builder.md`, `remaining-gaps-2026-06.md`,
  `tier1-simplification.md`, `api-integration-2026-06.md`,
  `eaxrotations-cross-class-robustness-sweep.md`
