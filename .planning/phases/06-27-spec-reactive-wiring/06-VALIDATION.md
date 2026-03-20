---
phase: 06
slug: 27-spec-reactive-wiring
status: draft
nyquist_compliant: true
wave_0_complete: true
created: 2026-03-20
---

# Phase 06 - Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | other - Lua assert scripts + CLI validation |
| **Config file** | none - existing `lua` entrypoints are sufficient |
| **Quick run command** | `rtk lua tests/reactive_runtime_spec.lua && rtk lua tests/reactive_runtime_wiring_spec.lua` |
| **Full suite command** | `rtk lua tests/reactive_engine_spec.lua && rtk lua tests/reactive_runtime_spec.lua && rtk lua tests/reactive_runtime_wiring_spec.lua && rtk lua tests/rotation_validation_spec.lua && rtk lua tools/rotation_validation.lua` |
| **Estimated runtime** | ~20 seconds |

---

## Sampling Rate

- **After every task commit:** Run `rtk lua tests/reactive_runtime_spec.lua && rtk lua tests/reactive_runtime_wiring_spec.lua`
- **After every plan wave:** Run `rtk lua tests/reactive_engine_spec.lua && rtk lua tests/reactive_runtime_spec.lua && rtk lua tests/reactive_runtime_wiring_spec.lua && rtk lua tests/rotation_validation_spec.lua && rtk lua tools/rotation_validation.lua`
- **Before `/gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** 20 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 06-01-01 | 01 | 1 | WIRE-02 | unit/contract | `rtk lua tests/reactive_runtime_spec.lua` | ✅ | ⬜ pending |
| 06-01-02 | 01 | 1 | WIRE-01, WIRE-02 | integration | `rtk lua tests/reactive_runtime_spec.lua && rtk lua tests/reactive_runtime_wiring_spec.lua` | ✅ | ⬜ pending |
| 06-02-01 | 02 | 2 | WIRE-01, WIRE-02 | parity | `rtk lua tests/reactive_runtime_wiring_spec.lua` | ✅ | ⬜ pending |
| 06-02-02 | 02 | 2 | WIRE-03 | blocking validation | `rtk lua tests/rotation_validation_spec.lua && rtk lua tools/rotation_validation.lua` | ✅ | ⬜ pending |

*Status: ⬜ pending - ✅ green - ❌ red - ⚠ flaky*

---

## Wave 0 Requirements

- Existing infrastructure covers all phase requirements.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Reactive retarget snap-back feels stable during real combat | WIRE-01 | The repo has Lua validation but no live Sylvanas combat simulator | In game, trigger one urgent retarget-capable reaction on a DPS spec and confirm the script returns to the prior main target when the urgent action resolves or fails |

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references
- [x] No watch-mode flags
- [x] Feedback latency < 20s
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
