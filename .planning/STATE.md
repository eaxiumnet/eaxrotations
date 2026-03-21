---
gsd_state_version: 1.0
milestone: v1.2
milestone_name: Rotation Reliability
status: defining_requirements
stopped_at: Milestone v1.2 started
last_updated: "2026-03-21T00:00:00.000Z"
progress:
  total_phases: 0
  completed_phases: 0
  total_plans: 0
  completed_plans: 0
---

# Project State

## Project Reference

See: `.planning/PROJECT.md` (updated 2026-03-21)

**Core value:** Every spec executes the mathematically optimal rotation while maintaining survival and encounter-specific awareness.
**Current focus:** Milestone v1.2 requirements definition

## Current Position

Phase: Not started (defining requirements)
Plan: -
Status: Defining requirements
Last activity: 2026-03-21 - Milestone v1.2 started

## Accumulated Context

### Decisions

Decisions are logged in PROJECT.md Key Decisions table.
Recent decisions affecting current work:

- [Phase 4]: Validation scope pinned to 27 canonical combat specs.
- [Phase 4]: Benchmark dry-run emits deterministic snapshot rows.
- [Milestone v1.1]: Phase numbering continues from v1.0 (start at Phase 5).
- [Phase 05]: Normalize combat percentages to 0..1 in one shared snapshot — Prevents downstream specs from mixing 0..100 and 0..1 scales across reactive logic.
- [Phase 05]: Return one primary reason code and action id per tick with a short hold buffer — Phase 06 wiring needs deterministic one-winner outputs and brief non-throughput stability.
- [Phase 05]: Expose reactive telemetry in benchmark output first using none/NO_ACTION placeholders — The contract becomes visible before live spec wiring exists, without implying real runtime integration yet.
- [Phase 05]: Generate and commit tools/api_allowlist.lua from repo .api files so validation stays deterministic and local-first.
- [Phase 05]: Keep tools/rotation_validation.lua as the single blocking command and append API gate status after spec validation.
- [Phase 05]: Let reactive_runtime.update_tick own the shared per-tick bridge from normalized context to telemetry persistence.
- [Phase 05]: Keep reactive_action as the canonical benchmark field while falling back to action_id for older snapshots.
- [Phase 05]: Strict hard-gate enforcement applies to documented API namespaces and runtime object receivers, not arbitrary Lua builtins or repo-local helper DSLs.
- [Phase 05]: The authoritative .api surface now includes missing runtime aliases and helper entrypoints so clean validation can pass honestly under the generated allowlist.
- [Phase 05]: Kept reactive_runtime.update_tick in the visual snapshot lane so all specs consume the shared contract without changing cast behavior before Phase 06.
- [Phase 05]: Stored bridge hold data in _visual_runtime.reactive_state for per-spec tick-to-tick carryover without introducing new globals.
- [Phase 05]: Locked reason_code and reactive_action HUD strings out of Phase 05 with a parity regression so live debug UI stays deferred.
- [Phase 06]: Keep reactive winner selection in the shared runtime, but require per-spec adapters to declare explicit handlers or noop=unsupported for all six branches.
- [Phase 06]: Expose reactive_status as handled/noop_unsupported/skipped_unsafe/none so unsupported or unsafe winners stay visible in telemetry and benchmarks.
- [Phase 06]: Let the shared runtime own urgent retarget and snap-back behavior while representative specs only resolve targets and invoke existing cast lanes.
- [Phase 06]: Every canonical spec now declares the same six-key reactive_adapter surface with explicit noop coverage for unsupported categories.
- [Phase 06]: tools/rotation_validation.lua stays the single blocking gate and now prints deterministic per-spec reactive parity lines plus PASS: reactive parity 27/27.
- [Phase 07]: Role-aware branch winners stay inside the existing six-branch reactive contract by routing runtime defaults through eax_shared/role_policy.lua.
- [Phase 07]: combat_context now exposes normalized party, tank, urgent-ally, and cast-victim fields so downstream specs can tune behavior without inventing their own scans.
- [Phase 07]: Keep tank recovery scoring shared
- [Phase 07]: Tank anti_aggro now chooses peel or personals from a shared pressure snapshot
- [Phase 07]: Tank interrupt retargeting reuses shared recovery target selection
- [Phase 07]: Healer specs now consume one shared triage helper, with each adapter building local member snapshots instead of adding new runtime plumbing.
- [Phase 07]: Group stabilization now outranks single-target tank saves when three or more allies are collapsing, so healer cooldowns can prevent wipes instead of tunneling one unit.
- [Phase 07]: Use one shared dps_risk module for hold, drop, and abort thresholds so all DPS specs react consistently.
- [Phase 07]: Build live DPS snapshots from combat_context via dps_runtime instead of duplicating threat and danger reads in each spec.
- [Phase 07]: Keep interrupts aggressive by only gating burst, threat drops, and risky cast commits, not interrupt winners.
- [Phase 07]: Keep tools/rotation_validation.lua as the single blocking gate and extend it with per-family role parity summaries. — Phase 07 needs one deterministic validation surface that fails fast on healer, tank, or DPS regressions instead of splitting checks across multiple scripts.
- [Phase 07]: Store role_signal and role_target_kind in the shared meter so dry-run and live benchmark rows share one telemetry contract. — Phase 08 matrix work needs one normalized source for role-quality telemetry instead of special-casing dry-run output.
- [Runtime fix]: Sylvanas plugin loader resolves `require("eax_shared/...")` relative to each plugin folder, so plugin-local `eax_shared/` bridge files are required when using repo-root shared modules.
- [Runtime fix]: `eax_shared/threat_manager.lua` must expose a safe `init()` because multiple specs call `threat_manager.init(me)` during startup.
- [Phase 08]: Keep matrix verdict math in shared helper modules so benchmark and validation entrypoints reuse one deterministic contract.
- [Phase 08]: Treat mock evidence as schema_only and release-nonpassing while exposing near_fail only as informational pass metadata.
- [Phase 08]: Derive TPS and behavior KPI counters from shared runtime ticks instead of reopening all 27 spec files.
- [Milestone v1.1]: Defer full Phase 8 benchmark-gated sign-off so shipment is not blocked by manual all-spec live capture.

### Pending Todos

None yet.

### Blockers/Concerns

- Healer/tank threshold calibration still needs phase-level tuning strategy during Phase 7 planning.

## Session Continuity

Last session: 2026-03-21T00:50:00.000Z
Stopped at: Milestone v1.2 started (requirements pending)
Resume file: None
