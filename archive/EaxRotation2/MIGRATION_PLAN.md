# EaxRotations to EaxRotation2 Migration Plan

## Executive Summary

Converting `EaxRotations/` to `EaxRotation2/` is possible, but not as a weekend refactor or a small compatibility shim. `api/common/izi_sdk.lua` already replaces most low-level castability, buff, debuff, item, and targeting boilerplate. It does not replace the gameplay policy that makes the legacy rotations complete: stance dancing, Slam weaving, consumables, interrupts, settings, healer triage, defensive logic, combat context, party scans, and spec-specific state machines.

The recommended path is **Option C: incremental migration**. Keep `EaxRotation2/` as the clean IZI-first target, build a small set of explicit engine/shared modules for missing policy, and port specs one at a time against measurable parity tests. Do not attempt a transparent metatable-backed `NS` shim. If a compatibility layer is needed, make it explicit, bounded, benchmarked, and temporary.

## Goals

- Preserve the reliability benefits of IZI: `izi.spell():cast_safe()`, object methods such as `unit:buff_up()`, and IZI target helpers as the castability source of truth.
- Recover the high-value gameplay policy currently present in `EaxRotations/` without copying the legacy framework wholesale.
- Keep each migrated spec understandable: preferred shape is `tick(me, target, enemies, ctx)` plus small shared helpers, not the old `NS.action_matches()` DSL everywhere.
- Support side-by-side operation until parity is proven.
- Make every phase verifiable with syntax tests, smoke tests, regression tests, and in-game checks.

## Non-Goals

- Do not delete `EaxRotations/` until all 29 specs have feature parity and field testing.
- Do not promise a 300-line compatibility layer. The honest compatibility surface is closer to 1,500 lines if it includes action matching, settings, aura points, item use, party safety, combat context, and healing policy.
- Do not reintroduce per-tick debug spam or manual castability gates that duplicate `cast_safe()`.
- Do not add WotLK/Cata spells or APIs outside Project Sylvanas `api/` and `apidocs/`.

## Recommended Architecture

```text
EaxRotation2/
  init.lua
  main.lua
  header.lua
  engine/
    dispatcher.lua              -- validates me/target/enemies, calls spec.tick()
    context.lua                 -- throttled combat/group/settings context
    settings.lua                -- Sylvanas core.menu-backed settings access
    spell_cache.lua             -- IZI spell rank fallback and 30s cache
    action.lua                  -- small explicit gates, not full legacy DSL first
    aura.lua                    -- buff/debuff points and safe aura access
    items.lua                   -- IZI item wrappers for consumables/trinkets
    units.lua                   -- same_unit, safe_field, class/mana helpers
  shared/
    interrupts.lua
    consumables.lua
    defensives.lua
    healer_engine.lua
    swing_timer.lua
    threat.lua
    cooldowns.lua
  specs/
    <class>/<spec>.lua          -- IZI-first priority logic
  tests/
    test_smoke.lua
    test_<module>.lua
    parity/<spec>_parity.lua
```

The engine should stay IZI-first. Shared modules may use raw Sylvanas APIs only where IZI has no equivalent, and those uses should be isolated behind named modules.

## Decision Matrix

| Option | Description | Pros | Cons | Use When | Verdict |
|---|---|---|---|---|---|
| A. Keep EaxRotation2 clean target | Continue with current ~60-100 line IZI specs and accept reduced feature depth | Lowest risk, fastest, easiest to debug, proves IZI reliability | Drops large amounts of gameplay policy per spec; not a full replacement | Testing IZI reliability, new simple rotations, emergency fallback package | Good short-term PoC, not full migration |
| B. NS compatibility shim | Run old `EaxRotations` specs on an IZI-backed fake `NS` layer | Preserves all spec logic initially; fewer spec edits | Large shim (~1,500 lines), semantic traps, hot-path overhead, harder debugging | Temporary parity harness or targeted legacy interop | Possible, but not recommended as final architecture |
| C. Incremental migration | Keep EaxRotation2 target, port shared policy modules and specs one by one | Best balance of reliability, maintainability, and feature parity | Months of work; requires disciplined tests and dual-running | Full replacement goal | **Recommended** |

Decision rule:

1. If the goal is immediate stable testing, choose **A**.
2. If the goal is preserving all old behavior this week, choose a bounded subset of **B**, but treat it as throwaway scaffolding.
3. If the goal is actually replacing `EaxRotations/`, choose **C** and budget months.

## Effort and Timeline

Assuming one engineer familiar with the repo and Sylvanas API:

| Phase | Duration | Outcome |
|---|---:|---|
| 0. Baseline and inventory | 3-5 days | Feature matrix, current EaxRotation2 test baseline, prioritized specs |
| 1. Foundation modules | 2-3 weeks | Explicit adapters for Tier 1/2 gaps and selected Tier 3 primitives |
| 2. Shared gameplay policy | 3-5 weeks | Interrupts, consumables, defensives, settings, healer engine, swing timer |
| 3. Pilot spec parity | 2-3 weeks | 3 migrated specs representing melee DPS, caster DPS, healer/tank |
| 4. Remaining spec migration | 8-14 weeks | All 29 specs ported with parity tests and field notes |
| 5. Hardening and cutover | 3-5 weeks | Performance, in-game QA, docs, default loader decision |

Realistic total: **4-6 months** for full feature parity. A reduced EaxRotation2 package can remain useful immediately, but it should not be described as equivalent to `EaxRotations/` until the later phases pass.

## Phase 0: Baseline and Inventory

### Deliverables

- `EaxRotation2/MIGRATION_PLAN.md` committed.
- A feature parity matrix with rows for all 29 specs and columns for:
  - core rotation priority
  - cooldowns
  - interrupts
  - consumables/trinkets/racials
  - defensives
  - settings/menu controls
  - leveling behavior
  - group/PvP logic
  - spec-specific mechanics such as stance dance, Slam weaving, Innervate targeting, PW:S absorb, Holy Shield charges
- A risk-ranked migration order.
- Baseline output from current tests.

### Suggested Migration Order

Start with specs that maximize learning while minimizing risk:

1. **Warrior Fury**: high-value melee policy gap; exposes rage, stance, Slam, interrupts, cooldowns.
2. **Priest Discipline**: exposes healer triage, PW:S absorb, group scanning, settings.
3. **Druid Balance**: exposes caster rotation, Innervate party scan, mana policy.
4. **Paladin Protection**: exposes tank policy, Holy Shield charges, defensives, threat.
5. Then complete remaining specs by class groups.

### Verification

Run from repo root:

```powershell
rtk luac -p EaxRotation2/init.lua
rtk luac -p EaxRotation2/main.lua
rtk luac -p EaxRotation2/engine/dispatcher.lua
rtk lua EaxRotation2/tests/test_smoke.lua
rtk lua EaxRotations/tests/run_rotation_tests.lua
rtk lua EaxRotations/tests/run_leveling_tests.lua
```

The legacy tests must remain green while EaxRotation2 is built side-by-side.

## Phase 1: Foundation Modules

### Goal

Build small explicit adapters that make IZI safe and ergonomic without recreating the entire legacy `NS` DSL.

### Tier 1: Direct Substitutions

Use these directly in specs unless a shared helper makes code clearer:

| Legacy | EaxRotation2 / IZI |
|---|---|
| `NS.GetPlayer()` | `izi.me()` |
| `NS.GetTarget()` | `izi.target()` |
| `NS.buff_up(unit, ids)` | `unit:buff_up(ids)` |
| `NS.debuff_remains(unit, ids)` | `unit:debuff_remains(ids)` |
| `NS.try_cast(spell, target, log)` | `spell:cast_safe(target)` |
| `NS.mana_pct(unit)` | `unit:mana_pct()` |
| `NS.GetEnemiesInRange(r)` | `izi.enemies(r)` or `me:get_enemies_in_range(r)` |

Implementation approach:

- Prefer direct IZI calls in spec code.
- Normalize `cast_safe()` return values only at module boundaries if needed; specs should treat any truthy successful cast as `true`.
- Keep logging outside spell readiness checks. If logging is needed, use the dispatcher's rate-limited idle reason pattern.

### Tier 2: Thin Adapters

Create these modules first:

#### `engine/spell_cache.lua`

Responsibilities:

- Replace `NS.spell_action({ ids = { ... } })` with cached `izi.spell(...)` objects.
- Support rank fallback using ordered spell IDs.
- Cache spell objects for 30 seconds or until spec reload.
- Expose:
  - `spell_cache.get(name, ids)`
  - `spell_cache.ready(spell, target, opts)`
  - `spell_cache.cast(spell, target)`

Notes:

- `ready()` should only add checks not covered by IZI, such as `expected_cooldown` or custom movement requirements.
- Do not duplicate all of `cast_safe()`.

#### `engine/items.lua`

Responsibilities:

- Replace `NS.is_item_ready(id)` and `NS.use_item_by_id(id, target)`.
- Expose:
  - `items.ready(id)` -> `izi.item(id):cooldown_up()`
  - `items.use_self(id)` -> `izi.item(id):use_self_safe()` or guarded `use_self()`
  - `items.use_on(id, unit)` -> `izi.item(id):use_on(unit)`

#### `engine/units.lua`

Responsibilities:

- Replace `NS.same_unit()` and `NS.safe_field()`.
- Provide pcall-safe unit field/method reads.
- Provide class checks used by Innervate, healing, and role logic.
- Expose:
  - `units.safe_call(unit, method, fallback, ...)`
  - `units.same(a, b)`
  - `units.class_id(unit)`
  - `units.hp_pct(unit)`
  - `units.mana_pct(unit)`

### Phase 1 Verification

- `luac -p` every new module.
- Add focused unit tests under `EaxRotation2/tests/` for cache behavior, item wrappers, and safe unit helpers.
- Extend `test_smoke.lua` mocks only as needed.
- Ensure current 29 PoC specs still load.

## Phase 2: Tier 3 Primitives and Shared Gameplay Policy

### Goal

Port the missing gameplay features as explicit shared modules. This phase creates the reusable foundation needed before deep spec parity work.

### Tier 3 Gap Handling

| Gap | Implementation Approach | Target Module |
|---|---|---|
| `NS.buff_points()` for PW:S absorb / Holy Shield charges | Add safe raw aura reader that returns `points` arrays. Use IZI object methods when available; otherwise isolate raw aura access here. | `engine/aura.lua` |
| `NS.action_matches()` / `NS.action_execute()` | Do not port wholesale first. Build small named predicates: `has_resource`, `target_hp_below`, `buff_missing`, `debuff_refresh`, `aoe_count_at_least`, `not_moving`, `stance_is`. Only add gates when a migrated spec needs them. | `engine/action.lua` |
| Observed enemy casts | IZI has local-player spell success, not full observed enemy casts. Keep Sylvanas `core.register_on_spell_cast_callback` behind an interrupt/event module. | `shared/interrupts.lua` |
| Settings/menu | Retain Sylvanas `core.menu.*`; wrap access in nil-guarded settings helpers. IZI is not a settings framework. | `engine/settings.lua` |
| Combat context (`incoming_dps`, `should_burst`) | Build throttled context using IZI time and object lists. Cache for 0.2-2.0 seconds depending on data cost. | `engine/context.lua` |
| Healing engine | Use `izi.friends()` as raw input only. Rebuild scoring: effective HP, tank priority, Weakened Soul/PW:S, dispel checks, incoming damage. | `shared/healer_engine.lua` |
| Party scan with class IDs | Use `units.class_id()`, `izi.party()` or `izi.friends()`, and safe mana checks. | `engine/units.lua`, spec helper |
| Swing timer / Slam weaving | Port swing tracking from legacy into a focused module with no dependency on `NS`. | `shared/swing_timer.lua` |
| Consumables/racials/trinkets | Use `engine/items.lua` and explicit setting gates. | `shared/consumables.lua`, `shared/cooldowns.lua` |

### Deliverables

- `engine/aura.lua` with `buff_points(unit, ids)` and `debuff_points(unit, ids)`.
- `engine/settings.lua` with nil-guarded menu reads and defaults.
- `engine/context.lua` producing `ctx` passed to specs: `ctx.now`, `ctx.in_combat`, `ctx.is_group`, `ctx.settings`, `ctx.lowest_friend`, `ctx.enemy_casts`, `ctx.should_burst`.
- `shared/interrupts.lua` using observed cast callbacks where required.
- `shared/consumables.lua` for healthstone, potions, trinkets, racials.
- `shared/healer_engine.lua` with tested triage output.
- `shared/swing_timer.lua` for melee timing.

### Verification

- Module unit tests with mocked IZI/core objects.
- Smoke test all 29 specs after dispatcher starts passing `ctx`.
- Legacy regression tests remain green.
- Manual in-game QA for:
  - interrupt fires on enemy casts
  - healthstone/potion fires at configured HP
  - healer engine selects expected low-HP unit
  - PW:S is not refreshed when absorb remains above threshold
  - Holy Shield charge refresh waits when meaningful charges remain

## Phase 3: Pilot Spec Parity

### Goal

Migrate representative specs deeply enough to prove the architecture before touching all 29 specs.

### Pilot 1: Warrior Fury

Port high-value legacy policy:

- Battle Shout maintenance.
- Bloodthirst / Whirlwind / Execute priority.
- Heroic Strike and Cleave rage dumping.
- Death Wish / Recklessness cooldown policy.
- Pummel interrupts via `shared/interrupts.lua`.
- Slam weaving via `shared/swing_timer.lua` if the legacy spec supports it.
- Stance requirements and stance-dance policy through explicit action predicates.
- Consumables/trinkets/racials through shared modules.
- Settings for thresholds and toggles.

Acceptance criteria:

- Fury PoC stays readable and IZI-first.
- No manual GCD/range/facing duplication except where IZI lacks a concept.
- Parity test covers priority outcomes for rage bands, execute target HP, interrupt target, buff state, cooldown enabled/disabled, and Slam timing.

### Pilot 2: Priest Discipline

Port:

- Healer triage with effective HP.
- PW:S absorb tracking via `engine/aura.lua`.
- Weakened Soul gating.
- Emergency heal thresholds.
- Damage fallback when no healing action is needed.
- Settings-backed thresholds.

Acceptance criteria:

- Does not overwrite healthy PW:S.
- Selects the expected friendly unit in mock triage cases.
- Still casts safely through IZI.

### Pilot 3: Druid Balance or Paladin Protection

Choose based on risk appetite:

- **Druid Balance** for Innervate party targeting, mana policy, caster DoT/debuff refresh.
- **Paladin Protection** for tank policy, Holy Shield charges, defensives, threat behavior.

Acceptance criteria:

- Spec-specific Tier 3 primitives are reusable by later specs.
- Manual in-game run confirms no idle spam and no silent failure in normal combat.

### Verification

For each pilot spec:

```powershell
rtk luac -p EaxRotation2/specs/<class>/<spec>.lua
rtk lua EaxRotation2/tests/test_smoke.lua
rtk lua EaxRotation2/tests/parity/<spec>_parity.lua
rtk lua EaxRotations/tests/run_rotation_tests.lua
rtk lua EaxRotations/tests/run_leveling_tests.lua
```

Also perform in-game smoke checks:

- Load only `EaxRotation2/init.lua`.
- Enter combat against a target dummy or low-risk mob.
- Confirm at least one successful cast per expected priority window.
- Confirm idle reasons are rate-limited and actionable.
- Confirm no Lua errors during 5 minutes of combat.

## Phase 4: Full Spec Migration

### Goal

Port all remaining specs by class groups using the pilot modules and parity test pattern.

### Class Group Order

1. Warrior: Arms, Fury, Protection
2. Priest: Discipline, Holy, Shadow, Smite
3. Druid: Balance, Bear, Cat, Resto
4. Paladin: Holy, Protection, Retribution
5. Mage: Arcane, Fire, Frost
6. Warlock: Affliction, Demonology, Destruction
7. Hunter: Beast Mastery, Marksmanship, Survival
8. Rogue: Assassination, Combat, Subtlety
9. Shaman: Elemental, Enhancement, Restoration

### Per-Spec Checklist

- Compare legacy spec against current EaxRotation2 spec.
- Categorize every legacy behavior as:
  - direct IZI call
  - shared module call
  - spec-local policy
  - intentionally omitted with documented reason
- Add/update settings defaults.
- Add parity tests for at least:
  - opener
  - normal priority
  - resource-starved state
  - execute/emergency state
  - buff/debuff refresh state
  - cooldown enabled/disabled
  - invalid target / no target safety
- Run syntax, smoke, parity, legacy tests.
- Complete one in-game smoke session before marking spec migrated.

### Deliverables

- 29 specs with documented parity status.
- Shared modules used by multiple specs instead of copy/paste helpers.
- `README.md` updated from PoC status to migration status when at least pilots pass.
- A `FEATURE_PARITY.md` or equivalent matrix maintained until cutover.

## Phase 5: Hardening and Cutover

### Goals

- Prove EaxRotation2 is stable enough to become the recommended loader.
- Keep legacy available as rollback until field confidence is high.

### Hardening Work

- Profile hot-path modules for allocation and per-tick CPU cost.
- Ensure shared modules reuse tables where needed.
- Audit for banned APIs: no `ffi.C`, `io.popen`, `os.execute`, `debug.*`.
- Audit distance checks for squared comparisons where manual distance math exists.
- Remove or rate-limit all per-tick string logging.
- Validate menu nil guards.
- Add loader docs explaining how to choose `EaxRotations` vs `EaxRotation2`.

### Cutover Criteria

Do not make EaxRotation2 the default until all are true:

- All 29 specs have parity tests.
- All EaxRotation2 syntax checks pass.
- `EaxRotation2/tests/test_smoke.lua` passes.
- Legacy `EaxRotations` rotation and leveling tests still pass.
- At least one in-game smoke test passes for every class.
- No known showstopper features remain missing from the parity matrix.
- Rollback instructions are documented.

## Verification Strategy

### Every Change

For any modified Lua file:

```powershell
rtk luac -p <modified-file>
```

For changed modules/specs:

```powershell
rtk lua EaxRotation2/tests/test_smoke.lua
```

### Module-Level Tests

Add mocked tests for every new engine/shared module:

- spell cache rank fallback and cache expiry
- item ready/use wrapper behavior
- settings fallback behavior
- aura points extraction and missing aura behavior
- safe unit method behavior when object methods throw
- healer scoring and tie-breaks
- interrupt observed-cast state
- swing timer timing windows

### Spec-Level Parity Tests

Each spec should get a parity test file that mocks `me`, `target`, `enemies`, `friends`, settings, buffs/debuffs, resources, and spell cast results. The test should assert the selected action, not just that `tick()` returns true.

### Repo-Level Regression

Run before merging a migrated spec group:

```powershell
rtk lua EaxRotation2/tests/test_smoke.lua
rtk lua EaxRotations/tests/run_rotation_tests.lua
rtk lua EaxRotations/tests/run_leveling_tests.lua
```

If practical, also syntax-check all EaxRotation2 Lua files:

```powershell
Get-ChildItem -Path EaxRotation2 -Recurse -File -Filter '*.lua' | ForEach-Object { rtk luac -p $_.FullName }
```

### Manual In-Game QA

For each migrated spec:

- Load `EaxRotation2/init.lua` in Sylvanas.
- Confirm spec detection or manual spec override.
- Fight target dummy or safe mob for 5 minutes.
- Confirm expected opener and steady-state casts.
- Toggle relevant settings and verify behavior changes.
- Test no target, invalid target, dead player, CC player, and out-of-combat states.
- Check console for Lua errors and idle spam.

## Highest-Value, Lowest-Risk Priorities

1. Keep current EaxRotation2 direct IZI casting model.
2. Add `engine/settings.lua` so specs can regain user controls without bringing back legacy `NS` complexity.
3. Add `engine/spell_cache.lua` and `engine/items.lua` to remove repeated spell/item boilerplate.
4. Add `engine/aura.lua` because PW:S absorb and Holy Shield charge behavior are concrete known gaps.
5. Add `shared/interrupts.lua` because IZI alone does not cover observed enemy casts.
6. Pilot Fury and Discipline before mass migration; they expose most architectural weaknesses early.
7. Only after pilots pass, migrate class groups.

## Risks and Mitigations

| Risk | Mitigation |
|---|---|
| Compatibility shim grows into a second legacy framework | Keep adapters explicit and module-scoped; reject metatable magic and whole-`NS` emulation as final design |
| Specs lose important behavior during simplification | Maintain feature parity matrix and per-spec parity tests |
| IZI method semantics differ from legacy helper semantics | Add focused tests for each adapter and manually QA high-risk behavior |
| Hot-path overhead from wrappers | Profile after Phase 2; cache spells/items; reuse tables in shared modules |
| Settings/menu crashes | Centralize nil-guarded setting reads in `engine/settings.lua` |
| Enemy cast observation missing | Use raw `core.register_on_spell_cast_callback` only inside `shared/interrupts.lua` |
| Healing behavior regresses | Build healer engine tests before porting healer specs |

## Engineering Rules

- IZI owns castability. Specs should not duplicate learned, cooldown, GCD, range, and facing checks unless a specific IZI gap is documented.
- Raw Sylvanas API access is allowed only in engine/shared modules with tests.
- Every new setting needs a fallback default and nil-guarded access.
- Every migrated spec needs a parity test before being marked done.
- Do not migrate all specs at once. Finish one pilot, verify, then generalize.
- Keep `EaxRotations/` tests green throughout the migration.

## Final Recommendation

Proceed with **Option C**. Treat the existing `EaxRotation2/` as a successful IZI-first proof of concept, not as a complete replacement yet. First add the foundation modules that cover known Tier 2 and Tier 3 gaps, then migrate Fury, Discipline, and one caster/tank pilot to prove the pattern. Only after those pilots pass syntax, smoke, parity, legacy regression, and in-game QA should the remaining 26 specs be migrated.
