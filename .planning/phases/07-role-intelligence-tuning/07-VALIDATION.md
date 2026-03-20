---
phase: 07
slug: role-intelligence-tuning
status: draft
nyquist_compliant: true
wave_0_complete: true
created: 2026-03-20
---

# Phase 07 - Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Lua assert-style scripts |
| **Config file** | none - existing repo test entrypoints |
| **Quick run command** | `rtk lua tests/reactive_runtime_wiring_spec.lua` |
| **Full suite command** | `rtk lua tests/combat_context_spec.lua && rtk lua tests/role_policy_spec.lua && rtk lua tests/healer_role_behavior_spec.lua && rtk lua tests/tank_role_behavior_spec.lua && rtk lua tests/dps_role_behavior_spec.lua && rtk lua tests/reactive_runtime_spec.lua && rtk lua tests/reactive_runtime_wiring_spec.lua && rtk lua tests/rotation_validation_spec.lua && rtk lua tools/rotation_validation.lua && rtk lua tools/dps_benchmark.lua --dry-run` |
| **Estimated runtime** | ~20 seconds |

---

## Sampling Rate

- **After every task commit:** Run the task's `<automated>` command.
- **After every plan wave:** Run `rtk lua tests/reactive_runtime_wiring_spec.lua` plus the changed-family spec for that wave.
- **Before `/gsd-verify-work`:** Full suite must be green.
- **Max feedback latency:** 20 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 07-01-01 | 01 | 1 | ROLE-01, ROLE-02, ROLE-03, ROLE-04 | unit | `rtk lua tests/combat_context_spec.lua && rtk lua tests/role_policy_spec.lua && rtk lua tests/reactive_runtime_spec.lua` | ✅ | ⬜ pending |
| 07-01-02 | 01 | 1 | ROLE-01, ROLE-02, ROLE-03, ROLE-04 | integration | `rtk lua tests/combat_context_spec.lua && rtk lua tests/role_policy_spec.lua && rtk lua tests/reactive_runtime_spec.lua` | ✅ | ⬜ pending |
| 07-02-01 | 02 | 2 | ROLE-02 | unit | `rtk lua tests/healer_role_behavior_spec.lua` | ✅ | ⬜ pending |
| 07-02-02 | 02 | 2 | ROLE-02 | integration | `rtk lua tests/healer_role_behavior_spec.lua && rtk lua tests/reactive_runtime_wiring_spec.lua` | ✅ | ⬜ pending |
| 07-03-01 | 03 | 2 | ROLE-03 | unit | `rtk lua tests/tank_role_behavior_spec.lua` | ✅ | ⬜ pending |
| 07-03-02 | 03 | 2 | ROLE-03, ROLE-04 | integration | `rtk lua tests/tank_role_behavior_spec.lua && rtk lua tests/reactive_runtime_wiring_spec.lua` | ✅ | ⬜ pending |
| 07-04-01 | 04 | 2 | ROLE-01 | unit | `rtk lua tests/dps_role_behavior_spec.lua` | ✅ | ⬜ pending |
| 07-04-02 | 04 | 2 | ROLE-01, ROLE-04 | integration | `rtk lua tests/dps_role_behavior_spec.lua && rtk lua tests/reactive_runtime_wiring_spec.lua` | ✅ | ⬜ pending |
| 07-05-01 | 05 | 3 | ROLE-01, ROLE-02, ROLE-03, ROLE-04 | unit | `rtk lua tests/rotation_validation_spec.lua` | ✅ | ⬜ pending |
| 07-05-02 | 05 | 3 | ROLE-01, ROLE-02, ROLE-03, ROLE-04 | integration | `rtk lua tests/rotation_validation_spec.lua && rtk lua tools/rotation_validation.lua && rtk lua tools/dps_benchmark.lua --dry-run` | ✅ | ⬜ pending |

*Status: ⬜ pending - ✅ green - ❌ red - ⚠ flaky*

---

## Wave 0 Requirements

Existing infrastructure covers all phase requirements.

---

## Manual-Only Verifications

All phase behaviors have automated verification.

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references
- [x] No watch-mode flags
- [x] Feedback latency < 20s
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
