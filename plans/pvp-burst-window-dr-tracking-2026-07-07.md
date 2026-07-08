# Plan: pvp_burst_window DR + enemy-CD tracking wiring

**Started:** 2026-07-07
**Status:** COMPLETE (2026-07-07)
**Scope:** `EaxRotations/shared/pvp_burst_window_sylvanas.lua` + new direct test + runner registration

## Problem
`pvp_burst_window_sylvanas.lua` has two stubbed helpers:
- `target_is_dr_immune(context)` -> returns `false` (line 100)
- `enemy_defensive_status(context)` -> returns `"unknown", 0` (line 135)

Both carry stale comments ("module was deleted"). The "What's Missing" audit flagged PvP
burst DR/enemy-CD tracking as the top functional gap.

## Root cause (verified against source)
The DRTracker / EnemyCDTracker modules were NOT actually deleted — they were reimplemented
behind native bridges in `core_sylvanas.lua`:
- `NS.pvp_is_cc_immune(unit, cc_flag)` (line 2665) -> true when a category's DR count >= 3 (native pvp_helper).
- `NS.PVP_DR_CATEGORIES` (line 2594) -> flag -> category-name table (`table<number,string>`).
- `NS.EnemyCDTracker.has_defensive_available(unit)` (line 196) -> true when a relevant defensive is READY (off CD).
- `NS.pvp_is_player` / `NS.pvp_trinket_used_recently` (lines 2683/2610) -> PvP trinket-on-CD signal.

The pvp_burst stubs were written against the OLD API and never wired to these bridges.

## Fix (low-risk wiring, not a from-scratch rebuild)
1. `target_is_dr_immune`: iterate `NS.PVP_DR_CATEGORIES`, filter to burst-relevant category
   names (stun/incapacitate/fear/disorient), return true if `NS.pvp_is_cc_immune` fires for any.
2. `enemy_defensive_status`: return "down" when `has_defensive_available` is false OR (PvP player
   AND trinket on CD); "ready" when a defensive is available; "unknown" when bridges unavailable.
3. Replace the stale "module was deleted" comments + update the file SAFETY header (Pattern 15).
4. Add `tests/test_pvp_burst_window.lua` (direct test) + register in `run_rotation_tests.lua`.

## Safety / no-regression
All native bridge calls are nil-guarded. When bridges are unavailable (PvE / unit tests without
pvp_helper), the helpers return the SAME safe defaults as the prior stubs (false / "unknown"),
so existing behaviour and all current tests are preserved. The only behaviour change is when the
native bridges ARE present (production PvP): DR-immunity and enemy-defensive-down are now scored.

## Out of scope
Spec adoption of `NS.PvPBurstWindow.score/should_burst` (no spec currently consumes it —
`context.should_burst` in main_sylvanas comes from `BurstLogic`, a different module). Adoption
is a separate concern/commit.

## Validation gate
- `luac -p` on the 3 changed files.
- `lua EaxRotations/tests/run_rotation_tests.lua` (all suites pass, incl. new test).
- `lua EaxRotations/tests/run_leveling_tests.lua` (all 13 pass).
