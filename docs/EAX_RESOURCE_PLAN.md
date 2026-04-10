# EAX Improvement Plan - Resource & Team Planning

**Document Version**: 1.0  
**Date**: April 10, 2026  
**Project**: EAX TBC Classic Rotation Improvement Plan  
**Timeline**: 30 weeks  
**Status**: Ready for execution

---

## 1. TEAM STRUCTURE

### 1.1 Core Team Composition (8 People)

| Role | Count | Primary Responsibility | Allocation |
|------|-------|----------------------|------------|
| **Project Lead** | 1 | Overall coordination, reviews, stakeholder management | 100% |
| **Senior Developers** | 2 | Complex specs, architecture decisions, mentoring | 100% each |
| **Mid-Level Developers** | 3 | Standard spec improvements, implementation | 100% each |
| **QA Engineer** | 1 | Test framework, validation, quality gates | 100% |
| **DevOps Engineer** | 1 | CI/CD, build automation, infrastructure | 80% (shared) |

**Total Team Size**: 8 people  
**Total FTE**: 7.8 FTE

### 1.2 Team Member Profiles

#### Project Lead (PL-001)
- **Name/Role**: TBD - Project Lead
- **Required Skills**: 
  - 5+ years Lua/Golang experience
  - Project management (Scrum/Agile)
  - Technical architecture design
  - Stakeholder communication
- **Primary Focus**: 
  - Sprint planning and coordination
  - Code reviews for all major changes
  - Risk management and escalation
  - External communication (wowsims integration)
- **Key Deliverables**: 
  - Weekly status reports
  - Architecture decision records (ADRs)
  - Final project retrospective

#### Senior Developer 1 (SD-001) - "Architecture Lead"
- **Name/Role**: TBD - Senior Developer
- **Required Skills**:
  - 7+ years Lua development
  - Experience with simulation systems
  - Deep TBC game mechanics knowledge
  - Performance optimization expertise
- **Primary Focus**:
  - Shared library architecture
  - APL system design
  - Simulation engine implementation
  - Mentoring mid-level developers
- **Key Deliverables**:
  - `shared/libraries/` architecture
  - APL parser and executor
  - Simulation engine core
  - Technical design documents

#### Senior Developer 2 (SD-002) - "Integration Lead"
- **Name/Role**: TBD - Senior Developer
- **Required Skills**:
  - 6+ years systems programming (Lua/Go)
  - CI/CD pipeline experience
  - Testing framework design
  - Middleware/Flux integration
- **Primary Focus**:
  - MCD system implementation
  - Test framework infrastructure
  - CI/CD pipeline setup
  - DevOps collaboration
- **Key Deliverables**:
  - MCD manager and scheduler
  - Test framework with Busted
  - GitHub Actions workflows
  - Integration patterns documentation

#### Mid-Level Developer 1 (MLD-001) - "Spec Specialist"
- **Name/Role**: TBD - Mid-Level Developer
- **Required Skills**:
  - 3+ years Lua development
  - TBC class knowledge (Warrior, Rogue, Hunter)
  - Rotation logic implementation
  - Unit testing experience
- **Primary Focus**:
  - Spec migration (Warrior, Rogue, Hunter specs)
  - Rotation optimization
  - APL condition implementation
  - QA support
- **Key Deliverables**:
  - 9 specs migrated to shared libraries
  - Rotation priority implementations
  - APL condition tests
  - Spec documentation

#### Mid-Level Developer 2 (MLD-002) - "Systems Specialist"
- **Name/Role**: TBD - Mid-Level Developer
- **Required Skills**:
  - 3+ years Lua development
  - Caster class knowledge (Mage, Warlock, Priest)
  - Buff/debuff system experience
  - AoE mechanics understanding
- **Primary Focus**:
  - Spec migration (Mage, Warlock, Priest specs)
  - Multi-target logic (AoE system)
  - Haste breakpoint calculations
  - DoT optimization
- **Key Deliverables**:
  - 10 specs migrated to shared libraries
  - AoE target counter system
  - Haste breakpoint calculator
  - DoT refresh optimization

#### Mid-Level Developer 3 (MLD-003) - "Hybrid Specialist"
- **Name/Role**: TBD - Mid-Level Developer
- **Required Skills**:
  - 3+ years Lua development
  - Druid/Shaman/Paladin knowledge
  - Healing rotation experience
  - Tank mechanics understanding
- **Primary Focus**:
  - Spec migration (Druid, Shaman, Paladin specs)
  - Healer rotation support
  - Tank threat mechanics
  - Encounter script implementation
- **Key Deliverables**:
  - 10 specs migrated to shared libraries
  - Healer rotation framework
  - Tank threat optimization
  - Encounter-specific rotations

#### QA Engineer (QA-001)
- **Name/Role**: TBD - QA Engineer
- **Required Skills**:
  - 4+ years testing experience
  - Lua testing frameworks (Busted)
  - CI/CD quality gates
  - Performance testing
- **Primary Focus**:
  - Test framework development
  - Test case design and execution
  - Drift detection automation
  - Quality metrics tracking
- **Key Deliverables**:
  - Comprehensive test framework
  - >60% test coverage
  - Drift detection scripts
  - Quality dashboards

#### DevOps Engineer (DO-001)
- **Name/Role**: TBD - DevOps Engineer
- **Required Skills**:
  - 4+ years DevOps experience
  - GitHub Actions expertise
  - Lua build tooling
  - Performance monitoring
- **Primary Focus**:
  - CI/CD pipeline
  - Build automation
  - Performance benchmarking
  - Infrastructure as code
- **Key Deliverables**:
  - GitHub Actions workflows
  - Automated build system
  - Performance benchmarks
  - Deployment automation

---

## 2. WORK ASSIGNMENT BY PHASE

### 2.1 Phase 1: Foundation (Weeks 1-6)

#### Week 1-2: Kickoff & Test Framework

| Work Unit | Owner | Team Members | Deliverables |
|-----------|-------|--------------|--------------|
| 1.1 Test Framework Infrastructure | SD-002 | QA-001 (support), DO-001 (CI/CD) | Test framework, CI pipeline |
| Team Onboarding | PL-001 | All | Project kickoff, environment setup |

**Assignments:**
- **SD-002** (Lead): Test framework architecture, Busted configuration
- **QA-001** (Support): Test utilities, mock development
- **DO-001** (Support): GitHub Actions workflow
- **PL-001**: Project charter, communication plan

#### Week 3-4: Shared Libraries - Core

| Work Unit | Owner | Team Members | Deliverables |
|-----------|-------|--------------|--------------|
| 1.2 Shared Library Extraction - Core | SD-001 | MLD-001 (support) | utils.lua, spell_resolver.lua, spells.lua |
| 1.3 Shared Library Extraction - Managers | SD-001 | MLD-002 (support) | managers/ directory |

**Assignments:**
- **SD-001** (Lead): Architecture design, core library extraction
- **MLD-001** (Support): utils.lua implementation, testing
- **MLD-002** (Support): Manager libraries, validation

#### Week 5-6: Pilot Spec Migration & Validation

| Work Unit | Owner | Team Members | Deliverables |
|-----------|-------|--------------|--------------|
| Pilot Spec Migration (3 specs) | MLD-001 | SD-001 (review), QA-001 (testing) | 3 specs on shared libs |
| Drift Detection Setup | QA-001 | DO-001 (automation) | Drift detection script |

**Assignments:**
- **MLD-001** (Lead): EAXWarriorArms migration
- **MLD-002** (Lead): EAXMageFire migration
- **MLD-003** (Lead): EAXRogueCombat migration
- **SD-001**: Code reviews, architecture validation
- **QA-001**: Testing, drift detection setup

---

### 2.2 Phase 2: Standardization (Weeks 7-12)

#### Week 7-8: APL System Development

| Work Unit | Owner | Team Members | Deliverables |
|-----------|-------|--------------|--------------|
| 2.2 APL Parser & Executor | SD-001 | MLD-001, MLD-002 | APL system, sample APLs |

**Assignments:**
- **SD-001** (Lead): APL parser architecture
- **MLD-001** (Support): Warrior APL, condition evaluation
- **MLD-002** (Support): Mage APL, action definitions
- **QA-001**: APL parsing tests

#### Week 9-10: Shared Library Rollout (Batch 1)

| Work Unit | Owner | Team Members | Deliverables |
|-----------|-------|--------------|--------------|
| 2.1 Shared Library Rollout | MLD-001 | SD-001 (review), QA-001 | 10 specs migrated |

**Assignments:**
- **MLD-001**: Druid specs (4), Hunter specs (3)
- **MLD-002**: Mage specs (3)
- **SD-001**: Code reviews, architectural guidance
- **QA-001**: Batch testing, validation

#### Week 11-12: Shared Library Rollout (Batch 2) + Test Coverage

| Work Unit | Owner | Team Members | Deliverables |
|-----------|-------|--------------|--------------|
| 2.1 Shared Library Rollout (remaining) | MLD-002, MLD-003 | SD-001, QA-001 | 19 specs migrated |
| 2.3 Test Coverage Expansion | QA-001 | All devs | >50% coverage |

**Assignments:**
- **MLD-002**: Paladin (3), Priest (4), Warlock (3)
- **MLD-003**: Shaman (3), Warrior (3 - remaining)
- **QA-001**: Test expansion, coverage analysis
- **All Developers**: Write tests for their specs

---

### 2.3 Phase 3: Advanced Engine (Weeks 13-20)

#### Week 13-14: MCD System Development

| Work Unit | Owner | Team Members | Deliverables |
|-----------|-------|--------------|--------------|
| 3.1 MajorCooldown System | SD-002 | MLD-001, MLD-002 | MCD manager, scheduler |

**Assignments:**
- **SD-002** (Lead): MCD architecture, priority system
- **MLD-001** (Support): MCD integration for WarriorFury
- **MLD-002** (Support): MCD integration for MageFire
- **QA-001**: MCD system tests

#### Week 15-16: Simulation Engine Core

| Work Unit | Owner | Team Members | Deliverables |
|-----------|-------|--------------|--------------|
| 3.2 Simulation Mode | SD-001 | SD-002, MLD-001 | Simulation engine |

**Assignments:**
- **SD-001** (Lead): Event-driven simulation loop
- **SD-002** (Support): Player/target modeling
- **MLD-001** (Support): Rotation runner, spell simulation
- **QA-001**: Simulation validation tests

#### Week 17-18: MCD Integration & AoE Logic

| Work Unit | Owner | Team Members | Deliverables |
|-----------|-------|--------------|--------------|
| 3.1 MCD Integration (remaining specs) | MLD-002, MLD-003 | SD-002 | 5 specs with MCD |
| 3.3 Multi-Target Logic | MLD-001 | SD-001 | AoE system |

**Assignments:**
- **MLD-002**: MCD for Rogue, Warlock specs
- **MLD-003**: MCD for Paladin, Shaman specs
- **MLD-001** (Lead): AoE target counter, positioning
- **SD-002**: MCD scheduling optimization

#### Week 19-20: Simulation Refinement & Validation

| Work Unit | Owner | Team Members | Deliverables |
|-----------|-------|--------------|--------------|
| 3.2 Simulation Refinement | SD-001 | QA-001 | Validated simulation |
| MCD Rollout Completion | SD-002 | All MLDs | All DPS specs with MCD |

**Assignments:**
- **SD-001**: Simulation accuracy improvements
- **SD-002**: MCD rollout to remaining specs
- **QA-001**: wowsims validation, accuracy testing
- **All**: Performance optimization

---

### 2.4 Phase 4: Optimization (Weeks 21-26)

#### Week 21-22: Stat Weight Calculator

| Work Unit | Owner | Team Members | Deliverables |
|-----------|-------|--------------|--------------|
| 4.1 Stat Weight Calculator | SD-001 | SD-002, MLD-002 | Stat weights system |

**Assignments:**
- **SD-001** (Lead): Differential simulation algorithm
- **SD-002** (Support): EP calculation, hit cap handling
- **MLD-002**: Caster stat weights implementation
- **QA-001**: Validation against wowsims

#### Week 23-24: Gear Comparison System

| Work Unit | Owner | Team Members | Deliverables |
|-----------|-------|--------------|--------------|
| 4.2 Gear Comparison | MLD-002 | SD-001 (review) | Gear comparison |

**Assignments:**
- **MLD-002** (Lead): Item database integration
- **SD-001**: Architecture review, performance optimization
- **MLD-001**: Gear comparison UI integration
- **QA-001**: Comparison accuracy tests

#### Week 25-26: DPS Reporting & Dashboard

| Work Unit | Owner | Team Members | Deliverables |
|-----------|-------|--------------|--------------|
| 4.3 DPS Reporting | MLD-001 | MLD-003, QA-001 | Enhanced dashboard |

**Assignments:**
- **MLD-001** (Lead): Real-time DPS estimation
- **MLD-003**: Spell usage histogram
- **QA-001**: Uptime tracking accuracy
- **SD-001**: Performance optimization

---

### 2.5 Phase 5: Polish (Weeks 27-30)

#### Week 27-28: Haste Breakpoints & Encounter Scripts

| Work Unit | Owner | Team Members | Deliverables |
|-----------|-------|--------------|--------------|
| 5.1 Haste Breakpoints | MLD-002 | SD-001 | Haste calculator |
| 5.2 Encounter Scripts | MLD-003 | SD-002 | 3 encounter scripts |

**Assignments:**
- **MLD-002** (Lead): DoT tick calculation, clipping estimation
- **SD-001**: Mathematical validation
- **MLD-003** (Lead): Encounter framework, Sunwell scripts
- **SD-002**: Phase detection logic

#### Week 29-30: Documentation & Final Integration

| Work Unit | Owner | Team Members | Deliverables |
|-----------|-------|--------------|--------------|
| 5.3 Documentation & Integration | PL-001 | All | Complete docs |
| Final Testing & Release | QA-001 | All | Release validation |

**Assignments:**
- **PL-001**: Documentation review, migration guide
- **SD-001**: API documentation
- **SD-002**: Architecture documentation
- **All MLDs**: Spec-specific documentation
- **QA-001**: Final test suite, release checklist
- **DO-001**: Release automation

---

## 3. WORK UNIT OWNERSHIP (15 Work Units)

### 3.1 Detailed Work Unit Assignments

#### Work Unit 1.1: Test Framework Infrastructure
| Attribute | Details |
|-----------|---------|
| **Work Unit ID** | 1.1 |
| **Name** | Test Framework Infrastructure |
| **Owner** | SD-002 (Senior Developer 2) |
| **Required Skills** | Lua testing, CI/CD, Busted framework |
| **Time Estimate** | 4 weeks (Weeks 1-2 + support) |
| **Dependencies** | None |
| **Deliverables** | Test framework, CI pipeline, initial test suite |
| **RACI** | R: SD-002, A: SD-002, C: QA-001, DO-001, I: All |

#### Work Unit 1.2: Shared Library Extraction - Core
| Attribute | Details |
|-----------|---------|
| **Work Unit ID** | 1.2 |
| **Name** | Shared Library Extraction - Core |
| **Owner** | SD-001 (Senior Developer 1) |
| **Required Skills** | Lua architecture, code deduplication, TBC mechanics |
| **Time Estimate** | 3 weeks (Weeks 3-4) |
| **Dependencies** | None |
| **Deliverables** | shared/libraries/core/, 5 core libraries |
| **RACI** | R: SD-001, A: SD-001, C: MLD-001, I: All |

#### Work Unit 1.3: Shared Library Extraction - Managers
| Attribute | Details |
|-----------|---------|
| **Work Unit ID** | 1.3 |
| **Name** | Shared Library Extraction - Managers |
| **Owner** | SD-001 (Senior Developer 1) |
| **Required Skills** | Middleware patterns, manager architecture |
| **Time Estimate** | 3 weeks (Weeks 3-6) |
| **Dependencies** | Work Unit 1.2 |
| **Deliverables** | shared/libraries/managers/, 5 manager libraries |
| **RACI** | R: SD-001, A: SD-001, C: MLD-002, I: All |

#### Work Unit 2.1: Shared Library Rollout - All 29 Specs
| Attribute | Details |
|-----------|---------|
| **Work Unit ID** | 2.1 |
| **Name** | Shared Library Rollout |
| **Owner** | MLD-001, MLD-002, MLD-003 (Mid-Level Developers) |
| **Required Skills** | Lua refactoring, spec knowledge, testing |
| **Time Estimate** | 6 weeks (Weeks 9-12) |
| **Dependencies** | Work Units 1.2, 1.3 |
| **Deliverables** | 29 specs migrated, drift detection |
| **RACI** | R: MLD-001/002/003, A: PL-001, C: SD-001, I: QA-001 |

#### Work Unit 2.2: APL System
| Attribute | Details |
|-----------|---------|
| **Work Unit ID** | 2.2 |
| **Name** | APL (Action Priority List) System |
| **Owner** | SD-001 (Senior Developer 1) |
| **Required Skills** | Parser design, compiler concepts, Lua |
| **Time Estimate** | 4 weeks (Weeks 7-8 + support) |
| **Dependencies** | Work Unit 1.2 |
| **Deliverables** | APL parser, executor, sample APLs |
| **RACI** | R: SD-001, A: SD-001, C: MLD-001, MLD-002, I: QA-001 |

#### Work Unit 2.3: Test Coverage Expansion
| Attribute | Details |
|-----------|---------|
| **Work Unit ID** | 2.3 |
| **Name** | Test Coverage Expansion |
| **Owner** | QA-001 (QA Engineer) |
| **Required Skills** | Test design, Lua testing, coverage analysis |
| **Time Estimate** | 4 weeks (Weeks 11-12 + ongoing) |
| **Dependencies** | Work Unit 1.1 |
| **Deliverables** | >50% test coverage, spec tests |
| **RACI** | R: QA-001, A: QA-001, C: All devs, I: PL-001 |

#### Work Unit 3.1: MajorCooldown System
| Attribute | Details |
|-----------|---------|
| **Work Unit ID** | 3.1 |
| **Name** | MajorCooldown (MCD) System |
| **Owner** | SD-002 (Senior Developer 2) |
| **Required Skills** | Priority queues, simulation concepts, TBC CDs |
| **Time Estimate** | 6 weeks (Weeks 13-18) |
| **Dependencies** | Work Unit 2.2 (APL) |
| **Deliverables** | MCD manager, scheduler, spec integrations |
| **RACI** | R: SD-002, A: SD-002, C: MLD-001, MLD-002, I: QA-001 |

#### Work Unit 3.2: Simulation Mode
| Attribute | Details |
|-----------|---------|
| **Work Unit ID** | 3.2 |
| **Name** | Simulation Mode |
| **Owner** | SD-001 (Senior Developer 1) |
| **Required Skills** | Event-driven simulation, game mechanics modeling |
| **Time Estimate** | 6 weeks (Weeks 15-20) |
| **Dependencies** | Work Unit 3.1 |
| **Deliverables** | Simulation engine, CLI tool, validation |
| **RACI** | R: SD-001, A: SD-001, C: SD-002, MLD-001, I: QA-001 |

#### Work Unit 3.3: Multi-Target Logic
| Attribute | Details |
|-----------|---------|
| **Work Unit ID** | 3.3 |
| **Name** | Multi-Target (AoE) Logic |
| **Owner** | MLD-001 (Mid-Level Developer 1) |
| **Required Skills** | AoE mechanics, positioning logic, target counting |
| **Time Estimate** | 3 weeks (Weeks 17-18 + support) |
| **Dependencies** | Work Unit 1.2 |
| **Deliverables** | AoE system, target counter, rotation switcher |
| **RACI** | R: MLD-001, A: MLD-001, C: SD-001, I: QA-001 |

#### Work Unit 4.1: Stat Weight Calculator
| Attribute | Details |
|-----------|---------|
| **Work Unit ID** | 4.1 |
| **Name** | Stat Weight Calculator |
| **Owner** | SD-001 (Senior Developer 1) |
| **Required Skills** | Statistics, differential analysis, TBC stats |
| **Time Estimate** | 3 weeks (Weeks 21-22) |
| **Dependencies** | Work Unit 3.2 (Simulation) |
| **Deliverables** | Stat weights, EP calculation, export tools |
| **RACI** | R: SD-001, A: SD-001, C: SD-002, MLD-002, I: QA-001 |

#### Work Unit 4.2: Gear Comparison System
| Attribute | Details |
|-----------|---------|
| **Work Unit ID** | 4.2 |
| **Name** | Gear Comparison System |
| **Owner** | MLD-002 (Mid-Level Developer 2) |
| **Required Skills** | Item databases, gear optimization, UI integration |
| **Time Estimate** | 3 weeks (Weeks 23-24) |
| **Dependencies** | Work Unit 3.2 (Simulation) |
| **Deliverables** | Gear comparison, upgrade finder, export |
| **RACI** | R: MLD-002, A: MLD-002, C: SD-001, I: QA-001 |

#### Work Unit 4.3: DPS Reporting
| Attribute | Details |
|-----------|---------|
| **Work Unit ID** | 4.3 |
| **Name** | DPS Reporting and Dashboard |
| **Owner** | MLD-001 (Mid-Level Developer 1) |
| **Required Skills** | Lua UI, real-time metrics, data visualization |
| **Time Estimate** | 3 weeks (Weeks 25-26) |
| **Dependencies** | Work Unit 3.2 (Simulation metrics) |
| **Deliverables** | Enhanced dashboard, spell breakdown, uptime tracking |
| **RACI** | R: MLD-001, A: MLD-001, C: MLD-003, I: QA-001 |

#### Work Unit 5.1: Haste Breakpoints
| Attribute | Details |
|-----------|---------|
| **Work Unit ID** | 5.1 |
| **Name** | Haste Breakpoint Calculator |
| **Owner** | MLD-002 (Mid-Level Developer 2) |
| **Required Skills** | Mathematical modeling, DoT mechanics, haste calculations |
| **Time Estimate** | 2 weeks (Week 27 + support) |
| **Dependencies** | Work Unit 3.2 |
| **Deliverables** | Haste calculator, DoT optimization, clipping prevention |
| **RACI** | R: MLD-002, A: MLD-002, C: SD-001, I: QA-001 |

#### Work Unit 5.2: Encounter Scripts
| Attribute | Details |
|-----------|---------|
| **Work Unit ID** | 5.2 |
| **Name** | Encounter Scripts |
| **Owner** | MLD-003 (Mid-Level Developer 3) |
| **Required Skills** | TBC raid encounters, phase detection, rotation adaptation |
| **Time Estimate** | 2 weeks (Week 27-28) |
| **Dependencies** | Work Unit 3.1 (MCD) |
| **Deliverables** | Encounter framework, 3 encounter scripts, phase detection |
| **RACI** | R: MLD-003, A: MLD-003, C: SD-002, I: QA-001 |

#### Work Unit 5.3: Documentation & Final Integration
| Attribute | Details |
|-----------|---------|
| **Work Unit ID** | 5.3 |
| **Name** | Documentation and Final Integration |
| **Owner** | PL-001 (Project Lead) |
| **Required Skills** | Technical writing, API documentation, training |
| **Time Estimate** | 2 weeks (Weeks 29-30) |
| **Dependencies** | All prior work units |
| **Deliverables** | Complete documentation, migration guide, training materials |
| **RACI** | R: PL-001, A: PL-001, C: All, I: Stakeholders |

---

## 4. PARALLEL WORKSTREAMS

### 4.1 Stream Overview

```
Timeline Visualization (30 weeks):

Stream A: Infrastructure ───────[████████████░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░] (Weeks 1-12)
Stream B: Engine Development ──[░░░░░░░░████░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░] (Weeks 4-12)
Stream C: Simulation & Opt ────[░░░░░░░░░░░░░░░░████████████░░░░░░░░░░░░░░░░░░░░] (Weeks 13-26)
Stream D: Polish ─────────────[░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░████████░░░░] (Weeks 27-30)
```

### 4.2 Stream A: Infrastructure (Weeks 1-12)

**Stream Lead**: SD-002  
**Focus**: Testing + Shared Libraries  
**Duration**: 12 weeks

**Work Units**:
- 1.1 Test Framework Infrastructure (Weeks 1-2)
- 1.2 Shared Library Extraction - Core (Weeks 3-4)
- 1.3 Shared Library Extraction - Managers (Weeks 3-6)
- 2.1 Shared Library Rollout (Weeks 9-12)
- 2.3 Test Coverage Expansion (Weeks 11-12)

**Team Allocation**:
| Role | Weeks 1-6 | Weeks 7-12 |
|------|-----------|------------|
| SD-001 | 80% | 40% (review) |
| SD-002 | 100% | 60% |
| MLD-001 | 50% | 100% |
| MLD-002 | 50% | 100% |
| MLD-003 | 50% | 100% |
| QA-001 | 100% | 100% |
| DO-001 | 100% | 40% |

**Dependencies**:
- None (foundation stream)
- Output: Enables Streams B, C, D

**Key Milestones**:
- Week 2: Test framework operational
- Week 4: Core libraries extracted
- Week 6: Manager libraries complete
- Week 8: Pilot specs validated
- Week 12: All 29 specs migrated

---

### 4.3 Stream B: Engine Development (Weeks 4-12)

**Stream Lead**: SD-001  
**Focus**: APL + MCD + AoE  
**Duration**: 8 weeks (overlaps Stream A)

**Work Units**:
- 1.3 Shared Library Extraction - Managers (Weeks 4-6, shared with A)
- 2.2 APL System (Weeks 7-8)
- 3.1 MCD System (Weeks 9-10 - preliminary)
- 3.3 Multi-Target Logic (Weeks 11-12)

**Team Allocation**:
| Role | Weeks 4-6 | Weeks 7-8 | Weeks 9-12 |
|------|-----------|-----------|------------|
| SD-001 | 100% | 100% | 60% |
| SD-002 | 50% | 40% | 60% |
| MLD-001 | 50% | 50% | 80% |
| MLD-002 | 50% | 50% | 80% |
| QA-001 | 50% | 50% | 50% |

**Dependencies**:
- Input: Stream A (Week 2 output - shared libraries foundation)
- Output: Enables Stream C (MCD system, APL foundation)

**Key Milestones**:
- Week 6: Manager libraries ready
- Week 8: APL parser operational
- Week 10: MCD system core complete
- Week 12: AoE system ready

---

### 4.4 Stream C: Simulation & Optimization (Weeks 13-26)

**Stream Lead**: SD-001  
**Focus**: Simulation + Stat Weights + Gear  
**Duration**: 14 weeks

**Work Units**:
- 3.1 MCD System Integration (Weeks 13-14, with Stream B completion)
- 3.2 Simulation Mode (Weeks 15-20)
- 4.1 Stat Weight Calculator (Weeks 21-22)
- 4.2 Gear Comparison (Weeks 23-24)
- 4.3 DPS Reporting (Weeks 25-26)

**Team Allocation**:
| Role | Weeks 13-14 | Weeks 15-20 | Weeks 21-26 |
|------|-------------|-------------|-------------|
| SD-001 | 80% | 100% | 60% |
| SD-002 | 80% | 60% | 40% |
| MLD-001 | 80% | 60% | 100% |
| MLD-002 | 80% | 60% | 100% |
| MLD-003 | 80% | 60% | 60% |
| QA-001 | 60% | 80% | 80% |

**Dependencies**:
- Input: Stream A (complete), Stream B (APL, MCD core)
- Output: Enables Stream D (complete feature set)

**Key Milestones**:
- Week 14: MCD in 5 pilot specs
- Week 18: Simulation engine operational
- Week 20: Simulation validated against wowsims
- Week 22: Stat weights functional
- Week 24: Gear comparison operational
- Week 26: Complete optimization suite

---

### 4.5 Stream D: Polish (Weeks 27-30)

**Stream Lead**: PL-001  
**Focus**: Haste + Encounters + Documentation  
**Duration**: 4 weeks

**Work Units**:
- 5.1 Haste Breakpoints (Week 27)
- 5.2 Encounter Scripts (Weeks 27-28)
- 5.3 Documentation & Integration (Weeks 29-30)

**Team Allocation**:
| Role | Weeks 27-28 | Weeks 29-30 |
|------|-------------|-------------|
| PL-001 | 40% | 100% |
| SD-001 | 40% | 60% |
| SD-002 | 40% | 40% |
| MLD-001 | 60% | 60% |
| MLD-002 | 80% | 60% |
| MLD-003 | 100% | 60% |
| QA-001 | 80% | 100% |
| DO-001 | 40% | 80% |

**Dependencies**:
- Input: All prior streams complete
- Output: Production-ready release

**Key Milestones**:
- Week 27: Haste calculator complete
- Week 28: 3 encounter scripts operational
- Week 29: Documentation complete
- Week 30: Release validated and deployed

---

## 5. RACI MATRIX FOR KEY DECISIONS

### 5.1 Decision Categories

| Decision Area | PL-001 | SD-001 | SD-002 | MLD-001/2/3 | QA-001 | DO-001 |
|---------------|--------|--------|--------|-------------|--------|--------|
| **Architecture Decisions** | A | R | C | C | I | I |
| **Technology Selection** | A | R | C | C | C | C |
| **Spec Migration Priority** | A | C | C | R | C | I |
| **Code Quality Standards** | A | C | C | C | R | C |
| **CI/CD Pipeline** | A | C | R | I | C | R |
| **Testing Strategy** | A | C | C | C | R | C |
| **Release Decisions** | R/A | C | C | I | C | C |
| **Resource Allocation** | R/A | C | C | C | I | I |
| **External Communications** | R | C | C | I | I | I |
| **Risk Mitigation** | R/A | C | C | C | C | I |

**Legend**: R = Responsible, A = Accountable, C = Consulted, I = Informed

### 5.2 Key Decision Points

#### Architecture Decision: Shared Library Structure
- **Decision**: How to organize shared libraries (core/ vs managers/ vs utils/)
- **R**: SD-001
- **A**: PL-001
- **Timeline**: Week 1-2 (Phase 1)
- **Escalation**: If disagreement, escalate to Project Sponsor

#### Technology Decision: APL Parser Approach
- **Decision**: Hand-written parser vs parser generator vs embedded Lua
- **R**: SD-001
- **A**: PL-001
- **Timeline**: Week 6 (Phase 2 start)
- **Escalation**: Technical review committee

#### Quality Decision: Test Coverage Threshold
- **Decision**: Minimum test coverage percentage (50%, 60%, 70%)
- **R**: QA-001
- **A**: PL-001
- **Timeline**: Week 3 (Phase 1)
- **Escalation**: QA lead + Project Lead decision

#### Migration Decision: Spec Rollout Order
- **Decision**: Which specs to migrate in which order
- **R**: MLD-001, MLD-002, MLD-003
- **A**: PL-001
- **Timeline**: Week 7 (Phase 2)
- **Escalation**: Based on complexity assessment

#### Release Decision: Go/No-Go
- **Decision**: Whether to release at end of Phase 5
- **R**: PL-001
- **A**: PL-001
- **Timeline**: Week 30
- **Escalation**: Project Sponsor + Technical Leads

---

## 6. COMMUNICATION CADENCE

### 6.1 Regular Meetings

| Meeting | Frequency | Duration | Attendees | Purpose |
|---------|-----------|----------|-----------|---------|
| **Daily Standup** | Daily | 15 min | All devs + PL | Blockers, progress, coordination |
| **Sprint Planning** | Bi-weekly | 2 hours | All | Plan next 2 weeks |
| **Sprint Review** | Bi-weekly | 1 hour | All + Stakeholders | Demo completed work |
| **Sprint Retrospective** | Bi-weekly | 1 hour | All | Process improvements |
| **Architecture Review** | Weekly | 1 hour | SD-001, SD-002, PL | Technical decisions |
| **Quality Review** | Weekly | 30 min | QA-001, PL, SDs | Quality metrics, coverage |
| **Stakeholder Update** | Weekly | 30 min | PL, Stakeholders | Progress report |
| **One-on-Ones** | Weekly | 30 min | PL + each team member | Individual feedback |

### 6.2 Communication Channels

| Channel | Purpose | Response Time |
|---------|---------|---------------|
| **Slack #eax-dev** | Daily coordination, quick questions | < 2 hours |
| **Slack #eax-architecture** | Technical discussions, ADRs | < 4 hours |
| **Slack #eax-qa** | Testing issues, bug reports | < 2 hours |
| **GitHub Issues** | Work unit tracking, bugs | < 24 hours |
| **GitHub PRs** | Code reviews | < 24 hours |
| **Email** | External communication, formal docs | < 24 hours |
| **Video (Zoom/Meet)** | Meetings, pair programming | Scheduled |
| **Confluence/Wiki** | Documentation, ADRs | Async |

### 6.3 Reporting Structure

#### Daily Standup Format (Slack #eax-standup)
```
Name: [Your Name]
Yesterday: [What you completed]
Today: [What you're working on]
Blockers: [Any blockers or help needed]
```

#### Weekly Status Report (Email to Stakeholders)
- **Sent by**: PL-001 every Friday
- **Content**:
  - Week summary (achievements)
  - Milestone status (on-track/at-risk/blocked)
  - Key metrics (coverage, specs migrated)
  - Risks and mitigation
  - Next week priorities

#### Sprint Review Agenda (Bi-weekly)
1. Sprint goal review (10 min)
2. Work unit demos (30 min)
3. Metrics review (10 min)
4. Stakeholder feedback (10 min)

---

## 7. ESCALATION PATHS

### 7.1 Escalation Levels

```
Level 1: Team Member → Stream Lead
         (SD-001 for Stream B/C, SD-002 for Stream A, PL-001 overall)
         Response: Within 4 hours

Level 2: Stream Lead → Project Lead (PL-001)
         Response: Within 8 hours

Level 3: Project Lead → Project Sponsor
         Response: Within 24 hours

Level 4: Project Sponsor → Executive Sponsor
         Response: Within 48 hours
```

### 7.2 Escalation Triggers

| Issue Type | Severity | Escalation Level | Example |
|------------|----------|------------------|---------|
| **Technical Blocker** | High | Level 1 → 2 | Cannot resolve architecture issue |
| **Resource Conflict** | Medium | Level 2 | Two streams need same person |
| **Scope Change** | High | Level 2 → 3 | Request to add/remove work units |
| **Timeline Risk** | High | Level 2 → 3 | Milestone at risk of missing |
| **Budget Issue** | Critical | Level 3 → 4 | Over budget or need more resources |
| **Team Conflict** | Medium | Level 2 | Interpersonal issues affecting work |
| **Quality Gate Failure** | High | Level 2 | Test coverage below threshold |
| **External Dependency** | Medium | Level 2 | wowsims integration blocked |

### 7.3 Escalation Contacts

| Level | Contact | Role | Contact Method |
|-------|---------|------|----------------|
| 1 | Stream Lead | SD-001 or SD-002 | Slack DM |
| 2 | Project Lead | PL-001 | Slack + Email |
| 3 | Project Sponsor | TBD | Email + Phone |
| 4 | Executive Sponsor | TBD | Email + Phone |

### 7.4 Escalation Procedure

1. **Identify Issue**: Team member identifies blocking issue
2. **Attempt Resolution**: Try to resolve within current level (1 hour)
3. **Document**: Write up issue with context and attempted solutions
4. **Escalate**: Contact next level with documentation
5. **Track**: Log escalation in project tracker
6. **Follow Up**: Check for resolution within expected timeframe
7. **Close**: Document resolution and close escalation

---

## 8. SKILL DEVELOPMENT PLAN

### 8.1 Skill Gaps Analysis

| Team Member | Current Skills | Needed Skills | Gap Level |
|-------------|----------------|---------------|-----------|
| SD-001 | Lua, Architecture | Simulation design, Parser theory | Medium |
| SD-002 | Lua, Testing | MCD systems, Flux integration | Low |
| MLD-001 | Lua, Warrior/Rogue | AoE mechanics, Testing | Low |
| MLD-002 | Lua, Mage/Warlock | Stat calculation, Optimization | Medium |
| MLD-003 | Lua, Druid/Shaman | Encounter scripting | Low |
| QA-001 | Testing, CI/CD | Lua testing, TBC mechanics | Medium |
| DO-001 | DevOps, CI/CD | Lua build tooling | Low |

### 8.2 Training Plan

#### Week 1-2: Onboarding Training
| Training | Audience | Format | Duration | Owner |
|----------|----------|--------|----------|-------|
| EAX Project Overview | All | Presentation | 2 hours | PL-001 |
| TBC Mechanics Deep Dive | All | Workshop | 4 hours | SD-001 |
| Sylvanas API Training | All | Hands-on | 4 hours | SD-002 |
| wowsims Analysis | SD-001, SD-002, MLDs | Self-study | 4 hours | SD-001 |
| Testing Framework (Busted) | All | Workshop | 3 hours | QA-001 |

#### Week 3-6: Technical Deep Dives
| Training | Audience | Format | Duration | Owner |
|----------|----------|--------|----------|-------|
| Shared Library Architecture | All devs | Workshop | 3 hours | SD-001 |
| APL Design Patterns | SD-001, MLDs | Pair programming | 8 hours | SD-001 |
| MCD System Design | SD-002, MLDs | Workshop | 3 hours | SD-002 |
| Simulation Concepts | SD-001, QA-001 | Self-study | 6 hours | SD-001 |
| Performance Optimization | All devs | Code review | Ongoing | SD-001 |

#### Week 7-12: Specialized Training
| Training | Audience | Format | Duration | Owner |
|----------|----------|--------|----------|-------|
| Stat Weight Calculations | MLD-002, SD-001 | Pair programming | 6 hours | SD-001 |
| AoE Mechanics | MLD-001 | Self-study + Review | 4 hours | MLD-001 |
| Encounter Scripting | MLD-003 | Workshop | 3 hours | MLD-003 |
| Advanced Testing Patterns | QA-001 | Self-study | 4 hours | QA-001 |
| Documentation Best Practices | All | Workshop | 2 hours | PL-001 |

#### Week 13-20: Advanced Topics
| Training | Audience | Format | Duration | Owner |
|----------|----------|--------|----------|-------|
| Simulation Validation | SD-001, QA-001 | Hands-on | 8 hours | SD-001 |
| Optimization Algorithms | SD-001, MLD-002 | Study group | 4 hours | SD-001 |
| Gear Optimization | MLD-002 | Self-study | 4 hours | MLD-002 |
| Metrics & Dashboards | MLD-001 | Workshop | 3 hours | MLD-001 |

#### Week 21-30: Continuous Learning
| Training | Audience | Format | Duration | Owner |
|----------|----------|--------|----------|-------|
| wowsims Integration | SD-001, QA-001 | Research | Ongoing | SD-001 |
| Haste Calculations | MLD-002 | Self-study | 4 hours | SD-001 |
| Code Review Skills | All devs | Practice | Ongoing | All |
| Knowledge Sharing | All | Presentations | 1 hour/week | Rotating |

### 8.3 Mentoring Assignments

| Mentor | Mentee | Focus Area | Check-in Frequency |
|--------|--------|------------|-------------------|
| SD-001 | MLD-001 | Architecture, Shared libs | Weekly |
| SD-001 | MLD-002 | Optimization, APL | Weekly |
| SD-002 | MLD-003 | Testing, MCD systems | Weekly |
| SD-001 | QA-001 | Lua, Simulation concepts | Bi-weekly |
| SD-002 | DO-001 | Build tooling integration | Bi-weekly |
| PL-001 | All | Project context, soft skills | Monthly |

### 8.4 Knowledge Transfer Sessions

| Topic | Presenter | Audience | When |
|-------|-----------|----------|------|
| wowsims Architecture | SD-001 | All | Week 3 |
| EAX Spec Patterns | MLD-001 | All | Week 4 |
| Flux Integration | SD-002 | All | Week 6 |
| Testing Best Practices | QA-001 | All | Week 5 |
| Simulation Results Analysis | SD-001 | All | Week 18 |
| Optimization Lessons Learned | MLD-002 | All | Week 24 |

### 8.5 Resources & Learning Materials

#### Internal Resources
- `docs/EAX_IMPROVEMENT_PLAN.md` - Project plan
- `docs/EAX_IMPROVEMENT_PLAN_SUPPLEMENT.md` - Technical deep-dive
- `docs/EAX_IMPROVEMENT_PLAN_FINAL.md` - Final enhanced plan
- `docs/integration_guide.md` - API integration patterns
- `docs/cross_spec_patterns.md` - Common patterns
- `api/` - Sylvanas API documentation
- `apidocs/` - Offline API docs

#### External Resources
- wowsims/tbc GitHub repository
- SimC APL documentation
- TBC Classic theorycrafting resources
- Lua 5.1 reference manual
- Busted testing framework docs

#### Budget Allocation
- **Training Budget**: $2,000 per person
- **Conference/Workshop**: $5,000 team budget
- **Books/Courses**: $500 per person
- **Total Training Budget**: ~$25,000

---

## 9. RESOURCE ALLOCATION SUMMARY

### 9.1 Effort by Phase (Person-Weeks)

| Phase | SD-001 | SD-002 | MLD-001 | MLD-002 | MLD-003 | QA-001 | DO-001 | Total |
|-------|--------|--------|---------|---------|---------|--------|--------|-------|
| **1: Foundation** | 4.8 | 6.0 | 3.0 | 3.0 | 3.0 | 6.0 | 4.8 | 30.6 |
| **2: Standardization** | 2.4 | 3.6 | 6.0 | 6.0 | 6.0 | 6.0 | 2.4 | 32.4 |
| **3: Advanced Engine** | 8.4 | 5.6 | 4.2 | 4.2 | 3.6 | 4.8 | 0.0 | 30.8 |
| **4: Optimization** | 3.6 | 2.4 | 6.0 | 6.0 | 3.6 | 4.8 | 0.0 | 28.4 |
| **5: Polish** | 1.6 | 1.6 | 2.4 | 3.2 | 4.0 | 4.0 | 2.4 | 19.2 |
| **Total** | 20.8 | 19.2 | 21.6 | 22.4 | 20.2 | 25.6 | 9.6 | 141.4 |

**Total Person-Weeks**: 141.4 (7.8 FTE × 30 weeks = 234 FTE-weeks available)  
**Utilization Rate**: 60.4% (allows for overhead, meetings, PTO)

### 9.2 Critical Path Analysis

**Critical Path**: Work Unit 1.2 → 1.3 → 2.2 → 3.1 → 3.2 → 4.1 → 4.2 → 5.3

**Critical Path Duration**: 26 weeks  
**Float Available**: 4 weeks (Phase 5 has flexibility)

### 9.3 Resource Contention Points

| Week | Contention | Resolution |
|------|------------|------------|
| 3-4 | SD-001 needed for both 1.2 and 1.3 | MLD-002 takes lead on 1.3 |
| 7-8 | All MLDs needed for 2.1 and 2.2 | Prioritize 2.2 (APL) |
| 9-10 | SD-002 needed for 3.1 and CI/CD | DO-001 takes more CI/CD load |
| 13-14 | All senior devs at capacity | Defer non-critical items |
| 21-22 | SD-001 needed for 4.1 and architecture | MLD-002 takes more stat weight work |

### 9.4 Budget Summary

| Category | Amount | Notes |
|----------|--------|-------|
| **Personnel** | $420,000 | 7.8 FTE × 30 weeks × ~$1,800/week |
| **Training** | $25,000 | See Section 8.5 |
| **Tools/Software** | $5,000 | Testing tools, CI/CD |
| **Infrastructure** | $3,000 | Servers, hosting |
| **Contingency (10%)** | $45,300 | Buffer for overruns |
| **Total Budget** | **$498,300** | |

---

## 10. RISK MITIGATION & CONTINGENCY

### 10.1 Resource Risks

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| **Team member leaves** | Medium | High | Cross-training, documentation, knowledge transfer |
| **Sick/PTO overlap** | Medium | Medium | 40% utilization buffer, flexible scheduling |
| **Skill gap larger than expected** | Low | Medium | Training budget, external consulting |
| **DevOps bandwidth insufficient** | Low | Medium | SD-002 can cover, automation priority |

### 10.2 Schedule Risks

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| **APL parser complexity** | Medium | High | Start with subset, iterative approach |
| **Simulation accuracy issues** | Medium | High | Incremental validation, wowsims collaboration |
| **Shared library drift** | Low | High | Automated detection, strict code review |
| **Spec migration slower** | Medium | Medium | Batch approach, parallel workstreams |

### 10.3 Contingency Plans

#### Scenario A: Team Member Departure
- **Trigger**: Any core team member (SD-001, SD-002, PL-001) leaves
- **Action**: 
  1. Immediate knowledge transfer documentation
  2. Contract/consultant backfill for critical skills
  3. Reassign work to remaining team members
  4. Consider scope reduction if necessary
- **Budget**: $20,000 contractor reserve

#### Scenario B: Technical Blocker
- **Trigger**: APL or Simulation work unit blocked >1 week
- **Action**:
  1. Escalate to Level 3 (Project Lead + Sponsor)
  2. Consider alternative implementation approaches
  3. Defer to Phase 5 if not critical path
  4. Engage external expert if needed
- **Budget**: $10,000 expert consulting reserve

#### Scenario C: Scope Reduction Needed
- **Trigger**: Timeline or budget constraints
- **Priority Order for Reduction**:
  1. First: Work Unit 5.2 (Encounter Scripts) - can defer post-release
  2. Second: Work Unit 5.1 (Haste Breakpoints) - can defer post-release
  3. Third: Work Unit 4.3 (DPS Reporting) - reduce scope
  4. Fourth: Work Unit 4.2 (Gear Comparison) - simplify
- **Minimum Viable Scope**: Work Units 1.1-3.2 (Simulation) for release

---

## 11. SUCCESS METRICS & KPIS

### 11.1 Team Performance Metrics

| Metric | Target | Measurement |
|--------|--------|-------------|
| **Velocity** | 8 story points/person/week | Sprint tracking |
| **Code Review Turnaround** | < 24 hours | GitHub PR metrics |
| **Test Coverage** | > 60% | Coverage reports |
| **Defect Rate** | < 2 bugs/week | Issue tracking |
| **Documentation Coverage** | 100% of public APIs | Documentation audit |

### 11.2 Project Success Metrics

| Metric | Phase 1 | Phase 2 | Phase 3 | Phase 4 | Phase 5 |
|--------|---------|---------|---------|---------|---------|
| **Specs Migrated** | 3 | 29 | 29 | 29 | 29 |
| **Test Coverage** | > 30% | > 60% | > 60% | > 70% | > 70% |
| **Shared Libraries** | 10 | 20 | 25 | 25 | 25 |
| **Simulation Accuracy** | N/A | N/A | < 10% delta | < 10% delta | < 5% delta |
| **Documentation Pages** | 10 | 25 | 40 | 50 | 60+ |

### 11.3 Quality Gates

| Gate | When | Criteria | Owner |
|------|------|----------|-------|
| **Phase 1 Gate** | Week 6 | Test framework works, 3 specs migrated, >30% coverage | QA-001 |
| **Phase 2 Gate** | Week 12 | 29 specs migrated, APL works, >60% coverage | QA-001 |
| **Phase 3 Gate** | Week 20 | MCD in 5 specs, simulation < 10% delta wowsims | QA-001 |
| **Phase 4 Gate** | Week 26 | Stat weights functional, gear comparison works | QA-001 |
| **Release Gate** | Week 30 | All docs complete, >70% coverage, 0 critical bugs | PL-001 |

---

## 12. APPENDICES

### Appendix A: Team Contact Information

| Role | ID | Name | Email | Slack | Phone |
|------|----|------|-------|-------|-------|
| Project Lead | PL-001 | [TBD] | [TBD] | [TBD] | [TBD] |
| Senior Dev 1 | SD-001 | [TBD] | [TBD] | [TBD] | [TBD] |
| Senior Dev 2 | SD-002 | [TBD] | [TBD] | [TBD] | [TBD] |
| Mid-Level 1 | MLD-001 | [TBD] | [TBD] | [TBD] | [TBD] |
| Mid-Level 2 | MLD-002 | [TBD] | [TBD] | [TBD] | [TBD] |
| Mid-Level 3 | MLD-003 | [TBD] | [TBD] | [TBD] | [TBD] |
| QA Engineer | QA-001 | [TBD] | [TBD] | [TBD] | [TBD] |
| DevOps Eng | DO-001 | [TBD] | [TBD] | [TBD] | [TBD] |

### Appendix B: Work Unit Quick Reference

| ID | Name | Owner | Start | End | Status |
|----|------|-------|-------|-----|--------|
| 1.1 | Test Framework | SD-002 | W1 | W2 | Not Started |
| 1.2 | Shared Libs - Core | SD-001 | W3 | W4 | Not Started |
| 1.3 | Shared Libs - Managers | SD-001 | W3 | W6 | Not Started |
| 2.1 | Shared Lib Rollout | MLDs | W9 | W12 | Not Started |
| 2.2 | APL System | SD-001 | W7 | W8 | Not Started |
| 2.3 | Test Coverage | QA-001 | W11 | W12 | Not Started |
| 3.1 | MCD System | SD-002 | W13 | W18 | Not Started |
| 3.2 | Simulation Mode | SD-001 | W15 | W20 | Not Started |
| 3.3 | AoE Logic | MLD-001 | W17 | W18 | Not Started |
| 4.1 | Stat Weights | SD-001 | W21 | W22 | Not Started |
| 4.2 | Gear Comparison | MLD-002 | W23 | W24 | Not Started |
| 4.3 | DPS Reporting | MLD-001 | W25 | W26 | Not Started |
| 5.1 | Haste Breakpoints | MLD-002 | W27 | W27 | Not Started |
| 5.2 | Encounter Scripts | MLD-003 | W27 | W28 | Not Started |
| 5.3 | Documentation | PL-001 | W29 | W30 | Not Started |

### Appendix C: Spec Migration Assignments

| Spec | Assigned To | Phase | Dependencies |
|------|-------------|-------|--------------|
| EAXWarriorArms | MLD-001 | 1 | Pilot |
| EAXWarriorFury | MLD-003 | 3 | MLD-001 support |
| EAXWarriorProtection | MLD-003 | 3 | - |
| EAXMageFire | MLD-002 | 1 | Pilot |
| EAXMageFrost | MLD-002 | 2 | - |
| EAXMageArcane | MLD-002 | 2 | - |
| EAXRogueCombat | MLD-001 | 1 | Pilot |
| EAXRogueAssassination | MLD-001 | 2 | - |
| EAXRogueSubtlety | MLD-001 | 2 | - |
| EAXHunterBM | MLD-001 | 2 | - |
| EAXHunterMM | MLD-001 | 2 | - |
| EAXHunterSurvival | MLD-001 | 2 | - |
| EAXWarlockAffliction | MLD-002 | 2 | - |
| EAXWarlockDemonology | MLD-002 | 2 | - |
| EAXWarlockDestruction | MLD-002 | 2 | - |
| EAXDruidBalance | MLD-003 | 2 | - |
| EAXDruidBear | MLD-003 | 2 | - |
| EAXDruidFeral | MLD-003 | 2 | - |
| EAXDruidResto | MLD-003 | 2 | - |
| EAXPriestDiscipline | MLD-002 | 2 | - |
| EAXPriestHoly | MLD-002 | 2 | - |
| EAXPriestShadow | MLD-002 | 2 | - |
| EAXPriestSmite | MLD-002 | 2 | - |
| EAXPaladinHoly | MLD-003 | 2 | - |
| EAXPaladinProtection | MLD-003 | 2 | - |
| EAXPaladinRetribution | MLD-003 | 2 | - |
| EAXShamanElemental | MLD-003 | 2 | - |
| EAXShamanEnhancement | MLD-003 | 2 | - |
| EAXShamanRestoration | MLD-003 | 2 | - |

---

**Document Owner**: Project Lead (PL-001)  
**Review Cycle**: Bi-weekly  
**Next Review**: [To be scheduled after kickoff]  
**Distribution**: All team members, stakeholders

---

*This resource plan is designed for execution. All team members should familiarize themselves with their assigned work units and understand the parallel workstream structure. Questions should be directed to the Project Lead.*
