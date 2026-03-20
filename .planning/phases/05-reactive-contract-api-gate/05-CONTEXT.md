# Phase 5: Reactive Contract + API Gate - Context

**Gathered:** 2026-03-20
**Status:** Ready for planning

<domain>
## Phase Boundary

Phase 5 establishes the shared reactive foundation for v1.1: a normalized combat context, a deterministic reactive decision ladder, and strict `@.api`-only validation gates. This phase defines how reactive decisions are represented and enforced; it does not add movement automation or deep per-role tuning beyond the shared contract.

</domain>

<decisions>
## Implementation Decisions

### Decision ladder
- Survival always wins over throughput. If a reactive safety condition trips, normal output should pause immediately rather than finishing throughput-first behavior.
- DPS specs should preempt for group protection, not just self-preservation. Interrupts, emergency utility, peels, threat drops, and group-saving tools are allowed to outrank personal DPS.
- Reactive arbitration should select a single highest-priority action per tick/GCD. No stacked multi-reaction chains should occur inside the same decision step.
- Returning from danger to throughput should use a short stability buffer so the engine does not oscillate between panic behavior and normal rotation.

### API hard gate
- Non-`@.api` runtime behavior calls should hard-fail immediately with no temporary waiver path in Phase 5.
- The API hard gate should run on every validation run, not just at release time.
- Violations should be reported with precise file and offending-call details so fixes are immediate.
- Phase 5 gate scope is runtime behavior code only; docs, generated planning artifacts, and non-runtime scripts are not the initial blocker surface.

### Reason visibility
- Reactive reasons should be surfaced primarily in validation and benchmark outputs first, not as a Phase 5 in-client UX feature.
- Reasons should use short structured reason codes instead of long sentence explanations.
- Each action should record only the primary winning reason, not a full stack of supporting reasons.
- Reason codes should be designed so future phases can expose them in optional in-client debug views if needed.

### Context freshness
- The normalized combat snapshot should prefer a stable/coherent view over ultra-fresh but flickery reads.
- Danger-related signals should bias toward caution when uncertain.
- If snapshot data becomes stale or incomplete, the engine should fail safe rather than guessing.
- Throughput signals can use the stable snapshot cadence, but danger signals should cut through faster than normal low-risk optimization inputs.

### Claude's Discretion
- Exact naming format for reason codes.
- Exact buffer duration values for stability windows and stale-context handling.
- Exact internal module split between combat context, reactive engine, and validation helpers.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Milestone and phase requirements
- `.planning/PROJECT.md` — milestone v1.1 goal, hard constraints, and movement-excluded scope.
- `.planning/REQUIREMENTS.md` — Phase 5 requirement set (`REACT-01..03`, `APIG-01..03`).
- `.planning/ROADMAP.md` — Phase 5 boundary, ordering, and success criteria.

### Existing runtime and validation surface
- `tools/rotation_validation.lua` — current validation entrypoint that the API hard gate must integrate into.
- `tools/dps_benchmark.lua` — existing benchmark/reporting baseline that reason visibility should feed first.
- `eax_shared/threat_manager.lua` — example shared runtime module with caching/safety patterns relevant to context freshness.
- `eax_shared/interrupt_manager.lua` — existing priority-based reactive behavior reference.
- `eax_shared/defensive_manager.lua` — existing defensive preemption reference.

### Allowed API surface
- `.api/core.lua` — canonical core callback/runtime API surface.
- `.api/game_object.lua` — canonical unit/object state surface, including incoming-heal and combat signal accessors.

### External Sylvanas references
- `https://docs.project-sylvanas.net/dev/` — official developer/API documentation; treat Legacy API behavior as canonical for this phase.
- `https://docs.project-sylvanas.net/examples/` — official example patterns for plugin structure and API usage; use as style/reference guidance, not as scope expansion.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `eax_shared/interrupt_manager.lua`: existing priority/preemption behavior that can inform the reactive ladder.
- `eax_shared/defensive_manager.lua`: existing defensive thresholds and shared response patterns.
- `eax_shared/threat_manager.lua`: threat/safety module already using cached reads and fail-safe guards.
- `tools/rotation_validation.lua`: current repo-wide validation command that should become the first hard-gate enforcement point.
- `tools/dps_benchmark.lua`: existing benchmark entrypoint where structured reason outputs can be consumed first.

### Established Patterns
- Shared cross-spec behavior lives in `eax_shared/*.lua`, while spec `main.lua` files stay as orchestration/adapters.
- Existing validation relies on simple Lua tooling and file scanning rather than external dependencies.
- The codebase already uses cautious wrappers (`pcall`, caching, nil guards) in shared modules, which fits the stable/fail-safe snapshot decision.

### Integration Points
- Phase 5 should connect the new reactive contract to shared managers first, then expose adapter expectations for later Phase 6 rollout.
- API hard-gate logic should plug into `tools/rotation_validation.lua` rather than creating a separate release-only path.
- Reason-code output should flow into validation/benchmark artifacts before any future in-client debug presentation.

</code_context>

<specifics>
## Specific Ideas

- User wants full combat automation except movement, with smart raid/dungeon response behavior.
- User explicitly wants strict `@.api` usage only.
- User provided official Sylvanas developer docs and examples as canonical references to follow.

</specifics>

<deferred>
## Deferred Ideas

- In-client live debug presentation of reactive reason codes — possible later phase, not required for Phase 5.
- Deep encounter-specific predictive tuning belongs to later milestone phases, not this contract phase.

</deferred>

---

*Phase: 05-reactive-contract-api-gate*
*Context gathered: 2026-03-20*
