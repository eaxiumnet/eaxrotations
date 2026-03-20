# Phase 08: Benchmark Matrix Hardening - Research

**Date:** 2026-03-21
**Scope:** MATX-01, MATX-02, MATX-03

## Current Baseline

- `tools/dps_benchmark.lua` is still a thin schema check: `--dry-run` emits 27 mock rows, and live mode only prints one `CURRENT_SPEC` snapshot with no matrix aggregation, variance math, or release verdicts.
- `eax_shared/dps_meter.lua` persists damage, healing, reactive, and role telemetry, but it does not yet accumulate threat throughput, sample counts, or behavior KPI counters that a matrix gate can score deterministically.
- `eax_shared/reactive_runtime.lua` already sees the shared combat snapshot every tick, which makes it the best place to feed matrix counters without reopening 27 spec files.
- `tools/rotation_validation.lua` remains the single blocking gate and already proves API, reactive parity, and role parity, but it has no benchmark-matrix pass/fail stage yet.
- Phase 07 already normalized `role_signal` and `role_target_kind` in the shared meter, so Phase 08 should score behavior KPIs from that shared contract instead of inventing per-spec reporting paths.

## Findings

### Shared KPI state should come before CLI/report work

1. `MATX-01` needs more than formatted CSV rows.
   - The matrix must score DPS/HPS/TPS plus reactive behavior KPIs.
   - The missing data is not in the benchmark script; it is in the shared snapshot contract.
   - Best fit: extend `eax_shared/dps_meter.lua` with `threat_total`, `tps`, `sample_count`, `reactive_event_count`, `noop_unsupported_count`, `unsafe_skip_count`, and `fail_safe_tick_count`, then update `eax_shared/reactive_runtime.lua` to feed those counters once per tick from the existing shared context/result pair.

2. Tank TPS can be derived from shared threat-pressure sampling without editing 27 specs.
   - `combat_context.build(...)` already exposes `ctx.self.threat_pct`.
   - `reactive_runtime.update_tick(...)` runs in every canonical spec already.
   - Phase 08 should accumulate positive threat-pressure deltas in the meter from that shared tick lane, then compute `tps = threat_total / duration_s`. This keeps the contract deterministic and avoids a new 27-file rollout.

### Matrix math and gate policy should live in shared tool modules

1. The benchmark runner and the validator must use the same verdict logic.
   - If `tools/dps_benchmark.lua` and `tools/rotation_validation.lua` each implement their own variance or blocker rules, they will drift.
   - Best fit: add one pure helper such as `tools/benchmark_matrix.lua` plus one constants/catalog file such as `tools/benchmark_thresholds.lua`, then reuse them from both entrypoints.

2. Locked strictness maps cleanly to exact constants.
   - Recommended exact values for planning:
     - `MIN_LIVE_RUNS = 3`
     - `MAX_VARIANCE_PCT = 0.05`
     - `NEAR_FAIL_MARGIN_PCT = 0.03`
     - `MIN_SAMPLE_COUNT = 30`
     - `MAX_FAIL_SAFE_TICKS = 0`
     - `MAX_NOOP_UNSUPPORTED = 0`
     - `MAX_UNSAFE_SKIP = 0`
   - `near_fail` is informational only. It must never turn a fail into a pass.
   - `evidence_mode=mock` remains useful for schema/tooling sanity, but mock rows must always classify as non-passing (`schema_only`) so live evidence remains mandatory.

### Keep `tools/dps_benchmark.lua` as the single matrix entrypoint

1. The context explicitly says to harden the existing benchmark tool, not replace it.
   - Add exact CLI support for matrix work instead of creating a second runner.
   - The useful flags are `--matrix`, `--dry-run`, `--live`, `--runs <n>`, `--label <text>`, `--output <path>`, and `--baseline <path>`.

2. Operator readability should be blockers-first.
   - The top of the report should show release verdict and exact blockers first.
   - Near-fail rows belong after the blocker summary.
   - The CSV schema still matters, but the human-readable summary should lead.

### Live evidence is a real checkpoint, not a hidden assumption

1. The repo can implement and test the gate logic locally, but an approved live baseline still has to come from the actual Sylvanas runtime.
   - That is a legitimate `checkpoint:human-action` because the repo cannot synthesize true live combat runs on its own.
   - Plans should make this explicit by capturing a checked-in live matrix artifact such as `benchmarks/phase08_live_baseline.csv`.

2. `tools/rotation_validation.lua` should fail loudly when that artifact is missing or mock-only.
   - Missing live evidence must not silently downgrade the gate.
   - The validator should continue printing the full failure picture across the matrix before exiting non-zero.

## Decisions for Planning

- Plan Phase 08 as three plans in three waves:
  1. extend shared telemetry plus create shared matrix/threshold helpers;
  2. upgrade `tools/dps_benchmark.lua` into the real matrix/report entrypoint and capture the live baseline artifact;
  3. make `tools/rotation_validation.lua` block on the matrix gate using the same helper logic.
- Keep `tools/rotation_validation.lua` as the only blocking release command.
- Keep `tools/dps_benchmark.lua` as the only benchmark CLI entrypoint.
- Use one shared threshold contract with exact constants (`3` live runs, `5%` max variance, `3%` near-fail band, zero tolerance for unsupported/unsafe/fail-safe ticks in passing rows).
- Treat mock output as schema/tooling evidence only; it can never satisfy the final gate.

## Risks / Pitfalls

- If Phase 08 only formats wider CSV rows without adding shared KPI counters, the matrix will look richer while still lacking trustworthy gate inputs.
- If TPS is gathered from ad hoc spec-specific hooks, matrix comparability will drift across classes; use the shared runtime tick instead.
- If the validator short-circuits on the first failing spec, operators lose the “full failure picture” locked in `08-CONTEXT.md`.
- If the live baseline artifact is optional or mock-compatible, the gate becomes negotiable, which directly violates the locked strictness decisions.
- If benchmark and validation verdict math diverge, milestone sign-off will become untrustworthy even when both tools appear green.

## Validation Architecture

- **Wave 0:** existing Lua assert-style scripts are sufficient; no framework install is needed.
- **Per task:** run the task's focused Lua spec first, then the affected CLI entrypoint.
- **Per wave:** run the phase suite:
  - `rtk lua tests/benchmark_matrix_spec.lua`
  - `rtk lua tests/dps_meter_spec.lua`
  - `rtk lua tests/reactive_runtime_spec.lua`
  - `rtk lua tests/dps_benchmark_spec.lua`
  - `rtk lua tests/rotation_validation_spec.lua`
  - `rtk lua tests/benchmark_gate_spec.lua`
  - `rtk lua tools/dps_benchmark.lua --dry-run`
  - `rtk lua tools/rotation_validation.lua`

## Sources

- `.planning/PROJECT.md`
- `.planning/REQUIREMENTS.md`
- `.planning/ROADMAP.md`
- `.planning/STATE.md`
- `.planning/phases/05-reactive-contract-api-gate/05-CONTEXT.md`
- `.planning/phases/06-27-spec-reactive-wiring/06-CONTEXT.md`
- `.planning/phases/07-role-intelligence-tuning/07-CONTEXT.md`
- `.planning/phases/05-reactive-contract-api-gate/05-03-SUMMARY.md`
- `.planning/phases/07-role-intelligence-tuning/07-05-SUMMARY.md`
- `.planning/codebase/STACK.md`
- `.planning/codebase/ARCHITECTURE.md`
- `.planning/codebase/CONVENTIONS.md`
- `.planning/codebase/TESTING.md`
- `eax_shared/combat_context.lua`
- `eax_shared/dps_meter.lua`
- `eax_shared/reactive_runtime.lua`
- `tools/dps_benchmark.lua`
- `tools/rotation_validation.lua`
- `tests/dps_benchmark_spec.lua`
- `tests/dps_meter_spec.lua`
- `tests/reactive_runtime_spec.lua`
- `tests/rotation_validation_spec.lua`

## RESEARCH COMPLETE

Phase 08 should be planned as 3 execution plans in 3 waves:
- Plan 01: define shared matrix contracts and persist the KPI counters the matrix needs.
- Plan 02: turn `tools/dps_benchmark.lua` into the true 27-spec matrix/report entrypoint and capture the approved live baseline.
- Plan 03: make `tools/rotation_validation.lua` enforce the benchmark matrix gate for milestone sign-off.
