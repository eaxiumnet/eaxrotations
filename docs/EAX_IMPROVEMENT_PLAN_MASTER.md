# EAX Improvement Plan - MASTER INDEX & CONSOLIDATION

**Document Version**: 1.0  
**Created**: April 10, 2026  
**Status**: Planning Complete - Ready for Execution  
**Total Documentation**: ~4,000 lines across 9 documents  

---

## TABLE OF CONTENTS

1. [Executive Summary](#executive-summary)
2. [Document Inventory](#document-inventory)
3. [Quick Reference](#quick-reference)
4. [Project Overview](#project-overview)
5. [Phase Summary](#phase-summary)
6. [Decision Matrix](#decision-matrix)
7. [Risk & Mitigation Summary](#risk--mitigation-summary)
8. [Team Structure](#team-structure)
9. [Success Metrics](#success-metrics)
10. [Next Steps](#next-steps)
11. [Document Locations](#document-locations)

---

## EXECUTIVE SUMMARY

### Project Identity

| Attribute | Value |
|-----------|-------|
| **Original Request** | Improve 29 EAX rotation specs using wowsims/tbc as reference |
| **Current State** | 29 specs × 30-35 libraries = ~870 files with 81.6% average quality |
| **Target State** | wowsims/tbc-level simulation accuracy, 93%+ quality score |
| **Planning Duration** | Multi-day comprehensive analysis |
| **Total Documentation** | ~4,000 lines across 9 planning documents |
| **Timeline** | 30 weeks (revised from original 15 weeks) |
| **Team Size** | 8 people across 4 work streams |
| **Estimated Reduction** | 92.1% file reduction (912 → 72 files) |

### Key Achievements in Planning

✅ **Concrete wowsims patterns identified** - 14 specific rotation patterns from rotation.go files  
✅ **Validated file audit completed** - 912 files mapped, 95.4% reduction confirmed  
✅ **Flux integration specifications** - Complete APL/MCD/Simulation architecture  
✅ **Baseline quality metrics** - 81.6% current quality with 29 specific improvement checklists  
✅ **wowsims validation methods** - 5 concrete methods for extracting reference DPS data  
✅ **Comprehensive test plan** - 25 test cases for validation  

### Impact Projections

| Metric | Current | Target | Improvement |
|--------|---------|--------|---------------|
| Average Quality Score | 81.6% | 93%+ | +11.4% |
| Library Files | 870 | 72 | -92.1% |
| Test Coverage | ~5% | >60% | +55% |
| DPS Accuracy | Unknown | Within 5% of wowsims | Baseline established |
| Rotation Decision Time | Variable | <5ms | Performance guaranteed |

---

## DOCUMENT INVENTORY

### Core Planning Documents

| # | Document | Lines | Path | Purpose |
|---|----------|-------|------|---------|
| 1 | EAX_IMPROVEMENT_PLAN.md | 953 | `C:\newbot\scripts\docs\EAX_IMPROVEMENT_PLAN.md` | Original 5-phase roadmap with work units |
| 2 | EAX_IMPROVEMENT_PLAN_SUPPLEMENT.md | 322 | `C:\newbot\scripts\docs\EAX_IMPROVEMENT_PLAN_SUPPLEMENT.md` | Oracle critique responses and technical deep-dives |
| 3 | EAX_IMPROVEMENT_PLAN_FINAL.md | 1,657 | `C:\newbot\scripts\docs\EAX_IMPROVEMENT_PLAN_FINAL.md` | Complete technical spec with all 29 spec checklists |
| 4 | Wowsims_To_EAX_Code_Mappings.md | 749 | `C:\newbot\Wowsims_To_EAX_Code_Mappings.md` | 5 concrete code transformation examples |
| 5 | FLUX_MIGRATION_EXAMPLES.lua | 883 | `C:\newbot\scripts\FLUX_MIGRATION_EXAMPLES.lua` | 3 migration examples (EAX → Flux) |
| 6 | EAX_TEST_SPECIFICATIONS.md | 1,534 | `C:\newbot\scripts\docs\EAX_TEST_SPECIFICATIONS.md` | 25 detailed test cases with wowsims baselines |

### Embedded Planning Content

| # | Content | Location | Details |
|---|---------|----------|---------|
| 7 | Resource Plan & Team Assignments | EAX_IMPROVEMENT_PLAN.md (lines 700-725) | 4 work streams, 8 people |
| 8 | Integration Test Plan | EAX_TEST_SPECIFICATIONS.md (lines 1486-1510) | 10 integration scenarios |
| 9 | Risk Contingencies | EAX_IMPROVEMENT_PLAN_FINAL.md (lines 1509-1540) | 5 major risks with mitigations |

**Total**: 9 document sources covering all aspects of the improvement plan

---

## QUICK REFERENCE

### Key Numbers

| Metric | Value | Reference |
|--------|-------|-----------|
| **Specs to Improve** | 29 | All TBC classes/specs |
| **wowsims Patterns** | 14 | From rotation.go analysis |
| **File Reduction** | 92.1% | 912 → 72 files |
| **Test Cases** | 25 | TEST-001 through TEST-025 |
| **Integration Scenarios** | 10 | See test specifications |
| **Risk Categories** | 5 | With detailed mitigations |
| **Quality Items** | 29 | One per spec |
| **Improvement Potential** | +11.4% | Average quality gain |

### Critical Success Factors

1. **Testing Infrastructure** - Must complete Phase 1 before any migration
2. **Shared Library Architecture** - Foundation for 92.1% file reduction
3. **APL System** - Enables wowsims-accurate rotations
4. **Simulation Mode** - Validates DPS accuracy against reference
5. **Feature Flags** - Enables safe gradual rollout

### Priority Actions

**Week 1-3 (Phase 1: Foundation)**:
- Set up test framework infrastructure
- Extract 6 core shared libraries
- Migrate 3 pilot specs
- Establish performance benchmarks

**Week 4-6 (Phase 2: Standardization)**:
- Roll out shared libraries to all 29 specs
- Implement APL parser (95% SimC support)
- Achieve >60% test coverage

**Week 7-12 (Phase 3: Advanced Engine)**:
- Deploy MajorCooldown system
- Enable simulation mode
- Implement multi-target AoE logic

---

## PROJECT OVERVIEW

### Scope

**In Scope**:
- 29 EAX TBC Classic rotation specs
- Shared library consolidation (92.1% reduction)
- APL (Action Priority List) system implementation
- MajorCooldown optimization system
- Simulation mode for offline validation
- Stat weight calculator
- Gear comparison system
- DPS reporting dashboard
- Haste breakpoint calculator
- Encounter-specific rotation scripts

**Out of Scope**:
- WotLK/Cata spell additions (TBC-only)
- External platform API integration
- Third-party addon compatibility
- Non-TBC content

### Timeline

```
Phase 1: Foundation (Weeks 1-6)
├── Test Framework Infrastructure
├── Shared Library Extraction (Core)
├── Shared Library Extraction (Managers)
└── 3 Pilot Spec Migrations

Phase 2: Standardization (Weeks 7-12)
├── Shared Library Rollout (29 specs)
├── APL System Implementation
├── Test Coverage Expansion
└── Drift Detection System

Phase 3: Advanced Engine (Weeks 13-20)
├── MajorCooldown System
├── Simulation Mode
├── Multi-Target AoE Logic
└── Performance Optimization

Phase 4: Optimization Tools (Weeks 21-26)
├── Stat Weight Calculator
├── Gear Comparison System
└── DPS Reporting Dashboard

Phase 5: Advanced Features (Weeks 27-30)
├── Haste Breakpoint Calculator
├── Encounter Scripts
└── Final Documentation & Training
```

### Parallel Work Streams

| Stream | Phases | Focus | Duration | Dependencies |
|--------|--------|-------|----------|--------------|
| **A: Infrastructure** | 1-2 | Testing + Shared Libraries | 6 weeks | None |
| **B: Engine** | 2-3 | APL + MCD + AoE | 6 weeks | Stream A Week 2 |
| **C: Simulation** | 3-4 | Simulation + Optimization | 6 weeks | Stream B Week 4 |
| **D: Polish** | 5 | Haste + Encounters + Docs | 3 weeks | Streams A, B, C |

---

## PHASE SUMMARY

### Phase 1: Foundation (Weeks 1-6)

**Theme**: Testing Infrastructure + Shared Library Extraction  
**Goal**: Establish foundation for all subsequent work

| Work Unit | Category | Deliverables | Success Criteria |
|-----------|----------|--------------|------------------|
| 1.1 | Test Framework | `tests/` directory, Busted config, WoWAPIMock.lua, CI workflow | `busted tests/` → 0 failures, >30% coverage |
| 1.2 | Shared Libs (Core) | `shared/libraries/` directory, 6 core libraries extracted | 3 pilot specs using shared libs |
| 1.3 | Shared Libs (Managers) | Manager libraries extracted to shared | 5 pilot specs using shared libs |

**Exit Criteria**:
- [ ] Test framework operational
- [ ] 6 core libraries in `shared/libraries/core/`
- [ ] 3 pilot specs migrated
- [ ] Performance benchmarks established

### Phase 2: Standardization (Weeks 7-12)

**Theme**: Complete Shared Library Rollout + APL System  
**Goal**: Standardize all 29 specs on shared infrastructure

| Work Unit | Category | Deliverables | Success Criteria |
|-----------|----------|--------------|------------------|
| 2.1 | Shared Lib Rollout | All 29 specs using shared libraries | 100% migration, 92.1% file reduction |
| 2.2 | APL System | `shared/apl/` parser and compiler | 95% SimC syntax support |
| 2.3 | Test Coverage | Expand tests to all specs | >60% coverage overall |

**Exit Criteria**:
- [ ] 29/29 specs on shared libraries
- [ ] APL parser handles 95% of SimC syntax
- [ ] >60% test coverage
- [ ] Drift detection operational

### Phase 3: Advanced Engine (Weeks 13-20)

**Theme**: MajorCooldown System + Simulation Mode + AoE Logic  
**Goal**: Implement advanced rotation features

| Work Unit | Category | Deliverables | Success Criteria |
|-----------|----------|--------------|------------------|
| 3.1 | MCD System | `shared/cooldowns/major_cd.lua` | Improves DPS by >3% |
| 3.2 | Simulation Mode | Offline simulation engine | DPS within 10% of wowsims |
| 3.3 | AoE Logic | Multi-target rotation system | Target counting accurate |

**Exit Criteria**:
- [ ] MCD system improves DPS by >3%
- [ ] Simulation DPS within 10% of wowsims
- [ ] <5ms rotation decision time
- [ ] 5 specs enhanced with AoE logic

### Phase 4: Optimization Tools (Weeks 21-26)

**Theme**: Stat Weights + Gear Comparison + DPS Reporting  
**Goal**: Provide optimization tools for players

| Work Unit | Category | Deliverables | Success Criteria |
|-----------|----------|--------------|------------------|
| 4.1 | Stat Weights | `shared/optimization/stat_weights.lua` | Within 15% of wowsims |
| 4.2 | Gear Comparison | Gear comparison system | Functional for all specs |
| 4.3 | DPS Reporting | Enhanced dashboard | Real-time DPS estimation |

**Exit Criteria**:
- [ ] Stat weights within 15% of wowsims
- [ ] Gear comparison functional
- [ ] Pawn/TSM export verified
- [ ] 5+ community testers validated

### Phase 5: Advanced Features (Weeks 27-30)

**Theme**: Haste Breakpoints + Encounter Scripts + Documentation  
**Goal**: Complete advanced features and documentation

| Work Unit | Category | Deliverables | Success Criteria |
|-----------|----------|--------------|------------------|
| 5.1 | Haste Breakpoints | `shared/optimization/haste_breakpoints.lua` | Accurate for 3 caster specs |
| 5.2 | Encounter Scripts | `shared/encounters/` with phase detection | 3+ encounters supported |
| 5.3 | Documentation | Complete API docs, migration guide, training | New contributor can onboard |

**Exit Criteria**:
- [ ] 3 caster specs with haste breakpoints
- [ ] 3+ encounter scripts working
- [ ] Complete documentation
- [ ] All 29 quality scores ≥ 93%

---

## DECISION MATRIX

### Go/No-Go Criteria by Phase

| Phase | Go Criteria | No-Go Triggers | Decision Authority |
|-------|-------------|----------------|-------------------|
| **Phase 1** | Test framework runs, 3 pilot specs migrated | >3 critical bugs in test framework | Tech Lead |
| **Phase 2** | 100% specs on shared libs, >60% coverage | >5 specs with shared lib issues | Tech Lead |
| **Phase 3** | MCD improves DPS >3%, simulation within 10% | Simulation variance >15% | Product Owner |
| **Phase 4** | Stat weights within 15%, gear comparison works | Export formats incompatible | Product Owner |
| **Phase 5** | All quality ≥93%, docs complete | <25 specs at 93% quality | Executive |

### Exit Criteria for Project

**MUST HAVE** (All required for project completion):
- [ ] All 29 specs quality score ≥93%
- [ ] 92.1% file reduction achieved (870→72 files)
- [ ] >60% test coverage across all specs
- [ ] DPS simulation within 10% of wowsims reference
- [ ] Complete documentation and migration guide

**SHOULD HAVE** (Important but not blocking):
- [ ] <5ms rotation decision time for all specs
- [ ] 10+ encounter scripts implemented
- [ ] Pawn/TSM export functional
- [ ] Community validation (10+ testers)

**NICE TO HAVE** (Optional enhancements):
- [ ] Real-time DPS dashboard
- [ ] Haste breakpoint calculator
- [ ] Video training materials
- [ ] Advanced gear optimization

### Success Metrics Summary

| Metric | Phase 1 | Phase 2 | Phase 3 | Phase 4 | Phase 5 | Final |
|--------|---------|---------|---------|---------|---------|-------|
| Test Coverage | >30% | >60% | >60% | >70% | >80% | >80% |
| Specs on Shared | 3 | 29 | 29 | 29 | 29 | 29 |
| Quality Score | 82% | 85% | 88% | 90% | 93% | 93%+ |
| File Reduction | 10% | 60% | 80% | 92% | 92% | 92% |
| DPS Variance | N/A | N/A | <10% | <10% | <5% | <5% |

---

## RISK & MITIGATION SUMMARY

### Top 5 Risks

| # | Risk | Likelihood | Impact | Mitigation Strategy |
|---|------|------------|--------|---------------------|
| 1 | **Shared Library Drift** | Medium | High | Drift detection script, library sync verification, feature flags |
| 2 | **Simulation Accuracy** | Medium | High | Validate against wowsims data, 0.5 DPS tolerance, incremental validation |
| 3 | **Timeline Overruns** | High | Medium | Parallel work streams (4), 50% buffer (30 vs 20 weeks), phase gates |
| 4 | **Spec Maintainer Adoption** | Medium | Medium | Migration guide, backward compatibility (2 weeks), pilot program (5 adopters) |
| 5 | **Scope Creep** | Medium | Medium | Strict phase gates, measurable success criteria, weekly reviews, change control |

### Risk Decision Trees

**Decision Tree 1: Shared Library Migration**
```
Start Migration
├── Pilot Phase (3 specs)
│   ├── Success → Continue to Phase 2.1
│   └── Issues Found → Extend pilot, fix issues
├── Phase 2.1 Rollout (29 specs)
│   ├── <3 specs with issues → Continue
│   ├── 3-5 specs with issues → Pause, fix, resume
│   └── >5 specs with issues → Rollback, reassess
└── Completion
    └── Enable drift detection for ongoing monitoring
```

**Decision Tree 2: Simulation Validation**
```
Run Simulation Validation
├── Variance <5% → Pass, continue
├── Variance 5-10% → Acceptable, document, continue
├── Variance 10-15% → Investigate, fix critical issues
└── Variance >15% → Halt, debug, fix before continuing
```

**Decision Tree 3: Phase Gate Review**
```
Phase Completion Review
├── All success criteria met → Approve next phase
├── 1-2 minor criteria missed → Approve with action items
├── Major criterion missed → Extend phase 1 week
└── Multiple criteria missed → Reassess timeline/resources
```

### Contingency Triggers

| Trigger | Action | Owner | Timeline |
|---------|--------|-------|----------|
| >5 specs with shared lib issues | Rollback to pilot, fix architecture | Tech Lead | 1 week |
| Simulation variance >15% | Halt Phase 3, debug simulation | Simulation Lead | 2 weeks |
| >2 weeks behind schedule | Activate parallel work streams | Project Manager | Immediate |
| <50% test coverage at Phase 2 | Extend Phase 2, add test resources | QA Lead | 1 week |
| <80% quality score at Phase 5 | Extend Phase 5, prioritize critical specs | Product Owner | 2 weeks |

---

## TEAM STRUCTURE

### Work Stream Assignments (Embedded in EAX_IMPROVEMENT_PLAN.md)

| Stream | Size | Focus Areas | Duration | Start After |
|--------|------|-------------|----------|-------------|
| **Stream A: Infrastructure** | 2-3 people | Testing + Shared Libraries | 6 weeks | - |
| **Stream B: Engine** | 2 people | APL + MCD + AoE | 6 weeks | Stream A Week 2 |
| **Stream C: Simulation** | 2 people | Simulation + Optimization | 6 weeks | Stream B Week 4 |
| **Stream D: Polish** | 1-2 people | Haste + Encounters + Docs | 3 weeks | Streams A, B, C |

### Estimated Hours by Phase

| Phase | Weeks | People | Hours/Week | Total Hours | Key Activities |
|-------|-------|--------|------------|-------------|----------------|
| 1 | 6 | 3 | 40 | 720 | Test framework, shared lib extraction |
| 2 | 6 | 3 | 40 | 720 | Shared lib rollout, APL system |
| 3 | 8 | 2 | 40 | 640 | MCD system, simulation mode |
| 4 | 6 | 2 | 40 | 480 | Stat weights, gear comparison |
| 5 | 4 | 2 | 40 | 320 | Haste breakpoints, encounters |
| **Total** | **30** | **varies** | **40** | **~2,880** | |

### Roles & Responsibilities

| Role | Responsibilities | Skills Required |
|------|-----------------|---------------|
| **Tech Lead** | Architecture decisions, code review, unblocking | Lua, TBC mechanics, leadership |
| **Simulation Lead** | Simulation engine, wowsims integration, validation | Go (for reference), Lua, statistics |
| **APL Lead** | APL parser, condition evaluators, SimC compatibility | Parser design, Lua, SimC syntax |
| **QA Lead** | Test framework, coverage, validation scripts | Lua testing, CI/CD, automation |
| **Spec Maintainers** | Per-spec migration, testing, feedback | Class knowledge, Lua, patience |
| **Documentation** | Migration guide, API docs, training materials | Technical writing, Lua, teaching |

---

## SUCCESS METRICS

### Quality Score Targets (Per Spec)

| Class | Spec | Current | Target | Items | Effort |
|-------|------|---------|--------|-------|--------|
| Warrior | Arms | 80% | 93% | 6 | Medium |
| Warrior | Fury | 83% | 93% | 6 | Low |
| Warrior | Protection | 78% | 93% | 7 | Medium |
| Paladin | Holy | 79% | 93% | 6 | Medium |
| Paladin | Protection | 81% | 93% | 6 | Medium |
| Paladin | Retribution | 82% | 93% | 5 | Low |
| Hunter | BM | 84% | 93% | 5 | Low |
| Hunter | MM | 82% | 93% | 5 | Low |
| Hunter | Survival | 80% | 93% | 6 | Medium |
| Rogue | Assassination | 83% | 93% | 5 | Low |
| Rogue | Combat | 81% | 93% | 6 | Medium |
| Rogue | Subtlety | 79% | 93% | 7 | Medium |
| Priest | Discipline | 79% | 93% | 6 | Medium |
| Priest | Holy | 77% | 93% | 6 | Medium |
| Priest | Shadow | 85% | 93% | 5 | Low |
| Priest | Smite | 76% | 93% | 7 | High |
| Shaman | Elemental | 82% | 93% | 6 | Medium |
| Shaman | Enhancement | 83% | 93% | 5 | Low |
| Shaman | Restoration | 78% | 93% | 6 | Medium |
| Mage | Arcane | 84% | 93% | 6 | Medium |
| Mage | Fire | 82% | 93% | 6 | Medium |
| Mage | Frost | 81% | 93% | 5 | Low |
| Warlock | Affliction | 83% | 93% | 6 | Medium |
| Warlock | Demonology | 80% | 93% | 6 | Medium |
| Warlock | Destruction | 82% | 93% | 5 | Low |
| Druid | Balance | 79% | 93% | 7 | Medium |
| Druid | Feral | 85% | 93% | 4 | Low |
| Druid | Bear | 80% | 93% | 6 | Medium |
| Druid | Restoration | 78% | 93% | 7 | Medium |

**Overall Average**: 81.6% → 93.0% (+11.4% improvement potential)

### Test Coverage Targets

| Phase | Coverage Target | Measured By |
|-------|-----------------|-------------|
| Phase 1 | >30% | Pilot specs only |
| Phase 2 | >60% | All 29 specs |
| Phase 3 | >60% | Maintain + add simulation tests |
| Phase 4 | >70% | Add optimization tool tests |
| Phase 5 | >80% | Complete coverage |

### DPS Accuracy Targets

| Metric | Target | Method |
|--------|--------|--------|
| Simulation vs wowsims | Within 10% | Parse .results files |
| Tolerance | 0.5 DPS acceptable variance | Statistical analysis |
| Validation | 5 methods | See EAX_TEST_SPECIFICATIONS.md |

### Performance Targets

| Metric | Target | Current |
|--------|--------|---------|
| Rotation decision time | <5ms | Variable |
| File count | 72 files | 870 files |
| Memory overhead | Minimal | Unknown |
| Load time | <100ms | Unknown |

---

## NEXT STEPS

### Immediate Actions (Week 1)

1. **Review All Documents**
   - [ ] Read EAX_IMPROVEMENT_PLAN.md (original roadmap)
   - [ ] Read EAX_IMPROVEMENT_PLAN_FINAL.md (complete technical spec)
   - [ ] Review EAX_TEST_SPECIFICATIONS.md (25 test cases)
   - [ ] Study Wowsims_To_EAX_Code_Mappings.md (5 examples)

2. **Assign Team Roles**
   - [ ] Identify Tech Lead
   - [ ] Assign Simulation Lead
   - [ ] Designate APL Lead
   - [ ] Confirm QA Lead
   - [ ] Recruit Spec Maintainers (1 per class minimum)
   - [ ] Assign Documentation lead

3. **Begin Phase 1: Foundation**
   - [ ] Set up development environment
   - [ ] Create `tests/` directory structure
   - [ ] Install Busted testing framework
   - [ ] Create WoWAPIMock.lua
   - [ ] Set up GitHub Actions CI
   - [ ] Create `shared/libraries/` directory
   - [ ] Identify 6 core libraries for extraction
   - [ ] Select 3 pilot specs (recommend: WarriorFury, MageFire, RogueCombat)

4. **Establish Weekly Status Tracking**
   - [ ] Create project tracking board
   - [ ] Schedule weekly standups
   - [ ] Set up phase gate review meetings
   - [ ] Define reporting format

### Week 2-3 Actions

- Extract 6 core libraries to `shared/libraries/core/`
- Write initial test suite for pilot specs
- Migrate 3 pilot specs to shared libraries
- Establish performance benchmarks
- Create drift detection script

### Week 4-6 Actions (Phase 2 Prep)

- Validate pilot specs for 48 hours
- Begin rollout to remaining 26 specs
- Implement APL parser core
- Expand test coverage to >60%
- Document migration guide

---

## DOCUMENT LOCATIONS

### Absolute Paths (All Documents)

| # | Document | Absolute Path | Size | Description |
|---|----------|---------------|------|-------------|
| 1 | **EAX_IMPROVEMENT_PLAN.md** | `C:\newbot\scripts\docs\EAX_IMPROVEMENT_PLAN.md` | 953 lines | Original 5-phase roadmap with 15 work units, dependency graph, and risk mitigations |
| 2 | **EAX_IMPROVEMENT_PLAN_SUPPLEMENT.md** | `C:\newbot\scripts\docs\EAX_IMPROVEMENT_PLAN_SUPPLEMENT.md` | 322 lines | Oracle critique responses with concrete wowsims patterns and technical deep-dives |
| 3 | **EAX_IMPROVEMENT_PLAN_FINAL.md** | `C:\newbot\scripts\docs\EAX_IMPROVEMENT_PLAN_FINAL.md` | 1,657 lines | Complete technical specification with all 29 spec checklists, 14 wowsims patterns, and implementation details |
| 4 | **Wowsims_To_EAX_Code_Mappings.md** | `C:\newbot\Wowsims_To_EAX_Code_Mappings.md` | 749 lines | 5 concrete code transformation examples showing wowsims Go → EAX Lua patterns |
| 5 | **FLUX_MIGRATION_EXAMPLES.lua** | `C:\newbot\scripts\FLUX_MIGRATION_EXAMPLES.lua` | 883 lines | 3 migration examples (EAX imperative → Flux declarative) with BEFORE/AFTER patterns |
| 6 | **EAX_TEST_SPECIFICATIONS.md** | `C:\newbot\scripts\docs\EAX_TEST_SPECIFICATIONS.md` | 1,534 lines | 25 detailed test cases with prerequisites, expected outputs, validation methods, and wowsims baselines |

### Embedded Content Locations

| Content | Embedded In | Lines | Description |
|---------|-------------|-------|-------------|
| **Team Structure** | EAX_IMPROVEMENT_PLAN.md | 700-725 | 4 work streams, parallel assignments, estimated durations |
| **Resource Planning** | EAX_IMPROVEMENT_PLAN.md | 700-725 | 8 people across streams, role definitions |
| **Integration Tests** | EAX_TEST_SPECIFICATIONS.md | 1486-1510 | 10 integration scenarios with file structure |
| **Risk Contingencies** | EAX_IMPROVEMENT_PLAN_FINAL.md | 1509-1540 | 5 risk categories with decision trees and mitigations |
| **Budget Estimates** | EAX_IMPROVEMENT_PLAN.md | 700-725 | ~2,880 total hours across 30 weeks |

### Supporting Documents

| Document | Path | Purpose |
|----------|------|---------|
| AGENTS.md | `C:\newbot\scripts\docs\AGENTS.md` | Agent operational context for documentation |
| cross_spec_patterns.md | `C:\newbot\scripts\docs\cross_spec_patterns.md` | Common patterns across specs |
| shared_libraries_analysis.md | `C:\newbot\scripts\docs\shared_libraries_analysis.md` | Library architecture and usage patterns |
| shared_library_drift_audit.md | `C:\newbot\scripts\docs\shared_library_drift_audit.md` | Cross-spec consistency checks |
| flux_reference_patterns.md | `C:\newbot\scripts\docs\flux_reference_patterns.md` | Flux pattern reference |
| eax_flux_review_report.md | `C:\newbot\scripts\docs\eax_flux_review_report.md` | Flux integration analysis |
| compliance_matrix.md | `C:\newbot\scripts\docs\compliance_matrix.md` | API compliance tracking |

---

## APPENDIX A: 14 WOWSIMS PATTERNS

From EAX_IMPROVEMENT_PLAN_SUPPLEMENT.md and EAX_IMPROVEMENT_PLAN_FINAL.md:

| # | Pattern | wowsims Implementation | Flux/EAX Adaptation | Impact |
|---|---------|----------------------|---------------------|--------|
| 1 | **OnGCDReady** | `OnGCDReady(sim)` callback | `A[3]` function in main.lua | Core architecture |
| 2 | **Phase Detection** | `sim.IsExecutePhase()` | Add to Flux context | +5% DPS for execute classes |
| 3 | **Normal/Execute Split** | Separate `normalRotation()` and `executeRotation()` | Split EAX `on_update()` | Cleaner code |
| 4 | **Should/Cast Pattern** | `ShouldBloodthirst()` + `Cast()` | Enhance `try_*` functions | Standardized interface |
| 5 | **Time-Based CDs** | `spell.CD.ReadyAt()` time.Duration | Add TimeToReady() | Better CD weaving |
| 6 | **Debuff Window** | `RemainingDuration(sim) <= SunderWindow` | Add to buff/debuff tracking | +3% DPS |
| 7 | **Boolean Flags** | `war.thunderClapNext` pattern | Add state machine flags | Cleaner state management |
| 8 | **Mana Regen Toggle** | `warlock.DoingRegen` flag | Add to mana classes | +2% DPS |
| 9 | **WaitForMana** | `spriest.WaitForMana(sim, cost)` | Add to Flux casting helpers | Prevents OOM clipping |
| 10 | **Adaptive Rotation** | `manaTracker.ProjectedManaSurplus()` | Create ManaSpendingRateTracker | +5% DPS for casters |
| 11 | **Pre-Sim Calibration** | `GetPresimOptions()` for DPS-per-action | Add calibration mode | Accurate prioritization |
| 12 | **Event-Based Waiting** | `waitUntilNextEvent(events[])` | Add for seal twisting/energy pooling | Critical timing accuracy |
| 13 | **Config Structs** | `FeralDruidRotation{RipCP: 5, ...}` | Add to complex rotations | Maintainable configs |
| 14 | **Constants Pattern** | `const BiteTrickCP = 4` | Add rotation threshold constants | Tuning flexibility |

---

## APPENDIX B: FILE REDUCTION BREAKDOWN

### Current State (Pre-Improvement)

```
29 specs × ~30-35 libraries = ~870-1,015 files
Plus: specs, README files, configs = ~912 total files
```

### Target State (Post-Improvement)

```
Category A (Identical): 6 files → 6 shared files (100% reduction)
Category B (Varied): 24 file types → 24 shared templates (abstraction pattern)
Category C (Spec-Specific): 12 file types → 12 per-spec files
Result: 6 + 24 + 12 = 42 core files + 30 per-spec configs = ~72 files
```

### Reduction Summary

| Category | Original | After | Reduction |
|----------|----------|-------|-----------|
| Identical Files | 174 (6×29) | 6 | 96.6% |
| Varied Files | 696 (24×29) | 24 | 96.6% |
| Spec-Specific | 42 (12×3.5 avg) | 42 | 0% |
| **Total** | **912** | **72** | **92.1%** |

---

## DOCUMENT CONTROL

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | April 10, 2026 | Planning Team | Initial master consolidation |

### Approval Status

- [ ] Tech Lead Review
- [ ] Product Owner Approval
- [ ] Team Assignment Confirmed
- [ ] Timeline Acknowledged
- [ ] Budget Approved

### Distribution

- Tech Lead
- Product Owner
- All Work Stream Leads
- Spec Maintainers
- Documentation Team

---

**END OF MASTER DOCUMENT**

*This document consolidates all EAX improvement planning. For detailed technical specifications, refer to individual documents listed in Section 11 (Document Locations).*
