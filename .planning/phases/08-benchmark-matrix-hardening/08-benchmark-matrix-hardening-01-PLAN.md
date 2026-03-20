---
phase: 08-benchmark-matrix-hardening
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - tools/benchmark_thresholds.lua
  - tools/benchmark_matrix.lua
  - eax_shared/dps_meter.lua
  - eax_shared/reactive_runtime.lua
  - tests/benchmark_matrix_spec.lua
  - tests/dps_meter_spec.lua
  - tests/reactive_runtime_spec.lua
autonomous: true
requirements: [MATX-01, MATX-02]
user_setup: []
must_haves:
  truths:
    - "Every canonical spec can emit one shared benchmark snapshot contract that includes DPS/HPS/TPS inputs and behavior KPI counters."
    - "Matrix verdict math is deterministic, shared, and strict enough that benchmark and validation tools cannot disagree."
    - "Mock rows stay usable for schema sanity while remaining incapable of passing the real release gate."
  artifacts:
    - path: "tools/benchmark_thresholds.lua"
      provides: "Exact matrix strictness constants and canonical spec role mapping"
      contains: "MIN_LIVE_RUNS"
    - path: "tools/benchmark_matrix.lua"
      provides: "Shared row building and verdict aggregation for the matrix"
      contains: "summarize_matrix"
    - path: "eax_shared/dps_meter.lua"
      provides: "Shared threat and behavior KPI counters for benchmark snapshots"
      contains: "threat_total"
  key_links:
    - from: "eax_shared/reactive_runtime.lua"
      to: "eax_shared/dps_meter.lua"
      via: "shared tick updates that persist threat and behavior KPI counters"
      pattern: "set_reactive_state"
    - from: "tools/benchmark_matrix.lua"
      to: "tools/benchmark_thresholds.lua"
      via: "one strict threshold contract reused by benchmark and validation entrypoints"
      pattern: "MIN_LIVE_RUNS"
    - from: "tests/benchmark_matrix_spec.lua"
      to: "tools/benchmark_matrix.lua"
      via: "deterministic pass, fail, variance, and near-fail coverage"
      pattern: "near_fail"
---

<objective>
Create the shared matrix foundation Phase 08 needs: one strict threshold/verdict contract plus one expanded shared snapshot contract carrying threat and behavior KPI counters.

Purpose: If Phase 08 starts with CLI formatting instead of shared data and verdict logic, the repo will ship a pretty report that cannot be trusted. This plan makes the benchmark math and inputs explicit first.
Output: New matrix helper modules plus shared meter/runtime telemetry fields that later plans can consume directly.
</objective>

<execution_context>
@C:/Users/Support/.config/opencode/get-shit-done/workflows/execute-plan.md
@C:/Users/Support/.config/opencode/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/PROJECT.md
@.planning/ROADMAP.md
@.planning/STATE.md
@.planning/phases/08-benchmark-matrix-hardening/08-CONTEXT.md
@.planning/phases/08-benchmark-matrix-hardening/08-RESEARCH.md
@.planning/phases/08-benchmark-matrix-hardening/08-VALIDATION.md
@eax_shared/dps_meter.lua
@eax_shared/reactive_runtime.lua
@tools/dps_benchmark.lua
@tests/dps_meter_spec.lua
@tests/reactive_runtime_spec.lua

<interfaces>
Current shared snapshot contract from `eax_shared/dps_meter.lua`:
```lua
return {
  damage_total = state.last_snapshot.damage_total,
  healing_total = state.last_snapshot.healing_total,
  duration_s = state.last_snapshot.duration_s,
  dps = state.last_snapshot.dps,
  hps = state.last_snapshot.hps,
  reactive_action = state.reactive.reactive_action,
  reason_code = state.reactive.reason_code,
  reactive_status = state.reactive.reactive_status,
  role_signal = state.reactive.role_signal,
  role_target_kind = state.reactive.role_target_kind,
}
```

Current runtime bridge from `eax_shared/reactive_runtime.lua`:
```lua
local ctx = combat_context.build(me, target, nil, ...)
local result = reactive_engine.try_handle(ctx, ...)
dps_meter.set_reactive_state({ ... })
```

Plan 01 must expand these contracts without changing the existing reactive branch names or removing current telemetry fields.
</interfaces>
</context>

<tasks>

<task type="auto" tdd="true">
  <name>Task 1: Define the strict matrix threshold and verdict helpers</name>
  <read_first>
    - tools/dps_benchmark.lua
    - eax_shared/dps_meter.lua
    - .planning/phases/08-benchmark-matrix-hardening/08-CONTEXT.md
  </read_first>
  <files>tools/benchmark_thresholds.lua, tools/benchmark_matrix.lua, tests/benchmark_matrix_spec.lua</files>
  <behavior>
    - Test 1: mock rows classify as `schema_only` and can never return a passing verdict.
    - Test 2: a live spec with fewer than 3 runs fails with a blocker naming the missing run count.
    - Test 3: a live spec with variance above 0.05 fails even when one sample looks strong.
    - Test 4: a live spec within 3% of the threshold is still `pass` but is tagged `near_fail=true` for operator visibility.
    - Test 5: a full 27-spec live matrix with zero unsupported/unsafe/fail-safe counters can summarize to `PASS` deterministically.
  </behavior>
  <action>Create `tools/benchmark_thresholds.lua` and `tools/benchmark_matrix.lua` as the single shared policy surface for Phase 08. Export these exact constants in `tools/benchmark_thresholds.lua`: `MIN_LIVE_RUNS = 3`, `MAX_VARIANCE_PCT = 0.05`, `NEAR_FAIL_MARGIN_PCT = 0.03`, `MIN_SAMPLE_COUNT = 30`, `MAX_FAIL_SAFE_TICKS = 0`, `MAX_NOOP_UNSUPPORTED = 0`, and `MAX_UNSAFE_SKIP = 0`. Also export the canonical 27-spec role map with `role = "dps" | "healer" | "tank"` and `primary_metric = "dps" | "hps" | "tps"`. In `tools/benchmark_matrix.lua`, export `CANONICAL_SPECS`, `build_row(spec, snapshot, meta)`, `summarize_spec_runs(rows, thresholds)`, `summarize_matrix(rows, thresholds)`, and `format_blockers(summary)`. Enforce these exact rules: `evidence_mode` must be exactly `live` or `mock`; `mock` rows always return `verdict = "schema_only"`; `near_fail` is informational only; `sample_count < 30`, any `noop_unsupported_count > 0`, any `unsafe_skip_count > 0`, or any `fail_safe_tick_count > 0` blocks a passing verdict; tank rows must use `tps` as the primary throughput metric and fail if `tps <= 0`. Add `tests/benchmark_matrix_spec.lua` covering the five behaviors above with deterministic fixture rows instead of shelling out to the CLI.</action>
  <acceptance_criteria>
    - `tools/benchmark_thresholds.lua` contains `MIN_LIVE_RUNS = 3`
    - `tools/benchmark_thresholds.lua` contains `MAX_VARIANCE_PCT = 0.05`
    - `tools/benchmark_matrix.lua` contains `summarize_matrix`
    - `tools/benchmark_matrix.lua` contains `schema_only`
    - `tests/benchmark_matrix_spec.lua` contains `near_fail`
  </acceptance_criteria>
  <verify>
    <automated>rtk lua tests/benchmark_matrix_spec.lua</automated>
  </verify>
  <done>Phase 08 has one strict, reusable matrix verdict engine that both the benchmark CLI and release validator can trust.</done>
</task>

<task type="auto" tdd="true">
  <name>Task 2: Persist threat throughput and behavior KPI counters in the shared meter</name>
  <read_first>
    - eax_shared/dps_meter.lua
    - eax_shared/reactive_runtime.lua
    - tests/dps_meter_spec.lua
    - tests/reactive_runtime_spec.lua
  </read_first>
  <files>eax_shared/dps_meter.lua, eax_shared/reactive_runtime.lua, tests/dps_meter_spec.lua, tests/reactive_runtime_spec.lua</files>
  <behavior>
    - Test 1: snapshots expose numeric `threat_total`, `tps`, and `sample_count` fields alongside existing DPS/HPS and reactive telemetry.
    - Test 2: repeated runtime ticks accumulate positive threat-pressure samples and compute non-zero `tps` when duration is non-zero.
    - Test 3: `reactive_event_count` increments only when the winning action is not `none`.
    - Test 4: `noop_unsupported_count`, `unsafe_skip_count`, and `fail_safe_tick_count` increment when the runtime reports those exact conditions.
    - Test 5: combat end/reset preserves the existing clear behavior and zero defaults for the new counters.
  </behavior>
  <action>Extend `eax_shared/dps_meter.lua` with these exact numeric snapshot fields: `threat_total`, `tps`, `sample_count`, `reactive_event_count`, `noop_unsupported_count`, `unsafe_skip_count`, and `fail_safe_tick_count`. Add a shared helper such as `record_threat_sample(threat_pct, now_s)` so the meter accumulates positive deltas from the normalized `ctx.self.threat_pct` stream and computes `tps = threat_total / duration_s`. Keep every existing field (`damage_total`, `healing_total`, `dps`, `hps`, `reactive_action`, `reason_code`, `reactive_status`, `role_signal`, `role_target_kind`) intact. Update `eax_shared/reactive_runtime.lua` so every tick records the current threat sample, increments `sample_count`, increments `reactive_event_count` when `result.action_id ~= "none"`, increments `noop_unsupported_count` on `reactive_status == "noop_unsupported"`, increments `unsafe_skip_count` on `reactive_status == "skipped_unsafe"`, and increments `fail_safe_tick_count` whenever `ctx.meta.fail_safe == true`. Update `tests/dps_meter_spec.lua` and `tests/reactive_runtime_spec.lua` to prove those counters behave deterministically.</action>
  <acceptance_criteria>
    - `eax_shared/dps_meter.lua` contains `threat_total`
    - `eax_shared/dps_meter.lua` contains `reactive_event_count`
    - `eax_shared/dps_meter.lua` contains `fail_safe_tick_count`
    - `eax_shared/reactive_runtime.lua` contains `sample_count`
    - `tests/dps_meter_spec.lua` contains `threat_total`
    - `tests/reactive_runtime_spec.lua` contains `noop_unsupported_count`
  </acceptance_criteria>
  <verify>
    <automated>rtk lua tests/dps_meter_spec.lua && rtk lua tests/reactive_runtime_spec.lua</automated>
  </verify>
  <done>The shared runtime now produces the exact throughput and behavior KPI counters the Phase 08 matrix needs, without reopening the 27 spec files.</done>
</task>

</tasks>

<verification>
Run the Plan 01 suite:
- `rtk lua tests/benchmark_matrix_spec.lua`
- `rtk lua tests/dps_meter_spec.lua`
- `rtk lua tests/reactive_runtime_spec.lua`
</verification>

<success_criteria>
Phase 08 now has a strict shared verdict contract and one expanded snapshot contract carrying the throughput and behavior KPI inputs that later matrix and gate work will score.
</success_criteria>

<output>
After completion, create `.planning/phases/08-benchmark-matrix-hardening/08-01-SUMMARY.md`
</output>
