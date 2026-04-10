# EAX Rotation Scripts - Comprehensive Improvement Plan
**Standalone Distribution Edition**

**Goal**: Bring EAX rotation quality up to wowsims/tbc standards while maintaining Project Sylvanas runtime compatibility.
**Distribution Model**: Each spec ships as standalone .zip with independent libraries
**Sync Strategy**: Cross-spec library standardization with automated consistency checking

**Current State**: 29 specs × 30-35 libraries = ~870 files with 81.6% quality compliance
**Target State**: wowsims/tbc-level simulation accuracy, comprehensive testing, standardized library patterns

---

## Executive Summary: Impact vs Effort Matrix

| Improvement Area | Impact | Effort | Priority | Phase |
|-----------------|--------|--------|----------|-------|
| **Test Infrastructure** | Very High (prevents regressions) | High | 1 | Phase 1-2 |
| **Library Standardization** | Very High (consistent patterns) | High | 2 | Phase 1-2 |
| **APL System** | High (rotation clarity) | Medium | 3 | Phase 2-3 |
| **MajorCooldown System** | High (CD optimization) | Medium | 4 | Phase 2-3 |
| **Simulation Mode** | High (offline validation) | High | 5 | Phase 3-4 |
| **Stat Weight Calculator** | Medium (gear optimization) | High | 6 | Phase 4 |
| **Multi-Target Logic** | Medium (AoE improvements) | Medium | 7 | Phase 3 |
| **Haste Breakpoints** | Medium (DoT optimization) | Low | 8 | Phase 3 |
| **Gear Comparison** | Medium (DPS improvements) | High | 9 | Phase 4 |
| **DPS Reporting** | Low (QoL feature) | Low | 10 | Phase 4 |
| **Encounter Scripts** | Low (raid optimization) | High | 11 | Phase 5 |

---

## Phase 1: Foundation (Weeks 1-6)
**Theme**: Testing Infrastructure + Library Standardization Framework
**Dependencies**: None - this is the foundation phase
**Parallel Work Streams**: Yes - 3 parallel tracks

### Work Unit 1.1: Test Framework Infrastructure
**Category**: `deep` (complex infrastructure)
**Skill Required**: Lua testing frameworks, CI/CD
**Deliverables**:
- [ ] `tests/` directory structure
- [ ] Busted configuration (`.busted`)
- [ ] `tests/mocks/WoWAPIMock.lua` (comprehensive WoW API mocking)
- [ ] `tests/helpers/rotation_test_utils.lua` (test utilities)
- [ ] GitHub Actions workflow (`.github/workflows/test.yml`)
- [ ] Coverage reporting (`.luacov`)
- [ ] Initial test suite for 1-2 representative specs (WarriorArms, MageFire)

**TDD Approach**:
1. Write tests FIRST for existing rotation behavior
2. Verify tests fail/pass against current implementation
3. Use as regression suite for future changes

**Success Criteria**:
- `busted tests/` runs without errors
- Coverage report shows >20% coverage for tested specs
- CI passes on every PR

**Atomic Commit Strategy**:
```
feat(tests): add busted test framework infrastructure

- Add WoWAPIMock.lua with 50+ API function mocks
- Add test utilities for rotation priority testing
- Setup CI/CD with GitHub Actions
- Add initial test suite for EAXWarriorArms rotation

Refs: #test-infrastructure
```

### Work Unit 1.2: Library Standardization Framework - Core Patterns
**Category**: `deep` (multi-file refactoring)
**Skill Required**: Lua, pattern standardization, code generation
**Deliverables**:
- [ ] Create `standards/` directory with reference implementations
- [ ] Define `standards/utils_reference.lua` (canonical utils pattern)
- [ ] Define `standards/spell_resolver_reference.lua` (canonical resolver)
- [ ] Define `standards/menu_reference.lua` (canonical menu structure)
- [ ] Create automated consistency checker (`tools/check_library_consistency.py`)
- [ ] Generate per-spec compliance reports
- [ ] Update 3 pilot specs to match standards (WarriorArms, MageFire, RogueCombat)

**Architecture Principle**:
Each spec maintains its own `libraries/` directory, but all follow identical patterns from `standards/`:
```lua
-- EAXWarriorFury/libraries/utils.lua (STANDARDIZED)
-- Functionally identical to EAXMageFire/libraries/utils.lua
-- but independently packaged for standalone distribution
local Utils = {}
function Utils.resolve_spell_id(spell_ranks) ... end  -- Standard pattern
return Utils
```

**Sync Strategy**:
1. Standards defined in `standards/` directory
2. Each spec's libraries are derived from these standards
3. `tools/sync_library_updates.py` propagates approved changes to all specs
4. Drift detection alerts when specs diverge from standards

**TDD Approach**:
1. Write tests for standard library functions
2. Standardize library maintaining exact behavior
3. Verify specs match standards and pass same tests

**Success Criteria**:
- 3 pilot specs match reference standards
- Consistency checker reports >95% pattern compliance
- No runtime errors in 48-hour stability test

**Atomic Commit Strategy**:
```
feat(standards): establish library standardization framework

- Add standards/ directory with reference implementations
- Add tools/check_library_consistency.py for automated checking
- Update EAXWarriorArms, EAXMageFire, EAXRogueCombat to match standards
- Add standards compliance guide to docs/

Refs: #library-standards
```

### Work Unit 1.3: Library Standardization Framework - Manager Patterns
**Category**: `deep`
**Skill Required**: Lua, middleware patterns
**Deliverables**:
- [ ] Define `standards/managers_reference/` directory
- [ ] Define `ooc_manager_reference.lua` (out-of-combat utilities)
- [ ] Define `burst_manager_reference.lua` (burst CD timing)
- [ ] Define `trinket_manager_reference.lua` (trinket automation)
- [ ] Define `interrupt_manager_reference.lua` (interrupt logic)
- [ ] Define `middleware_manager_reference.lua` (middleware chain)
- [ ] Create manager pattern validation tests

**Dependency Analysis**:
- Blocked by Work Unit 1.2 (core standards must exist first)
- CAN run in parallel with Work Unit 1.1

**Success Criteria**:
- All manager patterns documented in standards/
- Pilot specs match manager reference patterns
- Manager behavior 100% consistent across specs

**Atomic Commit Strategy**:
```
feat(standards): establish manager pattern standards

- Add standards/managers_reference/ with canonical patterns
- Add configuration interfaces for per-spec customization
- Update pilot specs

Refs: #manager-standards
```

---

## Phase 2: Standardization (Weeks 7-12)
**Theme**: APL System + Library Standardization Rollout
**Dependencies**: Phase 1 completion
**Parallel Work Streams**: Yes - 2 parallel tracks

### Work Unit 2.1: Library Standardization Rollout - All 29 Specs
**Category**: `coding` (high volume, low complexity per spec)
**Skill Required**: Lua, refactoring
**Deliverables**:
- [ ] Update remaining 26 specs to match reference standards
- [ ] Automated consistency checker runs in CI
- [ ] Per-spec compliance reports generated
- [ ] Archive original spec copies to `archive_original_specs/`

**Dependency Analysis**:
- Blocked by Work Units 1.2, 1.3 (standards must be defined)
- CAN run incrementally (5 specs per batch)

**TDD Approach**:
1. Each spec gets tests BEFORE standardization
2. Update to match reference patterns
3. Verify tests still pass
4. Consistency checker prevents future divergence

**Success Criteria**:
- 100% of specs match reference standards
- Consistency checker reports >95% compliance in CI
- Zero regressions in rotation behavior
- Pattern standardization: ~30 library types across 29 specs = 870 files (no consolidation, but standardized patterns)

**Atomic Commit Strategy** (per 5-spec batch):
```
refactor(specs): standardize specs 1-5 to reference patterns

- EAXDruidBalance, EAXDruidBear, EAXDruidFeral, EAXDruidResto, EAXHunterBM
- Update libraries to match reference patterns
- All tests pass

Refs: #library-standardization-rollout
```

### Work Unit 2.2: APL (Action Priority List) Parser
**Category**: `ultrabrain` (complex parser logic)
**Skill Required**: Lua, parsing, compiler design basics
**Deliverables**:
- [ ] `standards/apl/` directory with reference implementation
- [ ] `apl/parser_reference.lua` - Parse SimC-style APL syntax
- [ ] `apl/executor_reference.lua` - Execute parsed APL
- [ ] `apl/conditions_reference.lua` - Condition evaluation (buff.x.up, cooldown.x.remains, etc.)
- [ ] `apl/actions_reference.lua` - Action definitions
- [ ] Sample APL files for 3 specs (WarriorFury, MageFire, RogueCombat)
- [ ] APL-to-Lua compiler for static optimization
- [ ] Per-spec APL integration (each spec includes APL files in its standalone package)

**APL Syntax Support**:
```
# Sample APL for Warrior Fury
actions=auto_attack
actions+=/bloodthirst,if=rage>=30&(!buff.death_wish.up|cooldown.death_wish.remains>5)
actions+=/whirlwind,if=rage>=25&target.adds>1
actions+=/heroic_strike,if=rage>=50&cooldown.bloodthirst.remains>1
```

**Dependency Analysis**:
- CAN run in parallel with Work Unit 2.1
- Blocked by Work Unit 1.2 (needs standardized utils)

**TDD Approach**:
1. Write parser tests for each APL syntax element
2. Implement parser incrementally
3. Test against SimC reference APLs
4. Validate with wowsims/tbc rotation outputs

**Success Criteria**:
- Parser handles 90% of common SimC APL syntax
- APL files produce identical rotation behavior as hand-coded Lua
- APL condition evaluation matches SimC exactly
- Performance: <1ms per APL evaluation

**Atomic Commit Strategy**:
```
feat(apl): implement SimC-style APL parser and executor

- Add standards/apl/ with reference implementation
- Add apl/parser_reference.lua with full syntax support
- Add apl/executor_reference.lua with condition evaluation
- Add sample APLs for WarriorFury, MageFire, RogueCombat
- Tests for parser and executor

Refs: #apl-system
```

### Work Unit 2.3: Test Coverage Expansion
**Category**: `coding`
**Skill Required**: Lua testing
**Deliverables**:
- [ ] Tests for all 29 specs (minimum smoke tests)
- [ ] Priority logic tests for each spec
- [ ] Integration tests for standardized libraries
- [ ] API compliance validation tests
- [ ] Coverage reporting in CI (>50% coverage target)

**Dependency Analysis**:
- Blocked by Work Unit 1.1 (test framework)
- CAN run in parallel with other Phase 2 work

**Success Criteria**:
- Every spec has at least 5 priority logic tests
- Standard library patterns have >80% coverage
- CI fails if coverage drops below 50%

**Atomic Commit Strategy** (per 5-spec batch):
```
test(specs): add test coverage for specs 1-5

- Add priority logic tests for rotation verification
- Add smoke tests for basic rotation flow
- Achieve >50% coverage per spec

Refs: #test-coverage
```

---

## Phase 3: Advanced Rotation Engine (Weeks 13-20)
**Theme**: MajorCooldown System + Simulation + Multi-Target
**Dependencies**: Phase 2 completion, APL system
**Parallel Work Streams**: Yes - 2 parallel tracks

### Work Unit 3.1: MajorCooldown (MCD) System
**Category**: `ultrabrain` (complex priority system)
**Skill Required**: Lua, priority queues, simulation concepts
**Deliverables**:
- [ ] `standards/mcd/` directory with reference implementation
- [ ] `mcd/manager_reference.lua` - Priority-based cooldown management
- [ ] `mcd/cooldown_reference.lua` - Cooldown object with CanActivate/ShouldActivate
- [ ] `mcd/priority_reference.lua` - Priority constants and sorting
- [ ] `mcd/scheduler_reference.lua` - Usage timing optimization
- [ ] Integration with flux force commands
- [ ] MCD-aware rotation for 3 pilot specs

**wowsims/tbc Pattern Adaptation**:
```lua
-- Cooldown with priority and conditions
local recklessness = {
    spell = A.Recklessness,
    priority = 100,  -- Higher = more important
    type = "burst",
    
    CanActivate = function(context)
        return context.in_combat and 
               context.target_hp > 80 and  -- Don't waste on low HP
               not context.has_recklessness
    end,
    
    ShouldActivate = function(context)
        -- Optimization: use with other CDs
        return context.time_to_die > 20 or
               context.burst_phase == "opener"
    end
}
```

**Dependency Analysis**:
- Blocked by Phase 2 (needs APL for condition evaluation)
- Blocked by Work Unit 1.2 (needs standardized infrastructure)

**TDD Approach**:
1. Write tests for MCD priority sorting
2. Implement CanActivate/ShouldActivate separation
3. Test CD timing optimization
4. Validate against wowsims cooldown usage patterns

**Success Criteria**:
- MCD system matches wowsims priority behavior
- Cooldown usage improves DPS by >5% vs naive usage
- Force commands properly override MCD scheduling
- Tests cover all MCD edge cases (shared CDs, etc.)

**Atomic Commit Strategy**:
```
feat(mcd): implement MajorCooldown system

- Add standards/mcd/ with reference implementation
- Add mcd/manager_reference.lua with priority-based scheduling
- Add CanActivate/ShouldActivate separation
- Add integration with force commands
- Add MCD system to WarriorFury as pilot
- Comprehensive tests for MCD logic

Refs: #mcd-system
```

### Work Unit 3.2: Simulation Mode (Offline Validation)
**Category**: `ultrabrain` (most complex feature)
**Skill Required**: Lua, simulation, game mechanics modeling
**Deliverables**:
- [ ] `standards/simulation/` directory with reference implementation
- [ ] `simulation/engine_reference.lua` - Event-driven simulation loop
- [ ] `simulation/player_reference.lua` - Player state modeling
- [ ] `simulation/target_reference.lua` - Target/boss modeling
- [ ] `simulation/spell_reference.lua` - Spell effect simulation
- [ ] `simulation/rotation_runner_reference.lua` - Run rotation in simulation
- [ ] `simulation/report_reference.lua` - DPS/TPS reporting
- [ ] CLI tool for running simulations (`tools/simulate.lua`)

**Simulation Engine Features**:
- Event-driven time advancement (like wowsims)
- GCD, cooldown, buff/debuff tracking
- Damage calculation (spell coefficients, stats)
- Combat time-to-death (TTD) estimation
- Multiple iterations for statistical significance

**Dependency Analysis**:
- Blocked by all prior phases (needs full rotation engine)
- Blocked by Work Unit 3.1 (needs MCD for accurate simulation)

**TDD Approach**:
1. Write tests for simulation engine components
2. Implement event loop with test scenarios
3. Validate against known TBC spell damage values
4. Compare simulation DPS with wowsims reference

**Success Criteria**:
- Simulation DPS within 5% of wowsims/tbc for same gear/talents
- Can run 1000 iterations in <10 seconds
- Produces detailed breakdown (spell usage, DPS by spell)
- CLI tool usable for regression testing

**Atomic Commit Strategy**:
```
feat(sim): implement offline simulation mode

- Add standards/simulation/ with reference implementation
- Add simulation/engine_reference.lua with event-driven loop
- Add player/target/spell modeling
- Add rotation_runner for testing rotations offline
- Add DPS/TPS reporting with detailed breakdowns
- CLI tool for running simulations
- Validation tests against wowsims reference

Refs: #simulation-mode
```

### Work Unit 3.3: Multi-Target Logic Enhancement
**Category**: `coding`
**Skill Required**: Lua, AoE patterns
**Deliverables**:
- [ ] `standards/aoe/` directory with reference implementation
- [ ] `aoe/target_counter_reference.lua` - Intelligent enemy counting
- [ ] `aoe/positioning_reference.lua` - AoE positioning optimization
- [ ] `aoe/rotation_switcher_reference.lua` - Single-target vs AoE rotation switching
- [ ] `aoe/spells_reference.lua` - AoE spell definitions and thresholds
- [ ] Update 5 specs with enhanced multi-target logic

**Features**:
- Real enemy counting (not just nameplate scan)
- Position-based AoE hit prediction
- Rotation switching based on target count
- Dot spreading optimization

**Dependency Analysis**:
- CAN run in parallel with Work Units 3.1, 3.2
- Blocked by Work Unit 1.2 (needs standardized infrastructure)

**TDD Approach**:
1. Write tests for target counting with mocked enemies
2. Implement positioning calculation
3. Test rotation switching logic
4. Validate AoE predictions in simulation

**Success Criteria**:
- Target counting accurate within ±1 enemy
- AoE rotation activates at correct thresholds
- DPS improved in multi-target scenarios vs single-target rotation

**Atomic Commit Strategy**:
```
feat(aoe): implement multi-target logic system

- Add standards/aoe/ with reference implementation
- Add aoe/target_counter_reference.lua with position-based counting
- Add aoe/positioning_reference.lua for hit prediction
- Add aoe/rotation_switcher_reference.lua for ST/AoE switching
- Update WarriorFury, MageFire with enhanced AoE
- Tests for all AoE components

Refs: #multi-target
```

---

## Phase 4: Optimization Tools (Weeks 21-26)
**Theme**: Stat Weights + Gear Comparison + DPS Reporting
**Dependencies**: Phase 3 completion, simulation working
**Parallel Work Streams**: Yes - 2 parallel tracks

### Work Unit 4.1: Stat Weight Calculator
**Category**: `ultrabrain`
**Skill Required**: Lua, statistics, differential analysis
**Deliverables**:
- [ ] `standards/optimization/stat_weights_reference.lua`
- [ ] Differential simulation approach (+stat vs -stat)
- [ ] EP (Equivalency Point) calculation
- [ ] Hit cap detection and special handling
- [ ] Export to CSV/JSON for external tools
- [ ] CLI tool (`tools/calc_stat_weights.lua`)

**Algorithm** (adapted from wowsims/tbc):
```lua
function calculate_stat_weights(stats_to_weigh, reference_stat)
    -- 1. Baseline simulation
    local baseline_dps = run_simulation()
    
    -- 2. For each stat, run +mod and -mod simulations
    for _, stat in ipairs(stats_to_weigh) do
        local dps_high = run_simulation({[stat] = +stat_mod})
        local dps_low = run_simulation({[stat] = -stat_mod})
        
        -- Weight = (dps_diff) / stat_value
        weights[stat] = (dps_high - dps_low) / (2 * stat_mod)
        
        -- EP value = weight / reference_weight
        ep_values[stat] = weights[stat] / weights[reference_stat]
    end
    
    return weights, ep_values
end
```

**Dependency Analysis**:
- Blocked by Work Unit 3.2 (needs simulation engine)
- CAN run in parallel with Work Unit 4.2

**TDD Approach**:
1. Write tests for differential calculation
2. Implement stat weight algorithm
3. Validate EP values against known TBC weights
4. Test hit cap handling

**Success Criteria**:
- Stat weights within 10% of wowsims/tbc values
- Hit cap properly detected (weight drops near cap)
- Export format compatible with Pawn/TradeSkillMaster
- Calculation completes in <5 minutes for full stat set

**Atomic Commit Strategy**:
```
feat(opt): implement stat weight calculator

- Add standards/optimization/stat_weights_reference.lua
- Add differential simulation
- Add EP calculation and hit cap handling
- Add CSV/JSON export
- CLI tool for running calculations
- Tests for accuracy against wowsims reference

Refs: #stat-weights
```

### Work Unit 4.2: Gear Comparison System
**Category**: `coding`
**Skill Required**: Lua, item databases
**Deliverables**:
- [ ] `standards/optimization/gear_comparison_reference.lua`
- [ ] Item database integration (TBC items)
- [ ] Automatic gear comparison tests
- [ ] DPS delta calculation per item
- [ ] Upgrade finder (search all items for upgrades)
- [ ] Export results to usable format

**Dependency Analysis**:
- Blocked by Work Unit 3.2 (needs simulation)
- CAN run in parallel with Work Unit 4.1

**Success Criteria**:
- Can compare any two gear sets and show DPS delta
- Upgrade finder identifies actual upgrades
- Results match wowsims gear comparisons

**Atomic Commit Strategy**:
```
feat(opt): add gear comparison system

- Add standards/optimization/gear_comparison_reference.lua
- Add item database
- Add automatic DPS comparison
- Add upgrade finder
- Tests for comparison accuracy

Refs: #gear-comparison
```

### Work Unit 4.3: DPS Reporting and Dashboard
**Category**: `visual-engineering`
**Skill Required**: Lua, UI
**Deliverables**:
- [ ] Enhanced dashboard with DPS breakdown
- [ ] Spell usage histogram
- [ ] Buff/debuff uptime tracking
- [ ] Real-time DPS estimation
- [ ] Combat log integration
- [ ] Post-combat summary

**Dependency Analysis**:
- Blocked by Work Unit 3.2 (needs simulation metrics)
- CAN run in parallel with other Phase 4 work

**Success Criteria**:
- Dashboard shows accurate DPS estimate
- Spell breakdown matches simulation results
- Uptime tracking accurate

**Atomic Commit Strategy**:
```
feat(ui): enhanced DPS reporting dashboard

- Add spell usage breakdown
- Add buff/debuff uptime tracking
- Add real-time DPS estimation
- Add post-combat summary

Refs: #dps-reporting
```

---

## Phase 5: Advanced Features (Weeks 27-30)
**Theme**: Haste Breakpoints + Encounter Scripts + Polish
**Dependencies**: Phase 4 completion
**Parallel Work Streams**: Limited - mostly sequential

### Work Unit 5.1: Haste Breakpoint Calculator
**Category**: `coding` (mathematical modeling)
**Skill Required**: Lua, TBC mechanics knowledge
**Deliverables**:
- [ ] `standards/optimization/haste_breakpoints_reference.lua`
- [ ] DoT tick calculation with haste
- [ ] Clipping loss estimation
- [ ] Optimal refresh timing calculator
- [ ] Integration with 3 caster specs

**Dependency Analysis**:
- CAN run in parallel with other Phase 5 work
- Blocked by Phase 3 (needs standardized infrastructure)

**TDD Approach**:
1. Write tests for haste calculation accuracy
2. Implement DoT tick math
3. Validate against known TBC haste breakpoints
4. Test clipping loss estimation

**Success Criteria**:
- Haste breakpoints accurate to within 1ms
- DoT refresh recommendations improve DPS
- No DoT clipping losses >5%

**Atomic Commit Strategy**:
```
feat(opt): implement haste breakpoint calculator

- Add standards/optimization/haste_breakpoints_reference.lua
- Add DoT tick calculation
- Add clipping loss estimation
- Add optimal refresh timing
- Integrate with MageFire, WarlockAffliction, PriestShadow
- Tests for breakpoint accuracy

Refs: #haste-breakpoints
```

### Work Unit 5.2: Encounter Scripts
**Category**: `deep` (complex encounter logic)
**Skill Required**: Lua, encounter design
**Deliverables**:
- [ ] `standards/encounters/` directory
- [ ] `encounters/base_reference.lua` - Base encounter class
- [ ] `encounters/tbc_sunwell_reference.lua` - Sunwell bosses
- [ ] `encounters/tbc_black_temple_reference.lua` - BT bosses
- [ ] Phase detection and rotation adaptation
- [ ] Encounter-specific cooldown timing

**Dependency Analysis**:
- Blocked by all prior phases
- CAN run incrementally per raid tier

**Success Criteria**:
- Phase detection accurate for 5+ encounters
- DPS improves vs generic rotation in encounters
- Cooldown timing optimized per phase

**Atomic Commit Strategy**:
```
feat(enc): add encounter-specific rotation scripts

- Add standards/encounters/ with reference implementations
- Add encounters/base_reference.lua with phase detection
- Add Sunwell and Black Temple encounters
- Add phase-specific rotation adaptation
- Add encounter-specific CD timing
- Tests for phase detection accuracy

Refs: #encounter-scripts
```

### Work Unit 5.3: Final Integration and Documentation
**Category**: `writing` + `coding`
**Skill Required**: Documentation, integration testing
**Deliverables**:
- [ ] Complete documentation for all new systems
- [ ] Library standardization guide for spec authors
- [ ] Performance benchmarks
- [ ] Final integration tests
- [ ] Release notes and changelog
- [ ] Training materials for new contributors
- [ ] Per-spec distribution packaging guide

**Success Criteria**:
- All 29 specs match library standards
- Documentation covers all public APIs
- Standardization guide tested with external contributor
- Performance meets targets (<5ms per rotation decision)
- Standalone .zip packaging documented and tested

**Atomic Commit Strategy**:
```
docs: complete documentation and standardization guide

- Add comprehensive API documentation
- Add library standardization guide for spec authors
- Add performance benchmarks
- Add training materials
- Add per-spec packaging documentation
- Final integration tests

Refs: #documentation
```

---

## Dependency Graph

```
Phase 1: Foundation
├── 1.1 Test Framework ────────┐
├── 1.2 Standards (Core) ────────┼──→ 2.1 Standards Rollout
└── 1.3 Standards (Managers) ──────┘

Phase 2: Standardization
├── 2.1 Standards Rollout ──────┐
├── 2.2 APL System ─────────────┼──→ 3.1 MCD System
└── 2.3 Test Coverage ──────────┘   └──→ 3.3 AoE Logic

Phase 3: Advanced Engine
├── 3.1 MCD System ─────────────┐
├── 3.2 Simulation Mode ──────────┼──→ 4.1 Stat Weights
└── 3.3 AoE Logic ────────────────┼──→ 4.2 Gear Comparison
                              └──→ 4.3 DPS Reporting

Phase 4: Optimization
├── 4.1 Stat Weights ───────────┐
├── 4.2 Gear Comparison ────────┼──→ 5.1 Haste Breakpoints
└── 4.3 DPS Reporting ────────┼──→ 5.2 Encounter Scripts
                              └──→ 5.3 Documentation

Phase 5: Polish
├── 5.1 Haste Breakpoints
├── 5.2 Encounter Scripts
└── 5.3 Documentation
```

---

## Parallel Work Stream Assignments

**Stream A: Infrastructure (Phases 1-2)**
- Work Units: 1.1, 1.2, 2.1, 2.3
- Focus: Testing + Library Standards
- Estimated Duration: 6 weeks

**Stream B: Engine Development (Phases 2-3)**
- Work Units: 1.3, 2.2, 3.1, 3.3
- Focus: APL + MCD + AoE
- Estimated Duration: 6 weeks
- Can start after Stream A Week 2

**Stream C: Simulation & Optimization (Phases 3-4)**
- Work Units: 3.2, 4.1, 4.2, 4.3
- Focus: Simulation + Stat Weights + Gear
- Estimated Duration: 6 weeks
- Can start after Stream B Week 4

**Stream D: Polish (Phase 5)**
- Work Units: 5.1, 5.2, 5.3
- Focus: Haste + Encounters + Docs
- Estimated Duration: 4 weeks
- Can start after Streams A, B, C complete

---

## Distribution Model: Standalone .zip with Sync

### Why Standalone?
- **User Experience**: Each spec is a self-contained .zip for Project Sylvanas
- **No Runtime Dependencies**: No shared library loading issues
- **Independent Releases**: Specs can release on different schedules
- **Isolation**: Breaking changes in one spec don't affect others

### How Sync Works
1. **Standards Repository** (`standards/`): Canonical reference implementations
2. **Per-Spec Libraries** (`EAX*/libraries/`): Independent copies matching standards
3. **Sync Tool** (`tools/sync_library_updates.py`): Propagates approved changes to all specs
4. **Consistency Checker** (`tools/check_library_consistency.py`): Validates all specs match standards

### Sync Workflow
```bash
# 1. Update reference implementation
edit standards/utils_reference.lua

# 2. Review and test changes
git commit -m "feat(standards): improve spell resolution caching"

# 3. Sync to all specs
python tools/sync_library_updates.py --library=utils --specs=all

# 4. Verify consistency
python tools/check_library_consistency.py
# Output: All 29 specs match utils_reference.lua ✓
```

---

## Atomic Commit Strategy Summary

**Commit Message Format**:
```
<type>(<scope>): <short description>

<body>

Refs: #<issue-number>
```

**Types**:
- `feat`: New feature
- `fix`: Bug fix
- `refactor`: Code restructuring
- `test`: Adding or correcting tests
- `docs`: Documentation only
- `standards`: Reference implementation updates

**Scopes**:
- `standards`: Reference implementations
- `tests`: Test infrastructure
- `specs`: Individual spec updates
- `apl`: APL system
- `mcd`: MajorCooldown system
- `sim`: Simulation mode
- `opt`: Optimization tools
- `enc`: Encounter scripts
- `sync`: Library sync tooling

**Commit Size Guidelines**:
- Max 1 work unit per commit series
- Each commit should be deployable (passes CI)
- Rollback-safe (each commit can be reverted independently)

---

## Verification and Success Metrics

**Phase 1 Success**:
- [ ] Test framework runs: `busted tests/` → 0 failures
- [ ] Reference standards in `standards/` (>5 reference files)
- [ ] Pilot specs standardized: 3 specs matching references
- [ ] Coverage: >20% for tested specs
- [ ] Consistency checker operational

**Phase 2 Success**:
- [ ] All specs match standards: >95% pattern compliance (29/29)
- [ ] APL parser: Handles 90% of SimC syntax
- [ ] Test coverage: >50% overall
- [ ] Each spec has APL files in its standalone package

**Phase 3 Success**:
- [ ] MCD system: Matches wowsims priority behavior
- [ ] Simulation: DPS within 5% of wowsims
- [ ] AoE logic: Target counting accurate
- [ ] Performance: <5ms per rotation decision

**Phase 4 Success**:
- [ ] Stat weights: Within 10% of wowsims
- [ ] Gear comparison: Functional for all specs
- [ ] DPS reporting: Real-time dashboard
- [ ] Export compatibility: Works with Pawn/TSM

**Phase 5 Success**:
- [ ] Haste breakpoints: Accurate DoT refresh
- [ ] Encounter scripts: 5+ encounters supported
- [ ] Documentation: Complete API docs
- [ ] Training materials: New contributor can onboard
- [ ] Standalone packaging: All 29 specs build as .zip

---

## Risk Mitigation

**Risk 1: Library Pattern Drift**
- Mitigation: Automated consistency checker in CI
- Mitigation: Sync tool for propagating approved changes
- Mitigation: Standards changelog tracking all modifications

**Risk 2: Simulation Accuracy**
- Mitigation: Validate against wowsims reference data
- Mitigation: Incremental validation (test each component)

**Risk 3: Runtime Performance**
- Mitigation: Performance benchmarks in CI
- Mitigation: Profile before/after each phase

**Risk 4: Spec Maintainer Adoption**
- Mitigation: Comprehensive standardization guide
- Mitigation: Standards documentation with clear examples
- Mitigation: Training sessions for maintainers

**Risk 5: Project Scope Creep**
- Mitigation: Strict phase gates
- Mitigation: Success criteria defined upfront
- Mitigation: Regular reviews against plan

---

## Appendix A: TDD Test Patterns

### Pattern 1: Priority List Test
```lua
describe("Warrior Fury Priority", function()
    it("should cast Bloodthirst when rage >= 30 and cooldown ready", function()
        WoWAPIMock.SetGameState({
            rage = 35,
            in_combat = true
        })
        WoWAPIMock.SetSpellCooldown(23881, 0, 0)  -- BT ready
        
        local rotation = Rotation.new("fury")
        local spell = rotation:getNextSpell()
        
        assert.are.equal("Bloodthirst", spell.name)
    end)
end)
```

### Pattern 2: MCD Priority Test
```lua
describe("MCD Priority System", function()
    it("should use higher priority CD first", function()
        local mcd_manager = MCDManager.new()
        
        mcd_manager:add({spell = "Recklessness", priority = 100})
        mcd_manager:add({spell = "Bloodrage", priority = 50})
        
        local next_cd = mcd_manager:getNextCooldown({in_combat = true})
        
        assert.are.equal("Recklessness", next_cd.spell)
    end)
end)
```

### Pattern 3: Simulation Validation Test
```lua
describe("Simulation Accuracy", function()
    it("should match wowsims DPS within 5%", function()
        local sim = Simulation.new({duration = 180})
        local result = sim:runRotation("fury", WARRIOR_FURY_GEAR)
        
        local reference_dps = 1850  -- From wowsims
        local delta = math.abs(result.dps - reference_dps) / reference_dps
        
        assert.is_true(delta < 0.05, "DPS delta " .. delta .. " exceeds 5%")
    end)
end)
```

### Pattern 4: APL Execution Test
```lua
describe("APL Execution", function()
    it("should execute APL conditions correctly", function()
        local apl = APL.new()
        apl:parse("bloodthirst,if=rage>=30")
        
        WoWAPIMock.SetGameState({rage = 35})
        local action = apl:selectAction()
        
        assert.are.equal("Bloodthirst", action.spell)
    end)
end)
```

### Pattern 5: Library Consistency Test
```lua
describe("Library Standardization", function()
    it("all specs should have identical utils.resolve_spell_id", function()
        local reference = loadfile("standards/utils_reference.lua")
        
        for _, spec in ipairs(SPECS) do
            local spec_utils = loadfile(spec .. "/libraries/utils.lua")
            assert.are.same(reference.resolve_spell_id, spec_utils.resolve_spell_id,
                spec .. " utils.resolve_spell_id differs from standard")
        end
    end)
end)
```

---

## Appendix B: Project Sylvanas API Integration Notes

**Critical Patterns**:
- Always cache API references: `local _core_time = core.time`
- Use nil-guarded menu access: `(menu.x and menu.x:get()) or default`
- Throttle expensive calls: `combat_context.build()` → 2s throttle
- Use squared distance for range checks

**IZI SDK Integration**:
```lua
local izi = require("common/izi_sdk")
local spell = izi.spell(spell_id)

if spell:cooldown_up() and spell:can_cast(target) then
    spell:cast(target)
end
```

**Buff Manager Integration**:
```lua
local buff_manager = require("common/modules/buff_manager")
local data = buff_manager:get_buff(unit, buff_id)
```

---

## Appendix C: Library Standardization Guide for Spec Authors

**Step 1: Reference the Standards**
```lua
-- When implementing utils.lua, follow:
-- standards/utils_reference.lua
-- standards/utils_test.lua (shows expected behavior)
```

**Step 2: Maintain Identical Patterns**
```lua
-- Your libraries/utils.lua must match the reference:
local Utils = {}

-- Function signature must match exactly
function Utils.resolve_spell_id(spell_ranks)
    -- Implementation can vary slightly but behavior must match
    -- See standards for exact expected behavior
end

return Utils
```

**Step 3: Validate Against Standards**
```bash
# Before committing, run:
python tools/check_library_consistency.py --spec=EAXYourSpec

# Output should show: PASS - All libraries match standards
```

**Step 4: Sync Updates**
```bash
# When standards are updated, sync to your spec:
python tools/sync_library_updates.py --library=utils --specs=EAXYourSpec

# Review changes and commit
```

**Step 5: Test**
```bash
# Run tests to verify standardization didn't break anything
busted tests/EAXYourSpec/
luac -p EAXYourSpec/main.lua
```

---

## Appendix D: Standalone .zip Packaging

**Build Process**:
```bash
# For each spec:
python tools/package_spec.py --spec=EAXWarriorFury --output=dist/

# Output: dist/EAXWarriorFury_v2.1.0.zip
# Contains:
#   - main.lua
#   - header.lua
#   - plugin_info.lua
#   - libraries/ (all standardized libs)
#   - apls/ (APL rotation files)
```

**Distribution Structure**:
```
EAXWarriorFury_v2.1.0.zip
├── main.lua              # Entry point
├── header.lua            # Metadata
├── plugin_info.lua       # Version info
├── libraries/            # Standardized libraries (self-contained)
│   ├── utils.lua
│   ├── spell_resolver.lua
│   ├── menu.lua
│   ├── spells.lua
│   ├── combat_context.lua
│   ├── ooc_manager.lua
│   └── ...
└── apls/                 # APL rotation definitions
    ├── fury_single.apl
    └── fury_aoe.apl
```

**Versioning**:
- Each spec versions independently
- Standard library updates bump minor version
- Spec-specific features bump patch version
- Breaking changes bump major version

---

*This plan is designed for ultrawork execution with clear parallel tracks, atomic commits, and TDD validation at each phase. All 29 specs remain standalone for distribution while maintaining synchronized library patterns through the standards framework.*
