# Continuous Fixes — Warrior Leveling (Batch 1)

**Created:** 2026-07-01
**Status:** ✅ COMPLETE

## Goal
Ship a safe, atomic batch of bug/quality/spell-coverage fixes to the warrior leveling rotations.

## Changes

### 1. Dead code removal (5 locations)
Remove unreachable `if false then return ...("Scanner marker"/"PvP CC Gate") end` debug scaffolding:
- `classes/warrior/leveling_sylvanas.lua`: lines 467, 483, 536
- `classes/warrior/leveling_vanilla.lua`: lines 377, 438

### 2. Missing spell — vanilla leveling (all levels coverage)
Add to `classes/warrior/leveling_vanilla.lua`:
- **Berserker Rage** (18499, level 32) — fear immunity + rage generation

Already used in `arms_vanilla.lua`, `fury_vanilla.lua`, `protection_vanilla.lua`.
VictoryRush (34428) was considered but is TBC-only — NOT in any vanilla file or
vanilla spell data. Correctly excluded.

### 3. Test
Add `tests/test_warrior_leveling_vanilla_spells.lua` covering the new BerserkerRage strategy.

## Validation
- `luac -p` on both modified files + new test
- `lua EaxRotations/tests/run_rotation_tests.lua` — 214 pass
- `lua EaxRotations/tests/run_leveling_tests.lua` — 12 pass
