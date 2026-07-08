# Bear Tank Form Safety Fix — 2026-07-07

## Problem
User reported bear tank rotation was:
1. **Auto-casting Challenging Roar on cooldown** — this is a situational AoE taunt (10 min CD) that should never be automatic.
2. **Dropping bear form to cast Barkskin** — Barkskin is caster-form only in TBC Classic and forces the druid out of bear form, which is lethal while tanking.
3. **Dropping bear form to use healthstones / healing potions / Innervate** — even when consumables were disabled, the rotation used its own hardcoded healthstone/potion logic.

## Root Cause
- `bear_sylvanas.lua` had `barkskin_matches` with no form guard and no toggle.
- `bear_sylvanas.lua` had `challenging_roar_matches` with no toggle.
- `bear_sylvanas.lua` had `healthstone_matches` and `potion_matches` that ignored the master `use_auto_consumables` / `use_healthstones` / `use_health_potions` settings.
- `middleware_sylvanas.lua` had Barkskin and Innervate strategies with no form guards, so they could fire while in bear/cat/moonkin/tree form.

## Changes

### 1. Schema (`schema_sylvanas.lua`)
Added two new Bear Tank settings:
- `bear_use_barkskin` — checkbox, **default false**, tooltip warns it breaks bear form.
- `bear_use_challenging_roar` — checkbox, **default false**, tooltip says it's situational.

### 2. Bear Spec (`bear_sylvanas.lua`)
- `build_state`: reads `use_barkskin` and `use_challenging_roar` from settings (default false).
- `healthstone_matches`: gates on `use_auto_consumables` and `use_healthstones`.
- `potion_matches`: gates on `use_auto_consumables` and `use_health_potions`.
- `barkskin_matches`: gates on `use_barkskin` AND `not s.is_bear`.
- `challenging_roar_matches`: gates on `use_challenging_roar`.
- Updated header comment to document the new safety invariants.

### 3. Druid Middleware (`middleware_sylvanas.lua`)
- **Barkskin strategy**: added shifted-form buff check (`9634, 5487, 768, 24858, 33891`) — will NOT fire if in bear/cat/moonkin/tree.
- **Innervate strategy**: added identical shifted-form buff check — will NOT fire if in any shifted form.

## Validation
- `luac -p` passes on all 3 modified files.
- `lua EaxRotations/tests/run_rotation_tests.lua` — 245/245 PASS.
- `lua EaxRotations/tests/run_leveling_tests.lua` — 13/13 PASS.
- `test_bear_custom_matches.lua` — PASS.
- `test_bear_vanilla_nil_guards.lua` — PASS.
- `test_druid_middleware_nil_guard.lua` — PASS.

## User Impact
- Existing bear tanks will see Challenging Roar and Barkskin **stop firing automatically** (safe default).
- Users who want Barkskin must enable `Bear Tank → Barkskin (breaks form)`.
- Users who want Challenging Roar must enable `Bear Tank → Challenging Roar`.
- Healthstones/potions now respect the Consumables tab toggles.
- Innervate will no longer break bear form.
