# Phase 6: 27-Spec Reactive Wiring - Context

**Gathered:** 2026-03-20
**Status:** Ready for planning

<domain>
## Phase Boundary

Phase 6 wires the shared reactive runtime into all 27 canonical combat specs so every spec consumes the same reactive decision layer through explicit adapter parity. This phase is about safe, deterministic integration of the shared layer into live spec behavior; it does not introduce new reactive capability categories or deeper role tuning beyond the already-defined Phase 5 contract.

</domain>

<decisions>
## Implementation Decisions

### Retarget authority
- High-priority reactive retargeting is allowed when a legal interrupt, save, peel, or other urgent reaction requires it.
- After a reactive retarget action resolves, the system should snap back to the prior main target/intent if it is still valid.
- Autonomous retargeting is justified only for high-priority reactions, not convenience actions or throughput optimization.
- If reactive target choice is ambiguous or risky, the system should fail safe and avoid retargeting.
- Healer specs should immediately prefer urgent save targets over enemy-target continuity when a save reaction wins.
- DPS specs may briefly leave boss focus for truly dangerous add/caster reactions, then snap back.
- Restore only the prior main target/intent in Phase 6, not richer secondary targeting context.
- If a retarget-triggered reaction fails to fire, revert immediately to the prior intent.

### Unsupported action fallback
- If the shared engine requests an action that a spec cannot legally perform, the spec should skip and fail safe rather than guess a substitute.
- Unsupported-action cases must be visible both in validation and in telemetry; they are not silent runtime quirks.
- Adapter parity means every spec must either explicitly support a reactive category or explicitly declare a validated no-op for it.
- Explicit no-op handling must remain safe and non-disruptive at runtime.

### Cast-lane disruption
- The shared reactive layer should interrupt existing per-spec behavior only for clear, high-priority reactive winners.
- Existing casts/queues should be respected unless the reactive winner is truly urgent under the Phase 5 ladder.
- When adapter certainty is weak mid-rotation, Phase 6 should defer to the existing spec lane rather than forcing the shared layer.
- Phase 6 success should feel stable, safe, and non-chaotic before it feels deeply optimized.

### Claude's Discretion
- Exact adapter table shape and helper naming across the 27 specs.
- Exact validation output format for unsupported-action/parity reporting.
- Exact mechanism used to restore prior target/intent after a reactive retarget.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Milestone and phase scope
- `.planning/PROJECT.md` — milestone v1.1 goal, movement-excluded scope, and strict `@.api` requirement.
- `.planning/REQUIREMENTS.md` — Phase 6 requirement set (`WIRE-01`, `WIRE-02`, `WIRE-03`).
- `.planning/ROADMAP.md` — Phase 6 goal, success criteria, and dependency on Phase 5.
- `.planning/phases/05-reactive-contract-api-gate/05-CONTEXT.md` — locked Phase 5 reactive contract decisions that Phase 6 must preserve.

### Existing shared reactive surface
- `eax_shared/reactive_runtime.lua` — current shared runtime bridge and Phase 6 starting point.
- `eax_shared/combat_context.lua` — normalized per-tick snapshot contract introduced in Phase 5.
- `eax_shared/reactive_engine.lua` — one-winner precedence contract and reason-code behavior.
- `eax_shared/dps_meter.lua` — reactive telemetry persistence contract used by current bridge.

### Existing spec integration examples
- `EAXWarriorFury/main.lua` — representative DPS spec using the current visual-lane bridge.
- `EAXPriestHoly/main.lua` — representative healer spec using the current visual-lane bridge.
- `EAXWarriorProtection/main.lua` — representative tank spec using the current reactive telemetry lane.

### Validation and parity tooling
- `tools/rotation_validation.lua` — current blocking validation command that Phase 6 parity checks should extend, not replace.
- `tests/reactive_runtime_wiring_spec.lua` — current parity proof surface and canonical 27-spec list.

### External Sylvanas references
- `https://docs.project-sylvanas.net/dev/` — official developer/API documentation; treat Legacy API behavior as canonical.
- `https://docs.project-sylvanas.net/examples/` — official example plugin patterns and expected script structure.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `eax_shared/reactive_runtime.lua`: already provides the shared per-tick bridge from snapshot to reactive result/telemetry.
- `eax_shared/combat_context.lua`: stable nil-safe snapshot source all specs should keep consuming.
- `eax_shared/reactive_engine.lua`: current one-winner arbitration layer that must remain the single source of reactive precedence.
- `tests/reactive_runtime_wiring_spec.lua`: existing 27-spec parity scaffold for regression coverage.

### Established Patterns
- Shared behavior lives in `eax_shared/*.lua`; spec `main.lua` files stay as orchestration and adapter surfaces.
- Current reactive bridge is already inserted in the visual snapshot/update lane for all specs, so Phase 6 should evolve that wiring rather than inventing a second runtime lane.
- Existing spec files vary in role logic but share a repeated `visual_update_snapshot(...)` / update-callback structure that is the natural integration surface.

### Integration Points
- Phase 6 should turn the current telemetry-only `reactive_runtime.update_tick(...)` wiring into a true adapter contract consumed by every spec.
- Validation should extend the existing parity and blocking validation commands instead of creating parallel checks.
- Representative role-specific integrations should be proven against DPS, healer, and tank spec shapes before bulk rollout assumptions are accepted.

</code_context>

<specifics>
## Specific Ideas

- User wants the full shared reactive layer to behave consistently across all 27 specs, not as 27 unrelated implementations.
- User wants strict fail-safe behavior when a spec cannot legally react or target selection is ambiguous.
- User provided official Project Sylvanas developer docs and examples as canonical guidance for downstream work.

</specifics>

<deferred>
## Deferred Ideas

- Rich live debug presentation of reactive reasons/retarget behavior belongs in a later phase.
- Deeper role-specific reactive tuning belongs to Phase 7, not this wiring phase.

</deferred>

---

*Phase: 06-27-spec-reactive-wiring*
*Context gathered: 2026-03-20*
