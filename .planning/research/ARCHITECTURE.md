# Architecture Research

**Domain:** Druid reliability fixes in existing EAX reactive runtime
**Researched:** 2026-03-21
**Confidence:** HIGH

## Standard Architecture

### System Overview

```text
┌──────────────────────────────────────────────────────────────────────────┐
│ Per-Spec Tick Loop (existing)                                           │
├──────────────────────────────────────────────────────────────────────────┤
│ EAXDruidRestoration/main.lua                                            │
│ EAXDruidFeral/main.lua                                                  │
│  ├─ target selection + form/mode state                                  │
│  ├─ reactive_runtime.update_tick(..., adapter=reactive_adapter)         │
│  └─ spec rotation lane (healing lane / cat-bear lane)                   │
├──────────────────────────────────────────────────────────────────────────┤
│ Shared Decision Layer (existing, keep stable)                           │
│  reactive_runtime -> combat_context -> reactive_engine -> role_policy   │
│  + role helpers (healer_triage / tank_recovery)                         │
├──────────────────────────────────────────────────────────────────────────┤
│ Milestone Reliability Guards (new logic, mostly spec-local)             │
│  Resto role lock + solo DPS gate + group context cache                  │
│  Feral finisher gate (CP ownership, spend window, anti-overcap checks)  │
│  Adapter validation hooks (reactive action outcome logging)             │
└──────────────────────────────────────────────────────────────────────────┘
```

### Component Responsibilities

| Component | Responsibility | Typical Implementation |
|-----------|----------------|------------------------|
| `eax_shared/reactive_runtime.lua` | Keep branch ordering, adapter contract, retarget/restore safety | **Unchanged behavior**; only consume richer adapter outputs |
| `EAXDruidRestoration/main.lua` | Decide heal vs DPS by combat context and role policy | **Modified** with explicit `group_role_lock` gate before DPS fallback |
| `EAXDruidFeral/main.lua` | Execute cat/bear/guardian and CP finisher spend decisions | **Modified** with deterministic finisher gate before builder actions |
| `EAXDruidRestoration/menu.lua` | Operator controls for role lock and solo DPS safety | **Modified** with strict defaults (group lock ON, conservative solo DPS) |
| `EAXDruidFeral/menu.lua` | Operator controls for finisher consistency thresholds | **Modified** with CP spend safety toggles/thresholds |
| `tools/rotation_validation.lua` + role tests | Static guardrails for reactive parity and role-family contracts | **Existing** validation; extend with druid-specific assertions |
| `tools/dps_benchmark.lua` + `tools/benchmark_matrix.lua` | Runtime evidence collection and pass/fail matrix | **Existing** validation; use druid-focused runs as milestone gate |

## Recommended Project Structure

```text
EAXDruidRestoration/
├── main.lua                  # add group-role lock + solo DPS policy gate
├── menu.lua                  # add explicit reliability toggles/thresholds
└── utils.lua                 # keep casting/party helpers; no contract changes

EAXDruidFeral/
├── main.lua                  # add finisher reliability gate before builders
├── menu.lua                  # expose CP spend policy knobs with safe defaults
└── utils.lua                 # keep CP/mob identity helpers; avoid API drift

eax_shared/
├── reactive_runtime.lua      # unchanged adapter contract, used as integration bus
├── reactive_engine.lua       # unchanged branch order precedence
├── combat_context.lua        # unchanged source of role/threat/fail-safe data
├── healer_triage.lua         # existing resto ally-priority helper
└── tank_recovery.lua         # existing feral tank anti-aggro helper

tools/
├── rotation_validation.lua   # add druid reliability assertions
└── dps_benchmark.lua         # use matrix rows as acceptance evidence
```

### Structure Rationale

- **Spec-local first:** reliability bugs are behavior-level, so fix in `EAXDruidRestoration` and `EAXDruidFeral` first to minimize blast radius.
- **Shared runtime frozen:** keep `reactive_runtime`/`reactive_engine` contracts stable; they already provide safe sequencing and target-restore behavior.
- **Validation reused:** leverage existing matrix + role parity tooling instead of introducing new test infrastructure for this milestone.

## Architectural Patterns

### Pattern 1: Policy Gate Before Throughput Action

**What:** Insert explicit policy guards immediately before throughput actions (Resto DPS fallback, Feral builders) so reliability constraints are enforced at one choke point.
**When to use:** Any action that is valid only in a subset of contexts (solo-only DPS, finisher-only CP spend windows).
**Trade-offs:** Very low integration risk; small risk of over-blocking if thresholds are too strict.

**Example:**
```lua
-- Restoration: never DPS in grouped contexts
if policy.group_role_lock and context.in_group_content then
    return false -- skip DPS branch entirely
end

-- Feral: never build when spender window is open
if finisher_gate.should_spend_now(cp, energy, target_state) then
    return try_finisher(me, target)
end
```

### Pattern 2: Adapter-First Integration (No Engine Rewrite)

**What:** Implement milestone logic inside existing adapter handlers and spec rotation blocks; avoid changing shared reactive branch order.
**When to use:** Existing shared runtime already enforces action priority and retarget safety.
**Trade-offs:** Faster and safer for milestone delivery; less reusable than a full new shared policy module.

**Example:**
```lua
reactive_adapter.actions.life_save_ally = {
  handler = function(ctx, deps)
    -- apply resto role lock + triage routing here
    return try_group_stabilize_or_tank_save(ctx, deps)
  end,
}
```

### Pattern 3: Validation-Point Driven Changes

**What:** Every behavior change adds a deterministic checkpoint (static parity, runtime evidence, manual scenario pass/fail).
**When to use:** Manual-validation projects without a full automated combat simulator.
**Trade-offs:** Slightly more wiring in tools/docs; major reduction in regressions and ambiguous "looks better" claims.

## Data Flow

### Request Flow

```text
Sylvanas tick
    ↓
main.lua update callback
    ↓
build local context (mode/target/cp/form)
    ↓
reactive_runtime.update_tick(me, target, adapter)
    ↓
adapter action handlers (life_save/interrupt/anti_aggro)
    ↓
spec throughput lane (heal lane or cat/bear lane)
    ↓
policy gate checks (group lock / finisher gate)
    ↓
spell_queue cast request
```

### State Management

```text
runtime tables (per spec)
    ↓
cached mode + pending casts + combo state
    ↓
reactive_state (shared runtime hold/restore state)
    ↓
dps_meter snapshot + benchmark CSV rows
```

### Key Data Flows

1. **Resto role lock flow:** `detect_mode/get_effective_mode` -> `group context` -> block/allow `do_dps_fallback` -> cast or suppress offensive spell.
2. **Resto solo safety flow:** `me hp/mana + party_count + threat` -> solo DPS gate -> allow only safe offensive casts.
3. **Feral finisher flow:** `me:get_power(COMBOPOINTS_TBC)` + `cp_target` + `energy` + `rip_rem` -> finisher gate -> spend CP or continue builders.
4. **Reactive integration flow:** `combat_context` -> `reactive_engine action_id` -> druid adapter handler -> optional retarget/restore -> normal lane fallback.
5. **Validation evidence flow:** runtime counters/snapshot -> `dps_benchmark --matrix` rows -> druid milestone acceptance criteria.

## Scaling Considerations

| Scale | Architecture Adjustments |
|-------|--------------------------|
| Single milestone (now) | Keep changes in two druid specs + tool assertions; avoid shared runtime rewrites |
| Next class reliability waves | Extract repeated policy gates into shared `eax_shared` helpers once patterns stabilize |
| Full 27-spec hardening | Promote per-class reliability contracts into rotation validation and benchmark thresholds |

### Scaling Priorities

1. **First bottleneck:** inconsistent context detection (`solo` vs `group`) across specs; fix by centralizing druid mode gate usage before any DPS branch.
2. **Second bottleneck:** CP spend regressions from local edits; fix by making finisher gate the sole CP-spend entry point in feral cat lane.

## Anti-Patterns

### Anti-Pattern 1: Dual Source of Truth for DPS Eligibility

**What people do:** Check group/solo context in multiple scattered spots (targeting, lane entry, fallback spell blocks).
**Why it's wrong:** one missed branch reintroduces grouped DPS leaks in Resto.
**Do this instead:** one policy gate right before offensive cast path, reused everywhere.

### Anti-Pattern 2: Finisher Logic Interleaved With Builders

**What people do:** Evaluate builders and finishers in mixed order with ad-hoc CP checks.
**Why it's wrong:** causes CP overcap, delayed spend, and inconsistent finisher timing.
**Do this instead:** explicit finisher gate first; builders only run when gate says "not spend window."

## Integration Points

### External Services

| Service | Integration Pattern | Notes |
|---------|---------------------|-------|
| Sylvanas `core.object_manager` / `core.spell_book` / `core.input` | Existing direct API calls via spec `utils.lua` and runtime adapters | Keep API surface unchanged; milestone should not add new core dependencies |
| `common/modules/spell_queue` | Existing queued cast requests (`queue_spell_target`, fast variants) | Reliability gates should decide *whether* to cast, not alter queue mechanics |

### Internal Boundaries

| Boundary | Communication | Notes |
|----------|---------------|-------|
| `EAXDruidRestoration/main.lua` ↔ `eax_shared/reactive_runtime.lua` | Adapter callback contract | Keep required branches intact; add role-lock behavior inside handlers/rotation |
| `EAXDruidFeral/main.lua` ↔ `eax_shared/reactive_runtime.lua` | Adapter callback + resolve_target | No contract change; finisher reliability stays in feral rotation path |
| Druid specs ↔ `tools/rotation_validation.lua` | Static file-content assertions + syntax check | Add druid-specific checks: group lock present, finisher gate present |
| Druid specs ↔ `tools/dps_benchmark.lua` | Runtime snapshot to CSV row | Use druid-focused runs for acceptance: role-correct behavior + no unsafe skips |

## New vs Modified Components (Explicit)

### New (milestone capability additions)

1. **Resto group-role lock policy block** in `EAXDruidRestoration/main.lua` (new logic block).
2. **Resto solo DPS safety gate** in `EAXDruidRestoration/main.lua` (new logic block).
3. **Feral finisher gate block** in `EAXDruidFeral/main.lua` (new logic block controlling CP spend window).
4. **Druid-specific validation assertions** in `tools/rotation_validation.lua` (new checks, no new tool).

### Modified

1. `EAXDruidRestoration/main.lua` (wire new policy blocks into existing rotation + reactive adapter handlers).
2. `EAXDruidRestoration/menu.lua` (strict defaults and operator-facing controls for role lock / solo DPS limits).
3. `EAXDruidFeral/main.lua` (route cat lane through deterministic finisher gate before builder sequence).
4. `EAXDruidFeral/menu.lua` (expose finisher-related thresholds with conservative defaults).
5. `tools/rotation_validation.lua` (add druid reliability assertions without changing global validator flow).

## Dependency-Aware Build Order

1. **Lock acceptance contract first (docs + validator hooks)**
   - Add druid-specific assertions to `tools/rotation_validation.lua` (presence of role lock + finisher gate markers).
   - Validation point: static pass/fail before runtime testing.

2. **Implement Resto group role lock (highest trust issue)**
   - Insert single offensive gate before `do_dps_fallback` and any offensive spell calls.
   - Validation point: grouped dungeon/raid sessions show zero intentional DPS casts.

3. **Implement Resto solo DPS safety policy**
   - Permit offensive casts only when solo and safe (hp/mana/threat thresholds).
   - Validation point: solo sessions still DPS; group sessions remain heal/utility only.

4. **Implement Feral finisher gate before builders**
   - Centralize CP-spend decision path; builders only run outside spend window.
   - Validation point: no repeated CP overcap windows in combat logs; spend timing consistent.

5. **Wire menu defaults and migration-safe toggles**
   - Ship conservative defaults ON for reliability features; allow opt-out for troubleshooting.
   - Validation point: loading existing profiles does not break plugin startup.

6. **Run evidence loop and milestone gate**
   - `lua tools/rotation_validation.lua`
   - `lua tools/dps_benchmark.lua --matrix --live --runs 3 --label druid-reliability`
   - Manual scenario checks (group healing-only, solo DPS allowed, feral finisher consistency).

## Clear Validation Points

1. **VP-1 Static contract:** rotation validation passes with druid reliability assertions.
2. **VP-2 Adapter safety:** druid rows show `unsafe_skip_count=0`, `noop_unsupported_count=0`, `fail_safe_tick_count=0` in benchmark output.
3. **VP-3 Resto role correctness:** grouped runs show no offensive druid spell events while healing throughput remains active.
4. **VP-4 Solo fallback correctness:** solo runs show offensive casts only when safety gates pass.
5. **VP-5 Feral finisher reliability:** repeated combats show spend-before-overcap behavior and stable CP target lock at finisher threshold.

## Sources

- `C:\newbot\scripts\.planning\PROJECT.md`
- `C:\newbot\scripts\EAXDruidRestoration\main.lua`
- `C:\newbot\scripts\EAXDruidRestoration\menu.lua`
- `C:\newbot\scripts\EAXDruidFeral\main.lua`
- `C:\newbot\scripts\EAXDruidFeral\menu.lua`
- `C:\newbot\scripts\eax_shared\reactive_runtime.lua`
- `C:\newbot\scripts\eax_shared\reactive_engine.lua`
- `C:\newbot\scripts\eax_shared\combat_context.lua`
- `C:\newbot\scripts\eax_shared\healer_triage.lua`
- `C:\newbot\scripts\eax_shared\dps_meter.lua`
- `C:\newbot\scripts\tools\rotation_validation.lua`
- `C:\newbot\scripts\tools\dps_benchmark.lua`
- `C:\newbot\scripts\tools\benchmark_matrix.lua`
- `C:\newbot\scripts\tests\reactive_runtime_wiring_spec.lua`
- `C:\newbot\scripts\tests\healer_role_behavior_spec.lua`
- `C:\newbot\scripts\tests\tank_role_behavior_spec.lua`

---
*Architecture research for: Druid reliability fixes milestone (v1.2)*
*Researched: 2026-03-21*
