# Architecture Patterns

**Domain:** v1.1 Combat Intelligence for 27-spec TBC Lua rotations
**Researched:** 2026-03-20

## Recommended Architecture

Keep the current per-spec entrypoints (`EAX<Class><Spec>/main.lua`) and add a shared reactive pipeline in `common/eax_shared` so behavior depth increases without duplicating logic 27 times.

```text
Sylvanas Tick (per spec)
  -> main.lua:on_update
     -> preflight guards (enabled, player valid, mounted/eating, OOC)
     -> combat_context.build(...)               [NEW shared]
     -> reactive_engine.try_handle(ctx, deps)   [NEW shared]
        -> defensive_manager / interrupt_manager / utility adapters [existing]
     -> existing rotation lanes (core/utility/burst/queue)
     -> benchmark_probe.record(ctx, action)     [NEW shared]

CI/Tooling Flow
  -> tools/api_hard_gate.lua                    [NEW]
  -> tools/rotation_validation.lua              [MODIFIED]
  -> tools/dps_benchmark.lua                    [MODIFIED -> matrix mode]
  -> .planning/.../REGRESSION-CHECKLIST.md      [MODIFIED]
```

### Component Boundaries

| Component | Responsibility | Communicates With |
|-----------|---------------|-------------------|
| `main.lua` (27 specs) | Wiring/order only; passes spec metadata + adapters | `combat_context`, `reactive_engine`, existing lanes |
| `common/eax_shared/combat_context.lua` (new) | Build one normalized tick snapshot (player/target/party threat, incoming damage/heals, encounter flags, timing) | `encounter_manager`, `threat_manager`, `.api` health helpers |
| `common/eax_shared/reactive_engine.lua` (new) | Evaluate high-priority reactive rules before normal rotation | `defensive_manager`, `interrupt_manager`, spec adapter callbacks |
| `common/eax_shared/reactive_policies.lua` (new) | Role/spec rule tables and thresholds (DPS/HPS/TPS posture) | `reactive_engine`, spec keys |
| `tools/api_hard_gate.lua` (new) | Static allowlist gate for API usage (`@.api` contract) | `.api/**`, spec/shared Lua files |
| `tools/rotation_validation.lua` (modified) | Existing wiring/syntax checks + call hard-gate runner | `api_hard_gate`, spec discovery |
| `tools/dps_benchmark.lua` (modified) | Benchmark matrix output (all 27 rows, role columns, pass/fail thresholding) | `dps_meter`, `benchmark_probe` |
| `common/eax_shared/benchmark_probe.lua` (new) | Runtime counters for reactive events (save casts, interrupts, overheal cancels, threat saves) | `main.lua`, `reactive_engine`, `dps_meter` |

## Integration Plan: New vs Modified

### New Components

1. `common/eax_shared/combat_context.lua`
   - One function: `build(me, target, spec_meta, deps) -> ctx`.
   - Canonicalizes percentage scales (`0..1` internally) to stop mixed `0..100` vs `0..1` bugs.
   - Pulls predictive data from API-backed helpers (incoming damage and health forecast), encounter policy, and threat.

2. `common/eax_shared/reactive_engine.lua`
   - Stateless rule evaluator with strict precedence:
     `life_save > interrupt > anti-overheal > anti-aggro > burst_hold/release`.
   - Returns `{ acted = bool, reason = string, action_id = string }` for benchmark instrumentation.

3. `common/eax_shared/reactive_policies.lua`
   - Central threshold table keyed by role/spec (e.g., healer overheal cancel, tank emergency windows).
   - Prevents re-encoding identical thresholds in each `main.lua`.

4. `common/eax_shared/benchmark_probe.lua`
   - Collects reactive counters and timing windows per combat session.
   - Merges with `dps_meter` snapshot for matrix reporting.

5. `tools/api_hard_gate.lua`
   - Fails build/validation when files use non-approved API surfaces.
   - Enforces "allowed roots + approved methods" from `.api` docs and local allowlist.

### Modified Components

1. `EAX*/main.lua` (all 27)
   - Add one shared call path at the top of combat lane:
     `ctx = combat_context.build(...)` then `if reactive_engine.try_handle(ctx, deps).acted then return end`.
   - Keep spec-specific rotation logic intact after reactive guard.

2. `common/eax_shared/defensive_manager.lua`
   - Accept optional context and role posture so defensive triggers can use predicted damage, not HP only.

3. `common/eax_shared/interrupt_manager.lua`
   - Accept context priority hints (encounter urgency, healer-at-risk target scoring).

4. `tools/rotation_validation.lua`
   - Keep current checks; append hard-gate check and fail-fast output per spec/file.

5. `tools/dps_benchmark.lua`
   - Add `--matrix` mode that emits one row per spec with: DPS/HPS/TPS proxy + reactive KPIs + pass/fail verdict.

## Data Flow

1. `main.lua` obtains `me`, `target`, menu state, and existing mode/encounter hints.
2. `combat_context.build` composes a stable `ctx` object:
   - `ctx.self`: hp/resource/threat/incoming damage profile
   - `ctx.target`: cast state, TTD, threat relation
   - `ctx.party`: ally risk summary (for healers)
   - `ctx.encounter`: boss policy flags (`tank_damage_heavy`, `hold_cooldowns`, etc.)
3. `reactive_engine` evaluates policies in order and invokes existing managers/adapters.
4. If no reactive action fires, normal per-spec lanes execute unchanged.
5. `benchmark_probe` records outcomes for later matrix generation.
6. Tooling layer runs:
   - `rotation_validation` -> wiring/syntax + API hard gate
   - `dps_benchmark --matrix` -> standardized 27-spec matrix

## Patterns to Follow

### Pattern 1: Context-First Tick
**What:** Build context once per tick and pass it to all decision lanes.
**When:** Every combat tick in every spec.
**Example:**
```lua
local ctx = combat_context.build(me, target, SPEC_META, {
    encounter_manager = encounter_manager,
    threat_manager = threat_manager,
})

local reactive = reactive_engine.try_handle(ctx, deps)
if reactive.acted then
    benchmark_probe.record(ctx, reactive)
    return
end
```

### Pattern 2: Adapter Boundary for Spec Actions
**What:** Shared engine decides *what*; spec adapter decides *how* (spell IDs, cast wrappers).
**When:** Any action that differs by spec but shares intent.
**Example:**
```lua
local deps = {
    actions = {
        emergency_self = try_last_stand_or_equivalent,
        anti_overheal_cancel = try_cancel_heal,
        aggro_drop = try_fade_or_feign,
    }
}
```

## Anti-Patterns to Avoid

### Anti-Pattern 1: Re-implementing Reactive Logic in Each `main.lua`
**What:** Copy/paste role checks and incoming-damage logic per spec.
**Why bad:** 27x drift, inconsistent fixes, regression risk.
**Instead:** One `reactive_engine` + per-spec adapters.

### Anti-Pattern 2: HP-Only Defensive Triggers
**What:** Triggering defensives only from current HP thresholds.
**Why bad:** Too late for burst windows; ignores incoming damage prediction.
**Instead:** Use `current HP + predicted incoming` in context.

### Anti-Pattern 3: Hard Gate as Grep-Only String Match
**What:** Naive text search for banned tokens.
**Why bad:** False positives/negatives, easy bypass.
**Instead:** Build allowlist from `.api` surfaces and enforce per-file normalized call extraction.

## Scalability Considerations

| Concern | At 27 specs (now) | At 27 specs + v1.1 depth | Future content growth |
|---------|-------------------|--------------------------|-----------------------|
| Logic reuse | Shared managers already help | Add shared reactive layer to avoid new duplication | Keep per-spec adapters thin |
| Tick cost | Acceptable | Context caching (short TTL) + one snapshot per tick | Add optional sampling for heavy metrics |
| Validation quality | Syntax + import checks | Add API hard gate + matrix KPI thresholds | Add trend tracking per commit/run |
| Regression handling | Manual checklist | Matrix-backed pass/fail per spec | Historical baseline comparisons |

## Dependency-Safe Build Order

1. **Introduce `combat_context.lua` (read-only integration)**
   - No behavior changes; just expose normalized snapshot and loggable context.
2. **Introduce `reactive_policies.lua` + `reactive_engine.lua` behind feature flag**
   - Wire only one low-risk rule first (e.g., anti-overheal cancel).
3. **Add adapter calls in all 27 `main.lua` files**
   - Same insertion point and return contract; no lane rewrites.
4. **Upgrade `defensive_manager` and `interrupt_manager` to accept context hints**
   - Backward-compatible signature to avoid breakage.
5. **Add `benchmark_probe.lua` and extend `dps_benchmark.lua --matrix`**
   - Emit deterministic matrix schema with reactive KPIs.
6. **Implement `tools/api_hard_gate.lua` and hook into `rotation_validation.lua`**
   - Gate non-compliant API usage before benchmark signoff.
7. **Flip feature flag to required and enforce matrix + hard-gate in milestone quality checks**
   - Final step once all 27 specs are wired and stable.

## Sources

- `C:\newbot\scripts\.planning\PROJECT.md` (milestone goals and constraints)
- `C:\newbot\scripts\.planning\STATE.md` (current progress and prior decisions)
- `C:\newbot\scripts\EAXWarriorProtection\main.lua` (current per-spec tick wiring pattern)
- `C:\newbot\scripts\EAXPriestHoly\eax_utils.lua` (existing predictive overheal behavior)
- `C:\newbot\scripts\eax_shared\encounter_manager.lua` (encounter policy surface)
- `C:\newbot\scripts\eax_shared\defensive_manager.lua` (current HP-threshold defensive model)
- `C:\newbot\scripts\tools\rotation_validation.lua` (current validation gate)
- `C:\newbot\scripts\tools\dps_benchmark.lua` (current benchmark tool contract)
- `C:\newbot\scripts\.api\common\modules\health_prediction.lua` (incoming damage API surface)
- `C:\newbot\scripts\.api\common\izi_sdk.lua` (documented game object predictive/role methods)
