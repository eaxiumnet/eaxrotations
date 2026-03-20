---
phase: 06-27-spec-reactive-wiring
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - eax_shared/reactive_runtime.lua
  - eax_shared/dps_meter.lua
  - tools/dps_benchmark.lua
  - tests/reactive_runtime_spec.lua
  - EAXWarriorFury/main.lua
  - EAXPriestHoly/main.lua
  - EAXWarriorProtection/main.lua
autonomous: true
requirements: [WIRE-01, WIRE-02]
user_setup: []
must_haves:
  truths:
    - "Shared reactive evaluation can execute a real spec adapter instead of placeholder actions"
    - "Unsupported or unsafe reactive winners are visible as explicit no-op/skipped telemetry rather than silent gaps"
    - "Representative DPS, healer, and tank specs prove the same adapter contract can drive live behavior without replacing their existing cast lanes"
  artifacts:
    - path: "eax_shared/reactive_runtime.lua"
      provides: "Shared adapter execution, retarget/restore orchestration, and unsupported-action handling"
      contains: "reactive_status"
    - path: "eax_shared/dps_meter.lua"
      provides: "Telemetry field for handled vs noop/skipped reactive outcomes"
      contains: "reactive_status"
    - path: "EAXWarriorFury/main.lua"
      provides: "Representative DPS adapter wiring"
      contains: "reactive_adapter"
    - path: "EAXPriestHoly/main.lua"
      provides: "Representative healer adapter wiring"
      contains: "reactive_adapter"
    - path: "EAXWarriorProtection/main.lua"
      provides: "Representative tank adapter wiring with urgent retarget support"
      contains: "reactive_adapter"
  key_links:
    - from: "EAXWarriorFury/main.lua"
      to: "eax_shared/reactive_runtime.lua"
      via: "reactive_runtime.update_tick(me, target, { adapter = reactive_adapter, ... })"
      pattern: "adapter = reactive_adapter"
    - from: "eax_shared/reactive_runtime.lua"
      to: "eax_shared/dps_meter.lua"
      via: "set_reactive_state payload"
      pattern: "reactive_status"
    - from: "EAXWarriorProtection/main.lua"
      to: ".api/core.lua"
      via: "core.input.set_target(...) retarget/restore flow"
      pattern: "core\.input\.set_target"
---

<objective>
Turn the Phase 05 telemetry-only bridge into a real shared adapter runtime that can execute urgent reactive winners safely, report unsupported/no-op outcomes, and prove the pattern in one DPS, one healer, and one tank spec.

Purpose: Phase 06 needs one concrete contract before bulk rollout; otherwise 27 large `main.lua` files would drift into ad hoc reactive wiring.
Output: Shared runtime/telemetry contract updates plus representative adapter wiring in `EAXWarriorFury`, `EAXPriestHoly`, and `EAXWarriorProtection`.
</objective>

<execution_context>
@C:/Users/Support/.config/opencode/get-shit-done/workflows/execute-plan.md
@C:/Users/Support/.config/opencode/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/PROJECT.md
@.planning/ROADMAP.md
@.planning/STATE.md
@.planning/phases/06-27-spec-reactive-wiring/06-CONTEXT.md
@.planning/phases/06-27-spec-reactive-wiring/06-RESEARCH.md
@.planning/phases/06-27-spec-reactive-wiring/06-VALIDATION.md
@.planning/phases/05-reactive-contract-api-gate/05-CONTEXT.md
@.planning/phases/05-reactive-contract-api-gate/05-03-SUMMARY.md
@.planning/phases/05-reactive-contract-api-gate/05-05-SUMMARY.md
@eax_shared/reactive_engine.lua
@eax_shared/reactive_runtime.lua
@eax_shared/dps_meter.lua
@tools/dps_benchmark.lua
@EAXWarriorFury/main.lua
@EAXPriestHoly/main.lua
@EAXWarriorProtection/main.lua

<interfaces>
From `eax_shared/reactive_engine.lua`:
```lua
local ORDER = {
  { name = "life_save_self", reason_code = reactive_engine.reason_codes.LIFE_SAVE_SELF },
  { name = "life_save_ally", reason_code = reactive_engine.reason_codes.LIFE_SAVE_ALLY },
  { name = "interrupt_control", reason_code = reactive_engine.reason_codes.INTERRUPT_DANGER },
  { name = "anti_overheal", reason_code = reactive_engine.reason_codes.ANTI_OVERHEAL },
  { name = "anti_aggro", reason_code = reactive_engine.reason_codes.ANTI_AGGRO },
  { name = "throughput_resume", reason_code = reactive_engine.reason_codes.THROUGHPUT_RESUME },
}
```

From `eax_shared/reactive_runtime.lua`:
```lua
function reactive_runtime.update_tick(me, target, deps)
  -- builds combat context, runs reactive_engine, persists shared telemetry
end
```

From representative `main.lua` files:
```lua
reactive_runtime.update_tick(me, target, {
  encounter_manager = encounter_manager,
  state = _visual_runtime.reactive_state,
  spec = "EAXWarriorFury",
})
```
</interfaces>
</context>

<tasks>

<task type="auto" tdd="true">
  <name>Task 1: Extend the shared runtime contract with explicit adapter execution and noop telemetry</name>
  <read_first>
    - eax_shared/reactive_engine.lua
    - eax_shared/reactive_runtime.lua
    - eax_shared/dps_meter.lua
    - tools/dps_benchmark.lua
    - tests/reactive_runtime_spec.lua
  </read_first>
  <files>eax_shared/reactive_runtime.lua, eax_shared/dps_meter.lua, tools/dps_benchmark.lua, tests/reactive_runtime_spec.lua</files>
  <behavior>
    - Test 1: `reactive_runtime.update_tick(...)` still builds context and runs `reactive_engine`, but now accepts `adapter = { actions = { ... } }` with all six branch keys.
    - Test 2: when the winning branch has a real handler, runtime records `reactive_status = "handled"` and preserves the winning `reactive_action` / `reason_code`.
    - Test 3: when the winning branch is declared as an explicit no-op or the target is unsafe to retarget, runtime records `reactive_status = "noop_unsupported"` or `reactive_status = "skipped_unsafe"` instead of silently doing nothing.
  </behavior>
  <action>Update `eax_shared/reactive_runtime.lua` so `update_tick(me, target, deps)` supports a new `deps.adapter` table with this exact shape: `adapter.spec`, `adapter.actions`, and optional `adapter.resolve_target(action_id, ctx, deps)` / `adapter.restore_target(previous_target, ctx, deps)`. Require `adapter.actions` to declare all six branch names from `reactive_engine.ORDER`. Each branch must be either `{ handler = function(...) ... end }` or `{ noop = "unsupported" }`. Preserve the existing context build + engine call, then execute the winning branch through the adapter. Add shared state fields that remember the previous main target and whether a restore is pending. When a handler requires a different unit than the current target, use `core.input.set_target(unit)` before the cast and restore the prior target immediately on failure or on the next safe tick after success. Extend `eax_shared/dps_meter.lua` and `tools/dps_benchmark.lua` with one exact new field `reactive_status` and only these runtime values: `handled`, `noop_unsupported`, `skipped_unsafe`, `none`. Update `tests/reactive_runtime_spec.lua` to cover handled and noop/skipped outcomes using stub adapters instead of the old placeholder `DEFAULT_ACTIONS` assertions.</action>
  <acceptance_criteria>
    - `eax_shared/reactive_runtime.lua` contains `adapter.actions`
    - `eax_shared/reactive_runtime.lua` contains `core.input.set_target`
    - `eax_shared/dps_meter.lua` contains `reactive_status`
    - `tools/dps_benchmark.lua` contains `reactive_status`
    - `tests/reactive_runtime_spec.lua` contains both `handled` and `noop_unsupported`
  </acceptance_criteria>
  <verify>
    <automated>rtk lua tests/reactive_runtime_spec.lua</automated>
  </verify>
  <done>The shared runtime can execute or explicitly noop any winning reactive branch, and telemetry now reports whether the winner was handled, unsupported, unsafe, or absent.</done>
</task>

<task type="auto">
  <name>Task 2: Prove the adapter pattern in representative DPS, healer, and tank specs</name>
  <read_first>
    - .planning/phases/06-27-spec-reactive-wiring/06-CONTEXT.md
    - .planning/phases/06-27-spec-reactive-wiring/06-RESEARCH.md
    - EAXWarriorFury/main.lua
    - EAXPriestHoly/main.lua
    - EAXWarriorProtection/main.lua
    - eax_shared/reactive_runtime.lua
  </read_first>
  <files>EAXWarriorFury/main.lua, EAXPriestHoly/main.lua, EAXWarriorProtection/main.lua</files>
  <action>In each representative `main.lua`, declare one local `reactive_adapter` table near the existing runtime helpers and pass it into `reactive_runtime.update_tick(...)` as `adapter = reactive_adapter`. Use these exact action keys in every adapter: `life_save_self`, `life_save_ally`, `interrupt_control`, `anti_overheal`, `anti_aggro`, `throughput_resume`. For `EAXWarriorFury/main.lua`, wire `life_save_self` to `defensive_manager.try_defensive(me, "warrior", utils)`, wire `interrupt_control` to `interrupt_manager.try_interrupt(me, target, "warrior", utils)`, and mark the remaining unsupported categories as explicit no-ops. For `EAXPriestHoly/main.lua`, wire `life_save_self` and `life_save_ally` through the existing `try_cast_spell(...)` / heal helpers, wire `anti_overheal` to the existing stop-cast protection path, and mark unsupported hostile-only categories as explicit no-ops. For `EAXWarriorProtection/main.lua`, wire `life_save_self` to the existing defensive lane, wire `interrupt_control` through the existing interrupt / recovery-target surfaces, and allow urgent hostile retarget + restore through the shared runtime. Preserve the user's locked boundary: only urgent winners may retarget, restore the previous main target when the reaction resolves or fails, and never let convenience throughput retargeting bypass the existing spec lane.</action>
  <acceptance_criteria>
    - `EAXWarriorFury/main.lua` contains `local reactive_adapter = {`
    - `EAXPriestHoly/main.lua` contains `life_save_ally =`
    - `EAXWarriorProtection/main.lua` contains `interrupt_control =`
    - All three representative files pass `adapter = reactive_adapter` into `reactive_runtime.update_tick`
    - Unsupported branches in representative files are declared with exact `noop = "unsupported"` markers
  </acceptance_criteria>
  <verify>
    <automated>rtk lua tests/reactive_runtime_spec.lua && rtk lua tests/reactive_runtime_wiring_spec.lua</automated>
  </verify>
  <done>One DPS, one healer, and one tank spec now execute the shared adapter contract with real handlers, explicit no-ops, and urgent-only retarget behavior.</done>
</task>

</tasks>

<verification>
Run the shared runtime checks:
- `rtk lua tests/reactive_runtime_spec.lua`
- `rtk lua tests/reactive_runtime_wiring_spec.lua`
</verification>

<success_criteria>
The shared runtime is no longer telemetry-only: it can execute a declared spec adapter, report unsupported/no-op outcomes visibly, and demonstrate safe urgent retarget behavior in representative role specs.
</success_criteria>

<output>
After completion, create `.planning/phases/06-27-spec-reactive-wiring/06-01-SUMMARY.md`
</output>
