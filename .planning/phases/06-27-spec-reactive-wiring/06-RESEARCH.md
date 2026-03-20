# Phase 06: 27-Spec Reactive Wiring - Research

**Date:** 2026-03-20
**Scope:** WIRE-01, WIRE-02, WIRE-03

## Current Baseline

- `eax_shared/reactive_runtime.lua` already builds one combat snapshot, runs `reactive_engine.try_handle(...)`, and persists `reactive_action` / `reason_code` telemetry, but it still uses default placeholder handlers and never drives spec behavior.
- Every canonical `EAX*/main.lua` already imports `reactive_runtime` and calls `reactive_runtime.update_tick(...)` inside `visual_update_snapshot(...)`, so Phase 06 should evolve that lane instead of inventing a second runtime pass.
- Representative specs already expose the role-specific surfaces Phase 06 needs: `interrupt_manager.try_interrupt(...)`, `defensive_manager.try_defensive(...)`, healer spell helpers, `utils.find_best_target(...)`, focus-target overrides, and `core.input.set_target(...)` for explicit retargets.
- `tools/rotation_validation.lua` and `tests/reactive_runtime_wiring_spec.lua` already define the canonical 27-spec folder list and emit deterministic `PASS:` / `FAIL:` lines, making them the right parity gate to extend.

## Findings

### Shared Runtime Shape (WIRE-01, WIRE-02)

1. **Keep one shared runtime entrypoint, but add an explicit adapter contract**
   - Do not push reactive branching logic into 27 unrelated `main.lua` files.
   - Extend `eax_shared/reactive_runtime.lua` so `update_tick(me, target, deps)` still owns snapshot + engine evaluation, but can also consume a per-spec adapter table.
   - The adapter contract should require all six current action keys: `life_save_self`, `life_save_ally`, `interrupt_control`, `anti_overheal`, `anti_aggro`, `throughput_resume`.
   - Each key must be declared as either a real handler or an explicit validated no-op so unsupported behavior is never silent.

2. **Retarget only around urgent reactive winners**
   - The user locked retarget authority to urgent reactions only; the shared runtime should own this, not ad hoc per-spec code.
   - Use `core.input.set_target(unit)` as the canonical retarget API when a handler needs a different hostile or ally target than the current main target.
   - Persist the prior main-target identity in shared state, attempt the reactive handler, and immediately restore the prior target if the cast fails or once the urgent action resolves and the old target is still valid.
   - When target selection is ambiguous, invalid, or unsafe, fail closed and mark the action as skipped/no-op rather than guessing.

3. **Represent role behavior through existing managers first**
   - DPS specs already have interrupt and defensive surfaces; Phase 06 should route `interrupt_control` and `life_save_self` through those existing helpers before adding any new rotation logic.
   - Healer specs already have low-health ally targeting and cast-stop logic; `life_save_ally` and `anti_overheal` should lean on those existing helpers instead of inventing a new healing engine here.
   - Tank specs already contain recovery/retarget logic (for example `EAXWarriorProtection/main.lua`), so they are the best proof point for snap-away / snap-back behavior.

### Validation and Parity (WIRE-03)

1. **Promote parity from substring wiring to adapter coverage**
   - `tests/reactive_runtime_wiring_spec.lua` currently proves import/update wiring only.
   - Extend parity coverage so each canonical `main.lua` must expose one adapter declaration block with all six action keys and one call that passes that adapter into `reactive_runtime.update_tick(...)`.
   - Unsupported actions must be grep-visible through exact no-op markers, not implied by missing code.

2. **Extend the blocking validation command instead of adding a parallel script**
   - `tools/rotation_validation.lua` must remain the single blocking command.
   - Add a second pass that prints one deterministic reactive parity line per spec and a final `PASS: reactive parity 27/27` or `FAIL: reactive parity X/27` summary.
   - Include unsupported-action coverage failures in those lines so validation output makes adapter gaps obvious.

3. **Telemetry must show unsupported/no-op outcomes**
   - The user locked unsupported actions to be visible in telemetry as well as validation.
   - Reuse the existing shared `dps_meter` snapshot instead of adding a separate report channel.
   - Recommended shape: keep `reactive_action` / `reason_code`, and add one small status field such as `reactive_status` with exact values `handled`, `noop_unsupported`, `skipped_unsafe`, or `none`.

## Decisions for Planning

- Keep `reactive_runtime.update_tick(...)` as the only shared reactive runtime entrypoint; do not introduce a second orchestration module.
- Use one explicit per-spec adapter table declared in each `main.lua`, with all six action keys present and explicit no-ops where unsupported.
- Centralize urgent retarget / restore behavior inside `eax_shared/reactive_runtime.lua` using `core.input.set_target(...)` and shared per-spec state.
- Extend `tools/rotation_validation.lua` and `tests/reactive_runtime_wiring_spec.lua` as the canonical parity gate instead of creating a new validator.

## Risks / Pitfalls

- Bulk editing 27 large `main.lua` files is easy to do shallowly; plans must lock exact adapter fields and exact verification strings so executors do not add one-line stubs.
- Retarget restore can create target thrash if the runtime keeps switching on every tick; preserve the existing hold-buffer behavior and restore only after one urgent action path finishes or fails.
- Some specs do not have natural support for every category today; those gaps must become explicit validated no-ops, not silent missing branches.
- Healer specs often use ally-focused casts without changing hostile target; plans should preserve that behavior and only use `core.input.set_target(...)` where a real reactive target swap is required.

## Validation Architecture

- **Wave 0:** existing Lua assert-style specs are sufficient; no new framework install is needed.
- **Per task:** run the focused Lua specs that cover runtime contract changes first, then the blocking validation script.
- **Per wave:** run the full Phase 06 verification set:
  - `rtk lua tests/reactive_engine_spec.lua`
  - `rtk lua tests/reactive_runtime_spec.lua`
  - `rtk lua tests/reactive_runtime_wiring_spec.lua`
  - `rtk lua tests/rotation_validation_spec.lua`
  - `rtk lua tools/rotation_validation.lua`

## Sources

- `.planning/PROJECT.md`
- `.planning/REQUIREMENTS.md`
- `.planning/ROADMAP.md`
- `.planning/STATE.md`
- `.planning/phases/06-27-spec-reactive-wiring/06-CONTEXT.md`
- `.planning/phases/05-reactive-contract-api-gate/05-CONTEXT.md`
- `.planning/phases/05-reactive-contract-api-gate/05-01-SUMMARY.md`
- `.planning/phases/05-reactive-contract-api-gate/05-03-SUMMARY.md`
- `.planning/phases/05-reactive-contract-api-gate/05-05-SUMMARY.md`
- `.planning/codebase/STACK.md`
- `.planning/codebase/ARCHITECTURE.md`
- `.planning/codebase/CONVENTIONS.md`
- `.planning/codebase/TESTING.md`
- `eax_shared/reactive_engine.lua`
- `eax_shared/reactive_runtime.lua`
- `tools/rotation_validation.lua`
- `tests/reactive_engine_spec.lua`
- `tests/reactive_runtime_spec.lua`
- `tests/reactive_runtime_wiring_spec.lua`
- `tests/rotation_validation_spec.lua`
- `EAXWarriorFury/main.lua`
- `EAXPriestHoly/main.lua`
- `EAXWarriorProtection/main.lua`
- `.api/core.lua`

## RESEARCH COMPLETE

Phase 06 should be planned as 2 execution plans in 2 waves:
- Plan 01: extend the shared runtime contract, add unsupported/no-op telemetry, and prove the adapter pattern in representative DPS/healer/tank specs.
- Plan 02: roll the adapter contract across all 27 canonical specs and tighten parity validation/reporting into the blocking validation command.
