---
phase: 08-benchmark-matrix-hardening
plan: 02
type: execute
wave: 2
depends_on:
  - 08-benchmark-matrix-hardening-01
files_modified:
  - tools/dps_benchmark.lua
  - tests/dps_benchmark_spec.lua
  - benchmarks/phase08_live_baseline.csv
autonomous: false
requirements: [MATX-01, MATX-02]
user_setup: []
must_haves:
  truths:
    - "The benchmark command emits a complete 27-spec matrix with DPS/HPS/TPS, behavior KPI counters, run metadata, variance, and evidence tags."
    - "Operator output shows release blockers first, then near-fail edges, so weak specs are obvious immediately."
    - "The repo contains one approved live baseline artifact that later release gating can evaluate deterministically."
  artifacts:
    - path: "tools/dps_benchmark.lua"
      provides: "The single benchmark matrix CLI entrypoint with report output"
      contains: "evidence_mode"
    - path: "tests/dps_benchmark_spec.lua"
      provides: "Regression coverage for schema, live rows, and blockers-first summary output"
      contains: "variance_pct"
    - path: "benchmarks/phase08_live_baseline.csv"
      provides: "Checked-in live baseline matrix artifact for the 27 canonical specs"
      contains: "EAXWarriorProtection"
  key_links:
    - from: "tools/dps_benchmark.lua"
      to: "tools/benchmark_matrix.lua"
      via: "shared row building and summary formatting reused by the CLI"
      pattern: "format_blockers"
    - from: "tools/dps_benchmark.lua"
      to: "eax_shared/dps_meter.lua"
      via: "live rows export the expanded shared snapshot contract"
      pattern: "threat_total"
    - from: "benchmarks/phase08_live_baseline.csv"
      to: "tools/rotation_validation.lua"
      via: "later gate plan loads the approved live evidence artifact"
      pattern: "evidence_mode"
---

<objective>
Turn the existing benchmark command into the real Phase 08 matrix/report entrypoint and capture the checked-in live baseline evidence artifact that the final gate will consume.

Purpose: Phase 08 needs one trustworthy matrix surface, not scattered scripts and ad hoc CSV files. This plan makes `tools/dps_benchmark.lua` the operator-facing source of truth and then captures the required live evidence.
Output: Upgraded benchmark CLI/report output plus `benchmarks/phase08_live_baseline.csv` created from real runs.
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
@tools/dps_benchmark.lua
@tools/benchmark_thresholds.lua
@tools/benchmark_matrix.lua
@eax_shared/dps_meter.lua
@tests/dps_benchmark_spec.lua

<interfaces>
Plan 01 produces these shared helpers for this plan to consume directly:
```lua
local benchmark_thresholds = require("tools/benchmark_thresholds")
local benchmark_matrix = require("tools/benchmark_matrix")

benchmark_matrix.build_row(spec, snapshot, meta)
benchmark_matrix.summarize_matrix(rows, benchmark_thresholds)
benchmark_matrix.format_blockers(summary)
```

The expanded live snapshot now includes:
```lua
snapshot.threat_total
snapshot.tps
snapshot.sample_count
snapshot.reactive_event_count
snapshot.noop_unsupported_count
snapshot.unsafe_skip_count
snapshot.fail_safe_tick_count
```
</interfaces>
</context>

<tasks>

<task type="auto" tdd="true">
  <name>Task 1: Upgrade `tools/dps_benchmark.lua` into the full matrix/report CLI</name>
  <read_first>
    - tools/dps_benchmark.lua
    - tools/benchmark_thresholds.lua
    - tools/benchmark_matrix.lua
    - eax_shared/dps_meter.lua
    - tests/dps_benchmark_spec.lua
  </read_first>
  <files>tools/dps_benchmark.lua, tests/dps_benchmark_spec.lua</files>
  <behavior>
    - Test 1: `--dry-run --matrix` emits exactly 27 mock rows with the expanded schema and `verdict=schema_only`.
    - Test 2: live mode uses the expanded shared meter contract, including `threat_total`, `tps`, and behavior KPI counters.
    - Test 3: the printed summary shows blockers before near-fail rows.
    - Test 4: row metadata includes `evidence_mode`, `run_label`, `run_index`, and `variance_pct` for apples-to-apples comparison.
  </behavior>
  <action>Keep `tools/dps_benchmark.lua` as the only benchmark entrypoint, but add exact support for `--matrix`, `--dry-run`, `--live`, `--runs <n>`, `--label <text>`, `--output <path>`, and `--baseline <path>`. Reuse `tools/benchmark_matrix.lua` and `tools/benchmark_thresholds.lua` instead of duplicating verdict logic locally. Emit this exact CSV schema in both the `schema:` line and header line: `spec,role,damage_total,healing_total,threat_total,dps,hps,tps,duration_s,reactive_action,reason_code,reactive_status,role_signal,role_target_kind,reactive_event_count,noop_unsupported_count,unsafe_skip_count,fail_safe_tick_count,sample_count,evidence_mode,run_label,run_index,variance_pct,near_fail,verdict`. For `--dry-run --matrix`, emit one row per canonical spec with `evidence_mode=mock` and `verdict=schema_only`. For live mode, export the expanded shared meter snapshot for the current spec and append or write rows to the exact `--output` path. After row emission, print one blockers-first summary from `benchmark_matrix.format_blockers(summary)` and then one near-fail section. Update `tests/dps_benchmark_spec.lua` so it verifies the expanded schema, 27 dry-run rows, live-row field usage, and the blockers-first summary ordering.</action>
  <acceptance_criteria>
    - `tools/dps_benchmark.lua` contains `threat_total`
    - `tools/dps_benchmark.lua` contains `evidence_mode`
    - `tools/dps_benchmark.lua` contains `variance_pct`
    - `tools/dps_benchmark.lua` contains `format_blockers`
    - `tests/dps_benchmark_spec.lua` contains `schema_only`
    - `tests/dps_benchmark_spec.lua` contains `near_fail`
  </acceptance_criteria>
  <verify>
    <automated>rtk lua tests/dps_benchmark_spec.lua && rtk lua tools/dps_benchmark.lua --dry-run --matrix</automated>
  </verify>
  <done>The benchmark command now emits and summarizes the exact Phase 08 matrix contract instead of a narrow schema check.</done>
</task>

<task type="checkpoint:human-action" gate="blocking">
  <name>Task 2: Capture the approved live 27-spec baseline matrix</name>
  <read_first>
    - tools/dps_benchmark.lua
    - .planning/phases/08-benchmark-matrix-hardening/08-CONTEXT.md
    - .planning/phases/08-benchmark-matrix-hardening/08-VALIDATION.md
  </read_first>
  <files>benchmarks/phase08_live_baseline.csv</files>
  <action>Capture the approved baseline from the real Sylvanas/TBC runtime using the in-runtime append/export flow. The updated runtime now auto-appends combat-end snapshots into loader `scripts_data/benchmarks/phase08_live_baseline.csv`, keyed by canonical spec and capped at three live runs per spec with `run_label=phase08-baseline`. Run one character/spec at a time until all 27 canonical specs have three captured runs, then copy the finished artifact back into the repo as `benchmarks/phase08_live_baseline.csv`. Do not use `--dry-run`, and do not hand-edit the resulting CSV after capture.</action>
  <acceptance_criteria>
    - `benchmarks/phase08_live_baseline.csv` exists
    - `benchmarks/phase08_live_baseline.csv` contains `evidence_mode`
    - `benchmarks/phase08_live_baseline.csv` contains `,live,`
    - `benchmarks/phase08_live_baseline.csv` contains `EAXWarriorProtection`
    - `benchmarks/phase08_live_baseline.csv` contains `EAXPriestHoly`
    - `benchmarks/phase08_live_baseline.csv` contains `EAXShamanRestoration`
  </acceptance_criteria>
  <verify>
    <automated>rtk lua tools/dps_benchmark.lua --dry-run --matrix</automated>
  </verify>
  <how-to-verify>
    1. Copy the repo into the live Sylvanas scripts folder and load one canonical spec at a time in-game.
    2. Let the updated runtime write combat-end rows into loader `scripts_data/benchmarks/phase08_live_baseline.csv`; each spec auto-stops at three captured runs.
    3. Repeat across sessions/characters until the loader-side CSV contains all 27 canonical specs x 3 live runs.
    4. Copy `scripts_data/benchmarks/phase08_live_baseline.csv` back into the repo as `benchmarks/phase08_live_baseline.csv` without editing it.
  </how-to-verify>
  <resume-signal>Type "done" after `benchmarks/phase08_live_baseline.csv` exists in the repo, or describe blockers.</resume-signal>
  <done>The repo has one checked-in live baseline matrix artifact that later release gating can evaluate deterministically.</done>
</task>

</tasks>

<verification>
Before pausing for the live baseline checkpoint:
- `rtk lua tests/dps_benchmark_spec.lua`
- `rtk lua tools/dps_benchmark.lua --dry-run --matrix`

After the checkpoint:
- confirm `benchmarks/phase08_live_baseline.csv` exists and contains live rows for all canonical specs.
</verification>

<success_criteria>
`tools/dps_benchmark.lua` is now the real matrix/report entrypoint, and the repo contains the approved live baseline artifact that Phase 08 gating will require.
</success_criteria>

<output>
After completion, create `.planning/phases/08-benchmark-matrix-hardening/08-02-SUMMARY.md`
</output>
