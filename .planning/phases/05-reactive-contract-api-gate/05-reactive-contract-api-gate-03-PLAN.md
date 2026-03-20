---
phase: 05-reactive-contract-api-gate
plan: 03
type: execute
wave: 1
depends_on: []
files_modified:
  - eax_shared/reactive_runtime.lua
  - eax_shared/dps_meter.lua
  - tools/dps_benchmark.lua
  - tests/reactive_runtime_spec.lua
  - tests/dps_meter_spec.lua
  - tests/dps_benchmark_spec.lua
autonomous: true
requirements: [REACT-01, REACT-03]
user_setup: []
gap_closure: true
must_haves:
  truths:
    - "Shared runtime code can build one normalized reactive snapshot and persist its winning telemetry each tick"
    - "Benchmark live rows read the same reactive_action and reason_code fields that runtime evaluation writes"
    - "Reactive telemetry defaults to none/NO_ACTION only when no branch wins, not because the runtime path is disconnected"
  artifacts:
    - path: "eax_shared/reactive_runtime.lua"
      provides: "Shared runtime bridge from combat snapshot to reactive result"
      contains: "update_tick"
    - path: "eax_shared/dps_meter.lua"
      provides: "Shared benchmark snapshot including reactive telemetry fields"
      contains: "set_reactive_state"
    - path: "tools/dps_benchmark.lua"
      provides: "Live benchmark row output sourced from runtime reactive telemetry"
      contains: "reactive_action"
  key_links:
    - from: "eax_shared/reactive_runtime.lua"
      to: "eax_shared/combat_context.lua"
      via: "combat_context.build"
      pattern: "combat_context\.build"
    - from: "eax_shared/reactive_runtime.lua"
      to: "eax_shared/reactive_engine.lua"
      via: "reactive_engine.try_handle"
      pattern: "reactive_engine\.try_handle"
    - from: "eax_shared/dps_meter.lua"
      to: "tools/dps_benchmark.lua"
      via: "reactive_action/reason_code snapshot contract"
      pattern: "reactive_action|reason_code"
---

<objective>
Close the Phase 05 runtime-telemetry gap by adding one shared reactive runtime bridge that evaluates the normalized combat snapshot each tick and stores the winning reason/action in the benchmark-facing snapshot.

Purpose: Phase 05 must prove the reactive contract is alive in runtime code before Phase 06 starts full cast-lane integration across all 27 specs.
Output: A shared `reactive_runtime` bridge, an extended `dps_meter` contract, and benchmark output that reads live reactive telemetry instead of placeholder-only data.
</objective>

<execution_context>
@C:/Users/Support/.config/opencode/get-shit-done/workflows/execute-plan.md
@C:/Users/Support/.config/opencode/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/PROJECT.md
@.planning/ROADMAP.md
@.planning/STATE.md
@.planning/phases/05-reactive-contract-api-gate/05-CONTEXT.md
@.planning/phases/05-reactive-contract-api-gate/05-VERIFICATION.md
@.planning/phases/05-reactive-contract-api-gate/05-01-SUMMARY.md
@.planning/phases/04-polish-competitive-features/04-01-SUMMARY.md
@eax_shared/combat_context.lua
@eax_shared/reactive_engine.lua
@eax_shared/dps_meter.lua
@tools/dps_benchmark.lua

<interfaces>
From `eax_shared/combat_context.lua`:
```lua
function combat_context.build(me, target, spec_meta, deps)
  -- returns ctx.meta, ctx.self, ctx.target, ctx.party, ctx.encounter
end
```

From `eax_shared/reactive_engine.lua`:
```lua
function reactive_engine.try_handle(ctx, deps)
  -- returns { acted, reason_code, action_id, hold_until_s }
end
```

From `eax_shared/dps_meter.lua`:
```lua
function dps_meter.get_snapshot()
  -- currently returns damage_total, healing_total, duration_s, dps, hps, in_combat
end
```
</interfaces>
</context>

<tasks>

<task type="auto" tdd="true">
  <name>Task 1: Add a shared runtime bridge that persists reactive telemetry</name>
  <read_first>
    - .planning/phases/05-reactive-contract-api-gate/05-VERIFICATION.md
    - .planning/phases/05-reactive-contract-api-gate/05-01-SUMMARY.md
    - .planning/phases/04-polish-competitive-features/04-01-SUMMARY.md
    - eax_shared/combat_context.lua
    - eax_shared/reactive_engine.lua
    - eax_shared/dps_meter.lua
    - tests/dps_meter_spec.lua
  </read_first>
  <files>eax_shared/reactive_runtime.lua, eax_shared/dps_meter.lua, tests/reactive_runtime_spec.lua, tests/dps_meter_spec.lua</files>
  <behavior>
    - Test 1: `update_tick(me, target, deps)` builds one combat context, runs one `reactive_engine.try_handle(...)` evaluation, and returns both `ctx` and `result`.
    - Test 2: `dps_meter.get_snapshot()` now exposes `reactive_action`, `action_id`, `reason_code`, and `context_fail_safe` on idle, combat, and post-combat snapshots.
    - Test 3: runtime reactive telemetry is persisted through `dps_meter.set_reactive_state(...)` without changing existing DPS/HPS accumulation behavior.
  </behavior>
  <action>Create `eax_shared/reactive_runtime.lua` exporting `update_tick(me, target, deps)`. Inside `update_tick`, call `combat_context.build(me, target, nil, { health_prediction = require("health_prediction"), encounter_manager = deps.encounter_manager, party_reader = deps.party_reader, now_s = deps.now_s })`, then call `reactive_engine.try_handle(ctx, { state = deps.state, actions = DEFAULT_ACTIONS })`. Implement these exact shared telemetry-only handlers: `life_save_self` when `ctx.self.hp_pct > 0 and ctx.self.hp_pct <= 0.35` -> `{ action_id = "life_save_self" }`; `life_save_ally` when `ctx.party.any_ally_critical` -> `{ action_id = "life_save_ally" }`; `interrupt_control` when `ctx.target.exists and (ctx.target.is_casting or ctx.target.is_channeling) and ctx.target.interruptible` -> `{ action_id = "interrupt_control" }`; `anti_overheal` when `ctx.self.incoming_heal_pct >= 0.50 and ctx.self.hp_pct >= 0.85` -> `{ action_id = "anti_overheal" }`; `anti_aggro` when `ctx.self.threat_pct >= 0.90 and not ctx.self.is_tank` -> `{ action_id = "anti_aggro" }`; `throughput_resume` when `ctx.meta.fail_safe ~= true` -> `{ action_id = "throughput_resume", hold_until_s = 0 }`. After evaluation, call `dps_meter.set_reactive_state({ reactive_action = result.action_id or "none", action_id = result.action_id or "none", reason_code = result.reason_code or "NO_ACTION", context_fail_safe = ctx.meta.fail_safe == true })`. Extend `eax_shared/dps_meter.lua` so `zero_snapshot`, `build_snapshot`, and `get_snapshot` all include those four telemetry keys, and add `set_reactive_state(payload)` plus reset/clear logic on `reset`, `on_combat_start`, and `on_combat_end`. Preserve existing damage/heal totals and rates exactly.</action>
  <acceptance_criteria>
    - `eax_shared/reactive_runtime.lua` contains `function reactive_runtime.update_tick`
    - `eax_shared/reactive_runtime.lua` contains `life_save_self` and `interrupt_control`
    - `eax_shared/dps_meter.lua` contains `function dps_meter.set_reactive_state`
    - `eax_shared/dps_meter.lua` contains `reactive_action` and `context_fail_safe`
    - `tests/reactive_runtime_spec.lua` exits 0
    - `tests/dps_meter_spec.lua` exits 0
  </acceptance_criteria>
  <verify>
    <automated>rtk lua tests/reactive_runtime_spec.lua && rtk lua tests/dps_meter_spec.lua && rtk rg -n "function reactive_runtime.update_tick|life_save_self|interrupt_control|function dps_meter.set_reactive_state|reactive_action|context_fail_safe" eax_shared/reactive_runtime.lua eax_shared/dps_meter.lua</automated>
  </verify>
  <done>The shared runtime contract evaluates one normalized reactive snapshot and persists the winning action/reason into the benchmark-facing telemetry snapshot.</done>
</task>

<task type="auto" tdd="true">
  <name>Task 2: Unify benchmark live rows with the runtime reactive telemetry contract</name>
  <read_first>
    - .planning/phases/05-reactive-contract-api-gate/05-VERIFICATION.md
    - eax_shared/dps_meter.lua
    - tools/dps_benchmark.lua
    - tests/dps_benchmark_spec.lua
    - tests/reactive_runtime_spec.lua
  </read_first>
  <files>tools/dps_benchmark.lua, tests/dps_benchmark_spec.lua, tests/reactive_runtime_spec.lua</files>
  <behavior>
    - Test 1: dry-run rows still emit deterministic `none,NO_ACTION` placeholders.
    - Test 2: live `CURRENT_SPEC` rows read `reactive_action` and `reason_code` from the shared runtime snapshot.
    - Test 3: benchmark code still accepts older `action_id`-only snapshots as a compatibility fallback, but the canonical emitted field is `reactive_action`.
  </behavior>
  <action>Update `tools/dps_benchmark.lua` so live rows read `reactive_action` first, then fall back to `action_id`, and always keep the CSV/schema header as `reactive_action,reason_code`. Extend `tests/dps_benchmark_spec.lua` with a non-dry-run path that seeds `dps_meter.set_reactive_state({ reactive_action = "interrupt_control", action_id = "interrupt_control", reason_code = "INTERRUPT_DANGER", context_fail_safe = false })`, calls `run_benchmark({})`, and asserts the `CURRENT_SPEC` row ends with `interrupt_control,INTERRUPT_DANGER`. Extend `tests/reactive_runtime_spec.lua` so the runtime bridge asserts `result.action_id` and the persisted benchmark field `reactive_action` stay equal for the winning branch.</action>
  <acceptance_criteria>
    - `tools/dps_benchmark.lua` contains `snapshot_field(snapshot, "reactive_action"`
    - `tools/dps_benchmark.lua` contains `snapshot_field(snapshot, "action_id"`
    - `tests/dps_benchmark_spec.lua` exits 0
    - `rtk lua tools/dps_benchmark.lua --dry-run` exits 0
  </acceptance_criteria>
  <verify>
    <automated>rtk lua tests/dps_benchmark_spec.lua && rtk lua tests/reactive_runtime_spec.lua && rtk lua tools/dps_benchmark.lua --dry-run && rtk rg -n "reactive_action|action_id|CURRENT_SPEC|INTERRUPT_DANGER" tools/dps_benchmark.lua tests/dps_benchmark_spec.lua tests/reactive_runtime_spec.lua</automated>
  </verify>
  <done>Benchmark output consumes the same live reactive telemetry fields produced by runtime evaluation instead of depending on placeholder-only snapshots.</done>
</task>

</tasks>

<verification>
Run the runtime telemetry bridge checks:
- `rtk lua tests/reactive_runtime_spec.lua`
- `rtk lua tests/dps_meter_spec.lua`
- `rtk lua tests/dps_benchmark_spec.lua`
- `rtk lua tools/dps_benchmark.lua --dry-run`
</verification>

<success_criteria>
The repo has one shared runtime bridge that evaluates the Phase 05 reactive contract each tick and persists `reactive_action` plus `reason_code` into the benchmark snapshot contract.
</success_criteria>

<output>
After completion, create `.planning/phases/05-reactive-contract-api-gate/05-03-SUMMARY.md`
</output>
