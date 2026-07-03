# Class Dead State-Field Bugfixes — 2026-07-03

**Type:** bugfix (one concern per commit)
**Baseline:** 219/219 rotation suites pass, 13/13 leveling pass, 0 invalid spell IDs.

## Problem
Static scan across `EaxRotations/classes/**/*_sylvanas.lua` found several spec
files that READ a `state.<field>` in a `matches`/`execute` function but NEVER
populate it in `build_state` (and the field is not in the spec's safe_state
schema). Result: the read is always `nil` (→ falsy for boolean, → skips for
guards), so the strategy path in question is silently dead code. Tests pass
because the dead paths are never exercised.

These are real functionality bugs (broken features), not style issues.

(One candidate — `shaman/healing_sylvanas.lua:169 state.natures_swiftness_active`
— was a FALSE POSITIVE: `healing_sylvanas.lua` is a helper called by
`restoration_sylvanas.lua`, which sets `resto_state.natures_swiftness_active`
and passes its state into `select_heal`. Excluded from scope.)

## Scope (4 fixes, one per commit)

### FIX-1 — `mage/fire_sylvanas.lua`: Clearcasting never consumed
- `fireball_matches_fn` (line ~107) reads `state.has_clearcasting`.
- `build_state` (line ~80) never assigns `has_clearcasting` (it also lacks `me`).
- Frost (line 191) and Arcane (line 184) both assign it; Fire is the outlier.
- **Result:** Clearcasting proc is never consumed by Fireball — broken feature.
- **Fix:** add `me` + `fire_state.has_clearcasting = me and NS.buff_up(me, CLEARCASTING_BUFF) or false` to `build_state`.

### FIX-2 — `warrior/arms_sylvanas.lua`: Death Wish boss-burst path is dead
- `death_wish_matches` (line ~754) reads `state.is_boss` and `state.target_hp_pct`.
- Neither is assigned in `build_state` nor in `ARMS_SCHEMA`.
- **Result:** Death Wish never auto-fires on boss targets >20% HP — a documented burst opener is dead.
- **Fix:** add `is_boss = false` + `target_hp_pct = 100` to `ARMS_SCHEMA`, and populate both in `build_state` (`bool_call(target, "is_boss")` + derive from `target_hp`).

### FIX-3 — `druid/bear_sylvanas.lua`: Nature's Grasp PvP root-break never fires
- `NaturesGraspPvP` matcher (line ~835) reads `state.is_rooted or state.is_snared`.
- Neither is assigned in `build_state`; `state.is_target_boss` IS (line 37) via `safe_method`.
- **Result:** Bear never auto-casts Nature's Grasp when rooted/snared in PvP — broken peel.
- **Fix:** populate `state.is_rooted`/`state.is_snared` from `safe_method(state.me, ...)` in `build_state`, near the existing `is_target_boss` assignment.

### FIX-4 — `warlock/demonology_sylvanas.lua`: stale `state.in_combat` reference
- `PetDefensive`/`PetPassive`/`PetAggressive` matchers (lines 469/478/487) read `state.in_combat`.
- `build_state` never assigns it; guards fall through to `context.in_combat` (works, but the `or state.in_combat` is dead/stale).
- **Result:** not a crash, but a stale read; correctness fix to populate the field.
- **Fix:** add `demo_state.in_combat = context.in_combat or false` to `build_state`.

## Validation (after EACH fix)
1. `luac -p <file>`
2. `lua EaxRotations/tests/run_rotation_tests.lua` (must stay 219/219)
3. `lua EaxRotations/tests/run_leveling_tests.lua` (must stay 13/13)

## Out of Scope
- kebab Execute rage-rich WW/MS deferral (line ~258): deliberate "DW priority" design, not a bug.
- Any file using `spec_kit.safe_state` with schema'd fields (covered by proxy).
- Pre-existing uncommitted diagnostics in `cat_sylvanas.lua` / `affliction_sylvanas.lua` (another session) — left untouched.