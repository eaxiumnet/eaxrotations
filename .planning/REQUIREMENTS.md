# Requirements: EAX TBC Classic Rotations

**Defined:** 2026-03-21
**Milestone:** v1.2 Rotation Reliability
**Core Value:** Every spec executes the mathematically optimal rotation while maintaining survival and encounter-specific awareness.

## v1.2 Requirements

### Restoration Policy

- [ ] **REST-01**: User can run Restoration Druid in grouped content without intentional DPS casts (healing/utility-only policy).
- [ ] **REST-02**: User can run Restoration Druid solo with offensive casts enabled only when safety gates are satisfied.

### Feral Finisher Reliability

- [ ] **FERA-01**: User can run Feral Druid without combo-point spend stalls at high combo points.
- [ ] **FERA-02**: User can run Feral Druid with correct Rip or Ferocious Bite finisher selection by target-state window.

### Validation Evidence

- [ ] **VALD-01**: User can verify Restoration and Feral reliability behavior through repeatable druid scenario checks in validation tooling.

## Future Requirements (Deferred)

### Druid Reliability Enhancements

- **REST-03**: User can tune adaptive solo Restoration DPS aggressiveness based on dynamic risk scoring.
- **FERA-03**: User can recover automatically from combo-point desync/stuck-state anomalies with fail-safe logic.
- **VALD-02**: User can review objective benchmark counters for grouped-hostile cast leakage and feral finisher cadence.

### Cross-Milestone Deferred Infrastructure

- **MATX-01**: Benchmark tooling runs a 27-spec matrix with DPS/HPS/TPS and reactive behavior KPIs.
- **MATX-02**: Matrix outputs include run metadata, variance stats, and real-vs-mock tagging for trustworthy comparisons.
- **MATX-03**: Milestone quality gate passes only when matrix thresholds and regression checks succeed.

## Out of Scope

| Feature | Reason |
|---------|--------|
| Always-on Restoration DPS in grouped content | Violates healer-role reliability goal for this milestone |
| Aggressive powershift or high-risk optimization as first fix | Reliability-first milestone prioritizes deterministic correctness over throughput tuning |
| Per-encounter druid special-case scripts | Deferred until baseline druid reliability is stable and validated |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| REST-01 | Phase 9 | Pending |
| REST-02 | Phase 9 | Pending |
| FERA-01 | Phase 10 | Pending |
| FERA-02 | Phase 10 | Pending |
| VALD-01 | Phase 11 | Pending |

**Coverage:**
- v1.2 requirements: 5 total
- Mapped to phases: 5
- Unmapped: 0

---
*Requirements defined: 2026-03-21*
*Last updated: 2026-03-21 after milestone v1.2 roadmap mapping*
