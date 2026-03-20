# Phase 8: Benchmark Matrix Hardening - Context

**Gathered:** 2026-03-20
**Status:** Ready for planning

<domain>
## Phase Boundary

Phase 8 hardens the benchmark matrix and release gate so milestone quality is judged by trustworthy 27-spec performance and behavior evidence. This phase is about confidence, comparability, and final release-blocking rules on top of the already-built runtime, role telemetry, and validation surface; it does not add new combat behavior capabilities.

</domain>

<decisions>
## Implementation Decisions

### Pass/fail strictness
- The release gate should require all 27 canonical specs to pass.
- A single clear regression in any canonical spec should block the release.
- Behavior KPIs and raw throughput KPIs have equal gate weight in final pass/fail.
- There is no grace margin for near-miss results; under-threshold means fail.
- The final gate should be deterministic and rule-based, not judgment-driven.
- The matrix should still finish and report the full failure picture even when a hard failure appears early.
- The goal is an easy-to-trust gate, not a soft or negotiable one.

### Live-vs-mock evidence
- Dry-run/mock output is only for schema, coverage, and tooling sanity.
- Live benchmark evidence is required for actual pass/fail decisions.
- No live evidence means the matrix cannot pass.

### Variance policy
- A spec with unstable run-to-run results should fail even if one run looks strong.
- Multiple confirming runs are required before a result is trusted.
- Strong peak throughput does not excuse noisy or inconsistent behavior.
- The same variance standard should apply across all 27 specs.

### Matrix presentation
- The final report should emphasize release verdict clarity first.
- When the matrix fails, exact blockers should be the first thing shown.
- The report should optimize for immediate operator readability, with deeper details available after the top verdict.
- Even passing reports should surface near-fail edges so weak specs are not hidden.

### Claude's Discretion
- Exact numeric thresholds for variance and near-fail classification.
- Exact matrix output layout, as long as verdict clarity stays dominant.
- Exact run metadata fields beyond the locked trust/comparison requirements.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Milestone and phase scope
- `.planning/PROJECT.md` — milestone v1.1 goal and strict `@.api` release-quality intent.
- `.planning/REQUIREMENTS.md` — Phase 8 requirement set (`MATX-01`, `MATX-02`, `MATX-03`).
- `.planning/ROADMAP.md` — Phase 8 goal, success criteria, and dependency on Phase 7.
- `.planning/phases/05-reactive-contract-api-gate/05-CONTEXT.md` — locked API hard-gate and validation-surface decisions.
- `.planning/phases/06-27-spec-reactive-wiring/06-CONTEXT.md` — locked parity and adapter validation decisions.
- `.planning/phases/07-role-intelligence-tuning/07-CONTEXT.md` — locked role telemetry and role-quality signal decisions.

### Existing benchmark and validation surface
- `tools/dps_benchmark.lua` — current benchmark runner and output schema starting point.
- `tools/rotation_validation.lua` — existing single blocking validation command that Phase 8 should keep as the release gate surface.
- `eax_shared/dps_meter.lua` — telemetry source for reactive and role-quality fields.

### Existing telemetry/runtime contracts
- `eax_shared/reactive_runtime.lua` — current source of reactive/role telemetry values feeding the benchmark surface.
- `eax_shared/combat_context.lua` — normalized snapshot context underlying comparable runtime signals.

### External Sylvanas references
- `.api/core.lua` — canonical allowed runtime API surface for benchmark/validation scripts that inspect runtime behavior.
- `.api/game_object.lua` — canonical object/unit API surface for any runtime data assumptions.
- `.api/menu.lua` — canonical menu/runtime config API surface where relevant.
- `https://docs.project-sylvanas.net/dev/` — official API/runtime documentation.
- `https://docs.project-sylvanas.net/examples/` — official example patterns for plugin/runtime behavior.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `tools/dps_benchmark.lua`: already emits per-spec dry-run/live rows and is the natural base for a 27-spec matrix runner.
- `tools/rotation_validation.lua`: already acts as the single blocking gate and should remain the unified release check surface.
- `eax_shared/dps_meter.lua`: already stores `reactive_action`, `reason_code`, `reactive_status`, `role_signal`, and `role_target_kind` needed for matrix-level behavior KPIs.

### Established Patterns
- Validation is centralized and deterministic rather than split across many entrypoints.
- Telemetry fields are already normalized in shared code before benchmark export.
- Earlier phases have treated dry-run output as proof of schema/tooling and live output as proof of real behavior; Phase 8 should formalize that distinction.

### Integration Points
- Phase 8 should harden `tools/dps_benchmark.lua` into a true matrix source instead of inventing a separate benchmark pipeline.
- The release verdict should be enforced through `tools/rotation_validation.lua`, not a new side-channel gate.
- Matrix output should consume the existing shared telemetry contract rather than adding per-spec custom reporting paths.

</code_context>

<specifics>
## Specific Ideas

- A real Phase 8 pass means all functionality is 100% strict to `@.api/` and all 27 specs pass the release-quality matrix.
- Live evidence must dominate over dry-run/mock output.
- The matrix should be strict enough that a pass actually means the suite is trustworthy.

</specifics>

<deferred>
## Deferred Ideas

- Any future adaptive thresholding or learning-based scoring remains out of scope for this milestone.
- New combat behavior capabilities are out of scope; Phase 8 is purely about matrix confidence and release gating.

</deferred>

---

*Phase: 08-benchmark-matrix-hardening*
*Context gathered: 2026-03-20*
