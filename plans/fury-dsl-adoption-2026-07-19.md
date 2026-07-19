# Plan: Fury Warrior — Second Strategy DSL Adoption

**Created:** 2026-07-19
**Status:** COMPLETE (2026-07-19 — gate 317+21 green)
**One concern:** migrate `classes/warrior/fury_sylvanas.lua` to partially adopt the
declarative strategy DSL, validating DSL generality beyond arms (first adopter,
commit `37f4bb01`).

## What was converted (7 strategies)

Chosen by reading each fury match function and picking the ones whose gates are
simple boolean/threshold checks that map cleanly onto DSL nodes:

| Strategy    | Why declarative-friendly |
|-------------|--------------------------|
| BattleShout | throttle + two `has_*` buff checks + rage >= 10 — same shape as arms |
| VictoryRush | player-exists check + `victory_rush_ready` truthy — same shape as arms |
| Rampage     | throttle + in_combat + apply/refresh rule (`has_rampage` / `buff_remains <= 3`) + rage >= 30 |
| Execute     | `execute_phase` state flag + `execute_phase_rage` setting gate — same shape as arms |
| Bloodthirst | WW-yield gate (custom node) + `bt_ready` + rage >= 30 — validates DSL on a core rotational ability |
| Whirlwind   | `ww_ready` + `aoe_cc_nearby` falsy + conditional rage/AoE gate (custom node) |
| DemoralizingShout | throttle + `demo_remains <= 5` + PvP/enemy-count/HP gate (custom node) + rage >= 10 |

Complex logic (WW-yield, Rampage refresh rule, DemoShout PvP/HP gate) lives in
`{ type = "custom", fn = ... }` nodes copied verbatim from the imperative match
functions, including `NS.broken_api_throttled` guards and Pattern 14
`(state.x or default)` nil-guards. Casts moved into `{ type = "custom", fn =
cast(...) }` actions with the same `build_action` rows.

Deliberately NOT converted (imperative kept): HeroicStrike/Cleave (RageManager
integration + starvation windows), Slam/SwingDesync (swing-timer math),
Hamstring (PvP/weave branch asymmetry), stance swaps, Charge/Intercept,
Recklessness/DeathWish (multi-branch CD alignment), SunderArmor (armor/mode
settings), Healthstone/potions/EngineeringBomb (custom executors).

## Wiring (mirrors arms exactly)

- `local dsl = require("shared/strategy_dsl_sylvanas")` next to the spec_kit require.
- `DSL_DEFS` block after the match functions; compiled via
  `dsl.compile_strategies(DSL_DEFS, { get_state = build_state })`.
- `DSL_BY_NAME` lookup substituted in the `for i = 1, #STRATEGY_SPECS` loop —
  priority order unchanged (DSL names replace imperative entries at the same
  indices: BattleShout=9, VictoryRush=13, Rampage=18, Execute=19,
  Bloodthirst=20, Whirlwind=21, DemoralizingShout=26).
- All imperative match functions remain referenced by `STRATEGY_SPECS`.
- Pattern 15 header updated to document the DSL adoption.

## Tests

- New `tests/test_fury_dsl_priority.lua` (63 assertions): full 29-name priority
  order, DSL positions, plus per-strategy condition-equivalence checks with
  representative state inputs (explicit state tables → no build_state needed).
- Registered in `tests/run_rotation_tests.lua` after `test_arms_dsl_priority.lua`.

## Gate results

- Rotation suites: 316 → **317 passed / 0 failed**
- Leveling suites: **21 passed / 0 failed**
- `luac -p` clean on all touched files.

## Behavior-preservation notes / accepted deviations (same as arms)

1. `action()` readiness gates (`NS.spell_ready`) in matches are replicated via
   state readiness fields where they exist (`bt_ready`, `ww_ready`,
   `victory_rush_ready`); for BattleShout/Rampage/Execute/DemoralizingShout the
   spells have no meaningful cooldown and the check moves to cast time
   (`NS.try_cast` fails safely; the dispatcher continues to the next strategy
   when `execute` returns false — verified in `main_sylvanas.lua` run_list).
2. Stance gates (`required_stance = BERSERKER`) are enforced by `cast()` at
   execute time rather than in matches (arms pattern); in practice
   BerserkerStance sits above all converted strategies in priority.
3. Execute's hard 15-rage floor from the imperative `action(min_rage=15)` is
   covered by the `execute_phase_rage` setting gate (default 25); only a user
   setting < 15 differs, matching the arms adopter's accepted edge.
