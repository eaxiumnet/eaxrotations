---
phase: 04-polish-competitive-features
verified: 2026-03-20T13:40:00Z
status: passed
score: 15/15 must-haves verified
human_verification:
  - test: "In-combat HUD telemetry updates"
    expected: "DPS/HPS/CD/TTD and aura strip update live while next-action icon/text remain correct"
    why_human: "Requires live game rendering and frame-to-frame behavior confirmation"
  - test: "Vendor automation behavior"
    expected: "At vendor, repair occurs only when affordable and only grey items are sold"
    why_human: "Depends on runtime inventory/vendor APIs and live bag contents"
  - test: "Mount automation transitions"
    expected: "Character auto-dismounts entering combat and auto-mounts only out-of-combat while stationary"
    why_human: "Needs real movement/combat state transitions in-game"
  - test: "Consumables policy execution"
    expected: "Combat potions, OOC food/drink, and flask logic trigger only when toggle-gated conditions are met"
    why_human: "Needs live cooldowns, inventory, and class-state context"
---

# Phase 4: Polish & Competitive Features Verification Report

**Phase Goal:** Match and exceed competitors with integrated benchmarking, automation, and visual polish.
**Verified:** 2026-03-20T13:40:00Z
**Status:** passed
**Re-verification:** No - initial verification

## Human Verification Outcome

- In-combat HUD telemetry updates: approved
- Vendor automation behavior: approved
- Mount automation transitions: approved
- Consumables policy execution: approved

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
| --- | --- | --- | --- |
| 1 | Combat snapshots expose DPS/HPS totals per fight | ✓ VERIFIED | `eax_shared/dps_meter.lua:60`-`eax_shared/dps_meter.lua:122` implements combat window start/end and snapshot rates |
| 2 | HUD data includes cooldown remaining, TTD, and tracked aura states | ✓ VERIFIED | `eax_shared/visual_state.lua:29`-`eax_shared/visual_state.lua:42` composes `cooldown_s`, `ttd_s`, `tracked_auras` |
| 3 | Shared visual state can be consumed by every spec without per-spec rewrites | ✓ VERIFIED | Cross-spec scan: `visual link pass 27/27`; `EAXWarriorFury/main.lua:40` + `EAXWarriorFury/main.lua:125` |
| 4 | Each spec HUD displays DPS/HPS, cooldown timer, and TTD | ✓ VERIFIED | Cross-spec scan passed for all 27 `esp_renderer.lua` pattern checks (DPS/HPS/CD/TTD) |
| 5 | Each spec HUD shows tracked buff/debuff statuses | ✓ VERIFIED | `EAXWarriorFury/esp_renderer.lua:62`-`EAXWarriorFury/esp_renderer.lua:79` and aura strip rendering at `EAXWarriorFury/esp_renderer.lua:164` |
| 6 | Visual telemetry updates live during combat without breaking existing next-action rendering | ✓ VERIFIED | `EAXWarriorFury/main.lua:89`-`EAXWarriorFury/main.lua:130` updates snapshot each tick; `EAXWarriorFury/esp_renderer.lua:120` keeps `on_cast` next-action flow |
| 7 | Vendor automation can repair gear and sell greys safely | ✓ VERIFIED | `eax_shared/vendor_automation.lua:66`-`eax_shared/vendor_automation.lua:133` uses affordability checks, quality==0 filtering, and throttles |
| 8 | Consumable decisions are centralized in one shared module | ✓ VERIFIED | `eax_shared/consumables_manager.lua:40`, `eax_shared/consumables_manager.lua:54`, `eax_shared/consumables_manager.lua:86` |
| 9 | Mount/dismount behavior is combat-state aware | ✓ VERIFIED | `eax_shared/mount_manager.lua:63`-`eax_shared/mount_manager.lua:87` explicit combat dismount + OOC mount branch |
| 10 | Every spec can run auto-repair and auto-sell at vendor | ✓ VERIFIED | `automation link pass 27/27`; sample wiring `EAXWarriorFury/main.lua:2141`-`EAXWarriorFury/main.lua:2146` |
| 11 | Every spec can use shared consumables policy | ✓ VERIFIED | `automation link pass 27/27`; sample wiring `EAXWarriorFury/main.lua:2137`, `EAXWarriorFury/main.lua:2151`, `EAXWarriorFury/main.lua:2154` |
| 12 | Every spec supports auto-mount/dismount toggles | ✓ VERIFIED | Cross-spec menu scan passed for all seven AUTO toggles across 27 specs; sample `EAXWarriorFury/menu.lua:38`-`EAXWarriorFury/menu.lua:44` |
| 13 | Regression checks catch missing shared wiring and syntax regressions | ✓ VERIFIED | `lua tools/rotation_validation.lua` output: `PASS: 27/27 specs validated` |
| 14 | Benchmark output reports measurable DPS/HPS snapshots | ✓ VERIFIED | `lua tools/dps_benchmark.lua --dry-run` prints schema and rows with `spec,damage_total,healing_total,dps,hps,duration_s` |
| 15 | All 27 specs are tracked in an explicit pass/fail checklist | ✓ VERIFIED | `.planning/phases/04-polish-competitive-features/04-REGRESSION-CHECKLIST.md:3` plus row count command returned `27` |

**Score:** 15/15 truths verified

### Required Artifacts

| Artifact | Expected | Status | Details |
| --- | --- | --- | --- |
| `eax_shared/dps_meter.lua` | Fight-level damage/healing accumulation + rates | ✓ VERIFIED | Exists, substantive implementation (124 lines), syntactically valid via `luac -p` |
| `eax_shared/cooldown_tracker.lua` | Remaining cooldown readout for next action | ✓ VERIFIED | Exists, contains `seconds_remaining`; linked from `visual_state` |
| `eax_shared/visual_state.lua` | Unified visual snapshot payload | ✓ VERIFIED | Exists, contains `build_snapshot`; calls `dps_meter.get_snapshot` and `cooldown_tracker.seconds_remaining` |
| `EAX*/esp_renderer.lua` | HUD metrics + aura rendering contract | ✓ VERIFIED | 27/27 files matched required visual patterns; syntax pass |
| `EAX*/main.lua` | Visual + automation shared wiring | ✓ VERIFIED | 27/27 files matched required wiring patterns; syntax pass |
| `EAX*/menu.lua` | AUTO toggles surface | ✓ VERIFIED | 27/27 files contain all 7 automation toggles |
| `eax_shared/vendor_automation.lua` | Auto-repair + grey-sell module | ✓ VERIFIED | Uses documented repair and bag APIs with throttle + quality filtering |
| `eax_shared/consumables_manager.lua` | Combat/OOC/flask consumable policy | ✓ VERIFIED | Exports all required entry points with cooldown gating |
| `eax_shared/mount_manager.lua` | Combat dismount + OOC mount state transitions | ✓ VERIFIED | Explicit combat and OOC branches present |
| `tools/rotation_validation.lua` | Per-spec wiring/syntax validation CLI | ✓ VERIFIED | Defines `validate_spec` + `main`; executed successfully for 27/27 specs |
| `tools/dps_benchmark.lua` | Benchmark CLI with dry-run schema output | ✓ VERIFIED | Defines `run_benchmark`; dry-run emitted expected metrics columns |
| `.planning/phases/04-polish-competitive-features/04-REGRESSION-CHECKLIST.md` | 27-spec verification matrix | ✓ VERIFIED | Contains required columns and exactly 27 `| EAX...` rows |

### Key Link Verification

| From | To | Via | Status | Details |
| --- | --- | --- | --- | --- |
| `eax_shared/visual_state.lua` | `eax_shared/dps_meter.lua` | snapshot composition | WIRED | `dps_meter.get_snapshot` at `eax_shared/visual_state.lua:32` |
| `eax_shared/visual_state.lua` | `eax_shared/cooldown_tracker.lua` | cooldown readout | WIRED | `cooldown_tracker.seconds_remaining` at `eax_shared/visual_state.lua:34` |
| `EAX*/main.lua` | `eax_shared/visual_state.lua` | HUD payload construction | WIRED | Cross-spec key-link scan: `visual link pass 27/27` |
| `EAX*/esp_renderer.lua` | `EAX*/main.lua` | snapshot setter updates | WIRED | `update_visual_snapshot` path present across all 27 specs |
| `eax_shared/vendor_automation.lua` | `core.input.repair_all_items` | repair action | WIRED | `core.input.repair_all_items(false)` at `eax_shared/vendor_automation.lua:91` |
| `eax_shared/vendor_automation.lua` | `core.inventory` | vendor bag/value scans | WIRED | `get_total_repair_cost` at `eax_shared/vendor_automation.lua:76`; `get_items_in_bag` at `eax_shared/vendor_automation.lua:111` |
| `EAX*/main.lua` | `eax_shared/vendor_automation.lua` / `eax_shared/consumables_manager.lua` / `eax_shared/mount_manager.lua` | automation update lanes | WIRED | Cross-spec key-link scan: `automation link pass 27/27` |
| `tools/dps_benchmark.lua` | `eax_shared/dps_meter.lua` | snapshot pull | WIRED | `require("eax_shared/dps_meter")` at `tools/dps_benchmark.lua:1`; `get_snapshot` at `tools/dps_benchmark.lua:78` |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
| --- | --- | --- | --- | --- |
| VIS-01 | 01, 02 | DPS/HPS meter in ESP | ✓ SATISFIED | Shared meter + HUD rows: `eax_shared/dps_meter.lua`, `EAXWarriorFury/esp_renderer.lua:253` |
| VIS-02 | 01, 02 | Cooldown timer display in HUD | ✓ SATISFIED | `cooldown_tracker.seconds_remaining` -> `visual_state.cooldown_s` -> HUD `CD` row |
| VIS-03 | 01, 02 | TTD display in HUD | ✓ SATISFIED | `visual_state` `ttd_s` normalization and HUD `TTD` row at `EAXWarriorFury/esp_renderer.lua:256` |
| VIS-04 | 01, 02 | Buff/debuff tracker display in ESP | ✓ SATISFIED | Aura payload + strip rendering (`tracked_auras`) in renderer |
| AUTO-01 | 03, 04 | Auto-repair | ✓ SATISFIED | `vendor_automation.try_auto_repair` and 27-spec main wiring |
| AUTO-02 | 03, 04 | Auto-sell greys | ✓ SATISFIED | `vendor_automation.try_auto_sell_greys` quality==0 filtering + 27-spec wiring |
| AUTO-03 | 03, 04 | Consumables management | ✓ SATISFIED | `consumables_manager` functions and toggle-gated calls in all specs |
| AUTO-04 | 03, 04 | Auto-dismount/mount by combat state | ✓ SATISFIED | `mount_manager.update_mount_state` combat and OOC branches + 27-spec calls |
| QUAL-01 | 05 | Rotation validation framework | ✓ SATISFIED | `tools/rotation_validation.lua` executed: `PASS: 27/27 specs validated` |
| QUAL-02 | 05 | DPS benchmark tool | ✓ SATISFIED | `tools/dps_benchmark.lua --dry-run` produced metric schema + rows |
| QUAL-03 | 05 | Spec regression checklist | ✓ SATISFIED | Checklist exists with required columns and 27 rows |

Orphaned requirements (Phase 4 mapping in `REQUIREMENTS.md` not claimed by any Phase 04 plan): **None**.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
| --- | --- | --- | --- | --- |
| (none in phase-target files) | - | TODO/FIXME/PLACEHOLDER stubs | ℹ️ Info | Target files scanned; no blocker stub markers found |

### Human Verification Required

### 1. In-combat HUD telemetry updates

**Test:** Enter combat on any spec and observe HUD for DPS/HPS/CD/TTD and aura strip while rotation runs.
**Expected:** Metrics update continuously and next-action icon/text remains accurate.
**Why human:** Requires live rendering and temporal behavior.

### 2. Vendor automation behavior

**Test:** Open vendor with damaged gear and mixed-quality bags.
**Expected:** Repair only when affordable; only quality-0 items are sold.
**Why human:** Depends on runtime vendor/inventory APIs and real item states.

### 3. Mount automation transitions

**Test:** Toggle auto-mount/dismount on, move between idle travel and combat.
**Expected:** Auto-mount only out-of-combat while stationary; immediate dismount on combat.
**Why human:** Requires live movement/combat transitions.

### 4. Consumables policy execution

**Test:** Toggle auto-combat potions, auto OOC food/drink, and auto flask in real gameplay states.
**Expected:** Usage occurs only under intended conditions and cooldown gates.
**Why human:** Requires live inventory/cooldown state and combat context.

### Gaps Summary

No automated gaps found against Phase 04 must-haves. Code-level artifacts and key links are present and wired. Final signoff depends on in-game behavioral/UX validation listed above.

---

_Verified: 2026-03-20T13:29:25Z_
_Verifier: Claude (gsd-verifier)_
