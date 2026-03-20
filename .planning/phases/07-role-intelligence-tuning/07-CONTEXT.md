# Phase 7: Role Intelligence Tuning - Context

**Gathered:** 2026-03-20
**Status:** Ready for planning

<domain>
## Phase Boundary

Phase 7 tunes the shared reactive layer so DPS, healers, and tanks behave with role-correct quality under real encounter pressure. This phase is about decision quality and role personality on top of the already-shipped shared reactive wiring; it does not add movement automation, benchmark-gate policy, or new reactive capability families outside the current Phase 5/6 contract.

</domain>

<decisions>
## Implementation Decisions

### DPS tradeoff policy
- DPS behavior should stay meta-aligned and throughput-first, aiming to stay at the top of the leaderboards whenever possible.
- DPS should sacrifice throughput only for truly wipe-saving moments or self-death-preventing moments.
- Interrupts remain aggressively important even in a throughput-first DPS philosophy.
- DPS should hold major offensives when danger is still unstable enough to make spending them wasteful or dangerous.
- DPS should be preventive when danger signals are clear, but still low-chaos and disciplined rather than timid or over-defensive.
- When danger is clearly rising, DPS should abandon cast/channel commitment earlier instead of greedily finishing it.
- If in doubt between slight extra damage and clearly lower risk, Phase 7 DPS should prefer lower chaos and lower risk only when the lost damage is marginal.
- DPS behavior should feel disciplined and conservative in execution quality, but not weak or overly safety-biased.

### Healer triage policy
- Tank survival is the default first priority.
- Once the tank is stable enough, healer logic should choose the lowest / most urgent ally next.
- Healers should respect incoming heals from others and avoid piling onto already-covered targets unless danger is still real.
- Overheal awareness should push healers toward smarter target/spell choices, but it must never block a clearly stabilizing action.
- Healers should avoid pointless topping when no one is truly threatened.
- Emergency healer cooldowns should be spent early when collapse is clearly likely, not only at the last possible second.
- Healer behavior should be calm, predictive, and deterministic rather than frantic or flashy.
- Safety comes before mana efficiency when the group is at risk, but efficiency should still matter whenever the fight state allows it.
- Healers may sacrifice a likely single-target save if doing so is the better move for preventing total group collapse.

### Tank emergency posture
- Tank behavior should keep aggro on the tank at all times.
- If a friendly pulls aggro, the tank should use available tools to pull that aggro back quickly.
- Aggro recovery/control should usually beat personal defensive use unless self-death is truly imminent.
- Tank behavior should feel like active control of enemy attention, not just self-preservation.
- Tanks should use defensives proactively as pressure rises rather than waiting only for panic moments.
- Tanks should favor orderly pull control and recoverability over greedier offense.
- Tanks should help the party with utility when the pull remains stable enough to do so.
- Tank posture should feel calm, preplanned, and in control.

### Urgency-aware control
- Interrupt/control logic should prioritize wipe risk first.
- When multiple dangerous events exist, control should go to the single most dangerous one rather than being spread thin.
- Fear/control should be used only when the prevented danger is clearly worth any chaos it introduces.
- Control behavior should be predictive when danger is obvious, not purely reactive after the situation already collapses.

### Claude's Discretion
- Exact role-specific scoring/weight formulas for DPS, healer, and tank decision priorities.
- Exact thresholds for when tank is considered "stable enough" and when DPS danger becomes "truly wipe-saving or self-death-preventing".
- Exact mapping of urgency-aware control categories to class/spec-specific spell options.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Milestone and phase scope
- `.planning/PROJECT.md` — milestone v1.1 goal, movement-excluded scope, and product-level priorities.
- `.planning/REQUIREMENTS.md` — Phase 7 requirement set (`ROLE-01`, `ROLE-02`, `ROLE-03`, `ROLE-04`).
- `.planning/ROADMAP.md` — Phase 7 goal, success criteria, and dependency on Phase 6.
- `.planning/phases/05-reactive-contract-api-gate/05-CONTEXT.md` — locked reactive contract decisions that Phase 7 must preserve.
- `.planning/phases/06-27-spec-reactive-wiring/06-CONTEXT.md` — locked adapter/retarget/parity decisions that role tuning must build on.

### Existing shared reactive/runtime surface
- `eax_shared/reactive_runtime.lua` — current shared execution/retarget/restore layer.
- `eax_shared/reactive_engine.lua` — fixed reactive winner selection and reason-code contract.
- `eax_shared/combat_context.lua` — normalized per-tick combat snapshot.
- `eax_shared/dps_meter.lua` — current telemetry contract including reactive action/reason/status.

### Representative role examples
- `EAXMageFire/main.lua` — representative throughput-focused DPS shape for Phase 7 tuning.
- `EAXPriestHoly/main.lua` — representative healer triage and anti-overheal shape.
- `EAXWarriorProtection/main.lua` — representative tank aggro/control posture and urgent interrupt retargeting.

### Validation and parity tools
- `tools/rotation_validation.lua` — existing blocking validation command that role-quality checks should extend rather than replace.
- `tests/reactive_runtime_spec.lua` — runtime execution behavior reference.
- `tests/reactive_runtime_wiring_spec.lua` — canonical 27-spec adapter parity guardrail.

### External Sylvanas references
- `https://docs.project-sylvanas.net/dev/` — official developer/API documentation; Legacy API behavior remains canonical.
- `https://docs.project-sylvanas.net/examples/` — official example patterns and expected plugin structure.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `eax_shared/reactive_runtime.lua`: already owns one-winner execution, retarget/restore behavior, and reactive status telemetry.
- `eax_shared/reactive_engine.lua`: single precedence source that Phase 7 should tune through better role-specific inputs, not replace.
- `EAXPriestHoly/main.lua`: existing healer adapter already demonstrates life-save + anti-overheal behavior.
- `EAXWarriorProtection/main.lua`: existing tank adapter already demonstrates aggro-control and urgent interrupt targeting behavior.
- Current DPS spec adapters already expose the same six-key contract and can be tuned rather than re-architected.

### Established Patterns
- Shared role behavior should continue to live in `eax_shared` or shared adapter helpers, while spec `main.lua` files remain orchestration/adapters.
- The current runtime already supports conservative retargeting and unsafe-skip handling, so Phase 7 should focus on role-quality scoring and adapter decisions instead of plumbing changes.
- Validation remains centralized in `tools/rotation_validation.lua`, which should stay the blocking quality gate.

### Integration Points
- Phase 7 should tune role behavior by improving adapter handlers/decision inputs, not by introducing a second competing reactive runtime.
- DPS, healer, and tank representative specs should serve as first-class tuning anchors before broad role-family rollout assumptions are made.
- Role-quality signals should remain benchmark/telemetry-visible for later Phase 8 matrix gating.

</code_context>

<specifics>
## Specific Ideas

- DPS should stay as meta and leaderboard-focused as possible, only sacrificing damage for truly wipe-saving or self-death-preventing moments.
- Healers should keep the tank alive first, then triage the most urgent remaining ally.
- Tanks should keep aggro at all times and recover threat from allies aggressively.
- Control logic should prioritize the most wipe-relevant threat and only use chaos-causing control when the payoff is worth it.

</specifics>

<deferred>
## Deferred Ideas

- Movement automation remains out of scope for this milestone.
- Rich in-client debug presentation of role reasoning remains a later-phase concern.
- Benchmark threshold locking and matrix policy belong to Phase 8, not this tuning phase.

</deferred>

---

*Phase: 07-role-intelligence-tuning*
*Context gathered: 2026-03-20*
