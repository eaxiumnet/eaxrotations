---
phase: 04
slug: polish-competitive-features
status: draft
nyquist_compliant: true
wave_0_complete: false
created: 2026-03-20
---

# Phase 04 - Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | lua + shell checks (no unit-test framework) |
| **Config file** | none - grep/luac based |
| **Quick run command** | `rtk luac -p eax_shared/*.lua` |
| **Full suite command** | `rtk luac -p EAX*/main.lua && rtk luac -p EAX*/esp_renderer.lua && rtk lua tools/rotation_validation.lua` |
| **Estimated runtime** | ~45 seconds |

---

## Sampling Rate

- **After every task commit:** Run `rtk luac -p eax_shared/*.lua`
- **After every plan wave:** Run `rtk luac -p EAX*/main.lua && rtk luac -p EAX*/esp_renderer.lua && rtk lua tools/rotation_validation.lua`
- **Before `/gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** 60 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 04-01-01 | 01 | 1 | VIS-01 | static | `rtk rg -n "get_snapshot|on_damage|on_heal" eax_shared/dps_meter.lua` | ✅ | ⬜ pending |
| 04-01-02 | 01 | 1 | VIS-02,VIS-03,VIS-04 | static | `rtk rg -n "seconds_remaining|ttd|buff" eax_shared/cooldown_tracker.lua eax_shared/visual_state.lua` | ✅ | ⬜ pending |
| 04-02-01 | 02 | 2 | VIS-01..04 | integration | `rtk luac -p EAX*/esp_renderer.lua && rtk rg -n "DPS|HPS|TTD|Cooldown" EAX*/esp_renderer.lua` | ✅ | ⬜ pending |
| 04-03-01 | 03 | 1 | AUTO-01,AUTO-02 | static | `rtk rg -n "repair|sell|vendor" eax_shared/vendor_automation.lua` | ✅ | ⬜ pending |
| 04-03-02 | 03 | 1 | AUTO-03,AUTO-04 | static | `rtk rg -n "mount|dismount|consumable" eax_shared/consumables_manager.lua eax_shared/mount_manager.lua` | ✅ | ⬜ pending |
| 04-04-01 | 04 | 2 | AUTO-01..04 | integration | `rtk luac -p EAX*/main.lua && rtk rg -n "vendor_automation|consumables_manager|mount_manager" EAX*/main.lua` | ✅ | ⬜ pending |
| 04-05-01 | 05 | 3 | QUAL-01 | tooling | `rtk lua tools/rotation_validation.lua` | ❌ W0 | ⬜ pending |
| 04-05-02 | 05 | 3 | QUAL-02 | tooling | `rtk lua tools/dps_benchmark.lua --dry-run` | ❌ W0 | ⬜ pending |
| 04-05-03 | 05 | 3 | QUAL-03 | checklist | `rtk rg -n "EAX.*\|" .planning/phases/04-polish-competitive-features/04-REGRESSION-CHECKLIST.md` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠ flaky*

---

## Wave 0 Requirements

- [ ] `tools/rotation_validation.lua` - validation runner scaffold
- [ ] `tools/dps_benchmark.lua` - benchmark runner scaffold
- [ ] `.planning/phases/04-polish-competitive-features/04-REGRESSION-CHECKLIST.md` - 27-spec checklist scaffold

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| ESP layout readability during combat | VIS-01..04 | visual quality cannot be asserted by grep | Enable one melee + one caster spec, confirm HUD shows DPS/HPS, cooldown, TTD, aura rows without overlap |
| Auto-mount safety in contested areas | AUTO-04 | movement/combat race conditions are runtime dependent | Enter/leave combat repeatedly near hostile packs; verify instant dismount in combat and no mount spam while moving |

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references
- [x] No watch-mode flags
- [x] Feedback latency < 60s
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
