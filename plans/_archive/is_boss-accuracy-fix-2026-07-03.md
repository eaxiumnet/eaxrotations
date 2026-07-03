# is_boss Detection Accuracy Fix — 2026-07-03

**Type:** bugfix (one concern per commit)
**Baseline:** 219/219 rotation + 13/13 leveling green; 0 invalid spell IDs.

## Problem
The Sylvanas API docs (`apidocs/pages/dev/api/game-object.md`) explicitly warn that
the raw unit method `target:is_boss()` is **inaccurate** ("only certain bosses like
world bosses have this flag enabled") and recommend the **`unit_helper` module's**
`is_boss()` for accurate boss detection.

EaxRotations already exposes the accurate helper: `core_sylvanas.lua` wires
`NS.unit_is_boss(unit)` → `_unit_helper:is_boss(unit)` (the accurate one), and
`main_sylvanas.lua:494` computes `context.target_is_boss` once via that helper,
exposing it on every combat context (asserted non-nil by `test_context_completeness`).

But several call sites **bypass the accurate value** and call the raw, inaccurate
`target:is_boss()` directly. Consequences:
- `arms_sylvanas.lua` Death Wish boss-burst gate (recently added in [#fix-2]) may
  never fire on dungeon/raid bosses that the raw flag misses → dead burst CD.
- `combat_forecast_gate_sylvanas.lua` may wrongly throttle long CDs (Combustion,
  Demonic Sacrifice) on bosses because `is_boss` reads false on a real boss.
- `bear_sylvanas.lua` is mostly OK (context-first) but its fallback is the raw method.

## Scope (one commit, 3 micro-edits on one shared concern)
1. `shared/combat_forecast_gate_sylvanas.lua` — use `context.target_is_boss == true`
   first; fall back to `_G.EaxRotations.unit_is_boss(context.target)`.
2. `classes/warrior/arms_sylvanas.lua` — `arms_state.is_boss = context.target_is_boss
   == true or (NS.unit_is_boss and NS.unit_is_boss(target)) or false` (drop raw
   `bool_call(target,"is_boss")`).
3. `classes/druid/bear_sylvanas.lua` — keep context-first, replace raw
   `safe_method(state.target,"is_boss",false)` fallback with `NS.unit_is_boss(state.target)`.

## Validation
1. `luac -p` on the 3 files
2. `run_rotation_tests.lua` (219/219) + `run_leveling_tests.lua` (13/13)
3. sylvanas + vanilla spell audits (pre-commit)

## Out of Scope
- `is_tank` accuracy (`is_tank_unit` uses raw `unit:is_tank()` + role fallback, not
  the official `unit_helper:is_tank`): docs do NOT explicitly warn the raw
  `is_tank` is inaccurate (unlike is_boss), so this is a "could-be-better", not a
  confirmed bug. Noted for a future pass.
- `health_prediction`/`target_selector` modules: EaxRotations already uses their
  underlying capabilities (unit methods + own predictors). Not a gap.