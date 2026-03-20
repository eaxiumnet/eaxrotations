---
phase: 08
slug: benchmark-matrix-hardening
status: draft
nyquist_compliant: true
wave_0_complete: true
created: 2026-03-21
---

# Phase 08 - Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Lua assert-style scripts |
| **Config file** | none - existing repo test entrypoints |
| **Quick run command** | `rtk lua tests/benchmark_matrix_spec.lua` |
| **Full suite command** | `rtk lua tests/benchmark_matrix_spec.lua && rtk lua tests/dps_meter_spec.lua && rtk lua tests/reactive_runtime_spec.lua && rtk lua tests/dps_benchmark_spec.lua && rtk lua tests/rotation_validation_spec.lua && rtk lua tests/benchmark_gate_spec.lua && rtk lua tools/dps_benchmark.lua --dry-run && rtk lua tools/rotation_validation.lua` |
| **Estimated runtime** | ~25 seconds |

---

## Sampling Rate

- **After every task commit:** Run the task's `<automated>` command.
- **After every plan wave:** Run the full Phase 08 suite.
- **Before `/gsd-verify-work`:** Full suite must be green, then capture/update the live baseline if the checkpoint task requests it.
- **Max feedback latency:** 25 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 08-01-01 | 01 | 1 | MATX-01, MATX-02 | unit | `rtk lua tests/benchmark_matrix_spec.lua` | ✅ | ⬜ pending |
| 08-01-02 | 01 | 1 | MATX-01 | integration | `rtk lua tests/dps_meter_spec.lua && rtk lua tests/reactive_runtime_spec.lua` | ✅ | ⬜ pending |
| 08-02-01 | 02 | 2 | MATX-01, MATX-02 | integration | `rtk lua tests/dps_benchmark_spec.lua && rtk lua tools/dps_benchmark.lua --dry-run` | ✅ | ⬜ pending |
| 08-02-02 | 02 | 2 | MATX-02 | checkpoint | `rtk lua tools/dps_benchmark.lua --dry-run` | ❌ human creates `benchmarks/phase08_live_baseline.csv` | ⬜ pending |
| 08-03-01 | 03 | 3 | MATX-03 | unit | `rtk lua tests/benchmark_gate_spec.lua && rtk lua tests/rotation_validation_spec.lua` | ✅ | ⬜ pending |
| 08-03-02 | 03 | 3 | MATX-03 | integration | `rtk lua tests/benchmark_gate_spec.lua && rtk lua tests/rotation_validation_spec.lua && rtk lua tools/rotation_validation.lua` | ✅ | ⬜ pending |

*Status: ⬜ pending - ✅ green - ❌ red - ⚠ flaky*

---

## Wave 0 Requirements

Existing infrastructure covers all phase requirements.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Capture the approved 27-spec live baseline matrix | MATX-02, MATX-03 | Real Sylvanas/TBC runtime evidence is not reproducible from the repo-only CLI harness | Run the updated benchmark command in the live environment for all 27 canonical specs with 3 runs each, save `benchmarks/phase08_live_baseline.csv`, confirm rows use `evidence_mode=live`, then resume execution |

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references
- [x] No watch-mode flags
- [x] Feedback latency < 25s
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
