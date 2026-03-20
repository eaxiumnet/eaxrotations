---
phase: 07-role-intelligence-tuning
plan: 05
type: execute
wave: 3
depends_on:
  - 07-role-intelligence-tuning-02
  - 07-role-intelligence-tuning-03
  - 07-role-intelligence-tuning-04
files_modified:
  - eax_shared/dps_meter.lua
  - tools/dps_benchmark.lua
  - tools/rotation_validation.lua
  - tests/rotation_validation_spec.lua
  - tests/role_validation_spec.lua
autonomous: true
requirements: [ROLE-01, ROLE-02, ROLE-03, ROLE-04]
user_setup: []
must_haves:
  truths:
    - "Blocking validation proves healer, tank, and DPS role-intelligence parity instead of only generic adapter wiring"
    - "Benchmark output exposes role-quality telemetry fields needed for later Phase 08 matrix work"
    - "Phase 07 can fail fast when a role family regresses back to noop or greedy behavior"
  artifacts:
    - path: "tools/rotation_validation.lua"
      provides: "Blocking role-family parity and summary output for Phase 07"
      contains: "role parity"
    - path: "tools/dps_benchmark.lua"
      provides: "Dry-run/live rows with role-quality telemetry fields"
      contains: "role_signal"
    - path: "tests/role_validation_spec.lua"
      provides: "Regression coverage for Phase 07 role-parity output"
      contains: "PASS: role parity"
  key_links:
    - from: "tools/rotation_validation.lua"
      to: "EAX*/main.lua"
      via: "role-family grep checks for shared helper imports and non-noop behavior"
      pattern: "role parity"
    - from: "tools/dps_benchmark.lua"
      to: "eax_shared/dps_meter.lua"
      via: "benchmark rows export role-quality telemetry from the shared meter"
      pattern: "role_signal"
    - from: "tests/role_validation_spec.lua"
      to: "tools/rotation_validation.lua"
      via: "clean repo and broken fixture assertions on Phase 07 role parity output"
      pattern: "PASS: role parity"
---

<objective>
Finish Phase 07 with hard verification: validator-enforced role-family parity and benchmark-visible role-quality telemetry that later matrix work can consume.

Purpose: Without a blocking proof surface, Phase 07 regressions will hide behind generic adapter parity and only show up much later. This plan makes role intelligence observable and enforceable.
Output: Updated blocking validator, updated benchmark schema, and regression tests for role-parity output.
</objective>

<execution_context>
@C:/Users/Support/.config/opencode/get-shit-done/workflows/execute-plan.md
@C:/Users/Support/.config/opencode/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/PROJECT.md
@.planning/ROADMAP.md
@.planning/STATE.md
@.planning/phases/07-role-intelligence-tuning/07-CONTEXT.md
@.planning/phases/07-role-intelligence-tuning/07-RESEARCH.md
@.planning/phases/07-role-intelligence-tuning/07-VALIDATION.md
@eax_shared/dps_meter.lua
@tools/dps_benchmark.lua
@tools/rotation_validation.lua
@tests/rotation_validation_spec.lua
@tests/reactive_runtime_wiring_spec.lua

<interfaces>
Expected telemetry additions for this plan:
```lua
dps_meter.set_reactive_state({
  role_signal = "tank_save" | "triage_save" | "threat_recovery" | "danger_hold" | "none",
  role_target_kind = "self" | "tank" | "ally" | "hostile" | "none",
})
```
</interfaces>
</context>

<tasks>

<task type="auto" tdd="true">
  <name>Task 1: Add blocking role-parity validation for healer, tank, and DPS families</name>
  <read_first>
    - tools/rotation_validation.lua
    - tests/rotation_validation_spec.lua
    - tests/reactive_runtime_wiring_spec.lua
  </read_first>
  <files>tools/rotation_validation.lua, tests/rotation_validation_spec.lua, tests/role_validation_spec.lua</files>
  <behavior>
    - Test 1: validation fails when a healer file drops `healer_triage` usage or regresses `life_save_ally` back to noop/greedy behavior.
    - Test 2: validation fails when a tank file regresses `anti_aggro` to `noop = "unsupported"`.
    - Test 3: validation fails when a DPS file drops `dps_risk` usage or no longer exposes a danger-window hold/abort surface.
    - Test 4: a clean repo prints deterministic family summaries plus one final `PASS: role parity 27/27` line.
  </behavior>
  <action>Extend `tools/rotation_validation.lua` with a new Phase 07 pass after reactive adapter parity. Add exact family checks: healer files (`EAXDruidRestoration`, `EAXPaladinHoly`, `EAXPriestDiscipline`, `EAXPriestHoly`, `EAXShamanRestoration`) must require `healer_triage` and keep non-noop `life_save_ally`; tank files (`EAXDruidFeral`, `EAXPaladinProtection`, `EAXWarriorProtection`) must require `tank_recovery` and keep non-noop `anti_aggro`; all non-healer DPS files in Plan 04 must require `dps_risk` and expose either `should_hold_offense` or `should_abort_commit` call sites. Print deterministic per-spec lines plus family summaries and the exact final summary `PASS: role parity 27/27` or `FAIL: role parity X/27`. Update `tests/rotation_validation_spec.lua` and add `tests/role_validation_spec.lua` so broken fixtures prove each family failure mode and a clean repo proves the final summary string.</action>
  <acceptance_criteria>
    - `tools/rotation_validation.lua` contains `role parity`
    - `tools/rotation_validation.lua` contains `healer_triage`
    - `tools/rotation_validation.lua` contains `tank_recovery`
    - `tools/rotation_validation.lua` contains `dps_risk`
    - `tests/role_validation_spec.lua` contains `PASS: role parity 27/27`
  </acceptance_criteria>
  <verify>
    <automated>rtk lua tests/rotation_validation_spec.lua && rtk lua tests/role_validation_spec.lua && rtk lua tools/rotation_validation.lua</automated>
  </verify>
  <done>The repo has one blocking validator that proves role-family parity, not just generic adapter wiring.</done>
</task>

<task type="auto">
  <name>Task 2: Expose role-quality telemetry in the benchmark and shared meter</name>
  <read_first>
    - eax_shared/dps_meter.lua
    - tools/dps_benchmark.lua
    - eax_shared/reactive_runtime.lua
  </read_first>
  <files>eax_shared/dps_meter.lua, tools/dps_benchmark.lua</files>
  <action>Extend `eax_shared/dps_meter.lua` and `tools/dps_benchmark.lua` with two exact new telemetry fields: `role_signal` and `role_target_kind`. `role_signal` must use these exact values: `tank_save`, `triage_save`, `group_stabilize`, `threat_recovery`, `danger_hold`, or `none`. `role_target_kind` must use these exact values: `self`, `tank`, `ally`, `hostile`, or `none`. Keep existing reactive telemetry fields intact. Update the benchmark schema/header and row formatting so `--dry-run` emits the new columns deterministically and later live runs can carry the same fields into Phase 08 matrix work.</action>
  <acceptance_criteria>
    - `eax_shared/dps_meter.lua` contains `role_signal`
    - `eax_shared/dps_meter.lua` contains `role_target_kind`
    - `tools/dps_benchmark.lua` contains `role_signal`
    - `tools/dps_benchmark.lua` contains `role_target_kind`
    - `tools/dps_benchmark.lua --dry-run` prints the new schema columns
  </acceptance_criteria>
  <verify>
    <automated>rtk lua tools/dps_benchmark.lua --dry-run</automated>
  </verify>
  <done>Phase 07 role decisions are visible in shared telemetry and benchmark rows, ready for Phase 08 matrix gating.</done>
</task>

</tasks>

<verification>
Run final Phase 07 blocking checks:
- `rtk lua tests/rotation_validation_spec.lua`
- `rtk lua tests/role_validation_spec.lua`
- `rtk lua tools/rotation_validation.lua`
- `rtk lua tools/dps_benchmark.lua --dry-run`
</verification>

<success_criteria>
The repo can now prove role-intelligence parity with blocking validator output and emit benchmark-visible role-quality telemetry that later matrix gates can consume.
</success_criteria>

<output>
After completion, create `.planning/phases/07-role-intelligence-tuning/07-05-SUMMARY.md`
</output>
