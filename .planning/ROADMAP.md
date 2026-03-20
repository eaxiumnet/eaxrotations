# Roadmap: EAX TBC Classic Rotations

## Overview

Milestone v1.0 (Phases 1-4) is complete. This roadmap defines milestone v1.1 Combat Intelligence as Phases 5-8, focused on shared reactive contracts, strict API compliance, full 27-spec integration, role-aware behavior quality, and benchmark-gated sign-off.

## Milestones

- **v1.0 MVP** - Phases 1-4 (shipped)
- **v1.1 Combat Intelligence** - Phases 5-8 (planned)

## Phases

- [x] **Phase 5: Reactive Contract + API Gate** - Establish deterministic context, reasoned decisions, and fail-closed `@.api` enforcement.
- [ ] **Phase 6: 27-Spec Reactive Wiring** - Integrate the shared reactive engine into every canonical combat spec.
- [ ] **Phase 7: Role Intelligence Tuning** - Deliver DPS, healer, and tank behavior quality with urgency-aware control logic.
- [ ] **Phase 8: Benchmark Matrix Hardening** - Enforce 27-spec KPI/variance matrix gates for milestone sign-off.

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
**Plans**: 2 plans

Plans:
- [x] 05-reactive-contract-api-gate-01-PLAN.md - Create the shared combat snapshot and deterministic reactive decision contract.
- [x] 05-reactive-contract-api-gate-02-PLAN.md - Add generated API allowlist enforcement and wire it into the blocking validation flow.

### Phase 6: 27-Spec Reactive Wiring
**Goal**: Users can run any of the 27 specs with the same shared reactive decision layer active and adapter parity enforced.
**Depends on**: Phase 5
**Requirements**: WIRE-01, WIRE-02, WIRE-03
**Success Criteria** (what must be TRUE):
  1. Every canonical combat spec executes through the shared reactive engine without breaking existing cast lanes.
  2. Each spec exposes the required adapter contract so shared reactive actions resolve correctly for that spec.
  3. Coverage checks produce an explicit 27-spec pass/fail parity report with no missing wiring.
**Plans**: TBD

### Phase 7: Role Intelligence Tuning
**Goal**: Users observe role-correct reactive behavior quality for DPS, healers, and tanks under encounter pressure.
**Depends on**: Phase 6
**Requirements**: ROLE-01, ROLE-02, ROLE-03, ROLE-04
**Success Criteria** (what must be TRUE):
  1. DPS specs visibly trade throughput for survival/threat safety when incoming danger or threat windows demand it.
  2. Healer specs prioritize effective healing targets using incoming-heal and overheal-aware triage.
  3. Tank specs react to spike damage and threat instability with timely defensive and utility usage.
  4. Interrupt/fear/control decisions prioritize dangerous casts by urgency and encounter context instead of static ordering.
**Plans**: TBD

### Phase 8: Benchmark Matrix Hardening
**Goal**: Users can trust milestone quality because release gates require passing 27-spec performance and behavior KPIs.
**Depends on**: Phase 7
**Requirements**: MATX-01, MATX-02, MATX-03
**Success Criteria** (what must be TRUE):
  1. Benchmark runs emit a complete 27-spec matrix covering DPS/HPS/TPS plus reactive behavior KPIs.
  2. Matrix outputs include run metadata, variance stats, and real-vs-mock tagging suitable for apples-to-apples comparisons.
  3. Milestone quality gate passes only when thresholds and regression checks succeed across the matrix.
**Plans**: TBD

## Progress

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 5. Reactive Contract + API Gate | 2/2 | Complete | 2026-03-20 |
| 6. 27-Spec Reactive Wiring | 0/TBD | Not started | - |
| 7. Role Intelligence Tuning | 0/TBD | Not started | - |
| 8. Benchmark Matrix Hardening | 0/TBD | Not started | - |

---
*Roadmap updated: 2026-03-20 for milestone v1.1 Combat Intelligence*
