---
phase: 08-benchmark-matrix-hardening
plan: 03
type: execute
wave: 3
depends_on:
  - 08-benchmark-matrix-hardening-01
  - 08-benchmark-matrix-hardening-02
files_modified:
  - tools/rotation_validation.lua
  - tests/rotation_validation_spec.lua
  - tests/benchmark_gate_spec.lua
autonomous: true
requirements: [MATX-03]
user_setup: []
must_haves:
  truths:
    - "The single blocking validator now fails when live matrix evidence is missing or any canonical spec misses the strict matrix thresholds."
    - "Validation prints the full benchmark failure picture instead of stopping at the first broken spec."
    - "Milestone sign-off requires API, reactive parity, role parity, and benchmark matrix success together in one command."
  artifacts:
    - path: "tools/rotation_validation.lua"
      provides: "Single blocking release gate including benchmark matrix evaluation"
      contains: "benchmark matrix"
    - path: "tests/benchmark_gate_spec.lua"
      provides: "Regression coverage for missing-live-evidence and matrix-blocker failures"
      contains: "FAIL: benchmark live evidence missing"
    - path: "tests/rotation_validation_spec.lua"
      provides: "Clean-repo proof that existing validation plus benchmark gate all pass together"
      contains: "PASS: benchmark matrix"
  key_links:
    - from: "tools/rotation_validation.lua"
      to: "benchmarks/phase08_live_baseline.csv"
      via: "loads the approved live evidence artifact before final pass/fail"
      pattern: "benchmark live evidence"
    - from: "tools/rotation_validation.lua"
      to: "tools/benchmark_matrix.lua"
      via: "shared matrix verdict math reused inside the blocking validator"
      pattern: "summarize_matrix"
    - from: "tests/benchmark_gate_spec.lua"
      to: "tools/rotation_validation.lua"
      via: "fixture-driven regression proof for missing baseline, variance fail, and clean pass output"
      pattern: "benchmark matrix"
---

<objective>
Finish Phase 08 by making the existing blocking validator enforce the benchmark matrix gate and report exact blockers first.

Purpose: Without the final integration, Phase 08 would have a benchmark tool and a validator that still disagree about release readiness. This plan makes one command the milestone truth.
Output: Updated blocking validator plus regression tests for missing-live-evidence, failing-matrix, and clean-pass behavior.
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
@.planning/phases/08-benchmark-matrix-hardening/08-benchmark-matrix-hardening-01-PLAN.md
@.planning/phases/08-benchmark-matrix-hardening/08-benchmark-matrix-hardening-02-PLAN.md
@tools/rotation_validation.lua
@tools/benchmark_thresholds.lua
@tools/benchmark_matrix.lua
@tools/dps_benchmark.lua
@tests/rotation_validation_spec.lua

<interfaces>
This plan must reuse the Phase 08 matrix helper, not reimplement scoring locally:
```lua
local summary = benchmark_matrix.summarize_matrix(rows, benchmark_thresholds)
local blockers = benchmark_matrix.format_blockers(summary)
```

Plan 02 creates the required artifact for this gate:
```text
benchmarks/phase08_live_baseline.csv
```

The final validator output must add these exact summaries:
```text
PASS: benchmark matrix 27/27
FAIL: benchmark matrix X/27
FAIL: benchmark live evidence missing
```
</interfaces>
</context>

<tasks>

<task type="auto" tdd="true">
  <name>Task 1: Add failing regression coverage for the benchmark gate</name>
  <read_first>
    - tests/rotation_validation_spec.lua
    - tools/rotation_validation.lua
    - tools/benchmark_matrix.lua
    - .planning/phases/08-benchmark-matrix-hardening/08-CONTEXT.md
  </read_first>
  <files>tests/rotation_validation_spec.lua, tests/benchmark_gate_spec.lua</files>
  <behavior>
    - Test 1: the validator fails with `FAIL: benchmark live evidence missing` when `benchmarks/phase08_live_baseline.csv` is absent.
    - Test 2: the validator fails with `FAIL: benchmark matrix X/27` when any canonical spec exceeds the 0.05 variance cap.
    - Test 3: the validator prints the benchmark blocker summary before the final fail line so the operator sees exact causes first.
    - Test 4: a clean fixture with 27 live rows, 3 runs each, and zero unsupported/unsafe/fail-safe counts prints `PASS: benchmark matrix 27/27`.
  </behavior>
  <action>Update `tests/rotation_validation_spec.lua` and add `tests/benchmark_gate_spec.lua` so Phase 08 has deterministic failing coverage before implementation. Use fixture rows or temporary artifact files instead of shelling out to the live environment. Cover these exact cases: missing `benchmarks/phase08_live_baseline.csv`, mock-only evidence rows, one spec with `variance_pct > 0.05`, one spec with `sample_count < 30`, and a clean 27-spec live matrix that should produce `PASS: benchmark matrix 27/27`. Assert that benchmark blocker lines appear before the final summary line in the printed validator output.</action>
  <acceptance_criteria>
    - `tests/benchmark_gate_spec.lua` contains `FAIL: benchmark live evidence missing`
    - `tests/benchmark_gate_spec.lua` contains `PASS: benchmark matrix 27/27`
    - `tests/rotation_validation_spec.lua` contains `benchmark matrix`
    - `tests/benchmark_gate_spec.lua` contains `variance_pct`
  </acceptance_criteria>
  <verify>
    <automated>rtk lua tests/rotation_validation_spec.lua && rtk lua tests/benchmark_gate_spec.lua</automated>
  </verify>
  <done>The Phase 08 benchmark gate has failing regression coverage for the exact missing-evidence and bad-matrix cases the validator must block.</done>
</task>

<task type="auto">
  <name>Task 2: Enforce the benchmark matrix gate inside `tools/rotation_validation.lua`</name>
  <read_first>
    - tools/rotation_validation.lua
    - tools/benchmark_thresholds.lua
    - tools/benchmark_matrix.lua
    - tests/rotation_validation_spec.lua
    - tests/benchmark_gate_spec.lua
    - benchmarks/phase08_live_baseline.csv
  </read_first>
  <files>tools/rotation_validation.lua</files>
  <action>Extend `tools/rotation_validation.lua` after the existing API/reactive/role parity sections with one new Phase 08 gate that loads `benchmarks/phase08_live_baseline.csv`, evaluates all canonical rows with `tools/benchmark_matrix.lua`, and prints blockers before the final matrix summary. Keep `tools/rotation_validation.lua` as the only blocking release command; do not create a second validator. Add these exact fail conditions: baseline file missing, any row with `evidence_mode ~= "live"`, any canonical spec with fewer than 3 runs, any `variance_pct > 0.05`, any `sample_count < 30`, any `noop_unsupported_count > 0`, any `unsafe_skip_count > 0`, any `fail_safe_tick_count > 0`, or any spec summary whose verdict is not `pass`. Print `FAIL: benchmark live evidence missing` when the artifact is absent or mock-only, then continue printing the remaining matrix blockers so the operator sees the full failure picture. Print `PASS: benchmark matrix 27/27` only when all 27 canonical specs pass and the existing API/reactive/role gates also pass.</action>
  <acceptance_criteria>
    - `tools/rotation_validation.lua` contains `benchmark matrix`
    - `tools/rotation_validation.lua` contains `FAIL: benchmark live evidence missing`
    - `tools/rotation_validation.lua` contains `PASS: benchmark matrix`
    - `tools/rotation_validation.lua` contains `summarize_matrix`
  </acceptance_criteria>
  <verify>
    <automated>rtk lua tests/rotation_validation_spec.lua && rtk lua tests/benchmark_gate_spec.lua && rtk lua tools/rotation_validation.lua</automated>
  </verify>
  <done>The repository now has one blocking validator that refuses milestone sign-off until benchmark live evidence and strict matrix thresholds pass across all 27 canonical specs.</done>
</task>

</tasks>

<verification>
Run the final Phase 08 blocking checks:
- `rtk lua tests/benchmark_matrix_spec.lua`
- `rtk lua tests/dps_meter_spec.lua`
- `rtk lua tests/reactive_runtime_spec.lua`
- `rtk lua tests/dps_benchmark_spec.lua`
- `rtk lua tests/rotation_validation_spec.lua`
- `rtk lua tests/benchmark_gate_spec.lua`
- `rtk lua tools/dps_benchmark.lua --dry-run --matrix`
- `rtk lua tools/rotation_validation.lua`
</verification>

<success_criteria>
Phase 08 is complete when one blocking command proves API compliance, reactive parity, role parity, and a passing live 27-spec benchmark matrix with strict KPI and variance rules.
</success_criteria>

<output>
After completion, create `.planning/phases/08-benchmark-matrix-hardening/08-03-SUMMARY.md`
</output>
