# Plan: WotLK Strategy DSL Adoption

**Status:** Proposed (2026-07-22)
**Previous:** TBC DSL adoption — 100% complete (all 29 TBC specs, `plans/strategy-dsl-lazy-context-2026-07-19.md`)

## Context

The TBC rotation system achieved **100% strategy DSL coverage** across all 29 specs. The same declarative DSL engine (`shared/strategy_dsl_sylvanas.lua`) is available for WotLK specs — they already use `spec_kit` + `safe_state` + `define_action_for_class`. The conversion is a mechanical substitution of imperative match functions for declarative `DSL_DEFS` entries, proven across 29 TBC specs.

## Current State

- **41 WotLK spec files** exist (all 10 classes + Death Knight + leveling)
- **0 placeholder match functions** (all specs have real implementations per `check_wotlk_placeholders.lua`)
- **WotLK test runner** (`run_wotlk_tests.lua`) registers only 2 tests:
  - `test_warrior_arms_wotlk.lua` (comprehensive, 14 assertions)
  - `test_wotlk_specs_load.lua` (verifies 25 specs load and return strategies/build_state)
- All WotLK specs already use `spec_kit` + `safe_state` + `define_action_for_class` + guarded registration + canonical return shape

## What's Needed Per Spec

Each WotLK spec conversion requires:
1. Add `local dsl = require("shared/strategy_dsl_sylvanas")` 
2. Create `DSL_DEFS` table converting each imperative `{name, matches, execute}` entry to a declarative `{name, conditions={...}, action={...}}` definition
3. Replace `local strategies = { ... }` with name-only placeholders: `local strategies = { { name = "BattleShout" }, ... }`
4. Add name-based substitution loop (same pattern as TBC specs: iterates strategies, finds matching DSL_DEFS by name, replaces in-place)
5. Create a DSL priority test (`test_<spec>_dsl_priority.lua`) for each spec
6. Register new tests in `run_wotlk_tests.lua`
7. Update `check_wotlk_placeholders.lua` if needed (should still pass since no placeholder-only match functions will remain)

## DSL Engine Compatibility

The existing DSL engine supports all condition types needed by WotLK specs:

| Condition | WotLK Use Case |
|-----------|---------------|
| `state` | Rage/mana/energy, combo points, stance, buff/debuff remains |
| `context` | in_combat, is_moving, is_pvp, target_distance, enemy_count |
| `spell_ready` | Gate all spell casts on readiness |
| `buff` / `debuff` | Eclipse proc, Missile Barrage, Taste for Blood, diseases |
| `debuff_remains` | Rend, Moonfire, Insect Swarm, Expose Armor |
| `custom` | `NS.should_use_long_cd`, stance-dance logic, boss-only gates |

No DSL engine extensions are expected for WotLK — the existing condition types already cover all WotLK mechanics (Eclipse, Missile Barrage, Death Knight diseases, Blood Presence, Frost Presence, Unholy Presence, Savage Roar, etc.).

## Migration Order (Suggested)

### Phase 1: Warrior (all 5 specs) — proven DSL pattern, multiple TBC warrior adoptions
1. `arms_wotlk.lua` — 19 strategies (most mature WotLK spec)
2. `fury_wotlk.lua`
3. `protection_wotlk.lua`
4. `leveling_wotlk.lua` (warrior)
5. `deathknight/blood_wotlk.lua` — 3 Death Knight specs are entirely new

### Phase 2: Mage + Druid — proven on TBC, mana-based casters
6. `arcane_wotlk.lua` — 11 strategies (clean caster pattern)
7. `fire_wotlk.lua`
8. `frost_wotlk.lua`
9. `balance_wotlk.lua` — 6 strategies (simple DoT + Eclipse pattern)
10. `cat_wotlk.lua`
11. `bear_wotlk.lua`
12. `resto_wotlk.lua` (+ leveling)

### Phase 3: Hunter + Rogue — proven on TBC, focus/energy resource models
13. `beast_mastery_wotlk.lua`
14. `marksmanship_wotlk.lua`
15. `survival_wotlk.lua`
16. `assassination_wotlk.lua`
17. `combat_wotlk.lua`
18. `subtlety_wotlk.lua`

### Phase 4: Paladin + Priest — proven on TBC, mana-based + healing logic
19. `holy_wotlk.lua` (paladin)
20. `protection_wotlk.lua` (paladin)
21. `retribution_wotlk.lua`
22. `discipline_wotlk.lua`
23. `holy_wotlk.lua` (priest)
24. `shadow_wotlk.lua`

### Phase 5: Warlock + Shaman — proven on TBC
25. `affliction_wotlk.lua`
26. `demonology_wotlk.lua`
27. `destruction_wotlk.lua`
28. `elemental_wotlk.lua`
29. `enhancement_wotlk.lua`
30. `restoration_wotlk.lua`

### Phase 6: Death Knight — entirely new to DSL, requires careful validation
31. `blood_wotlk.lua`
32. `frost_wotlk.lua` (deathknight)
33. `unholy_wotlk.lua`

### Phase 7: Leveling specs — lower priority, simpler patterns
34. `druid/leveling_wotlk.lua`
35. `hunter/leveling_wotlk.lua`
36. `mage/leveling_wotlk.lua`
37. `paladin/leveling_wotlk.lua`
38. `priest/leveling_wotlk.lua`
39. `rogue/leveling_wotlk.lua`
40. `shaman/leveling_wotlk.lua`
41. `warlock/leveling_wotlk.lua`
42. `warrior/leveling_wotlk.lua`
43. `deathknight/leveling_wotlk.lua`

## Test Strategy

- **Pre-completion**: `run_wotlk_tests.lua` has 2 suites (arms + spec-load). This is the baseline.
- **Per-spec test**: Add `test_<spec>_dsl_priority.lua` with priority-order assertions + basic match case checks (same pattern as TBC: `test_arms_dsl_priority.lua`, `test_fury_dsl_priority.lua`, etc.)
- **Post-migration**: `run_wotlk_tests.lua` will have 2 + N suites (one per converted spec)
- **Cross-check**: `luac -p` on every modified file; pre-commit hook covers TBC specs only, WotLK specs are validated by `run_wotlk_tests.lua` and `check_wotlk_placeholders.lua`

## Acceptance Criteria

1. All 41 WotLK spec files converted to DSL
2. `lua EaxRotations/tests/run_wotlk_tests.lua` — all suites pass
3. `lua EaxRotations/tests/check_wotlk_placeholders.lua` — 0 placeholders (passes)
4. `luac -p` — clean on all modified files
5. No regressions in TBC rotation suite (`lua EaxRotations/tests/run_rotation_tests.lua` — 372/372 green (23 of 41 WotLK specs committed))
6. Each spec's behavior is preserved (DSL definitions match original match/execute logic)

## Risk Assessment

- **Low risk**: All TBC specs already converted — the pattern is proven, the DSL engine is stable
- **Medium risk**: Death Knight specs (blood/frost/unholy) have new mechanics (runes, diseases, presences) — may need custom conditions
- **Low risk**: WotLK-specific procs (Eclipse, Missile Barrage, Taste for Blood) are covered by existing condition types (buff/proc checks)
- **Greenfield**: DK specs are the only WotLK-only class — no TBC reference implementation to follow, but the DSL is class-agnostic

## Reference

- TBC reference spec (first adopter): `EaxRotations/classes/warrior/arms_sylvanas.lua`
- DSL engine: `EaxRotations/shared/strategy_dsl_sylvanas.lua`
- Lazy context: `EaxRotations/shared/lazy_context_sylvanas.lua`
- Prior plan: `plans/strategy-dsl-lazy-context-2026-07-19.md`
- WotLK placeholder checker: `EaxRotations/tests/check_wotlk_placeholders.lua`
- WotLK load test: `EaxRotations/tests/test_wotlk_specs_load.lua`
