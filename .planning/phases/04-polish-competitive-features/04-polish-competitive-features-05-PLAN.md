---
phase: 04-polish-competitive-features
plan: 05
type: execute
wave: 3
depends_on:
  - 04-polish-competitive-features-02
  - 04-polish-competitive-features-04
files_modified:
  - tools/rotation_validation.lua
  - tools/dps_benchmark.lua
  - .planning/phases/04-polish-competitive-features/04-REGRESSION-CHECKLIST.md
autonomous: true
requirements: [QUAL-01, QUAL-02, QUAL-03]
user_setup: []
must_haves:
  truths:
    - "Regression checks catch missing shared wiring and syntax regressions"
    - "Benchmark output reports measurable DPS/HPS snapshots"
    - "All 27 specs are tracked in an explicit pass/fail checklist"
  artifacts:
    - path: "tools/rotation_validation.lua"
      provides: "Automated static validation framework"
      contains: "validate_spec"
    - path: "tools/dps_benchmark.lua"
      provides: "Benchmark command that emits comparable output"
      contains: "run_benchmark"
    - path: ".planning/phases/04-polish-competitive-features/04-REGRESSION-CHECKLIST.md"
      provides: "Manual + scripted verification matrix for 27 specs"
      contains: "| EAX"
  key_links:
    - from: "tools/rotation_validation.lua"
      to: "EAX*/main.lua"
      via: "spec scan and rule checks"
      pattern: "EAX.*main\.lua"
    - from: "tools/dps_benchmark.lua"
      to: "eax_shared/dps_meter.lua"
      via: "snapshot pull"
      pattern: "dps_meter"
---

<objective>
Ship the quality gate for Phase 04 by adding automation for rotation validation, benchmark reporting, and per-spec regression tracking.

Purpose: Meet competitive-quality requirements with repeatable verification instead of ad-hoc checks.
Output: Two executable tools plus a maintained checklist artifact.
</objective>

<execution_context>
@C:/Users/Support/.config/opencode/get-shit-done/workflows/execute-plan.md
@C:/Users/Support/.config/opencode/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/PROJECT.md
@.planning/ROADMAP.md
@.planning/STATE.md
@.planning/phases/04-polish-competitive-features/04-VALIDATION.md
@.planning/codebase/TESTING.md
@eax_shared/dps_meter.lua
</context>

<tasks>

<task type="auto" tdd="true">
  <name>Task 1: Create rotation validation framework script</name>
  <read_first>
    - .planning/codebase/TESTING.md
    - EAXWarriorFury/main.lua
    - EAXMageArcane/main.lua
  </read_first>
  <files>tools/rotation_validation.lua</files>
  <behavior>
    - Test 1: script scans all `EAX*/main.lua` and reports missing shared-module imports.
    - Test 2: script fails non-zero when any file fails required checks.
    - Test 3: script prints per-spec pass/fail lines for grep-friendly consumption.
  </behavior>
  <action>Create `tools/rotation_validation.lua` with `validate_spec(spec_dir)` and `main()` entrypoint. Enforce these checks per spec: file exists, contains required visual imports (`visual_state`), contains required automation imports (`vendor_automation`, `consumables_manager`, `mount_manager`), and passes syntax check via `os.execute("luac -p ...")`. Exit code must be `0` on full pass, non-zero on any failure.</action>
  <acceptance_criteria>
    - Script defines `validate_spec` and `main`
    - Script prints deterministic `PASS:`/`FAIL:` lines
    - Script returns non-zero exit when any spec fails checks
  </acceptance_criteria>
  <verify>
    <automated>rtk lua tools/rotation_validation.lua</automated>
  </verify>
  <done>QUAL-01 validation framework is executable and enforces Phase 04 wiring rules.</done>
</task>

<task type="auto" tdd="true">
  <name>Task 2: Create DPS benchmark tool and regression checklist artifact</name>
  <read_first>
    - eax_shared/dps_meter.lua
    - .planning/phases/03-per-class-rotation-deep-dives/03-09-SUMMARY.md
    - .planning/phases/04-polish-competitive-features/04-VALIDATION.md
  </read_first>
  <files>tools/dps_benchmark.lua, .planning/phases/04-polish-competitive-features/04-REGRESSION-CHECKLIST.md</files>
  <behavior>
    - Test 1: benchmark script supports `--dry-run` and prints output schema.
    - Test 2: benchmark script outputs at least spec, damage_total, healing_total, dps, hps columns.
    - Test 3: checklist includes all 27 specs with status columns for VIS, AUTO, QUAL verification.
  </behavior>
  <action>Create `tools/dps_benchmark.lua` with `run_benchmark(args)` that reads `dps_meter.get_snapshot()` (or mocked snapshot in dry-run mode) and writes markdown/CSV lines with `spec`, `damage_total`, `healing_total`, `dps`, `hps`, `duration_s`. Create `.planning/phases/04-polish-competitive-features/04-REGRESSION-CHECKLIST.md` containing a 27-spec table and explicit columns: `Visual HUD`, `Automation`, `Validation Script`, `Benchmark`, `Manual Notes`.</action>
  <acceptance_criteria>
    - `tools/dps_benchmark.lua` supports `--dry-run`
    - Benchmark output contains all five metric columns
    - Regression checklist table contains exactly 27 spec rows
  </acceptance_criteria>
  <verify>
    <automated>rtk lua tools/dps_benchmark.lua --dry-run && rtk rg -n "spec|damage_total|healing_total|dps|hps|duration_s" tools/dps_benchmark.lua && rtk rg -n "^\| EAX" .planning/phases/04-polish-competitive-features/04-REGRESSION-CHECKLIST.md</automated>
  </verify>
  <done>QUAL-02 and QUAL-03 artifacts are present and executable.</done>
</task>

</tasks>

<verification>
Run final quality gate commands:
- `rtk lua tools/rotation_validation.lua`
- `rtk lua tools/dps_benchmark.lua --dry-run`
- `rtk rg -n "^\| EAX" .planning/phases/04-polish-competitive-features/04-REGRESSION-CHECKLIST.md`
</verification>

<success_criteria>
QUAL-01..QUAL-03 are fulfilled by runnable scripts and a complete 27-spec regression checklist.
</success_criteria>

<output>
After completion, create `.planning/phases/04-polish-competitive-features/04-05-SUMMARY.md`
</output>
