# Roadmap: EAX TBC Classic Rotations

## Overview

Milestones v1.0 (Phases 1-4) and v1.1 (Phases 5-7, with Phase 8 deferred) are complete enough for shipment goals. This roadmap now defines milestone v1.2 Rotation Reliability as Phases 9-11, focused only on druid reliability outcomes: Restoration role policy correctness, Feral finisher reliability, and repeatable validation evidence.

## Milestones

- **v1.0 MVP** - Phases 1-4 (shipped)
- **v1.1 Combat Intelligence** - Phases 5-7 (ready to close)
- **v1.2 Rotation Reliability** - Phases 9-11 (in planning)
- **Future / Deferred** - Phase 8 benchmark-matrix hardening and post-v1.2 reliability enhancements

## Phases

- [x] **Phase 5: Reactive Contract + API Gate** - Establish deterministic context, reasoned decisions, and fail-closed `@.api` enforcement.
- [x] **Phase 6: 27-Spec Reactive Wiring** - Integrate the shared reactive engine into every canonical combat spec.
- [x] **Phase 7: Role Intelligence Tuning** - Deliver DPS, healer, and tank behavior quality with urgency-aware control logic.
- [ ] **Phase 8: Benchmark Matrix Hardening** - Deferred from v1.1; preserve as future release-quality infrastructure.
- [ ] **Phase 9: Restoration Role Policy Reliability** - Ensure Restoration behavior is role-correct in grouped and solo contexts.
- [ ] **Phase 10: Feral Finisher Reliability** - Ensure Feral spends combo points reliably with correct finisher choice timing.
- [ ] **Phase 11: Druid Reliability Evidence Gate** - Prove Restoration/Feral reliability via repeatable validation evidence.

## Phase Details

### Phase 5: Reactive Contract + API Gate
**Goal**: Users get deterministic reactive behavior decisions backed by normalized combat context and strict `@.api`-only validation.
**Depends on**: Phase 4
**Requirements**: REACT-01, REACT-02, REACT-03, APIG-01, APIG-02, APIG-03
**Success Criteria** (what must be TRUE):
  1. Runtime decisions across specs are driven from one normalized combat snapshot per tick with stable nil-safe fields.
  2. Reactive actions consistently follow one observable precedence ladder (life-save first, then control, then safety, then throughput).
  3. Validation runs fail immediately when non-`@.api` calls are introduced in behavior code.
  4. Validation/release checks block milestone sign-off until API hard-gate compliance passes.
**Plans**: 5 plans

Plans:
- [x] 05-reactive-contract-api-gate-01-PLAN.md - Create the shared combat snapshot and deterministic reactive decision contract.
- [x] 05-reactive-contract-api-gate-02-PLAN.md - Add generated API allowlist enforcement and wire it into the blocking validation flow.
- [x] 05-reactive-contract-api-gate-03-PLAN.md - Add the shared runtime telemetry bridge and align benchmark live rows to runtime reactive telemetry.
- [x] 05-reactive-contract-api-gate-04-PLAN.md - Close the strict API hard-gate gap with allowlist-backed rooted and method enforcement.
- [x] 05-reactive-contract-api-gate-05-PLAN.md - Wire the shared reactive runtime into all 27 canonical specs and lock parity coverage.

### Phase 6: 27-Spec Reactive Wiring
**Goal**: Users can run any of the 27 specs with the same shared reactive decision layer active and adapter parity enforced.
**Depends on**: Phase 5
**Requirements**: WIRE-01, WIRE-02, WIRE-03
**Success Criteria** (what must be TRUE):
  1. Every canonical combat spec executes through the shared reactive engine without breaking existing cast lanes.
  2. Each spec exposes the required adapter contract so shared reactive actions resolve correctly for that spec.
  3. Coverage checks produce an explicit 27-spec pass/fail parity report with no missing wiring.
**Plans**: 2 plans

Plans:
- [x] 06-27-spec-reactive-wiring-01-PLAN.md - Extend the shared runtime into a real adapter executor with noop telemetry and representative role proofs.
- [x] 06-27-spec-reactive-wiring-02-PLAN.md - Roll the adapter contract across all 27 specs and enforce blocking reactive parity validation.

### Phase 7: Role Intelligence Tuning
**Goal**: Users observe role-correct reactive behavior quality for DPS, healers, and tanks under encounter pressure.
**Depends on**: Phase 6
**Requirements**: ROLE-01, ROLE-02, ROLE-03, ROLE-04
**Success Criteria** (what must be TRUE):
  1. DPS specs visibly trade throughput for survival/threat safety when incoming danger or threat windows demand it.
  2. Healer specs prioritize effective healing targets using incoming-heal and overheal-aware triage.
  3. Tank specs react to spike damage and threat instability with timely defensive and utility usage.
  4. Interrupt/fear/control decisions prioritize dangerous casts by urgency and encounter context instead of static ordering.
**Plans**: 5 plans

Plans:
- [x] 07-role-intelligence-tuning-01-PLAN.md - Build the shared role-policy contract and richer normalized snapshot inputs.
- [x] 07-role-intelligence-tuning-02-PLAN.md - Roll shared tank-first triage and anti-overheal logic into all healer specs.
- [x] 07-role-intelligence-tuning-03-PLAN.md - Roll shared threat-recovery and proactive defensive posture into all tank specs.
- [x] 07-role-intelligence-tuning-04-PLAN.md - Roll shared DPS danger-window burst holds and cast-abort logic into all non-healer DPS specs.
- [x] 07-role-intelligence-tuning-05-PLAN.md - Add blocking role-parity validation and benchmark-visible role-quality telemetry.

### Phase 8: Benchmark Matrix Hardening
**Goal**: Future milestone infrastructure: users can trust release quality because benchmark gates require passing 27-spec performance and behavior KPIs.
**Depends on**: Phase 7
**Requirements**: MATX-01, MATX-02, MATX-03
**Success Criteria** (what must be TRUE):
  1. Benchmark runs emit a complete 27-spec matrix covering DPS/HPS/TPS plus reactive behavior KPIs.
  2. Matrix outputs include run metadata, variance stats, and real-vs-mock tagging suitable for apples-to-apples comparisons.
  3. Milestone quality gate passes only when thresholds and regression checks succeed across the matrix.
**Plans**: 3 plans (deferred)

Plans:
- [ ] 08-benchmark-matrix-hardening-01-PLAN.md - Define the shared matrix verdict contract and persist throughput/behavior KPI counters.
- [ ] 08-benchmark-matrix-hardening-02-PLAN.md - Upgrade `tools/dps_benchmark.lua` into the 27-spec matrix runner and capture the approved live baseline.
- [ ] 08-benchmark-matrix-hardening-03-PLAN.md - Make `tools/rotation_validation.lua` block on the benchmark matrix release gate.

### Phase 9: Restoration Role Policy Reliability
**Goal**: Users can run Restoration Druid with deterministic role-correct behavior that never leaks intentional DPS in grouped healer contexts while still allowing safe solo offense.
**Depends on**: Phase 7
**Requirements**: REST-01, REST-02
**Success Criteria** (what must be TRUE):
  1. User can run Restoration Druid in party/raid/dungeon/raid-boss contexts without intentional hostile DPS casts.
  2. User can observe Restoration Druid continue healing/utility behavior normally in grouped content while DPS branches remain suppressed.
  3. User can run Restoration Druid solo and see offensive casts only when configured safety gates (health/mana/threat/emergency state) are satisfied.
**Plans**: TBD

### Phase 10: Feral Finisher Reliability
**Goal**: Users can run Feral Druid with consistent combo-point spending and correct Rip/Ferocious Bite finisher selection under live combat pacing.
**Depends on**: Phase 9
**Requirements**: FERA-01, FERA-02
**Success Criteria** (what must be TRUE):
  1. User can run Feral Druid through sustained combat without repeated high-combo-point stalls.
  2. User can observe Feral spend combo points before overcap when spend conditions are met.
  3. User can observe Rip or Ferocious Bite chosen according to target-state window rather than arbitrary or stale selection.
**Plans**: TBD

### Phase 11: Druid Reliability Evidence Gate
**Goal**: Users can verify milestone reliability outcomes for Restoration and Feral through repeatable scenario checks before v1.2 close.
**Depends on**: Phase 10
**Requirements**: VALD-01
**Success Criteria** (what must be TRUE):
  1. User can run a repeatable druid validation scenario set and get explicit pass/fail outcomes for Restoration grouped-role lock and solo-safe DPS behavior.
  2. User can run repeatable feral finisher reliability checks and confirm combo-point spend cadence remains stable across repeated runs.
  3. User can use validation tooling outputs as milestone-close evidence instead of one-off manual spot checks.
**Plans**: TBD

## Progress

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 5. Reactive Contract + API Gate | 5/5 | Complete | 2026-03-20 |
| 6. 27-Spec Reactive Wiring | 2/2 | Complete | 2026-03-20 |
| 7. Role Intelligence Tuning | 5/5 | Complete | 2026-03-20 |
| 8. Benchmark Matrix Hardening | Deferred | Deferred | - |
| 9. Restoration Role Policy Reliability | 0/TBD | Not started | - |
| 10. Feral Finisher Reliability | 0/TBD | Not started | - |
| 11. Druid Reliability Evidence Gate | 0/TBD | Not started | - |

---
*Roadmap updated: 2026-03-21 for milestone v1.2 roadmap creation (phases 9-11)*
