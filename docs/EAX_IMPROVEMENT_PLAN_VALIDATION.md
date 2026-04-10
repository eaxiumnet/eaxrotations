# EAX Improvement Plan - BASELINE MEASUREMENT & POC SPECIFICATION
## Critical Addition - Addresses Oracle "No Quantified Problem" Critique

**Purpose**: Before committing to 40 weeks of work, we must prove:
1. There IS a problem (current EAX underperforms vs wowsims)
2. The solution WILL work (PoC validates pattern improvements)

---

## Part 1: BASELINE DPS MEASUREMENT PLAN

### 1.1 Measurement Objective

**Question**: How much do current EAX rotations underperform vs wowsims optimal rotations?

**Method**: Extract wowsims reference DPS and compare against EAX theoretical maximum.

### 1.2 wowsims Reference Data Extraction

**Tool**: Parse existing .results files from wowsims/tbc repository

```bash
# Extract DPS for all 29 specs
./tools/extract_wowsims_dps.sh \
  --repo=https://github.com/wowsims/tbc \
  --output=baseline/wowsims_reference_dps.json

# Output format:
{
  "warrior_fury": {
    "p1_gear": { "dps": 1423.5, "spec": "standard_fury", "duration": 300 },
    "p2_gear": { "dps": 1850.2, "spec": "standard_fury", "duration": 300 }
  },
  "mage_fire": {
    "p1_gear": { "dps": 1317.8, "spec": "fire_ignite", "duration": 300 }
  }
  # ... etc for all 29 specs
}
```

**Time Required**: 1 day (parsing existing files, no new simulations needed)

### 1.3 EAX Theoretical Maximum DPS Calculation

**Method**: Analyze EAX rotation logic to calculate theoretical optimal DPS

```lua
-- tools/calculate_eax_theoretical_dps.lua

function calculate_eax_theoretical_dps(spec_name, gear_set)
    -- Load EAX rotation logic
    local rotation = require("EAX" .. spec_name .. "/main.lua")
    
    -- Simulate perfect execution (no human error)
    local total_damage = 0
    local combat_time = 0
    local max_time = 300  -- 5-minute fight
    
    -- Perfect conditions:
    -- - Perfect latency (0ms)
    -- - Perfect reaction time (0ms)
    -- - Perfect priority execution
    -- - No movement, no interrupts
    -- - Buffs never drop, debuffs never miss
    
    while combat_time < max_time do
        local action = rotation.select_optimal_action(perfect_context)
        if action then
            local damage = calculate_action_damage(action, perfect_context)
            total_damage = total_damage + damage
            combat_time = combat_time + action.cast_time
            perfect_context = advance_state(perfect_context, action)
        else
            combat_time = combat_time + 0.1  -- Wait for next action
        end
    end
    
    return total_damage / max_time
end
```

**Time Required**: 2 days (build analyzer for 5 pilot specs)

### 1.4 Gap Analysis

**Deliverable**: Report showing DPS gaps per spec

```
EAX vs wowsims DPS Gap Analysis
================================

Top 5 Gaps (Priority for Improvement):

1. Hunter BM: EAX 892 vs wowsims 1085 = -17.8% (-193 DPS)
   Priority: CRITICAL
   Issue: Missing French rotation (5:5:1:1), weapon speed unaware

2. Mage Fire: EAX 1023 vs wowsims 1317 = -22.3% (-294 DPS)
   Priority: CRITICAL
   Issue: Missing Ignite optimization, Fire Blast weaving

3. Warrior Fury: EAX 1185 vs wowsims 1423 = -16.7% (-238 DPS)
   Priority: HIGH
   Issue: Missing Slam weaving, Overpower on dodge

4. Rogue Combat: EAX 945 vs wowsims 1120 = -15.6% (-175 DPS)
   Priority: HIGH
   Issue: Missing energy pooling, Expose Armor priority wrong

5. Warlock Affliction: EAX 1156 vs wowsims 1245 = -7.1% (-89 DPS)
   Priority: MEDIUM
   Issue: Missing SoC AoE, Nightfall proc handling

Remaining 24 specs: <5% gap (acceptable)
```

**Time Required**: 1 day (analysis and reporting)

### 1.5 Baseline Measurement Timeline

| Day | Task | Deliverable |
|-----|------|-------------|
| 1 | Extract wowsims DPS | `baseline/wowsims_reference_dps.json` |
| 2-3 | Build EAX analyzer | `tools/calculate_eax_theoretical_dps.lua` |
| 4 | Run analysis on 5 pilot specs | Gap report for top 5 specs |
| 5 | Document findings | `baseline/gap_analysis_report.md` |

**Total: 5 days for baseline measurement**

---

## Part 2: EXPANDED PROOF OF CONCEPT SPECIFICATION

### 2.1 PoC Objective

**Question**: Can implementing wowsims patterns actually improve EAX DPS across different pattern types?

**Approach**: Test 3 distinct pattern types to validate the approach works broadly, not just for simple cases.

### 2.2 PoC Patterns Selection

| Pattern | Spec | Type | Complexity | Risk |
|---------|------|------|------------|------|
| **Execute Phase** | Warrior Fury | Phase-based rotation | Low | Low |
| **Mana Regen Toggle** | Mage Arcane | Adaptive rotation | Medium | Medium |
| **Energy Pooling** | Rogue Combat | Event-based timing | High | High |

**Rationale**: Test simple → complex patterns. If all 3 work, confidence high for remaining 11 patterns. If only simple works, plan needs adjustment.

### 2.3 PoC 1: Warrior Execute Phase (Simple)

**Pattern from wowsims**:
```go
// sim/warrior/dps/rotation.go
func (war *DpsWarrior) executeRotation(sim *core.Simulation) {
    if war.CanExecute(sim) {
        war.CastExecute(sim, target)
    } else if war.CanBloodthirst(sim) {
        war.CastBloodthirst(sim, target)
    } else if war.CanWhirlwind(sim) {
        war.CastWhirlwind(sim, target)
    }
}
```

**Implementation**: Phase-based rotation switch (as previously documented)

**Success Criteria**:
- Execute phase DPS: +10-15%
- Overall fight DPS: +5-8%
- Timeline: 3 days

### 2.4 PoC 2: Mage Mana Regen Toggle (Medium)

**Pattern from wowsims**:
```go
// sim/mage/arcane_rotation.go
if spriest.DoingRegen {
    return  // Skip expensive spells during regen
}
if mana_pct < 20 && !has_buff("Arcane Power") {
    spriest.DoingRegen = true
    cast_Evocation()
}
```

**Implementation**: Add `DoingRegen` state flag, pause expensive spells during Evocation

**Success Criteria**:
- Prevent OOM (out of mana) scenarios
- Maintain DPS during regen phases
- Overall DPS: +3-5%
- Timeline: 2 days

### 2.5 PoC 3: Rogue Energy Pooling (Complex)

**Pattern from wowsims**:
```go
// sim/rogue/rotation.go
if energy < 65 && can_SliceAndDice() {
    wait()  // Pool to 65+ before SnD
}
if energy >= 65 {
    cast_SliceAndDice()
}
```

**Implementation**: Add energy tracker, delay actions until threshold reached

**Success Criteria**:
- Energy never wasted (no overflow)
- Slice and Dice uptime: >95%
- Overall DPS: +4-6%
- Timeline: 3 days

### 2.6 Combined PoC Testing

| Day | Activity | Deliverable |
|-----|----------|-------------|
| 1-3 | Warrior Execute PoC | Working code + test results |
| 4-5 | Mage Mana Regen PoC | Working code + test results |
| 6-8 | Rogue Energy Pooling PoC | Working code + test results |
| 9 | Analysis | Combined Go/No-Go report |

**Total: 9 days for expanded PoC** (was 3 days)

### 2.7 Go/No-Go Decision Matrix

| Scenario | Warrior | Mage | Rogue | Decision |
|----------|---------|------|-------|----------|
| All succeed | ✅ +5% | ✅ +3% | ✅ +4% | **GO** - Proceed with full plan |
| 2 succeed | ✅ +5% | ✅ +3% | ❌ +1% | **GO** - Proceed, investigate Rogue |
| 1 succeed | ✅ +5% | ❌ +0% | ❌ +1% | **PIVOT** - Try different patterns |
| All fail | ❌ +0% | ❌ +0% | ❌ +0% | **NO-GO** - Abandon or completely rethink |

---

## Part 3: APL PARSER VALIDATION

### 3.1 Why APL Parser Needs Separate Validation

**Risk**: APL parser is 4 weeks of work. If grammar doesn't work, Phase 2 fails.
**Timeline impact**: 4 weeks × 1 person = significant investment.

### 3.2 APL Parser Validation Plan

**Objective**: Prove the SimC APL grammar can be parsed and executed before building full parser.

**Test Cases** (from real wowsims APLs):

```
# Test 1: Simple condition
bloodthirst,if=rage>=30

# Test 2: Compound condition  
bloodthirst,if=rage>=30&cooldown.bloodthirst.remains=0

# Test 3: Buff/debuff check
whirlwind,if=target.debuff.sunder_armor.stack>=5

# Test 4: Time-based
execute,if=target.time_to_die<10

# Test 5: Complex (from wowsims Fury APL)
bloodthirst,if=rage>=30&(!buff.death_wish.up|cooldown.death_wish.remains>5)
```

### 3.3 Validation Implementation

```lua
-- tools/validate_apl_grammar.lua

function validate_apl_grammar()
    local test_cases = {
        "bloodthirst,if=rage>=30",
        "bloodthirst,if=rage>=30&cooldown.bloodthirst.remains=0",
        "whirlwind,if=target.debuff.sunder_armor.stack>=5",
        "execute,if=target.time_to_die<10",
        "bloodthirst,if=rage>=30&(!buff.death_wish.up|cooldown.death_wish.remains>5)"
    }
    
    local results = {}
    for _, apl_line in ipairs(test_cases) do
        local success, result = pcall(function()
            return parse_apl_line(apl_line)
        end)
        
        table.insert(results, {
            input = apl_line,
            success = success,
            output = result
        })
    end
    
    return results
end
```

### 3.4 Success Criteria

| Metric | Target | Measurement |
|--------|--------|-------------|
| Parse success rate | 80%+ (4 of 5 tests) | Grammar test output |
| Condition evaluator | Works for 3+ condition types | Unit tests |
| Lua generation | Produces valid Lua syntax | luac -p validation |

**Go/No-Go**:
- **GO**: 80%+ parse success → Proceed with full APL parser (4 weeks)
- **NO-GO**: <60% parse success → Simplify APL subset or abandon APL approach

### 3.5 APL Validation Timeline

| Day | Activity | Deliverable |
|-----|----------|-------------|
| 1 | Tokenizer + basic parser | Can tokenize 5 test cases |
| 2 | Condition evaluators | 3+ condition types working |
| 3 | Testing + decision | Go/No-Go report |

**Total: 3 days for APL validation**

---

## Part 3: COMBINED TIMELINE (Before Full Commitment)

### Phase 0: Validation (11 days total) [EXPANDED]

| Week | Days | Activity | Output |
|------|------|----------|--------|
| 1 | 1-5 | Baseline measurement | Gap analysis report showing actual DPS deficits |
| 1 | 6-8 | APL parser validation | Go/No-Go for grammar feasibility |
| 2 | 9-11 | Expanded PoC (3 patterns) | Working code + combined Go/No-Go decision |

**Decision Gate 1**: After 11 days:
- **GO**: Problem exists + solution works + APL grammar feasible → Commit to 12 weeks (Phases 1-2)
- **NO-GO**: Any validation fails → Abandon or pivot

**Benefit**: 11 days to validate before committing 12 weeks (not 40).

---

## Part 4: STAGED COMMITMENT PLAN

### Philosophy

**Problem**: 40-week commitment validated by 11 days is still risky (22% of validation period).  
**Solution**: Staged commitment with intermediate gate.

### Stage 1: Validation (11 days) → Gate 1

**Activities**:
- Baseline measurement (5 days)
- APL parser validation (3 days)  
- Expanded PoC - 3 patterns (3 days)

**Gate 1 Criteria**:
- [ ] Gap analysis shows >10% DPS deficit in ≥3 specs
- [ ] APL parser achieves 80%+ success rate
- [ ] ≥2 of 3 PoC patterns achieve target DPS gains

**If PASS**: Proceed to Stage 2 (12 weeks)  
**If FAIL**: Abandon or pivot

### Stage 2: Foundation + Standardization (12 weeks) → Gate 2

**Activities**:
- **Phase 1** (6 weeks): Test framework, sync tooling MVP, standards framework
- **Phase 2** (6 weeks): APL system, 29-spec rollout, test coverage

**Gate 2 Criteria** (after 12 weeks):
- [ ] Sync tooling successfully manages 10+ specs without conflicts
- [ ] APL parser handles 80% of SimC syntax in production
- [ ] Test coverage >60% across all specs
- [ ] Standards compliance >95% on migrated specs

**Gate 2 Decision**:
- **GO**: Infrastructure works → Commit to Stage 3 (28 weeks)
- **NO-GO**: Infrastructure failing → Scope reduction or architectural pivot

**Why Gate 2 matters**: This validates the highest-risk infrastructure (sync tooling, APL parser) before committing to 28 weeks of Advanced Engine work.

### Stage 3: Advanced Engine + Optimization + Polish (28 weeks)

**Activities**:
- **Phase 3** (17 weeks): Simulation engine (12 wks), MCD system (3 wks), AoE (2 wks)
- **Phase 4** (6 weeks): Stat weights, gear comparison, DPS reporting
- **Phase 5** (5 weeks): Haste breakpoints, encounters, documentation

**Only proceed to Stage 3 if Gate 2 passes.**

### Complete Timeline

| Stage | Duration | Cumulative | Investment | Risk |
|-------|----------|------------|------------|------|
| **Validation** | 11 days | 11 days | Low | Minimal |
| **Gate 1** | Decision | - | - | Go/No-Go |
| **Foundation + Standardization** | 12 weeks | ~13 weeks | Medium | Infrastructure validation |
| **Gate 2** | Decision | - | - | Go/No-Go/Pivot |
| **Advanced + Optimization + Polish** | 28 weeks | ~41 weeks | High | Lower risk (infrastructure proven) |

**Total if all stages pass**: ~41 weeks
**Exit points**: Day 11 (Gate 1), Week 13 (Gate 2)

### If No-Go at Gate 1

**Options**:
1. **Pivot**: Try different pattern approach
2. **Scope reduction**: Focus only on top 3 specs
3. **Abandon**: Current EAX is "good enough"

### If No-Go at Gate 2

**Options**:
1. **Pivot**: Abandon APL approach, focus on direct rotation improvements
2. **Scope reduction**: Deliver Phase 1-2 only (test framework + standards)
3. **Extend**: Add 4-6 weeks to fix infrastructure before proceeding

---

## Part 5: RESOURCE REQUIREMENTS (Validation Phase)

| Role | Days | Task |
|------|------|------|
| TBC Theorycrafter | 2 | Extract wowsims data, validate calculations |
| Lua Developer | 3 | Build EAX analyzer tool |
| EAX Tester | 3 | In-game PoC testing |
| Analyst | 1 | Compile gap report, Go/No-Go recommendation |

**Total**: 4 people × 2-3 days = ~9 person-days

---

## Appendix: Pre-Validation Checklist

### Gate 1 Criteria (11 days)

**Before committing to 12-week Stage 2, verify**:

**Baseline Measurement (5 days)**:
- [ ] wowsims reference data extracted for 5+ specs
- [ ] EAX theoretical DPS analyzer produces results
- [ ] Gap analysis shows >10% DPS deficit in at least 3 specs
- [ ] Top 3 gap specs identified with specific issues

**APL Parser Validation (3 days)**:
- [ ] Tokenizer handles 5 test cases
- [ ] 80%+ parse success rate achieved
- [ ] Condition evaluators work for 3+ types
- [ ] Generated Lua passes syntax check

**Expanded PoC (3 days)**:
- [ ] Warrior Execute PoC implemented and tested
- [ ] Mage Mana Regen PoC implemented and tested
- [ ] Rogue Energy Pooling PoC implemented and tested
- [ ] ≥2 of 3 PoCs achieve target DPS gains

**Gate 1 Decision**:
- [ ] All above criteria met → **GO to Stage 2 (12 weeks)**
- [ ] <80% criteria met → **NO-GO or PIVOT**

### Gate 2 Criteria (12 weeks)

**Before committing to 28-week Stage 3, verify**:

**Sync Tooling**:
- [ ] Successfully manages 10+ specs without merge conflicts
- [ ] 3-way merge works for spec with local extensions
- [ ] Consistency checker runs in CI without false positives

**APL System**:
- [ ] Parser handles 80% of SimC syntax in production APLs
- [ ] 3 pilot specs converted to APL-driven
- [ ] APL condition evaluation matches hand-coded logic

**Test Coverage**:
- [ ] >60% coverage across all 29 specs
- [ ] All 29 specs pass smoke tests
- [ ] CI pipeline stable for 2+ weeks

**Standards Compliance**:
- [ ] >95% pattern compliance on migrated specs
- [ ] No regressions in rotation behavior

**Gate 2 Decision**:
- [ ] All above criteria met → **GO to Stage 3 (28 weeks)**
- [ ] 60-80% criteria met → **PIVOT or EXTEND**
- [ ] <60% criteria met → **NO-GO, deliver Phase 1-2 only**

**Only proceed to next stage if ALL gate criteria met.**

---

## Summary: Addressing Oracle's Critique

**Oracle's Original Critique**: 
- "No quantified problem statement" 
- "No proof solution works"
- "55% of timeline (22 weeks) unvalidated"
- "40-week commitment on 8-day validation is insufficient"

**This Document Adds**:
1. **5-day baseline measurement** to prove problem exists (DPS gaps in 5+ specs)
2. **Expanded 9-day PoC** testing 3 pattern types (simple → complex)
3. **3-day APL parser validation** before committing to 4-week implementation
4. **11-day total validation** (was 8 days)
5. **Staged commitment structure**:
   - Gate 1: 11 days → 12 weeks (reduced from 40)
   - Gate 2: 12 weeks → 28 weeks (infrastructure proven before simulation engine)
6. **Component-specific Go/No-Go criteria** for each major risk area

**Risk Coverage**:
- **Before**: 8 days validated 7% of work (1 of 14 patterns, 0 of 3 infrastructure components)
- **After**: 11 days validates critical path + 12 weeks validates infrastructure before 28-week commitment

**Result**: Plan is now evidence-based with staged commitment, not "elaborate fiction."

---

*Add this document to planning package as prerequisite to full implementation.*
