# Plan: Range Verification Audit + Fix (rotation stall when OOR)

**Started:** 2026-07-06
**Status:** In Progress
**Scope:** `EaxRotations/core_sylvanas.lua` (centralized) + targeted spec audit

## Problem (user report)
Rotations stall when out of range of a specific spell. Example: Shadow Priest Mind
Flay (24yd) is chosen while Mind Blast (36yd) is in range — the rotation "pauses"
until the player closes to 24yd instead of falling through to the in-range spell.

## Root Cause
Two defects in `core_sylvanas.lua`:

1. **`NS.is_spell_in_range` fails OPEN on a native OOR verdict.** When
   `spell_helper:is_spell_in_range` returns `false` (out of range), the function
   does NOT return false — it falls through to a blanket `dist <= 45` fallback
   (or `return true`). So a 24yd Mind Flay at 30yd is reported "in range". This
   is explicitly codified by `tests/test_range_false_fallback_allows_cast.lua`
   ("a hard failure would freeze the rotation") — the fail-open is intentional
   ONLY for the "range data unavailable" case, but it currently masks real OOR.

2. **No defense-in-depth OOR gate in `NS.evaluate_cast`.** The casting path relies
   solely on `spell_helper.is_spell_castable` (native). If that has a quirk for
   channeled spells (Mind Flay), an OOR spell *commits* (`try_cast` returns true
   via `spell_queue`), stopping the dispatcher on that one spell → stall.

Secondary finding: `NS.get_spell_range` checks `result.min`/`result.max` but the
API may return `min_range`/`max_range` (apidocs/api conflict) — broken, currently
unused.

## Fix (centralized — benefits all 29 specs)

### core_sylvanas.lua
1. **`NS.is_spell_in_range`**: respect the native `spell_helper` verdict (return
   `false` on OOR instead of falling through). Fallback (no spell_helper): use
   accurate `get_spell_max_range` + `NS.unit_distance`; fail-open ONLY when range
   genuinely cannot be determined (no max_range data, or unknown distance sentinel).
2. **`NS.is_out_of_range(spell, target)`** (NEW): independent ground-truth check —
   `unit_distance > spell_max_range + tolerance`. Returns true ONLY on confident,
   clear OOR (distance is a real number < 100, excluding the 999 "unknown"
   sentinel). Fail-open otherwise. Used as a backstop independent of native quirks.
3. **`NS.evaluate_cast`**: add defense-in-depth gate after the castable check —
   if `not skip_range and target != player and NS.is_out_of_range(spell, target)`
   then `return false`. This makes `try_cast` return false on OOR so the
   dispatcher (`run_list` in main_sylvanas.lua) falls through to the next strategy.
   Conservative `RANGE_TOLERANCE = 5.0` yd — only blocks clear OOR (e.g. MF@30,
   not MB@36), avoiding false positives from hitbox/range-data slack.
4. **`NS.get_spell_range`**: handle both `min/max` and `min_range/max_range`
   field names (correctness; unused today).
5. Cache `_get_spell_max_range` at module load.

### Spec audit (skip_range=true on targeted spells)
- `druid/balance_sylvanas.lua` Innervate — already self-gated (safe).
- `druid/resto_sylvanas.lua` Innervate — INNERVATE_OPTS has NO skip_range (safe).
- `druid/middleware_sylvanas.lua` Remove Curse/Abolish Poison on `target` use
  `skip_range=true` → bypass the new gate. **Deferred** (dispel target selection
  is form/aura-gated; changing risks dispel tests). Documented as follow-up.
- `priest/shadow_sylvanas.lua` PW:F — already fixed (uncommitted) with range gate.

## Why this is safe (no test regressions)
- No test mocks `get_spell_max_range`/`get_spell_range_data` → `is_out_of_range`
  returns false (fail-open) in ALL existing tests → distance gate is a no-op in
  tests, active in production.
- `is_spell_in_range` fallback fails-open when no max_range data → tests mocking
  `get_distance` (values up to 10000) are unaffected.
- `test_range_false_fallback_allows_cast.lua` still passes (no max_range data →
  fail-open → `is_spell_in_range == true`, cast allowed).

## Validation
- `luac -p` on `core_sylvanas.lua` + new test file.
- `lua EaxRotations/tests/run_rotation_tests.lua` (219 suites).
- `lua EaxRotations/tests/run_leveling_tests.lua` (13 suites).
- New regression test: `test_range_verification_oor_fallthrough.lua` — verifies
  try_cast returns false (no commit) when OOR by distance, and is_spell_in_range
  respects a native false verdict.

## Files
- `EaxRotations/core_sylvanas.lua` (edit)
- `EaxRotations/tests/test_range_verification_oor_fallthrough.lua` (new)
- `EaxRotations/tests/run_rotation_tests.lua` (register new test)
