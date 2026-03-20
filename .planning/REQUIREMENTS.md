# Requirements: EAX TBC Classic Rotations

**Defined:** 2026-03-20
**Milestone:** v1.1 Combat Intelligence
**Core Value:** Every spec executes the mathematically optimal rotation while maintaining survival and encounter-specific awareness.

## v1.1 Requirements

### Reactive Contract + Context

- [ ] **REACT-01**: System produces a normalized combat context snapshot each tick (self, target, party, encounter) with nil-safe defaults.
- [ ] **REACT-02**: System enforces a deterministic decision ladder (life-save > interrupt/control > anti-overheal/anti-aggro > throughput).
- [ ] **REACT-03**: Every reactive action emits a reason code for telemetry and debugging.

### API Hard Gate

- [ ] **APIG-01**: Validation fails when non-`@.api` calls are detected in runtime behavior code.
- [ ] **APIG-02**: API allowlist is generated/maintained from current `.api` surface and used as a fail-closed gate.
- [ ] **APIG-03**: Release/validation workflow blocks milestone sign-off when API-hard-gate checks fail.

### 27-Spec Reactive Wiring

- [ ] **WIRE-01**: Shared reactive engine is integrated into all 27 canonical combat specs without breaking existing cast lanes.
- [ ] **WIRE-02**: All specs implement adapter contracts for shared reactive decisions while preserving movement-excluded behavior.
- [ ] **WIRE-03**: Cross-spec wiring parity checks report pass/fail coverage for all 27 specs.

### Role Intelligence Tuning

- [ ] **ROLE-01**: DPS behavior reacts to incoming damage/threat and encounter windows with defensive/offensive cooldown timing.
- [ ] **ROLE-02**: Healer behavior uses incoming-heal and overheal-aware triage to prioritize effective healing.
- [ ] **ROLE-03**: Tank behavior responds to spike damage, incoming heals, and threat stability with defensive and utility timing.
- [ ] **ROLE-04**: Interrupt/fear/control utility uses urgency-aware logic based on cast danger, role context, and encounter policy.

### Benchmark Matrix Hardening

- [ ] **MATX-01**: Benchmark tooling runs a 27-spec matrix with DPS/HPS/TPS and reactive behavior KPIs.
- [ ] **MATX-02**: Matrix outputs include run metadata, variance stats, and real-vs-mock tagging for trustworthy comparisons.
- [ ] **MATX-03**: Milestone quality gate passes only when matrix thresholds and regression checks succeed.

## Future Requirements (Deferred)

- **FUT-01**: Encounter-specific predictive behavior packs beyond baseline parity (boss-by-boss advanced scripts).
- **FUT-02**: Adaptive threshold learning from historical encounter logs.
- **FUT-03**: User-facing policy editor for reactive behavior profiles.

## Out of Scope

| Feature | Reason |
|---------|--------|
| Movement/pathing automation | User explicitly keeps movement manual for this milestone |
| PvP behavior engine | Milestone is PvE combat-intelligence focused |
| Expansion support beyond TBC | Product scope remains TBC only |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| REACT-01 | Unmapped | Pending |
| REACT-02 | Unmapped | Pending |
| REACT-03 | Unmapped | Pending |
| APIG-01 | Unmapped | Pending |
| APIG-02 | Unmapped | Pending |
| APIG-03 | Unmapped | Pending |
| WIRE-01 | Unmapped | Pending |
| WIRE-02 | Unmapped | Pending |
| WIRE-03 | Unmapped | Pending |
| ROLE-01 | Unmapped | Pending |
| ROLE-02 | Unmapped | Pending |
| ROLE-03 | Unmapped | Pending |
| ROLE-04 | Unmapped | Pending |
| MATX-01 | Unmapped | Pending |
| MATX-02 | Unmapped | Pending |
| MATX-03 | Unmapped | Pending |

**Coverage:**
- v1.1 requirements: 16 total
- Mapped to phases: 0
- Unmapped: 16 ⚠

---
*Requirements defined: 2026-03-20*
*Last updated: 2026-03-20 after milestone v1.1 definition*
