# Implementation Plan: Hardcoded-to-API Migration

**Created:** 2026-06-13
**API Surface:** `api/common/enums.lua`, `api/common/izi_sdk.lua`, `api/common/buff_db.lua`, `api/core.lua`
**Docs References:** `apidocs/pages/dev/api/core.md`, `apidocs/pages/dev/api/buffs.md`

## Overview

Replace hardcoded constant tables in `core_sylvanas.lua` with Sylvanas API equivalents where the API provides identical or superior functionality. This reduces maintenance burden and eliminates stale ID lists.

## Scope

**In-scope:** `core_sylvanas.lua` only (the central hardcoded tables)
**Out-of-scope:** Spec files (class_sylvanas.lua spell rank arrays), shared modules (healer_deficit hardcoded sizes), item ID tables

## API Integration

| Function | File | Purpose |
|----------|------|---------|
| `enums.class_id.*` | `api/common/enums.lua` | Named class constants |
| `enums.power_type.*` | `api/common/enums.lua` | Named power type constants |
| `unit:is_cc()` | `api/common/izi_sdk.lua` | CC detection (replaces NS.CC_DEBUFFS) |
| `unit:is_stunned()` | `api/common/izi_sdk.lua` | Stun detection |
| `unit:is_feared()` | `api/common/izi_sdk.lua` | Fear detection |
| `unit:is_silenced()` | `api/common/izi_sdk.lua` | Silence detection |
| `unit:is_rooted()` | `api/common/izi_sdk.lua` | Root detection |
| `unit:has_burst()` | `api/common/izi_sdk.lua` | Burst buff detection |
| `unit:is_damage_immune()` | `api/common/izi_sdk.lua` | Defensive immunity detection |

## Files to Touch

| File | Change | API Used |
|------|--------|----------|
| `EaxRotations/core_sylvanas.lua` | Replace NS.CLASS_ID, NS.POWER_*, NS.CC_DEBUFFS, PVP_BURST_BUFFS, PLAYER_DEFENSIVE_BUFFS | enums.lua, izi_sdk.lua |

## Task List

### Phase 1: Foundation (Zero-Risk Replacements)
- [ ] Task 1: Replace `NS.CLASS_ID` with `enums.class_id`
  - **Files:** `EaxRotations/core_sylvanas.lua`
  - **API Used:** `require("common/enums")`, `enums.class_id.*`
  - **Acceptance:** `luac -p` passes, no runtime errors in class detection, rotation tests pass
  - **Verify:** `luac -p EaxRotations/core_sylvanas.lua` and `lua EaxRotations/tests/run_rotation_tests.lua`

- [ ] Task 2: Replace `NS.POWER_*` with `enums.power_type`
  - **Files:** `EaxRotations/core_sylvanas.lua`
  - **API Used:** `require("common/enums")`, `enums.power_type.*`
  - **Acceptance:** `luac -p` passes, power detection works correctly, rotation tests pass
  - **Verify:** `luac -p EaxRotations/core_sylvanas.lua` and `lua EaxRotations/tests/run_rotation_tests.lua`

### Phase 2: PvP State Replacements (High ROI)
- [ ] Task 3: Replace `NS.CC_DEBUFFS` with `unit:is_cc()` / `unit:is_stunned()` / `unit:is_feared()`
  - **Files:** `EaxRotations/core_sylvanas.lua`
  - **API Used:** `izi_sdk.lua` `unit:is_cc()` and specific CC type checks
  - **Acceptance:** `luac -p` passes, NS.is_cc() and NS.is_cc_or_talent() produce equivalent results
  - **Verify:** `luac -p EaxRotations/core_sylvanas.lua` and `lua EaxRotations/tests/run_rotation_tests.lua`

- [ ] Task 4: Replace `PVP_BURST_BUFFS` with `unit:has_burst()`
  - **Files:** `EaxRotations/core_sylvanas.lua`
  - **API Used:** `izi_sdk.lua` `unit:has_burst()`
  - **Acceptance:** `luac -p` passes, NS.is_target_bursting() equivalent behavior
  - **Verify:** `luac -p EaxRotations/core_sylvanas.lua` and `lua EaxRotations/tests/run_rotation_tests.lua`

- [ ] Task 5: Replace `PLAYER_DEFENSIVE_BUFFS` with `unit:is_damage_immune()`
  - **Files:** `EaxRotations/core_sylvanas.lua`
  - **API Used:** `izi_sdk.lua` `unit:is_damage_immune()`
  - **Acceptance:** `luac -p` passes, NS.is_player_defensive() equivalent behavior
  - **Verify:** `luac -p EaxRotations/core_sylvanas.lua` and `lua EaxRotations/tests/run_rotation_tests.lua`

### Phase 3: Validation
- [ ] Task 6: Full validation
  - **Verify:** All 95 rotation + 11 leveling suites pass, LSP zero errors on changed files
  - **Verify:** `git diff` shows only the intended changes

## Risks

| Risk | Impact | Mitigation |
|------|--------|------------|
| `enums` module not available at load time | Crash on startup | `pcall(require, "common/enums")` with fallback |
| `unit:is_cc()` returns different mask than NS.CC_DEBUFFS | Behavioral change | Characterization tests: verify old table covers all CC types |
| `unit:has_burst()` includes/excludes different buffs | PvP behavior shift | Compare BUFF_DB entries vs old hardcoded list |
| `unit:is_damage_immune()` includes/excludes different buffs | PvP behavior shift | Compare BUFF_DB entries vs old hardcoded list |

## Implementation Notes

- `NS.CLASS_ID` is used by `NS.GetClassName()` and other class detection helpers
- `NS.POWER_*` is used by `NS.power_current()`, `NS.power_pct()`, etc.
- `NS.CC_DEBUFFS` is used by `NS.is_cc()` and `NS.is_cc_or_talent()`
- `PVP_BURST_BUFFS` is used by `NS.is_target_bursting()`
- `PLAYER_DEFENSIVE_BUFFS` is used by `NS.is_player_defensive()` and `NS.is_player_defensive_extended()`
- All replacements must maintain backward compatibility for any external consumers of NS.*
